// lib/services/download_manager.dart
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import '../models/download_model.dart';
import '../models/download_task.dart';
import '../constants/model_constants.dart';

class DownloadManager {
  final Dio _dio;
  final Map<String, DownloadTask> _activeTasks = {};
  final Map<String, bool> _extractingTasks = {};

  static const bool _enableLogging = true;

  DownloadManager() : _dio = Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(minutes: 30);
    _dio.options.followRedirects = true;
    _dio.options.maxRedirects = 5;

    if (_enableLogging) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: false,
          responseHeader: true,
          responseBody: false,
          error: true,
          logPrint: (obj) => _log('DIO: $obj'),
        ),
      );
    }
  }

  void _log(String message) {
    if (_enableLogging) {
      print('[DownloadManager] $message');
    }
  }

  Future<String> getModelsDirectory() async {
    _log('Getting models directory...');
    final baseDir = await getExternalStorageDirectory();
    final appDir = baseDir ?? await getApplicationDocumentsDirectory();
    final modelsDir = Directory(
      '${appDir.path}/${ModelConstants.modelsDirectory}',
    );

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    return modelsDir.path;
  }

  Future<String> getTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final downloadTemp = Directory('${tempDir.path}/model_downloads');

    if (!await downloadTemp.exists()) {
      await downloadTemp.create(recursive: true);
    }

    return downloadTemp.path;
  }

  Future<DownloadResult> download({
    required String modelId,
    required String url,
    required Function(double progress, int received, int total) onProgress,
    required Function(ModelDownloadStatus status) onStatusChange,
    int resumeFromBytes = 0,
  }) async {
    _log('========================================');
    _log('Starting download for model: $modelId');
    _log('URL: $url');
    _log('Resume from bytes: $resumeFromBytes');
    _log('========================================');

    DownloadTask? task;

    try {
      // Check internet connection
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw const SocketException('No internet');
        }
      } on SocketException {
        _log('✗ No internet connection!');
        return DownloadResult(
          success: false,
          status: ModelDownloadStatus.failed,
          error: 'No internet connection',
        );
      }

      final tempDir = await getTempDirectory();
      final modelsDir = await getModelsDirectory();

      final fileName = _getFileNameFromUrl(url);
      final tempFilePath = '$tempDir/$modelId/$fileName';
      final modelDir = '$modelsDir/$modelId';

      // Create temp directory
      final tempModelDir = Directory('$tempDir/$modelId');
      if (!await tempModelDir.exists()) {
        await tempModelDir.create(recursive: true);
      }

      // Create or get existing task
      if (_activeTasks.containsKey(modelId)) {
        task = _activeTasks[modelId]!;
        task.resetCancelToken(); // Reset for resume
      } else {
        task = DownloadTask(
          modelId: modelId,
          downloadedBytes: resumeFromBytes,
          tempFilePath: tempFilePath,
        );
        _activeTasks[modelId] = task;
      }

      // Check for existing partial download
      final tempFile = File(tempFilePath);
      int startByte = 0;
      if (await tempFile.exists() && resumeFromBytes > 0) {
        startByte = await tempFile.length();
        task.downloadedBytes = startByte;
        _log('Found partial download: $startByte bytes');
      }

      onStatusChange(ModelDownloadStatus.downloading);

      // ✅ FIX: Use task's cancel token, not a local one!
      final cancelToken = task.cancelToken;

      _log('Starting Dio download with task cancelToken...');

      await _dio.download(
        url,
        tempFilePath,
        cancelToken: cancelToken,
        deleteOnError: false,
        options: Options(
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
          responseType: ResponseType.stream,
        ),
        onReceiveProgress: (received, total) {
          // Check if paused or cancelled
          if (task!.isPaused || task.isCancelled) {
            _log('Download ${task.isPaused ? "paused" : "cancelled"}');
            if (!cancelToken.isCancelled) {
              cancelToken.cancel(task.isPaused ? 'paused' : 'cancelled');
            }
            return;
          }

          final actualReceived = startByte + received;
          final actualTotal = total > 0 ? startByte + total : 0;
          final progress = actualTotal > 0 ? actualReceived / actualTotal : 0.0;

          task.downloadedBytes = actualReceived;
          task.updateProgress(progress);

          onProgress(progress, actualReceived, actualTotal);
        },
      );

      // Check states after download
      if (task.isCancelled) {
        _log('Download was cancelled');
        await _cleanupTask(modelId, tempFilePath);
        return DownloadResult(
          success: false,
          status: ModelDownloadStatus.cancelled,
        );
      }

      if (task.isPaused) {
        _log('Download was paused');
        return DownloadResult(
          success: false,
          status: ModelDownloadStatus.paused,
          downloadedBytes: task.downloadedBytes,
        );
      }

      // Verify downloaded file
      if (!await tempFile.exists()) {
        _log('ERROR: Downloaded file not found!');
        return DownloadResult(
          success: false,
          status: ModelDownloadStatus.failed,
          error: 'Downloaded file not found',
        );
      }

      final fileSize = await tempFile.length();
      _log('Downloaded file size: $fileSize bytes');

      // ✅ FIX: Mark as extracting and emit event
      _extractingTasks[modelId] = true;
      _log('Notifying status change: extracting');
      onStatusChange(ModelDownloadStatus.extracting);

      // Check cancel before extraction
      if (task.isCancelled) {
        _log('Cancelled before extraction');
        await _cleanupTask(modelId, tempFilePath);
        await _cleanupModelDir(modelDir);
        return DownloadResult(
          success: false,
          status: ModelDownloadStatus.cancelled,
        );
      }

      // Extract
      _log('Extracting archive...');
      String extractedPath;
      Map<String, String> modelFiles;

      try {
        extractedPath = await _extractIfNeeded(
          tempFilePath,
          modelDir,
          isCancelled: () => task!.isCancelled,
        );

        // Check cancel after extraction
        if (task.isCancelled) {
          _log('Cancelled during extraction');
          await _cleanupTask(modelId, tempFilePath);
          await _cleanupModelDir(modelDir);
          return DownloadResult(
            success: false,
            status: ModelDownloadStatus.cancelled,
          );
        }

        modelFiles = await _scanModelFiles(extractedPath);
        _log('Found model files: $modelFiles');
      } catch (e) {
        _log('Extraction failed: $e');
        _extractingTasks.remove(modelId);
        _activeTasks.remove(modelId);

        if (task.isCancelled || e.toString().contains('Cancelled')) {
          await _cleanupModelDir(modelDir);
          return DownloadResult(
            success: false,
            status: ModelDownloadStatus.cancelled,
          );
        }

        return DownloadResult(
          success: false,
          status: ModelDownloadStatus.failed,
          error: 'Extraction failed: $e',
        );
      }

      // Cleanup temp file
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        _log('Warning: Could not delete temp file: $e');
      }

      _extractingTasks.remove(modelId);
      _activeTasks.remove(modelId);

      _log('========================================');
      _log('Download completed successfully!');
      _log('========================================');

      return DownloadResult(
        success: true,
        status: ModelDownloadStatus.completed,
        localPath: extractedPath,
        modelFiles: modelFiles,
      );
    } on DioException catch (e) {
      _log('DioException: ${e.type} - ${e.message}');

      _extractingTasks.remove(modelId);

      if (e.type == DioExceptionType.cancel) {
        final currentTask = _activeTasks[modelId];

        if (currentTask?.isCancelled == true) {
          await _cleanupTask(modelId, task?.tempFilePath);
          return DownloadResult(
            success: false,
            status: ModelDownloadStatus.cancelled,
          );
        }

        if (currentTask?.isPaused == true) {
          return DownloadResult(
            success: false,
            status: ModelDownloadStatus.paused,
            downloadedBytes: currentTask?.downloadedBytes ?? 0,
          );
        }

        await _cleanupTask(modelId, task?.tempFilePath);
        return DownloadResult(
          success: false,
          status: ModelDownloadStatus.cancelled,
        );
      }

      _activeTasks.remove(modelId);

      final errorMessage = _getErrorMessage(e);
      return DownloadResult(
        success: false,
        status: ModelDownloadStatus.failed,
        error: errorMessage,
      );
    } catch (e, stackTrace) {
      _log('Exception: $e');
      _log('Stack: $stackTrace');

      _extractingTasks.remove(modelId);
      _activeTasks.remove(modelId);

      return DownloadResult(
        success: false,
        status: ModelDownloadStatus.failed,
        error: e.toString(),
      );
    }
  }

  String _getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout';
      case DioExceptionType.sendTimeout:
        return 'Send timeout';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout';
      case DioExceptionType.badResponse:
        return 'Bad response: ${e.response?.statusCode}';
      case DioExceptionType.connectionError:
        return 'Connection error';
      default:
        return e.message ?? 'Download failed';
    }
  }

  Future<void> _cleanupTask(String modelId, String? tempFilePath) async {
    final task = _activeTasks.remove(modelId);
    task?.dispose();
    _extractingTasks.remove(modelId);

    if (tempFilePath != null) {
      try {
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        final tempDir = tempFile.parent;
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        _log('Cleanup error: $e');
      }
    }
  }

  Future<void> _cleanupModelDir(String modelDir) async {
    try {
      final dir = Directory(modelDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      _log('Model dir cleanup error: $e');
    }
  }

  void pause(String modelId) {
    _log('Pausing download: $modelId');
    final task = _activeTasks[modelId];
    if (task != null) {
      task.isPaused = true;
      if (!task.cancelToken.isCancelled) {
        task.cancelToken.cancel('paused');
      }
      _log('Download paused');
    } else {
      _log('No active task found for $modelId');
    }
  }

  Future<void> cancel(String modelId) async {
    _log('Cancelling download: $modelId');

    final task = _activeTasks[modelId];
    if (task != null) {
      // ✅ FIX: Set cancelled flag FIRST
      task.isCancelled = true;

      // Then cancel the token
      if (!task.cancelToken.isCancelled) {
        task.cancelToken.cancel('cancelled');
      }

      // Give time for download to stop
      await Future.delayed(const Duration(milliseconds: 100));

      // Cleanup
      await _cleanupTask(modelId, task.tempFilePath);
      _log('Download cancelled and cleaned up');
    } else {
      _log('No active task found for $modelId');
      // Still try to cleanup temp files
      try {
        final tempDir = await getTempDirectory();
        final tempModelDir = Directory('$tempDir/$modelId');
        if (await tempModelDir.exists()) {
          await tempModelDir.delete(recursive: true);
        }
      } catch (e) {
        _log('Temp cleanup error: $e');
      }
    }

    _extractingTasks.remove(modelId);
  }

  Future<bool> deleteModel(String modelId, String localPath) async {
    _log('Deleting model: $modelId at $localPath');
    try {
      await cancel(modelId);

      if (localPath.isNotEmpty) {
        final modelDir = Directory(localPath);
        if (await modelDir.exists()) {
          await modelDir.delete(recursive: true);
          _log('Model deleted successfully');
        }
      }

      return true;
    } catch (e) {
      _log('Error deleting model: $e');
      return false;
    }
  }

  bool isDownloading(String modelId) {
    final task = _activeTasks[modelId];
    return task != null && !task.isPaused && !task.isCancelled;
  }

  bool isExtracting(String modelId) {
    return _extractingTasks[modelId] == true;
  }

  Stream<double>? getProgressStream(String modelId) {
    return _activeTasks[modelId]?.progressStream;
  }

  int getDownloadedBytes(String modelId) {
    return _activeTasks[modelId]?.downloadedBytes ?? 0;
  }

  Future<String> _extractIfNeeded(
    String filePath,
    String destDir, {
    required bool Function() isCancelled,
  }) async {
    _log('Extracting: $filePath to $destDir');

    final file = File(filePath);
    final fileName = _getFileName(filePath).toLowerCase();

    final destDirectory = Directory(destDir);
    if (!await destDirectory.exists()) {
      await destDirectory.create(recursive: true);
    }

    // Check cancel before starting
    if (isCancelled()) {
      throw Exception('Cancelled');
    }

    try {
      if (fileName.endsWith('.tar.bz2') || fileName.endsWith('.tbz2')) {
        _log('Extracting tar.bz2 archive...');

        if (isCancelled()) throw Exception('Cancelled');

        final bytes = await file.readAsBytes();
        _log('Read ${bytes.length} bytes, decompressing bz2...');

        if (isCancelled()) throw Exception('Cancelled');

        final decompressed = BZip2Decoder().decodeBytes(bytes);
        _log('Decompressed to ${decompressed.length} bytes');

        if (isCancelled()) throw Exception('Cancelled');

        final archive = TarDecoder().decodeBytes(decompressed);
        await _extractArchive(archive, destDir, isCancelled: isCancelled);
        return destDir;
      } else if (fileName.endsWith('.tar.gz') || fileName.endsWith('.tgz')) {
        _log('Extracting tar.gz archive...');

        if (isCancelled()) throw Exception('Cancelled');

        final bytes = await file.readAsBytes();
        final decompressed = GZipDecoder().decodeBytes(bytes);

        if (isCancelled()) throw Exception('Cancelled');

        final archive = TarDecoder().decodeBytes(decompressed);
        await _extractArchive(archive, destDir, isCancelled: isCancelled);
        return destDir;
      } else if (fileName.endsWith('.zip')) {
        _log('Extracting zip archive...');

        if (isCancelled()) throw Exception('Cancelled');

        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        await _extractArchive(archive, destDir, isCancelled: isCancelled);
        return destDir;
      } else if (fileName.endsWith('.onnx')) {
        _log('Copying single ONNX file...');
        final destFile = File('$destDir/${_getFileName(filePath)}');
        await file.copy(destFile.path);
        return destDir;
      }

      _log('Unknown format, copying file as-is...');
      final destFile = File('$destDir/${_getFileName(filePath)}');
      await file.copy(destFile.path);
      return destDir;
    } catch (e) {
      _log('Extraction error: $e');
      rethrow;
    }
  }

  Future<void> _extractArchive(
    Archive archive,
    String destDir, {
    required bool Function() isCancelled,
  }) async {
    _log('Extracting ${archive.length} files...');

    int fileCount = 0;
    for (final file in archive) {
      // Check cancel every few files
      if (fileCount % 5 == 0 && isCancelled()) {
        throw Exception('Cancelled');
      }
      fileCount++;

      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File('$destDir/$filename');
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);
        _log('  Extracted: $filename');
      } else {
        await Directory('$destDir/$filename').create(recursive: true);
      }
    }
    _log('Extraction complete');
  }

  Future<Map<String, String>> _scanModelFiles(String dirPath) async {
    final files = <String, String>{};
    final dir = Directory(dirPath);

    if (!await dir.exists()) {
      return files;
    }

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final name = entity.path.split('/').last;
        final ext = name.split('.').last.toLowerCase();

        if (ext == 'onnx') {
          files['onnx_${files.length}'] = entity.path;
        } else if (name.contains('tokens') || ext == 'txt') {
          files['tokens'] = entity.path;
        } else if (name.contains('lexicon')) {
          files['lexicon'] = entity.path;
        } else if (name.contains('espeak') || name.contains('data')) {
          files['data_dir'] = entity.parent.path;
        }
      }
    }

    return files;
  }

  String _getFileNameFromUrl(String url) {
    return Uri.parse(url).pathSegments.last;
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }

  void dispose() {
    _log('Disposing DownloadManager...');
    for (final task in _activeTasks.values) {
      if (!task.cancelToken.isCancelled) {
        task.cancelToken.cancel();
      }
      task.dispose();
    }
    _activeTasks.clear();
    _extractingTasks.clear();
  }
}

class DownloadResult {
  final bool success;
  final ModelDownloadStatus status;
  final String? localPath;
  final String? error;
  final int? downloadedBytes;
  final Map<String, String>? modelFiles;

  DownloadResult({
    required this.success,
    required this.status,
    this.localPath,
    this.error,
    this.downloadedBytes,
    this.modelFiles,
  });

  @override
  String toString() {
    return 'DownloadResult(success: $success, status: $status, error: $error)';
  }
}

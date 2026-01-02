// lib/services/model_import_service.dart
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../models/download_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
// RESULT CLASSES
// ═══════════════════════════════════════════════════════════════════════════

class ModelImportResult {
  final bool success;
  final String message;
  final DownloadedModel? model;
  final String? error;

  const ModelImportResult._({
    required this.success,
    required this.message,
    this.model,
    this.error,
  });

  factory ModelImportResult.success(String message, DownloadedModel model) =>
      ModelImportResult._(success: true, message: message, model: model);

  factory ModelImportResult.failure(String error) =>
      ModelImportResult._(success: false, message: error, error: error);
}

class ModelValidationResult {
  final bool isValid;
  final SherpaModelType? detectedType;
  final String? suggestedName;
  final List<String> files;
  final int estimatedSize;
  final String? error;

  const ModelValidationResult({
    required this.isValid,
    this.detectedType,
    this.suggestedName,
    this.files = const [],
    this.estimatedSize = 0,
    this.error,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// IMPORT SERVICE
// ═══════════════════════════════════════════════════════════════════════════

class ModelImportService {
  final String modelsDirectory;

  ModelImportService({required this.modelsDirectory});

  // ─────────────────────────────────────────────────────────────────────────
  // FILE PICKING
  // ─────────────────────────────────────────────────────────────────────────

  /// Pick a model archive or ONNX file
  Future<String?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'tar', 'gz', 'bz2', 'onnx', 'tgz'],
        allowMultiple: false,
        dialogTitle: 'Select Model File',
      );
      return result?.files.single.path;
    } catch (e) {
      debugPrint('Error picking file: $e');
      return null;
    }
  }

  /// Pick a folder containing model files
  Future<String?> pickFolder() async {
    try {
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Model Folder',
      );
    } catch (e) {
      debugPrint('Error picking folder: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VALIDATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Validate if the path contains a valid model
  Future<ModelValidationResult> validate(String sourcePath) async {
    try {
      final file = File(sourcePath);
      final dir = Directory(sourcePath);

      if (await file.exists()) {
        return await _validateFile(file);
      } else if (await dir.exists()) {
        return await _validateDirectory(dir);
      }

      return const ModelValidationResult(
        isValid: false,
        error: 'Path does not exist',
      );
    } catch (e) {
      return ModelValidationResult(
        isValid: false,
        error: 'Validation error: $e',
      );
    }
  }

  Future<ModelValidationResult> _validateFile(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    final name = p.basenameWithoutExtension(file.path);
    final size = await file.length();

    // Single ONNX file
    if (ext == '.onnx') {
      return ModelValidationResult(
        isValid: true,
        detectedType: _detectTypeFromName(name),
        suggestedName: _cleanName(name),
        files: [p.basename(file.path)],
        estimatedSize: size,
      );
    }

    // Archive files
    if (['.zip', '.tar', '.gz', '.bz2', '.tgz'].contains(ext)) {
      try {
        final bytes = await file.readAsBytes();
        final fullExt = _getFullExtension(file.path);

        final files = await compute(_listArchiveFiles, {
          'bytes': bytes,
          'extension': fullExt,
        });

        final hasOnnx = files.any((f) => f.endsWith('.onnx'));
        if (!hasOnnx) {
          return ModelValidationResult(
            isValid: false,
            files: files,
            error: 'No ONNX model files found in archive',
          );
        }

        return ModelValidationResult(
          isValid: true,
          detectedType: _detectTypeFromFiles(files),
          suggestedName: _cleanName(name),
          files: files,
          estimatedSize: size,
        );
      } catch (e) {
        return ModelValidationResult(
          isValid: false,
          error: 'Failed to read archive: $e',
        );
      }
    }

    return const ModelValidationResult(
      isValid: false,
      error: 'Unsupported file format. Use ZIP, TAR.GZ, or ONNX files.',
    );
  }

  Future<ModelValidationResult> _validateDirectory(Directory dir) async {
    final files = <String>[];
    int totalSize = 0;

    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          files.add(p.relative(entity.path, from: dir.path));
          totalSize += await entity.length();
        }
      }
    } catch (e) {
      return ModelValidationResult(
        isValid: false,
        error: 'Failed to read directory: $e',
      );
    }

    if (files.isEmpty) {
      return const ModelValidationResult(
        isValid: false,
        error: 'Directory is empty',
      );
    }

    final hasOnnx = files.any((f) => f.endsWith('.onnx'));
    if (!hasOnnx) {
      return ModelValidationResult(
        isValid: false,
        files: files,
        error: 'No ONNX model files found',
      );
    }

    return ModelValidationResult(
      isValid: true,
      detectedType: _detectTypeFromFiles(files),
      suggestedName: _cleanName(p.basename(dir.path)),
      files: files,
      estimatedSize: totalSize,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IMPORT
  // ─────────────────────────────────────────────────────────────────────────

  /// Import a model from local path
  Future<ModelImportResult> importModel({
    required String sourcePath,
    required SherpaModelType modelType,
    required String modelName,
    String language = 'unknown',
    String? description,
    void Function(double progress, String status)? onProgress,
  }) async {
    try {
      final cleanName = _cleanName(modelName.trim());
      if (cleanName.isEmpty) {
        return ModelImportResult.failure('Invalid model name');
      }

      onProgress?.call(0.0, 'Preparing...');

      // Check source
      final sourceFile = File(sourcePath);
      final sourceDir = Directory(sourcePath);
      final isFile = await sourceFile.exists();
      final isDirectory = await sourceDir.exists();

      if (!isFile && !isDirectory) {
        return ModelImportResult.failure('Source path not found');
      }

      // Create target directory
      final targetDir = Directory(p.join(modelsDirectory, cleanName));
      if (await targetDir.exists()) {
        return ModelImportResult.failure(
          'Model "$cleanName" already exists. Choose a different name.',
        );
      }

      await targetDir.create(recursive: true);

      try {
        onProgress?.call(0.1, 'Copying files...');

        if (isFile) {
          await _importFromFile(sourceFile, targetDir, onProgress);
        } else {
          await _importFromDirectory(sourceDir, targetDir, onProgress);
        }
      } catch (e) {
        // Cleanup on failure
        if (await targetDir.exists()) {
          await targetDir.delete(recursive: true);
        }
        return ModelImportResult.failure('Failed to copy files: $e');
      }

      onProgress?.call(0.95, 'Finalizing...');

      // Calculate final size and find model files
      int totalSize = 0;
      final modelFiles = <String, String>{};

      await for (final entity in targetDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
          //final relativePath = p.relative(entity.path, from: targetDir.path);

          // Categorize important files
          if (entity.path.endsWith('.onnx')) {
            modelFiles['model'] = entity.path;
          } else if (entity.path.contains('tokens')) {
            modelFiles['tokens'] = entity.path;
          } else if (entity.path.contains('lexicon')) {
            modelFiles['lexicon'] = entity.path;
          }
        }
      }

      // Create the model record
      final model = DownloadedModel.fromLocalImport(
        name: cleanName,
        modelType: modelType,
        language: language,
        localPath: targetDir.path,
        sizeBytes: totalSize,
        description: description,
        sourcePath: sourcePath,
        modelFiles: modelFiles.isNotEmpty ? modelFiles : null,
      );

      onProgress?.call(1.0, 'Import complete!');

      return ModelImportResult.success(
        'Successfully imported "$cleanName"',
        model,
      );
    } catch (e) {
      return ModelImportResult.failure('Import error: $e');
    }
  }

  Future<void> _importFromFile(
    File file,
    Directory targetDir,
    void Function(double, String)? onProgress,
  ) async {
    final ext = p.extension(file.path).toLowerCase();

    // Single ONNX file - just copy
    if (ext == '.onnx') {
      onProgress?.call(0.5, 'Copying model file...');
      await file.copy(p.join(targetDir.path, p.basename(file.path)));
      return;
    }

    // Extract archive
    onProgress?.call(0.15, 'Reading archive...');
    final bytes = await file.readAsBytes();
    final fullExt = _getFullExtension(file.path);

    onProgress?.call(0.25, 'Extracting files...');
    await _extractArchive(bytes, fullExt, targetDir.path, onProgress);
  }

  Future<void> _importFromDirectory(
    Directory source,
    Directory target,
    void Function(double, String)? onProgress,
  ) async {
    final entities = await source.list(recursive: true).toList();
    final files = entities.whereType<File>().toList();
    final totalFiles = files.length;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final relativePath = p.relative(file.path, from: source.path);
      final targetPath = p.join(target.path, relativePath);

      await File(targetPath).parent.create(recursive: true);
      await file.copy(targetPath);

      final progress = 0.1 + (0.85 * (i + 1) / totalFiles);
      onProgress?.call(progress, 'Copying: ${p.basename(relativePath)}');
    }
  }

  Future<void> _extractArchive(
    List<int> bytes,
    String extension,
    String targetPath,
    void Function(double, String)? onProgress,
  ) async {
    // Extract in isolate to avoid blocking UI
    final entries = await compute(_extractArchiveIsolate, {
      'bytes': bytes,
      'extension': extension,
    });

    final totalEntries = entries.length;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final name = entry['name'] as String;
      final content = entry['content'] as List<int>?;
      final isFile = entry['isFile'] as bool;

      final filePath = p.join(targetPath, name);

      if (isFile && content != null) {
        final outFile = File(filePath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(content);
      } else if (!isFile) {
        await Directory(filePath).create(recursive: true);
      }

      final progress = 0.25 + (0.7 * (i + 1) / totalEntries);
      onProgress?.call(progress, 'Extracting: ${p.basename(name)}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATIC HELPERS (for isolate)
  // ─────────────────────────────────────────────────────────────────────────

  static List<String> _listArchiveFiles(Map<String, dynamic> params) {
    final bytes = params['bytes'] as List<int>;
    final ext = params['extension'] as String;
    final archive = _decodeArchive(bytes, ext);
    return archive.files.map((f) => f.name).toList();
  }

  static List<Map<String, dynamic>> _extractArchiveIsolate(
    Map<String, dynamic> params,
  ) {
    final bytes = params['bytes'] as List<int>;
    final ext = params['extension'] as String;
    final archive = _decodeArchive(bytes, ext);

    return archive.files
        .map(
          (f) => {
            'name': f.name,
            'content': f.isFile ? (f.content as List<int>?) : null,
            'isFile': f.isFile,
          },
        )
        .toList();
  }

  static Archive _decodeArchive(List<int> bytes, String ext) {
    switch (ext) {
      case '.zip':
        return ZipDecoder().decodeBytes(bytes);
      case '.tar':
        return TarDecoder().decodeBytes(bytes);
      case '.gz':
      case '.tgz':
      case '.tar.gz':
        return TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
      case '.bz2':
      case '.tar.bz2':
        return TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes));
      default:
        throw Exception('Unsupported archive format: $ext');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INSTANCE HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _getFullExtension(String path) {
    final name = p.basename(path).toLowerCase();
    if (name.endsWith('.tar.gz')) return '.tar.gz';
    if (name.endsWith('.tar.bz2')) return '.tar.bz2';
    return p.extension(path).toLowerCase();
  }

  String _cleanName(String name) {
    return name
        .replaceAll(
          RegExp(
            r'\.(tar\.gz|tar\.bz2|tar|zip|gz|bz2|tgz|onnx)$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[^\w\-_.]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .trim();
  }

  SherpaModelType _detectTypeFromName(String name) {
    final lower = name.toLowerCase();

    if (_matchesAny(lower, ['tts', 'vits', 'piper', 'espeak'])) {
      return SherpaModelType.tts;
    }
    if (_matchesAny(lower, ['vad', 'silero_vad'])) {
      return SherpaModelType.vad;
    }
    if (_matchesAny(lower, ['speaker', 'ecapa', 'wespeaker', '3dspeaker'])) {
      return SherpaModelType.speakerIdentification;
    }
    if (_matchesAny(lower, ['lid', 'lang_id', 'language'])) {
      return SherpaModelType.languageIdentification;
    }

    return SherpaModelType.stt;
  }

  SherpaModelType _detectTypeFromFiles(List<String> files) {
    final all = files.join(' ').toLowerCase();

    // TTS indicators
    if (_matchesAny(all, ['espeak', 'lexicon', 'vits', 'piper', 'tts'])) {
      return SherpaModelType.tts;
    }

    // VAD indicators (exclude paraformer which also has 'vad' in path)
    if (_matchesAny(all, ['silero']) ||
        (all.contains('vad') && !all.contains('paraformer'))) {
      return SherpaModelType.vad;
    }

    // Speaker ID indicators
    if (_matchesAny(all, [
      'speaker',
      'ecapa',
      'wespeaker',
      '3dspeaker',
      'embedding',
    ])) {
      return SherpaModelType.speakerIdentification;
    }

    // Language ID indicators
    if (_matchesAny(all, ['lid', 'language_id'])) {
      return SherpaModelType.languageIdentification;
    }

    return SherpaModelType.stt;
  }

  bool _matchesAny(String text, List<String> patterns) {
    return patterns.any((pattern) => text.contains(pattern));
  }
}

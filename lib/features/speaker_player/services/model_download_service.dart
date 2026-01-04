import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/download_model.dart';
import '../models/model_info.dart';
import '../repositories/model_repository.dart';
import 'download_manager.dart';

class ModelDownloadService {
  final ModelRepository _repository;
  final DownloadManager _downloadManager;
  bool _isInitialized = false;

  static const bool _enableLogging = true;

  bool get isInitialized => _isInitialized;

  final _statusController = StreamController<ModelDownloadEvent>.broadcast();
  Stream<ModelDownloadEvent> get statusStream => _statusController.stream;

  ModelDownloadService({
    ModelRepository? repository,
    DownloadManager? downloadManager,
  }) : _repository = repository ?? ModelRepository(),
       _downloadManager = downloadManager ?? DownloadManager();

  void _log(String message) {
    if (_enableLogging) {
      debugPrint('[ModelDownloadService] $message');
    }
  }

  Future<void> init() async {
    if (_isInitialized) {
      _log('Already initialized');
      return;
    }

    _log('Initializing service...');
    await _repository.init();
    _isInitialized = true;
    _log('Service initialized');
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  Future<DownloadResult> downloadModel(ModelInfo modelInfo) async {
    _log('========================================');
    _log('downloadModel called');
    _log('Model ID: ${modelInfo.id}');
    _log('Model Name: ${modelInfo.name}');
    _log('========================================');

    try {
      await _ensureInitialized();

      // Check if already downloaded
      final existing = await _repository.getModel(modelInfo.id);
      if (existing != null &&
          existing.status == ModelDownloadStatus.completed) {
        _log('Model already downloaded at: ${existing.localPath}');
        return DownloadResult(
          success: true,
          status: ModelDownloadStatus.completed,
          localPath: existing.localPath,
        );
      }

      // Create or update model entry
      final model = existing ?? modelInfo.toDownloadedModel();
      model.status = ModelDownloadStatus.pending;
      model.progress = 0;
      model.errorMessage = null;

      await _repository.saveModel(model);

      _emitEvent(
        ModelDownloadEvent(
          modelId: model.id,
          status: ModelDownloadStatus.pending,
          progress: 0,
        ),
      );

      // Start download
      final result = await _downloadManager.download(
        modelId: model.id,
        url: model.url,
        resumeFromBytes: model.downloadedBytes,
        onProgress: (progress, received, total) {
          _updateProgress(model.id, progress, received, total);
        },
        onStatusChange: (status) {
          _updateStatus(model.id, status);
        },
      );

      _log('Download result: $result');

      // Update final status
      await _repository.updateModelStatus(
        model.id,
        status: result.status,
        progress: result.success ? 1.0 : model.progress,
        localPath: result.localPath,
        errorMessage: result.error,
        downloadedAt: result.success ? DateTime.now() : null,
        downloadedBytes: result.downloadedBytes,
        modelFiles: result.modelFiles,
      );

      // Auto-activate if this is the first model of its type
      if (result.success) {
        final activeModel = await _repository.getActiveModelForType(
          model.modelType,
        );
        if (activeModel == null) {
          await _repository.setActiveModel(model.id);
          _log('Auto-activated model: ${model.id}');
        }
      }

      _emitEvent(
        ModelDownloadEvent(
          modelId: model.id,
          status: result.status,
          progress: result.success ? 1.0 : model.progress,
          error: result.error,
          isCompleted: result.success,
        ),
      );

      return result;
    } catch (e, stackTrace) {
      _log('ERROR in downloadModel: $e');
      _log('Stack trace: $stackTrace');

      return DownloadResult(
        success: false,
        status: ModelDownloadStatus.failed,
        error: e.toString(),
      );
    }
  }

  Future<void> pauseDownload(String modelId) async {
    _log('pauseDownload: $modelId');
    _downloadManager.pause(modelId);

    final downloadedBytes = _downloadManager.getDownloadedBytes(modelId);

    await _repository.updateModelStatus(
      modelId,
      status: ModelDownloadStatus.paused,
      downloadedBytes: downloadedBytes,
    );

    _emitEvent(
      ModelDownloadEvent(modelId: modelId, status: ModelDownloadStatus.paused),
    );
  }

  Future<DownloadResult> resumeDownload(String modelId) async {
    _log('resumeDownload: $modelId');

    final model = await _repository.getModel(modelId);
    if (model == null) {
      return DownloadResult(
        success: false,
        status: ModelDownloadStatus.failed,
        error: 'Model not found',
      );
    }

    if (!model.canResume) {
      return DownloadResult(
        success: false,
        status: model.status,
        error: 'Cannot resume this download',
      );
    }

    _emitEvent(
      ModelDownloadEvent(
        modelId: modelId,
        status: ModelDownloadStatus.downloading,
        progress: model.progress,
      ),
    );

    final result = await _downloadManager.download(
      modelId: model.id,
      url: model.url,
      resumeFromBytes: model.downloadedBytes,
      onProgress: (progress, received, total) {
        _updateProgress(model.id, progress, received, total);
      },
      onStatusChange: (status) {
        _updateStatus(model.id, status);
      },
    );

    await _repository.updateModelStatus(
      model.id,
      status: result.status,
      progress: result.success ? 1.0 : null,
      localPath: result.localPath,
      errorMessage: result.error,
      downloadedAt: result.success ? DateTime.now() : null,
      downloadedBytes: result.downloadedBytes,
      modelFiles: result.modelFiles,
    );

    _emitEvent(
      ModelDownloadEvent(
        modelId: model.id,
        status: result.status,
        progress: result.success ? 1.0 : model.progress,
        error: result.error,
        isCompleted: result.success,
      ),
    );

    return result;
  }

  Future<void> cancelDownload(String modelId) async {
    _log('cancelDownload: $modelId');
    await _downloadManager.cancel(modelId);
    await _repository.deleteModel(modelId);

    _emitEvent(
      ModelDownloadEvent(
        modelId: modelId,
        status: ModelDownloadStatus.cancelled,
      ),
    );
  }

  Future<bool> deleteModel(String modelId) async {
    _log('deleteModel: $modelId');
    final model = await _repository.getModel(modelId);
    if (model == null) return false;

    final deleted = await _downloadManager.deleteModel(
      modelId,
      model.localPath,
    );
    if (deleted) {
      await _repository.deleteModel(modelId);
      _emitEvent(
        ModelDownloadEvent(
          modelId: modelId,
          status: ModelDownloadStatus.cancelled,
          isDeleted: true,
        ),
      );
    }
    return deleted;
  }

  /// Set a model as the active/default model for its type
  Future<void> setActiveModel(String modelId) async {
    await _ensureInitialized();
    await _repository.setActiveModel(modelId);
    _emitEvent(
      ModelDownloadEvent(
        modelId: modelId,
        status: ModelDownloadStatus.completed,
        isActivated: true,
      ),
    );
  }

  /// Get the active model for a specific type
  Future<DownloadedModel?> getActiveModelForType(SherpaModelType type) async {
    await _ensureInitialized();
    return _repository.getActiveModelForType(type);
  }

  Future<DownloadedModel?> getModel(String modelId) async {
    await _ensureInitialized();
    return _repository.getModel(modelId);
  }

  Future<List<DownloadedModel>> getAllModels() async {
    await _ensureInitialized();
    return _repository.getAllModels();
  }

  Future<List<DownloadedModel>> getDownloadedModels() async {
    await _ensureInitialized();
    return _repository.getDownloadedModels();
  }

  Future<List<DownloadedModel>> getModelsByType(SherpaModelType type) async {
    await _ensureInitialized();
    return _repository.getModelsByType(type);
  }

  Future<bool> isModelDownloaded(String modelId) async {
    await _ensureInitialized();
    return _repository.isModelDownloaded(modelId);
  }

  /// Get set of downloaded model IDs
  Future<Set<String>> getDownloadedModelIds() async {
    await _ensureInitialized();
    return _repository.getDownloadedModelIds();
  }

  /// Get set of all model IDs in repository
  Future<Set<String>> getAllModelIds() async {
    await _ensureInitialized();
    return _repository.getAllModelIds();
  }

  Future<String?> getModelPath(String modelId) async {
    await _ensureInitialized();
    final model = await _repository.getModel(modelId);
    if (model?.status == ModelDownloadStatus.completed) {
      await _repository.updateLastUsed(modelId);
      return model?.localPath;
    }
    return null;
  }

  Future<Map<String, String>?> getModelFiles(String modelId) async {
    await _ensureInitialized();
    final model = await _repository.getModel(modelId);
    return model?.modelFiles;
  }

  Future<bool> verifyModel(String modelId) async {
    await _ensureInitialized();
    final model = await _repository.getModel(modelId);
    if (model == null || model.localPath.isEmpty) return false;

    final dir = Directory(model.localPath);
    if (!await dir.exists()) {
      await _repository.updateModelStatus(
        modelId,
        status: ModelDownloadStatus.failed,
        errorMessage: 'Model files not found',
      );
      return false;
    }

    bool hasOnnx = false;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.onnx')) {
        hasOnnx = true;
        break;
      }
    }

    return hasOnnx;
  }

  Stream<DownloadedModel?> watchModel(String modelId) {
    return _repository.watchModel(modelId).map((event) {
      return event.value as DownloadedModel?;
    });
  }

  Future<int> getTotalDiskUsage() async {
    await _ensureInitialized();
    final models = await getDownloadedModels();
    int totalSize = 0;

    for (final model in models) {
      if (model.localPath.isNotEmpty) {
        final dir = Directory(model.localPath);
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File) {
              totalSize += await entity.length();
            }
          }
        }
      }
    }

    return totalSize;
  }

  void _updateProgress(
    String modelId,
    double progress,
    int received,
    int total,
  ) {
    _repository.updateModelStatus(
      modelId,
      status: ModelDownloadStatus.downloading,
      progress: progress,
      downloadedBytes: received,
      totalBytes: total,
    );

    _emitEvent(
      ModelDownloadEvent(
        modelId: modelId,
        status: ModelDownloadStatus.downloading,
        progress: progress,
        downloadedBytes: received,
        totalBytes: total,
      ),
    );
  }

  void _updateStatus(String modelId, ModelDownloadStatus status) {
    _repository.updateModelStatus(modelId, status: status);
    _emitEvent(ModelDownloadEvent(modelId: modelId, status: status));
  }

  void _emitEvent(ModelDownloadEvent event) {
    _log('Emitting event: ${event.modelId} - ${event.status}');
    if (!_statusController.isClosed) {
      _statusController.add(event);
    }
  }

  /// Save an imported local model to repository
  Future<void> saveImportedModel(DownloadedModel model) async {
    _log('saveImportedModel: ${model.id} - ${model.name}');
    await _ensureInitialized();

    // Save to repository
    await _repository.saveModel(model);

    // Auto-activate if this is the first model of its type
    final activeModel = await _repository.getActiveModelForType(
      model.modelType,
    );
    if (activeModel == null) {
      await _repository.setActiveModel(model.id);
      _log('Auto-activated imported model: ${model.id}');
    }

    _emitEvent(
      ModelDownloadEvent(
        modelId: model.id,
        status: ModelDownloadStatus.completed,
        progress: 1.0,
        isCompleted: true,
      ),
    );
  }

  /// Get the models directory path
  Future<String> modelsDirectory() async {
    return _downloadManager.getModelsDirectory();
  }

  /// Check if a model name already exists
  Future<bool> modelNameExists(String name) async {
    await _ensureInitialized();
    final models = await _repository.getAllModels();
    return models.any((m) => m.name.toLowerCase() == name.toLowerCase());
  }

  Future<void> removeActiveModel(String modelId) async {
    await _ensureInitialized();
    await _repository.removeActiveModel(modelId);
    _emitEvent(
      ModelDownloadEvent(
        modelId: modelId,
        status: ModelDownloadStatus.completed,
        isActivated: false, // You might want to add isDeactivated flag
      ),
    );
  }

  Future<void> dispose() async {
    _log('Disposing service...');
    await _statusController.close();
    _downloadManager.dispose();
    await _repository.close();
  }
}

class ModelDownloadEvent {
  final String modelId;
  final ModelDownloadStatus status;
  final double? progress;
  final int? downloadedBytes;
  final int? totalBytes;
  final String? error;
  final bool isDeleted;
  final bool isCompleted;
  final bool isActivated;

  ModelDownloadEvent({
    required this.modelId,
    required this.status,
    this.progress,
    this.downloadedBytes,
    this.totalBytes,
    this.error,
    this.isDeleted = false,
    this.isCompleted = false,
    this.isActivated = false,
  });

  @override
  String toString() {
    return 'ModelDownloadEvent(modelId: $modelId, status: $status, progress: $progress)';
  }
}

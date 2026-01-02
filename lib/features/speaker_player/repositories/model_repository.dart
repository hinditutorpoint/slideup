import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/download_model.dart';
import '../constants/model_constants.dart';

class ModelRepository {
  Box<DownloadedModel>? _modelsBox;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('[ModelRepository] Already initialized');
      return;
    }

    debugPrint('[ModelRepository] Initializing...');
    _modelsBox = await Hive.openBox<DownloadedModel>(
      ModelConstants.hiveBoxName,
    );
    _isInitialized = true;
    debugPrint(
      '[ModelRepository] Initialized with ${_modelsBox!.length} models',
    );
  }

  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  Box<DownloadedModel> get _box {
    if (_modelsBox == null) {
      throw StateError('ModelRepository not initialized. Call init() first.');
    }
    return _modelsBox!;
  }

  // CRUD Operations
  Future<void> saveModel(DownloadedModel model) async {
    await ensureInitialized();
    debugPrint('[ModelRepository] Saving model: ${model.id}');
    await _box.put(model.id, model);
  }

  Future<DownloadedModel?> getModel(String id) async {
    await ensureInitialized();
    return _box.get(id);
  }

  Future<List<DownloadedModel>> getAllModels() async {
    await ensureInitialized();
    return _box.values.toList();
  }

  Future<List<DownloadedModel>> getModelsByStatus(
    ModelDownloadStatus status,
  ) async {
    await ensureInitialized();
    return _box.values.where((m) => m.status == status).toList();
  }

  Future<List<DownloadedModel>> getModelsByType(SherpaModelType type) async {
    await ensureInitialized();
    return _box.values.where((m) => m.modelType == type).toList();
  }

  Future<List<DownloadedModel>> getDownloadedModels() async {
    return getModelsByStatus(ModelDownloadStatus.completed);
  }

  /// Get active model for a specific type
  Future<DownloadedModel?> getActiveModelForType(SherpaModelType type) async {
    await ensureInitialized();
    try {
      return _box.values.firstWhere(
        (m) => m.modelType == type && m.isActive && m.isDownloaded,
      );
    } catch (_) {
      return null;
    }
  }

  /// Set a model as active (deactivate others of same type)
  Future<void> setActiveModel(String modelId) async {
    await ensureInitialized();
    final model = _box.get(modelId);
    if (model == null || !model.isDownloaded) return;

    // Deactivate all other models of the same type
    for (final m in _box.values) {
      if (m.modelType == model.modelType && m.isActive) {
        m.isActive = false;
        await m.save();
      }
    }

    // Activate this model
    model.isActive = true;
    await model.save();
    debugPrint('[ModelRepository] Activated model: ${model.id}');
  }

  /// Deactivate a model
  Future<void> deactivateModel(String modelId) async {
    await ensureInitialized();
    final model = _box.get(modelId);
    if (model != null) {
      model.isActive = false;
      await model.save();
    }
  }

  Future<void> updateModelStatus(
    String id, {
    ModelDownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? localPath,
    String? errorMessage,
    DateTime? downloadedAt,
    Map<String, String>? modelFiles,
    bool? isActive,
  }) async {
    await ensureInitialized();
    final model = _box.get(id);
    if (model != null) {
      if (status != null) model.status = status;
      if (progress != null) model.progress = progress;
      if (downloadedBytes != null) model.downloadedBytes = downloadedBytes;
      if (totalBytes != null) model.totalBytes = totalBytes;
      if (localPath != null) model.localPath = localPath;
      if (errorMessage != null) model.errorMessage = errorMessage;
      if (downloadedAt != null) model.downloadedAt = downloadedAt;
      if (isActive != null) model.isActive = isActive;
      await model.save();
    }
  }

  Future<void> updateLastUsed(String id) async {
    await ensureInitialized();
    final model = _box.get(id);
    if (model != null) {
      model.lastUsedAt = DateTime.now();
      await model.save();
    }
  }

  Future<void> deleteModel(String id) async {
    await ensureInitialized();
    await _box.delete(id);
  }

  Future<bool> hasModel(String id) async {
    await ensureInitialized();
    return _box.containsKey(id);
  }

  Future<bool> isModelDownloaded(String id) async {
    await ensureInitialized();
    final model = _box.get(id);
    return model?.status == ModelDownloadStatus.completed;
  }

  /// Get all downloaded model IDs
  Future<Set<String>> getDownloadedModelIds() async {
    await ensureInitialized();
    return _box.values
        .where((m) => m.status == ModelDownloadStatus.completed)
        .map((m) => m.id)
        .toSet();
  }

  /// Get all model IDs (including pending/downloading)
  Future<Set<String>> getAllModelIds() async {
    await ensureInitialized();
    return _box.values.map((m) => m.id).toSet();
  }

  Stream<BoxEvent> watchModels() {
    return _box.watch();
  }

  Stream<BoxEvent> watchModel(String id) {
    return _box.watch(key: id);
  }

  Future<void> clearAll() async {
    await ensureInitialized();
    await _box.clear();
  }

  Future<void> removeActiveModel(String modelId) async {
    await ensureInitialized();
    final model = await getModel(modelId);
    if (model != null && model.isActive) {
      model.isActive = false;
      await _modelsBox!.put(modelId, model);
    }
  }

  Future<void> close() async {
    if (_isInitialized && _modelsBox != null) {
      await _modelsBox!.close();
      _isInitialized = false;
    }
  }
}

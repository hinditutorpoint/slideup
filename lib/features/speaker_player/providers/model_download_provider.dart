import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/download_model.dart';
import '../models/model_info.dart';
import '../services/model_download_service.dart';
import '../services/model_import_service.dart';
import '../constants/model_constants.dart';

// Service provider
final modelDownloadServiceProvider = Provider<ModelDownloadService>((ref) {
  final service = ModelDownloadService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Models directory path provider
final modelsDirectoryProvider = FutureProvider<String>((ref) async {
  await ref.watch(modelServiceInitProvider.future);
  final service = ref.watch(modelDownloadServiceProvider);
  return service.modelsDirectory();
});

/// Model import service provider
final modelImportServiceProvider = FutureProvider<ModelImportService>((
  ref,
) async {
  final modelsDir = await ref.watch(modelsDirectoryProvider.future);
  return ModelImportService(modelsDirectory: modelsDir);
});

/// Import progress state
class ImportProgress {
  final double progress;
  final String status;
  final bool isImporting;
  final String? error;

  const ImportProgress({
    this.progress = 0.0,
    this.status = '',
    this.isImporting = false,
    this.error,
  });
}

final importProgressProvider = StateProvider<ImportProgress>((ref) {
  return const ImportProgress();
});

/// Local models only provider
final localModelsProvider = FutureProvider<List<DownloadedModel>>((ref) async {
  final allModels = await ref.watch(allModelsProvider.future);
  return allModels.where((m) => m.isLocal).toList();
});

// Add to DownloadController class:

// Initialize service
final modelServiceInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(modelDownloadServiceProvider);
  await service.init();
});

// All models from repository
final allModelsProvider = FutureProvider<List<DownloadedModel>>((ref) async {
  await ref.watch(modelServiceInitProvider.future);
  final service = ref.watch(modelDownloadServiceProvider);
  return service.getAllModels();
});

// Downloaded model IDs (for quick lookup)
final downloadedModelIdsProvider = FutureProvider<Set<String>>((ref) async {
  await ref.watch(modelServiceInitProvider.future);
  final service = ref.watch(modelDownloadServiceProvider);
  return service.getDownloadedModelIds();
});

// All model IDs in repository
final allModelIdsProvider = FutureProvider<Set<String>>((ref) async {
  await ref.watch(modelServiceInitProvider.future);
  final service = ref.watch(modelDownloadServiceProvider);
  return service.getAllModelIds();
});

// Downloaded models only
final downloadedModelsProvider = FutureProvider<List<DownloadedModel>>((
  ref,
) async {
  await ref.watch(modelServiceInitProvider.future);
  final service = ref.watch(modelDownloadServiceProvider);
  return service.getDownloadedModels();
});

// Available models (not downloaded yet)
final availableModelsProvider = FutureProvider<List<ModelInfo>>((ref) async {
  await ref.watch(modelServiceInitProvider.future);
  final modelIds = await ref.watch(allModelIdsProvider.future);

  // Filter out models that are already in repository (downloaded or downloading)
  return ModelConstants.availableModels
      .where((m) => !modelIds.contains(m.id))
      .toList();
});

// Models by type
final modelsByTypeProvider =
    FutureProvider.family<List<DownloadedModel>, SherpaModelType>((
      ref,
      type,
    ) async {
      await ref.watch(modelServiceInitProvider.future);
      final service = ref.watch(modelDownloadServiceProvider);
      return service.getModelsByType(type);
    });

// Active model for type
final activeModelForTypeProvider =
    FutureProvider.family<DownloadedModel?, SherpaModelType>((ref, type) async {
      await ref.watch(modelServiceInitProvider.future);
      final service = ref.watch(modelDownloadServiceProvider);
      return service.getActiveModelForType(type);
    });

// Single model state
final modelStateProvider = FutureProvider.family<DownloadedModel?, String>((
  ref,
  modelId,
) async {
  await ref.watch(modelServiceInitProvider.future);
  final service = ref.watch(modelDownloadServiceProvider);
  return service.getModel(modelId);
});

// Download events stream
final downloadEventsProvider = StreamProvider<ModelDownloadEvent>((ref) {
  final service = ref.watch(modelDownloadServiceProvider);
  return service.statusStream;
});

// Disk usage
final diskUsageProvider = FutureProvider<int>((ref) async {
  await ref.watch(modelServiceInitProvider.future);
  final service = ref.watch(modelDownloadServiceProvider);
  return service.getTotalDiskUsage();
});

// Real-time all models provider using stream
final liveAllModelsProvider = StreamProvider<List<DownloadedModel>>((
  ref,
) async* {
  final service = ref.watch(modelDownloadServiceProvider);
  await service.ensureInitialized();

  // Emit initial state
  yield await service.getAllModels();

  // Listen for updates and re-emit
  await for (final _ in service.statusStream) {
    yield await service.getAllModels();
  }
});

// Download controller
class DownloadController extends StateNotifier<AsyncValue<void>> {
  final ModelDownloadService _service;
  final Ref _ref;

  DownloadController(this._service, this._ref)
    : super(const AsyncValue.data(null));

  void _invalidateProviders() {
    _ref.invalidate(allModelsProvider);
    _ref.invalidate(downloadedModelsProvider);
    _ref.invalidate(availableModelsProvider);
    _ref.invalidate(downloadedModelIdsProvider);
    _ref.invalidate(allModelIdsProvider);
    _ref.invalidate(diskUsageProvider);
  }

  Future<void> download(ModelInfo modelInfo) async {
    state = const AsyncValue.loading();
    try {
      await _service.downloadModel(modelInfo);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> pause(String modelId) async {
    await _service.pauseDownload(modelId);
    _invalidateProviders();
  }

  Future<void> resume(String modelId) async {
    state = const AsyncValue.loading();
    try {
      await _service.resumeDownload(modelId);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> cancel(String modelId) async {
    await _service.cancelDownload(modelId);
    _invalidateProviders();
  }

  Future<void> delete(String modelId) async {
    await _service.deleteModel(modelId);
    _invalidateProviders();
  }

  Future<void> setActive(String modelId) async {
    await _service.setActiveModel(modelId);
    _invalidateProviders();
  }

  Future<void> removeActive(String modelId) async {
    await _service.removeActiveModel(modelId);
    _invalidateProviders();
  }

  /// Add an imported model to the repository
  Future<void> addImportedModel(DownloadedModel model) async {
    state = const AsyncValue.loading();
    try {
      await _service.saveImportedModel(model);
      _invalidateProviders();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final downloadControllerProvider =
    StateNotifierProvider<DownloadController, AsyncValue<void>>((ref) {
      final service = ref.watch(modelDownloadServiceProvider);
      return DownloadController(service, ref);
    });

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/model_download_provider.dart';
import '../widgets/download_item_widget.dart';
import '../models/download_model.dart';
import '../widgets/model_import_dialog.dart';
import '../models/model_info.dart';

class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen> {
  @override
  void initState() {
    super.initState();
    _enableScreenOn();
  }

  @override
  void dispose() {
    _disableScreenOn();
    super.dispose();
  }

  Future<void> _enableScreenOn() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Failed to enable wakelock: $e');
    }
  }

  Future<void> _disableScreenOn() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Failed to disable wakelock: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    // Listen to ALL download events and refresh UI
    ref.listen(downloadEventsProvider, (previous, next) {
      next.whenData((event) {
        // Refresh on any status change for real-time updates
        ref.invalidate(allModelsProvider);
        ref.invalidate(downloadedModelsProvider);
        ref.invalidate(availableModelsProvider);
        ref.invalidate(diskUsageProvider);
      });
    });

    final allModels = ref.watch(allModelsProvider);
    final availableModels = ref.watch(availableModelsProvider);
    final downloadedModels = ref.watch(downloadedModelsProvider);
    final diskUsage = ref.watch(diskUsageProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Model Manager'),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.check_circle),
                text: 'Downloaded ${_getCount(downloadedModels)}',
              ),
              Tab(
                icon: const Icon(Icons.cloud_download),
                text: 'Available ${_getCount(availableModels)}',
              ),
              Tab(
                icon: const Icon(Icons.list),
                text: 'All ${_getCount(allModels)}',
              ),
            ],
          ),
          actions: [
            // Disk usage indicator
            diskUsage.when(
              data: (size) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storage,
                          size: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatBytes(size),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            // Refresh button
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _refreshAll(ref),
              tooltip: 'Refresh',
            ),
            // More options
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => _handleMenuAction(context, ref, value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'import_model',
                  child: ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text('Import Model'),
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _showImportDialog(),
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_failed',
                  child: ListTile(
                    leading: Icon(Icons.clear_all),
                    title: Text('Clear Failed'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_cache',
                  child: ListTile(
                    leading: Icon(Icons.cached),
                    title: Text('Clear Cache'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Downloaded Tab
            _buildDownloadedTab(context, ref, downloadedModels),

            // Available Tab
            _buildAvailableTab(context, ref, availableModels),

            // All Tab
            _buildAllTab(context, ref, allModels),
          ],
        ),
      ),
    );
  }

  String _getCount(AsyncValue<List<dynamic>> models) {
    return models.when(
      data: (list) => list.isNotEmpty ? '(${list.length})' : '',
      loading: () => '',
      error: (_, __) => '',
    );
  }

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(allModelsProvider);
    ref.invalidate(downloadedModelsProvider);
    ref.invalidate(availableModelsProvider);
    ref.invalidate(diskUsageProvider);
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'clear_failed':
        _clearFailedDownloads(context, ref);
        break;
      case 'clear_cache':
        _clearCache(context, ref);
        break;
    }
  }

  Future<void> _clearFailedDownloads(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = ref.read(downloadControllerProvider.notifier);
    final allModels = await ref.read(allModelsProvider.future);

    final failedModels = allModels
        .where(
          (m) =>
              m.status == ModelDownloadStatus.failed ||
              m.status == ModelDownloadStatus.cancelled,
        )
        .toList();

    if (failedModels.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No failed downloads to clear')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Failed Downloads'),
        content: Text(
          'Remove ${failedModels.length} failed/cancelled download(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final model in failedModels) {
        await controller.delete(model.id);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleared ${failedModels.length} downloads')),
      );
    }
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
    _refreshAll(ref);
  }

  Widget _buildDownloadedTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<DownloadedModel>> models,
  ) {
    return models.when(
      data: (modelList) {
        final downloaded = modelList
            .where((m) => m.status == ModelDownloadStatus.completed)
            .toList();

        if (downloaded.isEmpty) {
          return _buildEmptyState(
            icon: Icons.download_done,
            title: 'No Downloaded Models',
            subtitle:
                'Download models from Available tab\nor import from local storage',
            action: Column(
              children: [
                TextButton.icon(
                  onPressed: () =>
                      DefaultTabController.of(context).animateTo(1),
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Browse Available'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _showImportDialog,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Import Local'),
                ),
              ],
            ),
          );
        }

        // Group by model type
        final groupedModels = _groupByType(downloaded);

        return RefreshIndicator(
          onRefresh: () async => _refreshAll(ref),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groupedModels.length,
            itemBuilder: (context, index) {
              final entry = groupedModels.entries.elementAt(index);
              return _buildTypeSection(context, entry.key, entry.value);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState(e.toString(), () => _refreshAll(ref)),
    );
  }

  Widget _buildAvailableTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ModelInfo>> models,
  ) {
    return models.when(
      data: (modelList) {
        if (modelList.isEmpty) {
          return _buildEmptyState(
            icon: Icons.cloud_done,
            title: 'All Models Downloaded',
            subtitle: 'You have downloaded all available models',
          );
        }

        // Group by model type
        final groupedModels = <SherpaModelType, List<ModelInfo>>{};
        for (final model in modelList) {
          groupedModels.putIfAbsent(model.modelType, () => []).add(model);
        }

        return RefreshIndicator(
          onRefresh: () async => _refreshAll(ref),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groupedModels.length,
            itemBuilder: (context, index) {
              final entry = groupedModels.entries.elementAt(index);
              return _buildInfoTypeSection(context, entry.key, entry.value);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState(e.toString(), () => _refreshAll(ref)),
    );
  }

  Widget _buildAllTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<DownloadedModel>> models,
  ) {
    return models.when(
      data: (modelList) {
        if (modelList.isEmpty) {
          return _buildEmptyState(
            icon: Icons.folder_open,
            title: 'No Models',
            subtitle: 'Download or import models to get started',
            action: Column(
              children: [
                TextButton.icon(
                  onPressed: () =>
                      DefaultTabController.of(context).animateTo(1),
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('Browse Available'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _showImportDialog,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Import Local'),
                ),
              ],
            ),
          );
        }

        // Sort by status (active downloads first)
        modelList.sort((a, b) {
          final statusOrder = {
            ModelDownloadStatus.downloading: 0,
            ModelDownloadStatus.extracting: 1,
            ModelDownloadStatus.paused: 2,
            ModelDownloadStatus.pending: 3,
            ModelDownloadStatus.completed: 4,
            ModelDownloadStatus.failed: 5,
            ModelDownloadStatus.cancelled: 6,
          };
          final aOrder = statusOrder[a.status] ?? 99;
          final bOrder = statusOrder[b.status] ?? 99;
          if (aOrder != bOrder) return aOrder.compareTo(bOrder);
          // Active models first within completed
          if (a.isActive && !b.isActive) return -1;
          if (!a.isActive && b.isActive) return 1;
          return a.name.compareTo(b.name);
        });

        return RefreshIndicator(
          onRefresh: () async => _refreshAll(ref),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: modelList.length,
            itemBuilder: (context, index) {
              return DownloadItemWidget(model: modelList[index]);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState(e.toString(), () => _refreshAll(ref)),
    );
  }

  Map<SherpaModelType, List<DownloadedModel>> _groupByType(
    List<DownloadedModel> models,
  ) {
    final grouped = <SherpaModelType, List<DownloadedModel>>{};
    for (final model in models) {
      grouped.putIfAbsent(model.modelType, () => []).add(model);
    }

    // Sort each group: active first, then by name
    for (final list in grouped.values) {
      list.sort((a, b) {
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        return a.name.compareTo(b.name);
      });
    }

    return grouped;
  }

  Widget _buildTypeSection(
    BuildContext context,
    SherpaModelType type,
    List<DownloadedModel> models,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, type, models.length),
        ...models.map((model) => DownloadItemWidget(model: model)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildInfoTypeSection(
    BuildContext context,
    SherpaModelType type,
    List<ModelInfo> models,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, type, models.length),
        ...models.map((info) => DownloadItemWidget(modelInfo: info)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    SherpaModelType type,
    int count,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _getTypeIcon(type),
          const SizedBox(width: 8),
          Text(
            _getTypeName(type),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Icon _getTypeIcon(SherpaModelType type) {
    switch (type) {
      case SherpaModelType.tts:
        return const Icon(
          Icons.record_voice_over,
          size: 20,
          color: Colors.blue,
        );
      case SherpaModelType.stt:
        return const Icon(Icons.hearing, size: 20, color: Colors.green);
      case SherpaModelType.vad:
        return const Icon(Icons.mic, size: 20, color: Colors.orange);
      case SherpaModelType.speakerIdentification:
        return const Icon(Icons.person_search, size: 20, color: Colors.purple);
      case SherpaModelType.languageIdentification:
        return const Icon(Icons.language, size: 20, color: Colors.teal);
    }
  }

  String _getTypeName(SherpaModelType type) {
    switch (type) {
      case SherpaModelType.tts:
        return 'Text-to-Speech';
      case SherpaModelType.stt:
        return 'Speech-to-Text';
      case SherpaModelType.vad:
        return 'Voice Activity Detection';
      case SherpaModelType.speakerIdentification:
        return 'Speaker Identification';
      case SherpaModelType.languageIdentification:
        return 'Language Identification';
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 24), action],
          ],
        ),
      ),
    );
  }

  Future<void> _showImportDialog() async {
    final importServiceAsync = ref.read(modelImportServiceProvider);

    // Wait for the import service to be ready
    final importService = importServiceAsync.when(
      data: (service) => service,
      loading: () => null,
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize import: $e')),
        );
        return null;
      },
    );

    if (importService == null || !mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ModelImportDialog(
        importService: importService,
        onImportComplete: (model) async {
          final controller = ref.read(downloadControllerProvider.notifier);
          await controller.addImportedModel(model);
        },
      ),
    );

    if (result == true) {
      _refreshAll(ref);
    }
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Error Loading Models',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

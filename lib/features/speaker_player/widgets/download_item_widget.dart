import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/download_model.dart';
import '../models/model_info.dart';
import '../providers/model_download_provider.dart';

class DownloadItemWidget extends ConsumerStatefulWidget {
  final DownloadedModel? model;
  final ModelInfo? modelInfo;

  const DownloadItemWidget({super.key, this.model, this.modelInfo})
    : assert(model != null || modelInfo != null);

  @override
  ConsumerState<DownloadItemWidget> createState() => _DownloadItemWidgetState();
}

class _DownloadItemWidgetState extends ConsumerState<DownloadItemWidget> {
  // Local state for real-time updates
  ModelDownloadStatus? _currentStatus;
  double _currentProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  bool _isProcessing = false;
  bool _isActive = false;

  String get _modelId => widget.model?.id ?? widget.modelInfo?.id ?? '';

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
    if (widget.model != null) {
      _currentStatus = widget.model!.status;
      _currentProgress = widget.model!.progress;
      _downloadedBytes = widget.model!.downloadedBytes;
      _totalBytes = widget.model!.totalBytes;
      _errorMessage = widget.model!.errorMessage;
      _isActive = widget.model!.isActive;
    }
  }

  @override
  void didUpdateWidget(DownloadItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != null && widget.model != oldWidget.model) {
      setState(() {
        _currentStatus = widget.model!.status;
        _currentProgress = widget.model!.progress;
        _downloadedBytes = widget.model!.downloadedBytes;
        _totalBytes = widget.model!.totalBytes;
        _errorMessage = widget.model!.errorMessage;
        _isActive = widget.model!.isActive;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(downloadControllerProvider.notifier);

    // Listen to download events for THIS model
    ref.listen(downloadEventsProvider, (previous, next) {
      next.whenData((event) {
        if (event.modelId == _modelId) {
          setState(() {
            _currentStatus = event.status;
            _isProcessing = false;

            if (event.progress != null) {
              _currentProgress = event.progress!;
            }
            if (event.downloadedBytes != null) {
              _downloadedBytes = event.downloadedBytes!;
            }
            if (event.totalBytes != null) {
              _totalBytes = event.totalBytes!;
            }
            if (event.error != null) {
              _errorMessage = event.error;
            }
            if (event.isActivated) {
              _isActive = true;
            }

            if (event.status == ModelDownloadStatus.downloading ||
                event.status == ModelDownloadStatus.completed) {
              _errorMessage = null;
            }
          });

          if (event.isCompleted || event.isDeleted || event.isActivated) {
            ref.invalidate(allModelsProvider);
            ref.invalidate(downloadedModelsProvider);
            ref.invalidate(availableModelsProvider);
            ref.invalidate(diskUsageProvider);
          }
        }
      });
    });

    if (widget.model != null) {
      return _buildModelCard(context, widget.model!, controller);
    } else if (widget.modelInfo != null) {
      return _buildInfoCard(context, widget.modelInfo!, controller);
    }

    return const SizedBox.shrink();
  }

  ModelDownloadStatus get _effectiveStatus =>
      _currentStatus ?? widget.model?.status ?? ModelDownloadStatus.pending;

  bool get _isDownloading =>
      _effectiveStatus == ModelDownloadStatus.downloading;
  bool get _isPaused => _effectiveStatus == ModelDownloadStatus.paused;
  bool get _isExtracting => _effectiveStatus == ModelDownloadStatus.extracting;
  bool get _isFailed => _effectiveStatus == ModelDownloadStatus.failed;
  bool get _isCompleted => _effectiveStatus == ModelDownloadStatus.completed;
  bool get _isPending => _effectiveStatus == ModelDownloadStatus.pending;

  Widget _buildModelCard(
    BuildContext context,
    DownloadedModel model,
    DownloadController controller,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: _isActive ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _isActive
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isCompleted
            ? () => _showOptionsMenu(context, model, controller)
            : null,
        onLongPress: _isCompleted
            ? () => _showOptionsMenu(context, model, controller)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _buildTypeIcon(model.modelType),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                model.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (_isActive && _isCompleted) _buildActiveChip(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${model.language} • ${_getTypeLabel(model.modelType)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(_effectiveStatus),
                ],
              ),

              // Description
              if (model.description != null &&
                  model.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  model.description!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Progress section
              if (_isDownloading ||
                  _isPaused ||
                  _isExtracting ||
                  _isPending) ...[
                const SizedBox(height: 12),
                _buildProgressSection(context),
              ],

              // Error message
              if (_errorMessage != null && _isFailed) ...[
                const SizedBox(height: 8),
                _buildErrorMessage(),
              ],

              // Actions
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _buildActions(context, model, controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _isExtracting || _isPending ? null : _currentProgress,
            backgroundColor: Colors.grey[300],
            minHeight: 6,
            valueColor: AlwaysStoppedAnimation<Color>(
              _isPaused
                  ? Colors.orange
                  : _isExtracting
                  ? Colors.purple
                  : Colors.blue,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (_isDownloading) ...[
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_isExtracting) ...[
                  const Icon(Icons.unarchive, size: 14, color: Colors.purple),
                  const SizedBox(width: 4),
                ],
                Text(
                  _getProgressStatusText(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _isPaused ? Colors.orange : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (_totalBytes > 0 && !_isExtracting)
              Text(
                '${_formatBytes(_downloadedBytes)} / ${_formatBytes(_totalBytes)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        if (!_isExtracting && !_isPending && _currentProgress > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${(_currentProgress * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _getProgressStatusText() {
    if (_isPending) return 'Preparing download...';
    if (_isExtracting) return 'Extracting files...';
    if (_isPaused) return 'Paused';
    if (_isDownloading) return 'Downloading...';
    return '';
  }

  Widget _buildInfoCard(
    BuildContext context,
    ModelInfo info,
    DownloadController controller,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildTypeIcon(info.modelType),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${info.language} • ${_getTypeLabel(info.modelType)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  if (info.estimatedSize != null)
                    Text(
                      'Size: ~${_formatBytes(info.estimatedSize!)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () async {
                      setState(() => _isProcessing = true);
                      await controller.download(info);
                    },
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download, size: 18),
              label: Text(_isProcessing ? 'Starting...' : 'Download'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(
    BuildContext context,
    DownloadedModel model,
    DownloadController controller,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Model info header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildTypeIcon(model.modelType),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${model.language} • ${_getTypeLabel(model.modelType)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (_isActive)
                    const Chip(
                      label: Text('Active'),
                      backgroundColor: Colors.green,
                      labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Options
            if (!_isActive)
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Set as Default'),
                subtitle: Text(
                  'Use this model for ${_getTypeLabel(model.modelType)}',
                ),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _isProcessing = true);
                  await controller.setActive(model.id);
                  setState(() {
                    _isProcessing = false;
                    _isActive = true;
                  });
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${model.name} is now the default'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),

            if (_isActive)
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.orange,
                ),
                title: const Text('Remove as Default'),
                subtitle: const Text(
                  'This model will no longer be the default',
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _removeAsDefault(context, model, controller);
                  } catch (e) {
                    debugPrint(e.toString());
                  }
                },
              ),

            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: const Text('Model Info'),
              onTap: () {
                Navigator.pop(context);
                _showModelInfo(context, model);
              },
            ),

            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Model'),
              subtitle: const Text('Remove from device'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, model, controller);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _removeAsDefault(
    BuildContext context,
    DownloadedModel model,
    DownloadController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove as Default'),
        content: Text(
          'Remove "${model.name}" as the default ${_getTypeLabel(model.modelType)} model?\n\n'
          'You can set another model as default later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      await controller.removeActive(model.id);
      setState(() {
        _isProcessing = false;
        _isActive = false;
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${model.name} is no longer the default'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showModelInfo(BuildContext context, DownloadedModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            _buildTypeIcon(model.modelType),
            const SizedBox(width: 12),
            Expanded(child: Text(model.name)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Type', _getTypeLabel(model.modelType)),
              _buildInfoRow('Language', model.language),
              if (model.description != null)
                _buildInfoRow('Description', model.description!),
              _buildInfoRow('Status', _isActive ? 'Active (Default)' : 'Ready'),
              if (model.downloadedAt != null)
                _buildInfoRow('Downloaded', _formatDate(model.downloadedAt!)),
              if (model.lastUsedAt != null)
                _buildInfoRow('Last Used', _formatDate(model.lastUsedAt!)),
              _buildInfoRow('Version', 'v${model.version}'),
              if (model.localPath.isNotEmpty)
                _buildInfoRow('Path', model.localPath, isPath: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPath = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isPath ? 11 : 14,
                fontFamily: isPath ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildActions(
    BuildContext context,
    DownloadedModel model,
    DownloadController controller,
  ) {
    final actions = <Widget>[];

    if (_isDownloading) {
      actions.add(
        _ActionButton(
          onPressed: _isProcessing
              ? null
              : () async {
                  setState(() => _isProcessing = true);
                  await controller.pause(model.id);
                  setState(() => _isProcessing = false);
                },
          icon: Icons.pause,
          label: 'Pause',
          isLoading: _isProcessing,
          color: Colors.orange,
        ),
      );
      actions.add(const SizedBox(width: 8));
      actions.add(
        _ActionButton(
          onPressed: () => _showCancelConfirmation(context, model, controller),
          icon: Icons.close,
          label: 'Cancel',
          color: Colors.red,
        ),
      );
    } else if (_isPaused) {
      actions.add(
        _ActionButton(
          onPressed: _isProcessing
              ? null
              : () async {
                  setState(() => _isProcessing = true);
                  await controller.resume(model.id);
                },
          icon: Icons.play_arrow,
          label: 'Resume',
          isLoading: _isProcessing,
          color: Colors.green,
        ),
      );
      actions.add(const SizedBox(width: 8));
      actions.add(
        _ActionButton(
          onPressed: () => _showCancelConfirmation(context, model, controller),
          icon: Icons.close,
          label: 'Cancel',
          color: Colors.red,
        ),
      );
    } else if (_isExtracting) {
      actions.add(
        _ActionButton(
          onPressed: () => _showCancelConfirmation(context, model, controller),
          icon: Icons.close,
          label: 'Cancel',
          color: Colors.red,
        ),
      );
    } else if (_isFailed) {
      actions.add(
        _ActionButton(
          onPressed: _isProcessing
              ? null
              : () async {
                  setState(() {
                    _isProcessing = true;
                    _errorMessage = null;
                  });
                  await controller.resume(model.id);
                },
          icon: Icons.refresh,
          label: 'Retry',
          isLoading: _isProcessing,
          color: Colors.blue,
        ),
      );
      actions.add(const SizedBox(width: 8));
      actions.add(
        _ActionButton(
          onPressed: () => _showDeleteConfirmation(context, model, controller),
          icon: Icons.delete_outline,
          label: 'Remove',
          color: Colors.red,
        ),
      );
    } else if (_isCompleted) {
      // Show options button for completed models
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _showOptionsMenu(context, model, controller),
          icon: const Icon(Icons.more_horiz, size: 18),
          label: const Text('Options'),
        ),
      );
    }

    return actions;
  }

  Widget _buildActiveChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 12, color: Colors.green),
          SizedBox(width: 4),
          Text(
            'Default',
            style: TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelConfirmation(
    BuildContext context,
    DownloadedModel model,
    DownloadController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Download'),
        content: Text(
          'Are you sure you want to cancel downloading "${model.name}"?\n\n'
          'All progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Downloading'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Download'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      await controller.cancel(model.id);
    }
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    DownloadedModel model,
    DownloadController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${model.name}"?'),
            const SizedBox(height: 8),
            const Text(
              'This will remove the model files from your device.',
              style: TextStyle(color: Colors.grey),
            ),
            if (_isActive) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is currently the default model',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      await controller.delete(model.id);
    }
  }

  Widget _buildTypeIcon(SherpaModelType type) {
    IconData icon;
    Color color;

    switch (type) {
      case SherpaModelType.tts:
        icon = Icons.record_voice_over;
        color = Colors.blue;
        break;
      case SherpaModelType.stt:
        icon = Icons.hearing;
        color = Colors.green;
        break;
      case SherpaModelType.vad:
        icon = Icons.mic;
        color = Colors.orange;
        break;
      case SherpaModelType.speakerIdentification:
        icon = Icons.person_search;
        color = Colors.purple;
        break;
      case SherpaModelType.languageIdentification:
        icon = Icons.language;
        color = Colors.teal;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildStatusChip(ModelDownloadStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case ModelDownloadStatus.pending:
        color = Colors.grey;
        label = 'Pending';
        icon = Icons.hourglass_empty;
        break;
      case ModelDownloadStatus.downloading:
        color = Colors.blue;
        label = 'Downloading';
        icon = Icons.downloading;
        break;
      case ModelDownloadStatus.paused:
        color = Colors.orange;
        label = 'Paused';
        icon = Icons.pause_circle;
        break;
      case ModelDownloadStatus.completed:
        color = Colors.green;
        label = 'Ready';
        icon = Icons.check_circle;
        break;
      case ModelDownloadStatus.failed:
        color = Colors.red;
        label = 'Failed';
        icon = Icons.error;
        break;
      case ModelDownloadStatus.cancelled:
        color = Colors.grey;
        label = 'Cancelled';
        icon = Icons.cancel;
        break;
      case ModelDownloadStatus.extracting:
        color = Colors.purple;
        label = 'Extracting';
        icon = Icons.unarchive;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(SherpaModelType type) {
    switch (type) {
      case SherpaModelType.tts:
        return 'Text-to-Speech';
      case SherpaModelType.stt:
        return 'Speech-to-Text';
      case SherpaModelType.vad:
        return 'Voice Activity';
      case SherpaModelType.speakerIdentification:
        return 'Speaker ID';
      case SherpaModelType.languageIdentification:
        return 'Language ID';
    }
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

class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool isLoading;
  final Color color;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isLoading = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(foregroundColor: color),
    );
  }
}

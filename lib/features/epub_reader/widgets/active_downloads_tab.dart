import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../models/download_task.dart';
import '../providers/epub_provider.dart';

class ActiveDownloadsTab extends ConsumerWidget {
  final VoidCallback? onDownloadComplete;

  const ActiveDownloadsTab({super.key, this.onDownloadComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);
    final tasks = downloadState.tasks;

    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    // Sort: active first, then by date
    final sortedTasks = List<DownloadTask>.from(tasks)
      ..sort((a, b) {
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedTasks.length,
      itemBuilder: (context, index) {
        final task = sortedTasks[index];
        return CompactDownloadCard(
          task: task,
          onPause: () =>
              ref.read(downloadProvider.notifier).pauseDownload(task.id),
          onResume: () =>
              ref.read(downloadProvider.notifier).resumeDownload(task.id),
          onCancel: () => _confirmCancel(context, ref, task),
          onRetry: () =>
              ref.read(downloadProvider.notifier).retryDownload(task.id),
          onRemove: () =>
              ref.read(downloadProvider.notifier).removeTask(task.id),
          onOpen: task.status == DownloadStatus.completed
              ? () => _openBook(context, ref, task)
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_download_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No Downloads',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your active downloads will appear here',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref, DownloadTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Download?'),
        content: const Text('This will stop and remove the download.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(downloadProvider.notifier).cancelDownload(task.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _openBook(BuildContext context, WidgetRef ref, DownloadTask task) {
    // Navigate to reader - handled by parent
  }
}

/// Compact Download Card
class CompactDownloadCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;
  final VoidCallback? onOpen;

  const CompactDownloadCard({
    super.key,
    required this.task,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
    this.onRemove,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: task.status == DownloadStatus.completed ? onOpen : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Status indicator
                _buildStatusIndicator(),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        _extractTitle(task.fileName),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Status & Progress
                      if (task.status == DownloadStatus.downloading) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: task.progress,
                                  backgroundColor: Colors.grey[200],
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${task.progressPercentage}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              task.progressText,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${task.formattedSpeed} • ${task.formattedTimeRemaining}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor().withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getStatusText(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getStatusColor(),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (task.status == DownloadStatus.failed &&
                                task.errorMessage != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task.errorMessage!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red[400],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions
                const SizedBox(width: 8),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final size = 36.0;

    if (task.status == DownloadStatus.downloading) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: task.progress,
              strokeWidth: 3,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation(Colors.blue),
            ),
            Icon(Icons.download, size: 14, color: Colors.blue[700]),
          ],
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(_getStatusIcon(), color: _getStatusColor(), size: 18),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.canPause) _miniButton(Icons.pause, onPause, tooltip: 'Pause'),
        if (task.canResume)
          _miniButton(Icons.play_arrow, onResume, tooltip: 'Resume'),
        if (task.canRetry)
          _miniButton(Icons.refresh, onRetry, tooltip: 'Retry'),
        if (task.status == DownloadStatus.completed)
          _miniButton(
            Icons.menu_book,
            onOpen,
            color: Colors.green,
            tooltip: 'Read',
          ),
        if (task.canCancel)
          _miniButton(
            Icons.close,
            onCancel,
            color: Colors.red,
            tooltip: 'Cancel',
          ),
        if (task.status == DownloadStatus.completed ||
            task.status == DownloadStatus.cancelled ||
            task.status == DownloadStatus.failed)
          _miniButton(
            Icons.delete_outline,
            onRemove,
            color: Colors.grey,
            tooltip: 'Remove',
          ),
      ],
    );
  }

  Widget _miniButton(
    IconData icon,
    VoidCallback? onTap, {
    Color? color,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color ?? Colors.grey[700]),
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (task.status) {
      case DownloadStatus.queued:
        return Icons.hourglass_empty;
      case DownloadStatus.paused:
        return Icons.pause;
      case DownloadStatus.completed:
        return Icons.check;
      case DownloadStatus.failed:
        return Icons.error_outline;
      case DownloadStatus.cancelled:
        return Icons.cancel_outlined;
      default:
        return Icons.download;
    }
  }

  Color _getStatusColor() {
    switch (task.status) {
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.queued:
        return Colors.orange;
      case DownloadStatus.paused:
        return Colors.amber[700]!;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.cancelled:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (task.status) {
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  String _extractTitle(String fileName) {
    String name = fileName;
    if (name.toLowerCase().endsWith('.epub')) {
      name = name.substring(0, name.length - 5);
    }
    return name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  }
}

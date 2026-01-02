import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import '../shared/widgets/empty_state_widget.dart';
import '../shared/widgets/loading_widget.dart';
import '../../features/documents/models/download_task.dart';
import '../providers/download_providers.dart';
import 'package:slideup/features/documents/screens/unified_reader_screen.dart';
import '../models/media_file.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsState = ref.watch(downloadsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Downloads'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
              Tab(text: 'Failed'),
            ],
          ),
          actions: [
            if (downloadsState.downloads.isNotEmpty)
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, ref, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'cancel_all',
                    child: Text('Cancel All'),
                  ),
                  const PopupMenuItem(
                    value: 'clear_completed',
                    child: Text('Clear Completed'),
                  ),
                  const PopupMenuItem(
                    value: 'clear_failed',
                    child: Text('Clear Failed'),
                  ),
                ],
              ),
          ],
        ),
        body: downloadsState.isLoading
            ? const LoadingWidget()
            : TabBarView(
                children: [
                  _ActiveDownloadsList(
                    downloads: downloadsState.activeDownloads,
                  ),
                  _CompletedDownloadsList(
                    downloads: downloadsState.completedDownloads,
                  ),
                  _FailedDownloadsList(
                    downloads: downloadsState.failedDownloads,
                  ),
                ],
              ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    final notifier = ref.read(downloadsProvider.notifier);
    final state = ref.read(downloadsProvider);

    switch (action) {
      case 'cancel_all':
        for (final download in state.activeDownloads) {
          notifier.cancelDownload(download.id);
        }
        break;
      case 'clear_completed':
        for (final download in state.completedDownloads) {
          notifier.deleteDownload(download.id);
        }
        break;
      case 'clear_failed':
        for (final download in state.failedDownloads) {
          notifier.deleteDownload(download.id);
        }
        break;
    }
  }
}

class _ActiveDownloadsList extends ConsumerWidget {
  final List<DownloadTask> downloads;

  const _ActiveDownloadsList({required this.downloads});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (downloads.isEmpty) {
      return const EmptyStateWidget(
        title: 'No active downloads',
        subtitle: 'Downloads in progress will appear here',
        icon: Icons.download_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: downloads.length,
      itemBuilder: (context, index) {
        final download = downloads[index];
        return _ActiveDownloadItem(
          key: ValueKey(download.id),
          download: download,
        );
      },
    );
  }
}

class _ActiveDownloadItem extends ConsumerWidget {
  final DownloadTask download;

  const _ActiveDownloadItem({super.key, required this.download});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(downloadProgressProvider(download.id));
    final currentDownload = progressAsync.value ?? download;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Progress indicator
            CircularPercentIndicator(
              radius: 28,
              lineWidth: 4,
              percent: currentDownload.progress,
              center: Text(
                '${currentDownload.progressPercent}%',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              progressColor: _getStatusColor(
                currentDownload.status,
                colorScheme,
              ),
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentDownload.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentDownload.formattedProgress,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getStatusText(currentDownload.status),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getStatusColor(
                        currentDownload.status,
                        colorScheme,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currentDownload.canPause)
                  IconButton(
                    icon: const Icon(Icons.pause),
                    onPressed: () => ref
                        .read(downloadsProvider.notifier)
                        .pauseDownload(currentDownload.id),
                    tooltip: 'Pause',
                  ),
                if (currentDownload.canResume)
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => ref
                        .read(downloadsProvider.notifier)
                        .resumeDownload(currentDownload.id),
                    tooltip: 'Resume',
                  ),
                if (currentDownload.canCancel)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _showCancelDialog(context, ref),
                    tooltip: 'Cancel',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Download'),
        content: Text('Cancel downloading "${download.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(downloadsProvider.notifier).cancelDownload(download.id);
              Navigator.pop(context);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(DownloadStatus status, ColorScheme colorScheme) {
    switch (status) {
      case DownloadStatus.downloading:
        return colorScheme.primary;
      case DownloadStatus.paused:
        return colorScheme.secondary;
      case DownloadStatus.pending:
        return colorScheme.outline;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return colorScheme.error;
      case DownloadStatus.cancelled:
        return colorScheme.outline;
    }
  }

  String _getStatusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.pending:
        return 'Waiting...';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class _CompletedDownloadsList extends ConsumerWidget {
  final List<DownloadTask> downloads;

  const _CompletedDownloadsList({required this.downloads});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (downloads.isEmpty) {
      return const EmptyStateWidget(
        title: 'No completed downloads',
        subtitle: 'Completed downloads will appear here',
        icon: Icons.download_done_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: downloads.length,
      itemBuilder: (context, index) {
        final download = downloads[index];
        return _CompletedDownloadItem(
          key: ValueKey(download.id),
          download: download,
        );
      },
    );
  }
}

class _CompletedDownloadItem extends ConsumerWidget {
  final DownloadTask download;

  const _CompletedDownloadItem({super.key, required this.download});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _openFile(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Colors.green),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      download.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      download.formattedSize,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              PopupMenuButton<String>(
                onSelected: (value) => _handleAction(context, ref, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: ListTile(
                      leading: Icon(Icons.open_in_new),
                      title: Text('Open'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.share),
                      title: Text('Share'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'open':
        _openFile(context);
        break;
      case 'share':
        _shareFile();
        break;
      case 'delete':
        _showDeleteDialog(context, ref);
        break;
    }
  }

  Future<void> _openFile(BuildContext context) async {
    if (download.filePath == null) return;

    try {
      final file = File(download.filePath!);
      if (await file.exists()) {
        final size = await file.length();
        final modified = await file.lastModified();
        final extension = path.extension(file.path).toLowerCase();
        final MediaFile mediafile = MediaFile(
          id: file.path,
          name: file.path,
          path: file.path,
          type: MediaType.document,
          size: size,
          dateModified: modified,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UnifiedReaderScreen(
              documentUrl: mediafile.path,
              title: mediafile.name,
              source: 'local',
            ),
          ),
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('File not found')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open file: $e')));
      }
    }
  }

  Future<void> _shareFile() async {
    if (download.filePath == null) return;

    try {
      await Share.shareXFiles([
        XFile(download.filePath!),
      ], text: download.title);
    } catch (e) {
      debugPrint('Failed to share file: $e');
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete "${download.title}"?'),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: true,
              onChanged: null,
              title: const Text('Also delete file'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(downloadsProvider.notifier)
                  .deleteDownload(download.id, deleteFile: true);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _FailedDownloadsList extends ConsumerWidget {
  final List<DownloadTask> downloads;

  const _FailedDownloadsList({required this.downloads});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (downloads.isEmpty) {
      return const EmptyStateWidget(
        title: 'No failed downloads',
        subtitle: 'Failed downloads will appear here',
        icon: Icons.error_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: downloads.length,
      itemBuilder: (context, index) {
        final download = downloads[index];
        return _FailedDownloadItem(
          key: ValueKey(download.id),
          download: download,
        );
      },
    );
  }
}

class _FailedDownloadItem extends ConsumerWidget {
  final DownloadTask download;

  const _FailedDownloadItem({super.key, required this.download});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.error_outline, color: colorScheme.error),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    download.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    download.error ?? 'Download failed',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref
                      .read(downloadsProvider.notifier)
                      .retryDownload(download.id),
                  tooltip: 'Retry',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => ref
                      .read(downloadsProvider.notifier)
                      .deleteDownload(download.id),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

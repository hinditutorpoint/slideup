import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../models/download_task.dart';
import '../providers/epub_provider.dart';

/// Compact download progress indicator for list items
class DownloadProgressIndicator extends ConsumerWidget {
  final String taskId;
  final double size;
  final double strokeWidth;

  const DownloadProgressIndicator({
    super.key,
    required this.taskId,
    this.size = 24,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final downloadState = ref.watch(downloadProvider);
      final task = downloadState.tasks.cast<DownloadTask?>().firstWhere(
        (t) => t?.id == taskId,
        orElse: () => null,
      );

      if (task == null) {
        return SizedBox(width: size, height: size);
      }

      return _buildIndicator(context, task);
    } catch (e) {
      return SizedBox(width: size, height: size);
    }
  }

  Widget _buildIndicator(BuildContext context, DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: task.progress,
            strokeWidth: strokeWidth,
            valueColor: const AlwaysStoppedAnimation(Colors.blue),
          ),
        );

      case DownloadStatus.queued:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation(Colors.orange.shade300),
          ),
        );

      case DownloadStatus.paused:
        return Icon(
          Icons.pause_circle_filled,
          size: size,
          color: Colors.orange,
        );

      case DownloadStatus.completed:
        return Icon(Icons.check_circle, size: size, color: Colors.green);

      case DownloadStatus.failed:
        return Icon(Icons.error, size: size, color: Colors.red);

      case DownloadStatus.cancelled:
        return Icon(Icons.cancel, size: size, color: Colors.grey);

      default:
        return Icon(Icons.download_outlined, size: size, color: Colors.grey);
    }
  }
}

/// Full download progress card
class DownloadProgressCard extends ConsumerWidget {
  final DownloadTask task;
  final String? bookTitle;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onOpen;

  const DownloadProgressCard({
    super.key,
    required this.task,
    this.bookTitle,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Status icon
                _buildStatusIcon(),
                const SizedBox(width: 12),

                // Title and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookTitle ?? task.fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.statusText,
                        style: TextStyle(
                          color: task.status.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                _buildActionButtons(context),
              ],
            ),

            // Progress section (for downloading/paused states)
            if (task.status == DownloadStatus.downloading ||
                task.status == DownloadStatus.paused ||
                task.status == DownloadStatus.queued) ...[
              const SizedBox(height: 16),
              _buildProgressSection(),
            ],

            // Error message (for failed state)
            if (task.status == DownloadStatus.failed &&
                task.errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorMessage(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    final iconData = task.status.icon;
    final color = task.status.color;

    if (task.status == DownloadStatus.downloading) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: task.progress,
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(color),
            ),
            Text(
              '${task.progressPercentage}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.canPause)
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: onPause,
            tooltip: 'Pause',
            iconSize: 20,
          ),

        if (task.canResume)
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: onResume,
            tooltip: 'Resume',
            iconSize: 20,
          ),

        if (task.canRetry)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRetry,
            tooltip: 'Retry',
            iconSize: 20,
          ),

        if (task.isCompleted)
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: onOpen,
            tooltip: 'Open',
            iconSize: 20,
          ),

        if (task.canCancel)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onCancel,
            tooltip: 'Cancel',
            iconSize: 20,
          ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: task.status == DownloadStatus.queued ? null : task.progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(task.status.color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),

        // Progress details
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Downloaded / Total
            Text(
              task.progressText,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),

            // Speed and ETA
            if (task.status == DownloadStatus.downloading)
              Text(
                '${task.formattedSpeed} • ${task.formattedTimeRemaining}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.errorMessage!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Download progress list
class DownloadProgressList extends ConsumerWidget {
  final bool showCompleted;
  final bool showFailed;
  final ScrollController? scrollController;

  const DownloadProgressList({
    super.key,
    this.showCompleted = true,
    this.showFailed = true,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);
    final libraryState = ref.watch(libraryProvider);

    final tasks = _filterTasks(downloadState.tasks);

    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final book = libraryState.books.cast<dynamic>().firstWhere(
          (b) => b.id == task.bookId,
          orElse: () => null,
        );

        return DownloadProgressCard(
          task: task,
          bookTitle: book?.title,
          onPause: () =>
              ref.read(downloadProvider.notifier).pauseDownload(task.id),
          onResume: () =>
              ref.read(downloadProvider.notifier).resumeDownload(task.id),
          onCancel: () => _confirmCancel(context, ref, task),
          onRetry: () =>
              ref.read(downloadProvider.notifier).retryDownload(task.id),
          onOpen: () => _openBook(context, ref, task.bookId),
        );
      },
    );
  }

  List<DownloadTask> _filterTasks(List<DownloadTask> tasks) {
    return tasks.where((task) {
      if (!showCompleted && task.status == DownloadStatus.completed) {
        return false;
      }
      if (!showFailed && task.status == DownloadStatus.failed) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) {
      // Active downloads first
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
      // Then by creation time (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_done, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No active downloads',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your downloads will appear here',
              style: TextStyle(color: Colors.grey[500]),
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
        content: const Text('Are you sure you want to cancel this download?'),
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
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _openBook(BuildContext context, WidgetRef ref, String bookId) {
    // Navigate to reader
    // This would be handled by the parent widget or navigation
  }
}

/// Floating download indicator
class FloatingDownloadIndicator extends ConsumerWidget {
  final VoidCallback? onTap;

  const FloatingDownloadIndicator({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = ref.watch(activeDownloadsCountProvider);
    final progress = ref.watch(overallDownloadProgressProvider);

    if (activeCount == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 16,
      right: 16,
      child: GestureDetector(
        onTap: onTap,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$activeCount downloading',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Download button with state
class DownloadButton extends ConsumerWidget {
  final String bookId;
  final String? downloadUrl;
  final VoidCallback? onDownloadStart;
  final VoidCallback? onOpen;

  const DownloadButton({
    super.key,
    required this.bookId,
    this.downloadUrl,
    this.onDownloadStart,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookStatus = ref.watch(bookWithStatusProvider(bookId));

    if (bookStatus == null) {
      return const SizedBox.shrink();
    }

    if (bookStatus.isDownloaded) {
      return ElevatedButton.icon(
        onPressed: onOpen,
        icon: const Icon(Icons.book),
        label: const Text('Read'),
      );
    }

    if (bookStatus.isDownloading) {
      final task = bookStatus.downloadTask!;
      return OutlinedButton(
        onPressed: () => _showDownloadOptions(context, ref, task),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: task.progress,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 8),
            Text('${task.progressPercentage}%'),
          ],
        ),
      );
    }

    // Not downloaded yet
    if (downloadUrl == null) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.download_outlined),
        label: const Text('Download'),
      );
    }

    return ElevatedButton.icon(
      onPressed: () {
        onDownloadStart?.call();
        ref
            .read(downloadProvider.notifier)
            .startDownload(url: downloadUrl!, bookId: bookId);
      },
      icon: const Icon(Icons.download),
      label: const Text('Download'),
    );
  }

  void _showDownloadOptions(
    BuildContext context,
    WidgetRef ref,
    DownloadTask task,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.canPause)
              ListTile(
                leading: const Icon(Icons.pause),
                title: const Text('Pause Download'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(downloadProvider.notifier).pauseDownload(task.id);
                },
              ),
            if (task.canResume)
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Resume Download'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(downloadProvider.notifier).resumeDownload(task.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text(
                'Cancel Download',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(downloadProvider.notifier).cancelDownload(task.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

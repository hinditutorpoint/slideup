import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../features/documents/models/download_task.dart';
import '../providers/download_providers.dart';

class DownloadButton extends ConsumerWidget {
  final String identifier;
  final String title;
  final String downloadUrl;
  final String mediaType;
  final String? thumbnailUrl;
  final double size;
  final Color? backgroundColor;

  const DownloadButton({
    super.key,
    required this.identifier,
    required this.title,
    required this.downloadUrl,
    required this.mediaType,
    this.thumbnailUrl,
    this.size = 36,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadTask = ref.watch(isDownloadedProvider(identifier));

    return downloadTask.when(
      data: (task) {
        if (task == null) {
          return _DownloadStartButton(
            size: size,
            backgroundColor: backgroundColor,
            onPressed: () => _startDownload(ref),
          );
        }

        return _DownloadProgressButton(
          task: task,
          size: size,
          backgroundColor: backgroundColor,
          onPause: () =>
              ref.read(downloadsProvider.notifier).pauseDownload(task.id),
          onResume: () =>
              ref.read(downloadsProvider.notifier).resumeDownload(task.id),
          onRetry: () =>
              ref.read(downloadsProvider.notifier).retryDownload(task.id),
        );
      },
      loading: () => SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => _DownloadStartButton(
        size: size,
        backgroundColor: backgroundColor,
        onPressed: () => _startDownload(ref),
      ),
    );
  }

  Future<void> _startDownload(WidgetRef ref) async {
    await ref
        .read(downloadsProvider.notifier)
        .startDownload(
          identifier: identifier,
          title: title,
          url: downloadUrl,
          mediaType: mediaType,
          thumbnailUrl: thumbnailUrl,
        );

    // Refresh the download status
    ref.invalidate(isDownloadedProvider(identifier));
  }
}

class _DownloadStartButton extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final VoidCallback onPressed;

  const _DownloadStartButton({
    required this.size,
    this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.black38,
      borderRadius: BorderRadius.circular(size / 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.download, size: size * 0.5, color: Colors.white),
        ),
      ),
    );
  }
}

class _DownloadProgressButton extends ConsumerWidget {
  final DownloadTask task;
  final double size;
  final Color? backgroundColor;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRetry;

  const _DownloadProgressButton({
    required this.task,
    required this.size,
    this.backgroundColor,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for progress updates
    final progressAsync = ref.watch(downloadProgressProvider(task.id));
    final currentTask = progressAsync.value ?? task;

    switch (currentTask.status) {
      case DownloadStatus.completed:
        return _buildCompletedButton(context);
      case DownloadStatus.downloading:
        return _buildProgressButton(context, currentTask, onPause);
      case DownloadStatus.paused:
        return _buildPausedButton(context, currentTask, onResume);
      case DownloadStatus.pending:
        return _buildPendingButton(context);
      case DownloadStatus.failed:
        return _buildFailedButton(context, onRetry);
      case DownloadStatus.cancelled:
        return _DownloadStartButton(
          size: size,
          backgroundColor: backgroundColor,
          onPressed: onRetry,
        );
    }
  }

  Widget _buildCompletedButton(BuildContext context) {
    return Material(
      color: Colors.green,
      borderRadius: BorderRadius.circular(size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.check, size: size * 0.5, color: Colors.white),
      ),
    );
  }

  Widget _buildProgressButton(
    BuildContext context,
    DownloadTask task,
    VoidCallback onPause,
  ) {
    return CircularPercentIndicator(
      radius: size / 2,
      lineWidth: 3,
      percent: task.progress,
      center: InkWell(
        onTap: onPause,
        borderRadius: BorderRadius.circular(size / 2),
        child: Icon(
          Icons.pause,
          size: size * 0.4,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      progressColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildPausedButton(
    BuildContext context,
    DownloadTask task,
    VoidCallback onResume,
  ) {
    return CircularPercentIndicator(
      radius: size / 2,
      lineWidth: 3,
      percent: task.progress,
      center: InkWell(
        onTap: onResume,
        borderRadius: BorderRadius.circular(size / 2),
        child: Icon(
          Icons.play_arrow,
          size: size * 0.4,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      progressColor: Theme.of(context).colorScheme.secondary,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildPendingButton(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _buildFailedButton(BuildContext context, VoidCallback onRetry) {
    return Material(
      color: Theme.of(context).colorScheme.error,
      borderRadius: BorderRadius.circular(size / 2),
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.refresh, size: size * 0.5, color: Colors.white),
        ),
      ),
    );
  }
}

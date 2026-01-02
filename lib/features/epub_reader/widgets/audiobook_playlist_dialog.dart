import 'package:flutter/material.dart';
import '../../speaker_player/services/background_chapter_generator.dart';
import '../../speaker_player/tts_controller.dart';

class AudiobookPlaylistDialog extends StatefulWidget {
  final String bookId;
  final int currentChapterIndex;
  final int totalChapters;
  final List<String> chapterTitles;
  final Function(int chapterIndex)? onChapterTap;

  const AudiobookPlaylistDialog({
    super.key,
    required this.bookId,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.chapterTitles,
    this.onChapterTap,
  });

  @override
  State<AudiobookPlaylistDialog> createState() =>
      _AudiobookPlaylistDialogState();
}

class _AudiobookPlaylistDialogState extends State<AudiobookPlaylistDialog>
    with SingleTickerProviderStateMixin {
  final _bgGenerator = BackgroundChapterGenerator.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 500,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.queue_music),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Audiobook Playlist',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Ready'),
                Tab(text: 'Generating'),
              ],
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllChapters(),
                  _buildReadyChapters(),
                  _buildGeneratingChapters(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllChapters() {
    return StreamBuilder<GenerationJob>(
      stream: _bgGenerator.jobStatusStream,
      builder: (context, snapshot) {
        return FutureBuilder<List<dynamic>>(
          future: TtsController.instance.getGeneratedAudioForBook(
            widget.bookId,
          ),
          builder: (context, cacheSnapshot) {
            final cachedChapters = cacheSnapshot.data ?? [];
            final jobs =
                _bgGenerator.allJobs
                    .where((j) => j.bookId == widget.bookId)
                    .toList()
                  ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.totalChapters,
              itemBuilder: (context, index) {
                final isCurrent = index == widget.currentChapterIndex;
                final isCached = cachedChapters.any(
                  (c) => c.pageNumber == index,
                );
                final job = jobs
                    .where((j) => j.chapterIndex == index)
                    .firstOrNull;

                return _buildChapterItem(
                  index: index,
                  isCurrent: isCurrent,
                  isCached: isCached,
                  job: job,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReadyChapters() {
    return FutureBuilder<List<dynamic>>(
      future: TtsController.instance.getGeneratedAudioForBook(widget.bookId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final cachedChapters = snapshot.data!;
        if (cachedChapters.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No chapters ready yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: cachedChapters.length,
          itemBuilder: (context, index) {
            final entry = cachedChapters[index];
            final chapterIndex = entry.pageNumber ?? 0;
            final isCurrent = chapterIndex == widget.currentChapterIndex;

            return _buildChapterItem(
              index: chapterIndex,
              isCurrent: isCurrent,
              isCached: true,
              job: null,
            );
          },
        );
      },
    );
  }

  Widget _buildGeneratingChapters() {
    return StreamBuilder<GenerationJob>(
      stream: _bgGenerator.jobStatusStream,
      builder: (context, snapshot) {
        final jobs =
            _bgGenerator.allJobs
                .where(
                  (j) =>
                      j.bookId == widget.bookId &&
                      (j.status == JobStatus.generating ||
                          j.status == JobStatus.queued),
                )
                .toList()
              ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));

        if (jobs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'No chapters generating',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            return _buildGeneratingJobItem(job);
          },
        );
      },
    );
  }

  Widget _buildChapterItem({
    required int index,
    required bool isCurrent,
    required bool isCached,
    GenerationJob? job,
  }) {
    final title = index < widget.chapterTitles.length
        ? widget.chapterTitles[index]
        : 'Chapter ${index + 1}';

    return ListTile(
      leading: _buildLeadingIcon(isCurrent, isCached, job),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: isCurrent ? Theme.of(context).primaryColor : null,
        ),
      ),
      subtitle: _buildSubtitle(isCached, job),
      trailing: _buildTrailing(isCached, job),
      onTap: isCached
          ? () {
              widget.onChapterTap?.call(index);
              Navigator.pop(context);
            }
          : null,
      selected: isCurrent,
    );
  }

  Widget _buildLeadingIcon(bool isCurrent, bool isCached, GenerationJob? job) {
    if (isCurrent) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.play_arrow, color: Colors.white),
      );
    }

    if (job?.status == JobStatus.generating) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(value: job!.progress, strokeWidth: 3),
            Text(
              '${(job.progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (isCached) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 40);
    }

    if (job?.status == JobStatus.queued) {
      return const Icon(Icons.schedule, color: Colors.orange, size: 40);
    }

    return const Icon(Icons.music_note_outlined, color: Colors.grey, size: 40);
  }

  Widget? _buildSubtitle(bool isCached, GenerationJob? job) {
    if (job != null) {
      switch (job.status) {
        case JobStatus.generating:
          return Text('Generating: ${(job.progress * 100).toInt()}%');
        case JobStatus.queued:
          return const Text('Queued for generation');
        case JobStatus.completed:
        case JobStatus.skipped:
          return const Text('Ready to play');
        case JobStatus.failed:
          return Text(
            'Failed: ${job.error}',
            style: const TextStyle(color: Colors.red),
          );
        case JobStatus.cancelled:
          return const Text('Cancelled');
      }
    }

    if (isCached) {
      return const Text('Ready');
    }

    return const Text('Not generated');
  }

  Widget? _buildTrailing(bool isCached, GenerationJob? job) {
    if (job?.status == JobStatus.generating ||
        job?.status == JobStatus.queued) {
      return IconButton(
        icon: const Icon(Icons.close, size: 20),
        onPressed: () => _bgGenerator.cancelJob(job!.id),
        tooltip: 'Cancel',
      );
    }

    return null;
  }

  Widget _buildGeneratingJobItem(GenerationJob job) {
    final title = job.chapterIndex < widget.chapterTitles.length
        ? widget.chapterTitles[job.chapterIndex]
        : 'Chapter ${job.chapterIndex + 1}';

    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: job.status == JobStatus.generating ? job.progress : null,
              strokeWidth: 3,
            ),
            if (job.status == JobStatus.generating)
              Text(
                '${(job.progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
      title: Text(title),
      subtitle: Text(
        job.status == JobStatus.generating
            ? 'Generating: ${(job.progress * 100).toInt()}%'
            : 'Queued (position ${_bgGenerator.queuedJobs.indexOf(job) + 1})',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (job.startedAt != null && job.completedAt == null)
            Text(
              _formatElapsedTime(DateTime.now().difference(job.startedAt!)),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => _bgGenerator.cancelJob(job.id),
            tooltip: 'Cancel',
          ),
        ],
      ),
    );
  }

  String _formatElapsedTime(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = duration.inMinutes;
    return '${minutes}m ${seconds % 60}s';
  }
}

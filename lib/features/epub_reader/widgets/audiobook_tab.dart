import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/epub_book.dart';
import '../../speaker_player/tts_controller.dart';
import '../../speaker_player/services/language_detection_service.dart';

/// Audio status for each chapter
enum ChapterAudioStatus { notGenerated, generating, generated, playing, error }

/// Chapter audio info
class ChapterAudioInfo {
  final int chapterIndex;
  final String chapterTitle;
  final ChapterAudioStatus status;
  final Duration? duration;
  final String? audioPath;
  final DateTime? generatedAt;
  final String? error;

  const ChapterAudioInfo({
    required this.chapterIndex,
    required this.chapterTitle,
    this.status = ChapterAudioStatus.notGenerated,
    this.duration,
    this.audioPath,
    this.generatedAt,
    this.error,
  });

  ChapterAudioInfo copyWith({
    ChapterAudioStatus? status,
    Duration? duration,
    String? audioPath,
    DateTime? generatedAt,
    String? error,
  }) {
    return ChapterAudioInfo(
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      status: status ?? this.status,
      duration: duration ?? this.duration,
      audioPath: audioPath ?? this.audioPath,
      generatedAt: generatedAt ?? this.generatedAt,
      error: error,
    );
  }

  String get statusLabel {
    switch (status) {
      case ChapterAudioStatus.notGenerated:
        return 'Not generated';
      case ChapterAudioStatus.generating:
        return 'Generating...';
      case ChapterAudioStatus.generated:
        return duration != null ? _formatDuration(duration!) : 'Ready';
      case ChapterAudioStatus.playing:
        return 'Playing';
      case ChapterAudioStatus.error:
        return 'Error';
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Audiobook tab widget for ChapterDrawer
class AudiobookTab extends ConsumerStatefulWidget {
  final EpubBook book;
  final List<EpubChapterMeta> chapters;
  final int currentChapterIndex;
  final String bookId;
  final Future<String?> Function(int chapterIndex) getChapterText;
  final void Function(int chapterIndex)? onChapterTap;
  final void Function(int chapterIndex)? onAutoAdvanceChapter;
  final void Function()? onStartAudiobook;

  const AudiobookTab({
    super.key,
    required this.book,
    required this.chapters,
    required this.currentChapterIndex,
    required this.bookId,
    required this.getChapterText,
    this.onChapterTap,
    this.onAutoAdvanceChapter,
    this.onStartAudiobook,
  });

  @override
  ConsumerState<AudiobookTab> createState() => _AudiobookTabState();
}

class _AudiobookTabState extends ConsumerState<AudiobookTab> {
  final Map<int, ChapterAudioInfo> _chapterAudioInfo = {};
  bool _isLoading = true;
  int? _currentlyPlaying;
  int? _currentlyGenerating;

  @override
  void initState() {
    super.initState();
    _loadAudioStatus();
  }

  Future<void> _loadAudioStatus() async {
    try {
      setState(() => _isLoading = true);

      // Initialize chapter info
      for (int i = 0; i < widget.chapters.length; i++) {
        final chapter = widget.chapters[i];

        // Check if audio is cached for this chapter
        final isCached = await TtsController.instance.isPageCached(
          bookId: widget.bookId,
          pageNumber: i,
        );

        CachedAudioEntry? cachedEntry;
        if (isCached) {
          final entries = await TtsController.instance.getGeneratedAudioForBook(
            widget.bookId,
          );
          cachedEntry = entries.where((e) => e.pageNumber == i).firstOrNull;
        }

        _chapterAudioInfo[i] = ChapterAudioInfo(
          chapterIndex: i,
          chapterTitle: chapter.title,
          status: isCached
              ? ChapterAudioStatus.generated
              : ChapterAudioStatus.notGenerated,
          duration: cachedEntry?.duration,
          audioPath: cachedEntry?.filePath,
          generatedAt: cachedEntry?.createdAt,
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[AudiobookTab] Load status error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateChapterAudio(int chapterIndex) async {
    if (_currentlyGenerating != null) {
      _showMessage('Already generating audio');
      return;
    }

    try {
      setState(() {
        _currentlyGenerating = chapterIndex;
        _chapterAudioInfo[chapterIndex] = _chapterAudioInfo[chapterIndex]!
            .copyWith(status: ChapterAudioStatus.generating);
      });

      // Get chapter text
      final text = await widget.getChapterText(chapterIndex);
      if (text == null || text.isEmpty) {
        throw Exception('Chapter has no text content');
      }

      // Detect language
      final detectedLang = LanguageDetectionService.instance.detectCode(text);

      // Generate audio
      final result = await TtsController.instance.generateAudio(
        text: text,
        language: detectedLang,
        bookId: widget.bookId,
        pageNumber: chapterIndex,
        useCache: true,
      );

      if (result.success && result.audioPath != null) {
        setState(() {
          _chapterAudioInfo[chapterIndex] = _chapterAudioInfo[chapterIndex]!
              .copyWith(
                status: ChapterAudioStatus.generated,
                audioPath: result.audioPath,
                duration: result.duration,
                generatedAt: DateTime.now(),
              );
        });
        _showMessage(
          'Audio generated for ${widget.chapters[chapterIndex].title}',
        );
      } else {
        throw Exception(result.error ?? 'Generation failed');
      }
    } catch (e) {
      debugPrint('[AudiobookTab] Generate error: $e');
      setState(() {
        _chapterAudioInfo[chapterIndex] = _chapterAudioInfo[chapterIndex]!
            .copyWith(status: ChapterAudioStatus.error, error: e.toString());
      });
      _showMessage('Failed to generate audio: $e');
    } finally {
      setState(() => _currentlyGenerating = null);
    }
  }

  Future<void> _playChapter(int chapterIndex,
      {bool autoAdvance = false}) async {
    try {
      final info = _chapterAudioInfo[chapterIndex];
      if (info == null) return;

      // Stop current playback
      if (_currentlyPlaying != null) {
        await TtsController.instance.stopAll();
        setState(() {
          if (_chapterAudioInfo[_currentlyPlaying!] != null) {
            _chapterAudioInfo[_currentlyPlaying!] =
                _chapterAudioInfo[_currentlyPlaying!]!.copyWith(
                  status: ChapterAudioStatus.generated,
                );
          }
        });
      }

      // If not generated, generate first
      if (info.status == ChapterAudioStatus.notGenerated) {
        await _generateChapterAudio(chapterIndex);
        // Check if generation was successful
        if (_chapterAudioInfo[chapterIndex]?.status !=
            ChapterAudioStatus.generated) {
          return;
        }
      }

      // Play the audio
      setState(() {
        _currentlyPlaying = chapterIndex;
        _chapterAudioInfo[chapterIndex] = _chapterAudioInfo[chapterIndex]!
            .copyWith(status: ChapterAudioStatus.playing);
      });

      final audioPath = _chapterAudioInfo[chapterIndex]!.audioPath;
      if (audioPath == null) {
        throw Exception('Audio path not found');
      }

      // Get cached entry to play
      final entries = await TtsController.instance.getGeneratedAudioForBook(
        widget.bookId,
      );
      final entry = entries
          .where((e) => e.pageNumber == chapterIndex)
          .firstOrNull;
      if (!mounted) return;
      if (entry != null) {
        await TtsController.instance.playCachedEntry(
          entry: entry,
          context: context,
          showUi: true,
          onCompleted: () {
            if (mounted) {
              setState(() {
                _chapterAudioInfo[chapterIndex] =
                    _chapterAudioInfo[chapterIndex]!.copyWith(
                      status: ChapterAudioStatus.generated,
                    );
                _currentlyPlaying = null;
              });

              // Auto-play next chapter
              if (chapterIndex < widget.chapters.length - 1) {
                _playChapter(chapterIndex + 1, autoAdvance: true);
              }
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _chapterAudioInfo[chapterIndex] =
                    _chapterAudioInfo[chapterIndex]!.copyWith(
                      status: ChapterAudioStatus.error,
                      error: error,
                    );
                _currentlyPlaying = null;
              });
            }
          },
        );
      }

      // Notify chapter change.
      // Auto-advance uses the dedicated callback (no drawer pop) so the reader
      // route is never popped from an already-closed drawer.
      final navigate = autoAdvance
          ? (widget.onAutoAdvanceChapter ?? widget.onChapterTap)
          : widget.onChapterTap;
      navigate?.call(chapterIndex);
    } catch (e) {
      debugPrint('[AudiobookTab] Play error: $e');
      _showMessage('Failed to play: $e');
      setState(() {
        _currentlyPlaying = null;
        if (_chapterAudioInfo[chapterIndex] != null) {
          _chapterAudioInfo[chapterIndex] = _chapterAudioInfo[chapterIndex]!
              .copyWith(status: ChapterAudioStatus.error, error: e.toString());
        }
      });
    }
  }

  Future<void> _generateAllChapters() async {
    for (int i = 0; i < widget.chapters.length; i++) {
      if (_chapterAudioInfo[i]?.status == ChapterAudioStatus.notGenerated) {
        await _generateChapterAudio(i);

        // Small delay between generations
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    _showMessage('All chapters generated!');
  }

  Future<void> _deleteChapterAudio(int chapterIndex) async {
    try {
      final entries = await TtsController.instance.getGeneratedAudioForBook(
        widget.bookId,
      );
      final entry = entries
          .where((e) => e.pageNumber == chapterIndex)
          .firstOrNull;

      if (entry != null) {
        await TtsController.instance.deleteCachedEntry(entry);

        setState(() {
          _chapterAudioInfo[chapterIndex] = ChapterAudioInfo(
            chapterIndex: chapterIndex,
            chapterTitle: widget.chapters[chapterIndex].title,
            status: ChapterAudioStatus.notGenerated,
          );
        });

        _showMessage('Audio deleted');
      }
    } catch (e) {
      debugPrint('[AudiobookTab] Delete error: $e');
      _showMessage('Failed to delete: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.chapters.isEmpty) {
      return _buildEmptyState();
    }

    // Calculate stats
    final generatedCount = _chapterAudioInfo.values
        .where((i) => i.status == ChapterAudioStatus.generated)
        .length;
    final totalDuration = _chapterAudioInfo.values
        .where((i) => i.duration != null)
        .fold<Duration>(Duration.zero, (sum, i) => sum + i.duration!);

    return Column(
      children: [
        // Header with stats and actions
        _buildHeader(generatedCount, totalDuration),

        const Divider(height: 1),

        // Chapter list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.chapters.length,
            itemBuilder: (context, index) {
              return _buildChapterTile(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(int generatedCount, Duration totalDuration) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
      child: Column(
        children: [
          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.audiotrack,
                label: 'Generated',
                value: '$generatedCount / ${widget.chapters.length}',
              ),
              _StatItem(
                icon: Icons.timer,
                label: 'Total Duration',
                value: _formatTotalDuration(totalDuration),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _currentlyPlaying == null
                      ? () => _playChapter(widget.currentChapterIndex)
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play from Current'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _currentlyGenerating == null
                    ? _generateAllChapters
                    : null,
                icon: const Icon(Icons.download_for_offline),
                tooltip: 'Generate All',
                style: IconButton.styleFrom(backgroundColor: Colors.grey[200]),
              ),
            ],
          ),

          // Stop button if playing
          if (_currentlyPlaying != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await TtsController.instance.stopAll();
                  setState(() {
                    if (_currentlyPlaying != null &&
                        _chapterAudioInfo[_currentlyPlaying!] != null) {
                      _chapterAudioInfo[_currentlyPlaying!] =
                          _chapterAudioInfo[_currentlyPlaying!]!.copyWith(
                            status: ChapterAudioStatus.generated,
                          );
                    }
                    _currentlyPlaying = null;
                  });
                },
                icon: const Icon(Icons.stop),
                label: const Text('Stop Playback'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChapterTile(int index) {
    final chapter = widget.chapters[index];
    final info = _chapterAudioInfo[index];
    final isCurrent = index == widget.currentChapterIndex;
    final isPlaying = _currentlyPlaying == index;
    final isGenerating = _currentlyGenerating == index;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildLeadingIcon(info, isPlaying, isGenerating),
      title: Text(
        chapter.title,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: isCurrent ? Theme.of(context).primaryColor : null,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        info?.statusLabel ?? 'Unknown',
        style: TextStyle(fontSize: 12, color: _getStatusColor(info?.status)),
      ),
      trailing: _buildTrailingActions(index, info, isPlaying, isGenerating),
      selected: isCurrent,
      selectedTileColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      onTap: () => _playChapter(index),
    );
  }

  Widget _buildLeadingIcon(
    ChapterAudioInfo? info,
    bool isPlaying,
    bool isGenerating,
  ) {
    if (isGenerating) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (isPlaying) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.volume_up, color: Colors.white, size: 18),
      );
    }

    final status = info?.status ?? ChapterAudioStatus.notGenerated;

    IconData icon;
    Color color;

    switch (status) {
      case ChapterAudioStatus.generated:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case ChapterAudioStatus.error:
        icon = Icons.error;
        color = Colors.red;
        break;
      default:
        icon = Icons.radio_button_unchecked;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildTrailingActions(
    int index,
    ChapterAudioInfo? info,
    bool isPlaying,
    bool isGenerating,
  ) {
    if (isGenerating) {
      return const SizedBox(width: 48);
    }

    final status = info?.status ?? ChapterAudioStatus.notGenerated;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == ChapterAudioStatus.generated) ...[
          // Play button
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: () {
              if (isPlaying) {
                TtsController.instance.togglePlayPause();
              } else {
                _playChapter(index);
              }
            },
            tooltip: isPlaying ? 'Pause' : 'Play',
            visualDensity: VisualDensity.compact,
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _deleteChapterAudio(index),
            tooltip: 'Delete audio',
            visualDensity: VisualDensity.compact,
          ),
        ] else if (status == ChapterAudioStatus.notGenerated) ...[
          // Generate button
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _generateChapterAudio(index),
            tooltip: 'Generate audio',
            visualDensity: VisualDensity.compact,
          ),
        ] else if (status == ChapterAudioStatus.error) ...[
          // Retry button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: () => _generateChapterAudio(index),
            tooltip: 'Retry',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(ChapterAudioStatus? status) {
    switch (status) {
      case ChapterAudioStatus.generated:
        return Colors.green;
      case ChapterAudioStatus.generating:
        return Colors.blue;
      case ChapterAudioStatus.playing:
        return Colors.purple;
      case ChapterAudioStatus.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.audiotrack, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No Chapters',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This book has no chapters to generate audio for',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTotalDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

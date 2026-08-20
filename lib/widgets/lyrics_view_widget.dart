import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_data.dart';
import '../models/lyric_line.dart';
import '../providers/audio_handler_provider.dart';
import '../providers/lyrics_provider.dart';
import '../services/lyrics_service.dart';

class LyricsViewWidget extends ConsumerStatefulWidget {
  final String songTitle;
  final String? artist;
  final Duration? duration;
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;
  final AudioData? audioData;

  const LyricsViewWidget({
    super.key,
    required this.songTitle,
    this.artist,
    this.duration,
    this.onClose,
    this.onMinimize,
    this.audioData,
  });

  @override
  ConsumerState<LyricsViewWidget> createState() => _LyricsViewWidgetState();
}

class _LyricsViewWidgetState extends ConsumerState<LyricsViewWidget> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;
  bool _isMinimized = false;

  String get _effectiveTitle => widget.audioData?.title ?? widget.songTitle;
  String? get _effectiveArtist => widget.audioData?.artist ?? widget.artist;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(covariant LyricsViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldEffectiveTitle = oldWidget.audioData?.title ?? oldWidget.songTitle;
    final oldEffectiveArtist = oldWidget.audioData?.artist ?? oldWidget.artist;
    if (oldEffectiveTitle != _effectiveTitle ||
        oldEffectiveArtist != _effectiveArtist) {
      _loadLyrics();
    }
  }

  void _loadLyrics({bool force = false}) {
    Future.microtask(() {
      ref.read(lyricsProvider.notifier).loadLyrics(
            title: _effectiveTitle,
            artist: _effectiveArtist,
            duration: widget.duration,
            forceRefresh: force,
          );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index, int totalLines) {
    if (_userIsScrolling || !_scrollController.hasClients) return;
    if (index < 0 || index >= totalLines) return;

    // Approximate height per line ~ 48px
    const itemHeight = 48.0;
    final viewport = _scrollController.position.viewportDimension;
    final targetOffset =
        (index * itemHeight) - (viewport / 2) + (itemHeight / 2);
    final maxScroll = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  int _findActiveLineIndex(Duration position, List<LyricLine> lines) {
    if (lines.isEmpty) return -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].time) {
        return i;
      }
    }
    return 0;
  }

  void _showManualSearchDialog() {
    final cleanedTitle = LyricsService.cleanQuery(_effectiveTitle);
    final cleanedArtist = _effectiveArtist != null
        ? LyricsService.cleanQuery(_effectiveArtist!)
        : null;
    final searchCtrl = TextEditingController(
      text: cleanedArtist != null && cleanedArtist.isNotEmpty
          ? '$cleanedTitle $cleanedArtist'
          : cleanedTitle,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search Lyrics'),
        content: TextField(
          controller: searchCtrl,
          decoration: const InputDecoration(
            hintText: 'e.g. Kesariya Arijit Singh',
            labelText: 'Song Title & Artist',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final query = searchCtrl.text.trim();
              if (query.isNotEmpty) {
                ref.read(lyricsProvider.notifier).searchCustom(query);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);
    final audioHandler = ref.watch(audioHandlerProvider);
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.lyrics_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lyrics',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (lyricsState.data?.source != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          lyricsState.data!.source!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.unfold_more, size: 20),
                    tooltip: 'Minimize to current line',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      if (widget.onMinimize != null) {
                        widget.onMinimize!();
                      } else {
                        setState(() => _isMinimized = true);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, size: 20),
                    tooltip: 'Manual Search',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _showManualSearchDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Reload',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _loadLyrics(force: true),
                  ),
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Close Lyrics',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onClose,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content Area — minimize shows only the current line
            Flexible(
              child: _isMinimized
                  ? _buildMinimizedBar(lyricsState, audioHandler, theme)
                  : _buildLyricsBody(lyricsState, audioHandler, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimizedBar(
    LyricsState state,
    dynamic audioHandler,
    ThemeData theme,
  ) {
    final lyrics = state.data;
    if (lyrics == null || lyrics.lines.isEmpty) {
      return _buildEmptyMinimizedBar(state, theme);
    }

    if (lyrics.isSynced) {
      return StreamBuilder<Duration>(
        stream: audioHandler.positionStream,
        builder: (context, snapshot) {
          final currentPos = snapshot.data ?? Duration.zero;
          final activeIndex = _findActiveLineIndex(currentPos, lyrics.lines);
          final line = lyrics.lines[activeIndex.clamp(0, lyrics.lines.length - 1)];
          return _MinimizedLine(
            text: line.text,
            onMaximize: () => setState(() => _isMinimized = false),
            theme: theme,
          );
        },
      );
    }

    final topIndex = _scrollController.hasClients
        ? (_scrollController.offset / 48).round().clamp(
              0,
              lyrics.lines.length - 1,
            )
        : 0;
    return _MinimizedLine(
      text: lyrics.lines[topIndex].text,
      onMaximize: () => setState(() => _isMinimized = false),
      theme: theme,
    );
  }

  Widget _buildEmptyMinimizedBar(LyricsState state, ThemeData theme) {
    return _MinimizedLine(
      text: state.error ?? 'No lyrics',
      onMaximize: () => setState(() => _isMinimized = false),
      theme: theme,
    );
  }

  Widget _buildLyricsBody(
    LyricsState state,
    dynamic audioHandler,
    ThemeData theme,
  ) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Searching Bollywood & Global Lyrics...',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (state.error != null || state.data == null || state.data!.isEmpty) {
      return SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.music_off_outlined,
                  size: 48,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 12),
                Text(
                  state.error ?? 'No lyrics found for this track',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showManualSearchDialog,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search by Song Name'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final lyrics = state.data!;

    if (!lyrics.isSynced) {
      // Plain lyrics view
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            _userIsScrolling = true;
          } else if (notification is ScrollEndNotification) {
            _userIsScrolling = false;
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          itemCount: lyrics.lines.length,
          itemBuilder: (context, index) {
            final line = lyrics.lines[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Text(
                line.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      );
    }

    // Synced Karaoke lyrics view
    return StreamBuilder<Duration>(
      stream: audioHandler.positionStream,
      builder: (context, snapshot) {
        final currentPos = snapshot.data ?? Duration.zero;
        final activeIndex = _findActiveLineIndex(currentPos, lyrics.lines);

        if (activeIndex != _lastActiveIndex) {
          _lastActiveIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToIndex(activeIndex, lyrics.lines.length);
          });
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              _userIsScrolling = true;
            } else if (notification is ScrollEndNotification) {
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) _userIsScrolling = false;
              });
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: lyrics.lines.length,
            itemBuilder: (context, index) {
              final line = lyrics.lines[index];
              final isActive = index == activeIndex;

              return GestureDetector(
                onTap: () {
                  audioHandler.seek(line.time);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    line.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isActive ? 19 : 15,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MinimizedLine extends StatelessWidget {
  final String text;
  final VoidCallback onMaximize;
  final ThemeData theme;

  const _MinimizedLine({
    required this.text,
    required this.onMaximize,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.unfold_less, size: 20),
            tooltip: 'Maximize lyrics',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: theme.colorScheme.onSurface,
            onPressed: onMaximize,
          ),
        ],
      ),
    );
  }
}

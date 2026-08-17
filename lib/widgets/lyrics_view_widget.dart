import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lyric_line.dart';
import '../providers/audio_handler_provider.dart';
import '../providers/lyrics_provider.dart';

class LyricsViewWidget extends ConsumerStatefulWidget {
  final String songTitle;
  final String? artist;
  final Duration? duration;
  final VoidCallback? onClose;

  const LyricsViewWidget({
    super.key,
    required this.songTitle,
    this.artist,
    this.duration,
    this.onClose,
  });

  @override
  ConsumerState<LyricsViewWidget> createState() => _LyricsViewWidgetState();
}

class _LyricsViewWidgetState extends ConsumerState<LyricsViewWidget> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(covariant LyricsViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songTitle != widget.songTitle ||
        oldWidget.artist != widget.artist) {
      _loadLyrics();
    }
  }

  void _loadLyrics({bool force = false}) {
    Future.microtask(() {
      ref.read(lyricsProvider.notifier).loadLyrics(
            title: widget.songTitle,
            artist: widget.artist,
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
    final targetOffset = (index * itemHeight) - 100.0;
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
    final searchCtrl = TextEditingController(
      text: widget.artist != null && widget.artist!.isNotEmpty
          ? '${widget.songTitle} ${widget.artist}'
          : widget.songTitle,
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  Icon(
                    Icons.lyrics_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lyrics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (lyricsState.data?.source != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        lyricsState.data!.source!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search, size: 20),
                    tooltip: 'Manual Search',
                    onPressed: _showManualSearchDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Reload',
                    onPressed: () => _loadLyrics(force: true),
                  ),
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Close Lyrics',
                      onPressed: widget.onClose,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content Area — use Flexible so it fills remaining SizedBox height
            Flexible(
              child: _buildLyricsBody(lyricsState, audioHandler, theme),
            ),
          ],
        ),
      ),
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
      return Center(
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

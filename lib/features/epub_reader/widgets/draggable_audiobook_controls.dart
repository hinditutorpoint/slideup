import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/epub_audiobook_controller.dart';
import '../../speaker_player/services/background_chapter_generator.dart';
import '../../speaker_player/tts_controller.dart';

class DraggableAudiobookControls extends StatefulWidget {
  final AudiobookStatus status;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onClose;
  final void Function(double speed)? onSpeedChange;
  final void Function(Duration duration)? onSleepTimer;
  final VoidCallback? onCancelSleepTimer;
  final Color? backgroundColor;
  final Color? textColor;
  final Size screenSize;
  final EdgeInsets safeArea;
  final String? bookId;
  final List<String>? chapterTitles;
  final Function(int chapterIndex)? onChapterTap;

  const DraggableAudiobookControls({
    super.key,
    required this.status,
    required this.onPlayPause,
    required this.onStop,
    required this.onPrevious,
    required this.onNext,
    required this.screenSize,
    required this.safeArea,
    this.onClose,
    this.onSpeedChange,
    this.onSleepTimer,
    this.onCancelSleepTimer,
    this.backgroundColor,
    this.textColor,
    this.bookId,
    this.chapterTitles,
    this.onChapterTap,
  });

  @override
  State<DraggableAudiobookControls> createState() =>
      _DraggableAudiobookControlsState();
}

class _DraggableAudiobookControlsState extends State<DraggableAudiobookControls>
    with TickerProviderStateMixin {
  late Offset _position;
  late AnimationController _dismissAnimationController;
  late Animation<double> _dismissAnimation;
  // NOTE: TabController removed — tab switching is driven by _selectedPlaylistTab state
  //       which avoids allocating an unused controller object.

  bool _isDragging = false;
  bool _isInDismissZone = false;
  bool _isExpanded = true;
  bool _showSettings = false;
  bool _showPlaylist = false;
  int _selectedPlaylistTab = 0;

  // UI 8: Dismiss zone stays visible briefly after drag ends for smooth fade-out
  bool _showDismissZone = false;

  final _bgGenerator = BackgroundChapterGenerator.instance;

  // Cache of generated chapters — refreshed reactively when job stream emits
  List<dynamic> _cachedChapters = [];
  bool _cacheLoading = false;

  static const double _controlsWidth = 340.0;
  static const double _baseControlsHeight = 240.0;
  static const double _playlistHeight = 220.0;
  static const double _miniHeight = 60.0;
  static const double _dismissZoneHeight = 100.0;

  /// Safe widget width — never wider than screen minus 16px padding
  double get _safeWidth =>
      _controlsWidth.clamp(0.0, widget.screenSize.width - 16.0);

  /// Safe max height — never taller than usable screen area
  double get _maxAllowedHeight =>
      widget.screenSize.height -
      widget.safeArea.top -
      widget.safeArea.bottom -
      24.0; // 24px breathing room

  double get _currentHeight {
    if (!_isExpanded) return _miniHeight;
    double raw;
    if (_showSettings) {
      raw = 280.0;
    } else {
      raw = _baseControlsHeight + (_showPlaylist ? _playlistHeight : 0);
    }
    // Clamp so widget never overflows on small phones
    return raw.clamp(0.0, _maxAllowedHeight);
  }

  static const List<double> _speedOptions = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  static const List<Duration> _sleepTimerOptions = [
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(hours: 1),
    Duration(hours: 2),
  ];

  @override
  void initState() {
    super.initState();

    final safeWidth = _controlsWidth.clamp(0.0, widget.screenSize.width - 16.0);
    _position = Offset(
      ((widget.screenSize.width - safeWidth) / 2).clamp(0.0, widget.screenSize.width - safeWidth),
      (widget.screenSize.height -
              _baseControlsHeight -
              widget.safeArea.bottom -
              80)
          .clamp(
            widget.safeArea.top,
            widget.screenSize.height - _baseControlsHeight - widget.safeArea.bottom,
          ),
    );

    _dismissAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _dismissAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _dismissAnimationController,
        curve: Curves.easeOut,
      ),
    );

    // Load cache once eagerly, then refresh whenever a job finishes
    _refreshCache();
    _bgGenerator.jobStatusStream.listen((_) {
      if (mounted) _refreshCache();
    });
  }

  @override
  void dispose() {
    _dismissAnimationController.dispose();
    // _playlistTabController already removed — nothing extra to dispose
    super.dispose();
  }

  /// Fetch the cached chapter list from TtsController and store in state.
  /// Called once on init and again whenever a generation job emits an event.
  Future<void> _refreshCache() async {
    if (widget.bookId == null) return;
    if (!mounted) return;
    setState(() => _cacheLoading = true);
    try {
      final chapters = await TtsController.instance
          .getGeneratedAudioForBook(widget.bookId!);
      if (mounted) {
        setState(() {
          _cachedChapters = chapters;
          _cacheLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cacheLoading = false);
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _showDismissZone = true; // UI 8: show dismiss zone when drag starts
    });
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;
      _position = Offset(
        // Use safeWidth so widget never goes off-screen on small phones
        _position.dx.clamp(0.0, widget.screenSize.width - _safeWidth),
        _position.dy.clamp(
          widget.safeArea.top,
          widget.screenSize.height - _currentHeight - widget.safeArea.bottom,
        ),
      );

      final dismissThreshold =
          widget.screenSize.height -
          _dismissZoneHeight -
          widget.safeArea.bottom;
      _isInDismissZone = _position.dy > dismissThreshold;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);

    if (_isInDismissZone) {
      HapticFeedback.mediumImpact();
      _dismissAnimationController.forward().then((_) {
        widget.onStop();
        widget.onClose?.call();
      });
    } else {
      _snapToEdge();
    }

    // UI 8: Keep dismiss zone visible briefly then fade it out smoothly
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _showDismissZone = false);
    });
  }

  void _snapToEdge() {
    final centerX = widget.screenSize.width / 2;
    final newX = _position.dx + _controlsWidth / 2 < centerX
        ? 8.0
        : widget.screenSize.width - _controlsWidth - 8;

    setState(() => _position = Offset(newX, _position.dy));
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      _showSettings = false;
      _showPlaylist = false;
    });
    HapticFeedback.selectionClick();
  }

  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
      _showPlaylist = false;
    });
    _adjustPosition();
    HapticFeedback.selectionClick();
  }

  void _togglePlaylist() {
    setState(() {
      _showPlaylist = !_showPlaylist;
      _showSettings = false;
    });
    _adjustPosition();
    HapticFeedback.selectionClick();
  }

  void _adjustPosition() {
    // Calculate maxY BEFORE setState (same frame) to avoid a visible 1-frame jump.
    // _currentHeight has already been updated by the caller's setState.
    final maxY =
        widget.screenSize.height - _currentHeight - widget.safeArea.bottom;
    if (_position.dy > maxY) {
      // Already inside a setState call from togglePlaylist/toggleSettings,
      // so we call setState again only when necessary.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _position.dy > maxY) {
          setState(() => _position = Offset(_position.dx, maxY));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI 6: dynamic width — never wider than screen minus 16px margin
    final safeWidth = _safeWidth;

    return Stack(
      children: [
        // UI 8: Dismiss zone with AnimatedOpacity for smooth fade-out
        AnimatedOpacity(
          opacity: _showDismissZone ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: _isInDismissZone
                  ? _dismissZoneHeight + widget.safeArea.bottom
                  : _dismissZoneHeight / 2 + widget.safeArea.bottom,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _isInDismissZone
                        ? Colors.red.withValues(alpha: 0.5)
                        : Colors.red.withValues(alpha: 0.2),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: _isInDismissZone
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      size: _isInDismissZone ? 32 : 24,
                    ),
                    if (_isInDismissZone)
                      const Text(
                        'Release to stop',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Controls
        AnimatedPositioned(
          duration: _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 200),
          left: _position.dx,
          top: _position.dy,
          child: FadeTransition(
            opacity: _dismissAnimation,
            child: ScaleTransition(
              scale: _dismissAnimation,
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  // UI 6: use safeWidth so widget never clips on small phones
                  width: safeWidth,
                  constraints: BoxConstraints(
                    maxHeight:
                        widget.screenSize.height -
                        widget.safeArea.top -
                        widget.safeArea.bottom -
                        20,
                  ),
                  child: _isExpanded
                      ? (_showSettings
                            ? _buildSettingsPanel()
                            : _buildExpandedControls())
                      : _buildMiniControls(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedControls() {
    final bgColor =
        widget.backgroundColor ?? Colors.black.withValues(alpha: 0.95);
    final fgColor = widget.textColor ?? Colors.white;
    final status = widget.status;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: _isDragging
              ? _getStateColor().withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: _isDragging ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: fgColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          _buildHeader(status, fgColor),

          // Next chapter status
          if (widget.bookId != null) _buildNextChapterStatus(status, fgColor),

          // Chapter info
          _buildChapterInfo(status, fgColor),

          // Progress bar
          _buildProgressBar(status, fgColor),

          const SizedBox(height: 6),

          // Playback controls
          _buildPlaybackControls(fgColor),

          const SizedBox(height: 8),

          // Collapsible Playlist (BELOW player)
          if (_showPlaylist) _buildPlaylistPanel(fgColor),
        ],
      ),
    );
  }

  Widget _buildHeader(AudiobookStatus status, Color fgColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _getStateColor().withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _buildStateIcon(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Audiobook',
                        style: TextStyle(
                          color: fgColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (status.ttsModelName != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          status.ttsModelName!,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  status.userFacingMessage,
                  style: TextStyle(
                    color: _getStateColor(),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildSmallIconButton(
            icon: _showPlaylist
                ? Icons.queue_music
                : Icons.queue_music_outlined,
            onPressed: _togglePlaylist,
            color: _showPlaylist
                ? _getStateColor()
                : fgColor.withValues(alpha: 0.7),
          ),
          _buildSmallIconButton(
            icon: Icons.settings,
            onPressed: _toggleSettings,
            color: fgColor.withValues(alpha: 0.7),
          ),
          _buildSmallIconButton(
            icon: Icons.expand_more,
            onPressed: _toggleExpanded,
            color: fgColor.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterInfo(AudiobookStatus status, Color fgColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status.currentChapterTitle ??
                      'Chapter ${status.currentChapter + 1}',
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 18,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildCompactBadge(
                        'Cur',
                        status.currentChapterStatus?.state,
                      ),
                      if (status.currentChapter < status.totalChapters - 1) ...[
                        const SizedBox(width: 4),
                        _buildCompactBadge(
                          'Next',
                          status.nextChapterStatus?.state,
                        ),
                      ],
                      if (status.readyChapterCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 9,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${status.readyChapterCount}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (status.detectedLanguage != null)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.detectedLanguage!.toUpperCase(),
                style: const TextStyle(
                  color: Colors.purple,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(AudiobookStatus status, Color fgColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: status.playbackProgress,
              backgroundColor: fgColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(_getStateColor()),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ch ${status.currentChapter + 1}/${status.totalChapters}',
                style: TextStyle(
                  color: fgColor.withValues(alpha: 0.6),
                  fontSize: 9,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${status.playbackSpeed}x',
                    style: TextStyle(
                      color: fgColor.withValues(alpha: 0.6),
                      fontSize: 9,
                    ),
                  ),
                  if (status.isSleepTimerActive) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.bedtime, size: 10, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      _formatRemainingTime(status.sleepTimerRemaining),
                      style: const TextStyle(color: Colors.amber, fontSize: 9),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(Color fgColor) {
    final status = widget.status;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.skip_previous_rounded,
            onPressed: status.currentChapter > 0 ? widget.onPrevious : null,
            color: fgColor,
            size: 24,
          ),
          _buildMainButton(fgColor),
          _buildControlButton(
            icon: Icons.skip_next_rounded,
            onPressed: status.currentChapter < status.totalChapters - 1
                ? widget.onNext
                : null,
            color: fgColor,
            size: 24,
          ),
          _buildControlButton(
            icon: Icons.stop_rounded,
            onPressed: status.isActive || status.isPaused
                ? widget.onStop
                : null,
            color: Colors.red,
            size: 22,
          ),
        ],
      ),
    );
  }

  // ==================== PLAYLIST PANEL ====================

  Widget _buildPlaylistPanel(Color fgColor) {
    return Container(
      height: _playlistHeight,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: fgColor.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tab bar
          SizedBox(
            height: 32,
            child: Row(
              children: [
                _buildPlaylistTab('All', 0, fgColor),
                _buildPlaylistTab('Ready', 1, fgColor),
                _buildPlaylistTab('Queue', 2, fgColor),
              ],
            ),
          ),
          Divider(height: 1, color: fgColor.withValues(alpha: 0.1)),
          // Tab content — Flexible fills remaining height of the 220px Container
          Flexible(child: _buildPlaylistContent(fgColor)),
        ],
      ),
    );
  }

  Widget _buildPlaylistTab(String label, int index, Color fgColor) {
    final isSelected = _selectedPlaylistTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlaylistTab = index),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? _getStateColor() : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? _getStateColor()
                  : fgColor.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistContent(Color fgColor) {
    switch (_selectedPlaylistTab) {
      case 0:
        return _buildAllChaptersList(fgColor);
      case 1:
        return _buildReadyChaptersList(fgColor);
      case 2:
        return _buildQueuedChaptersList(fgColor);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAllChaptersList(Color fgColor) {
    if (widget.bookId == null) {
      return _buildEmptyState('No book loaded', Icons.book_outlined, fgColor);
    }

    // UI 7: Show loading shimmer while initial cache fetch is in progress
    if (_cacheLoading && _cachedChapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  fgColor.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading chapters...',
              style: TextStyle(
                color: fgColor.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    // Use cached data + live job list — no nested FutureBuilder
    final jobs = _bgGenerator.allJobs
        .where((j) => j.bookId == widget.bookId)
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: widget.status.totalChapters,
      itemBuilder: (context, index) {
        final isCurrent = index == widget.status.currentChapter;
        final isCached = _cachedChapters.any((c) => c.pageNumber == index);
        final job = jobs.where((j) => j.chapterIndex == index).firstOrNull;

        return _buildPlaylistItem(
          index: index,
          fgColor: fgColor,
          isCurrent: isCurrent,
          isCached: isCached,
          job: job,
        );
      },
    );
  }

  Widget _buildReadyChaptersList(Color fgColor) {
    if (widget.bookId == null) {
      return _buildEmptyState('No book loaded', Icons.book_outlined, fgColor);
    }

    // Show loading indicator while cache is being fetched
    if (_cacheLoading && _cachedChapters.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_cachedChapters.isEmpty) {
      return _buildEmptyState(
        'No chapters ready',
        Icons.hourglass_empty,
        fgColor,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _cachedChapters.length,
      itemBuilder: (context, index) {
        final entry = _cachedChapters[index];
        final chapterIndex = entry.pageNumber ?? 0;
        final isCurrent = chapterIndex == widget.status.currentChapter;

        return _buildPlaylistItem(
          index: chapterIndex,
          fgColor: fgColor,
          isCurrent: isCurrent,
          isCached: true,
          job: null,
        );
      },
    );
  }

  Widget _buildQueuedChaptersList(Color fgColor) {
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
          return _buildEmptyState(
            'No chapters in queue',
            Icons.check_circle_outline,
            fgColor,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            return _buildQueuedJobItem(job, fgColor);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon, Color fgColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: fgColor.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: fgColor.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistItem({
    required int index,
    required Color fgColor,
    required bool isCurrent,
    required bool isCached,
    GenerationJob? job,
  }) {
    final title =
        (widget.chapterTitles != null && index < widget.chapterTitles!.length)
        ? widget.chapterTitles![index]
        : 'Chapter ${index + 1}';

    final isGenerating = job?.status == JobStatus.generating;
    final isQueued = job?.status == JobStatus.queued;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isCached ? () => widget.onChapterTap?.call(index) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isCurrent ? _getStateColor().withValues(alpha: 0.15) : null,
          ),
          child: Row(
            children: [
              // Leading icon
              SizedBox(
                width: 28,
                height: 28,
                child: _buildPlaylistLeadingIcon(
                  isCurrent: isCurrent,
                  isCached: isCached,
                  isGenerating: isGenerating,
                  isQueued: isQueued,
                  progress: job?.progress ?? 0,
                  fgColor: fgColor,
                ),
              ),
              const SizedBox(width: 8),
              // Title and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: fgColor.withValues(alpha: isCurrent ? 1.0 : 0.8),
                        fontSize: 11,
                        fontWeight: isCurrent
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getItemStatusText(isCached, job),
                      style: TextStyle(
                        color: _getItemStatusColor(
                          isCached,
                          job,
                        ).withValues(alpha: 0.8),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              // Trailing actions
              if (isGenerating || isQueued)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.red.shade300,
                    ),
                    onPressed: () => _bgGenerator.cancelJob(job!.id),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistLeadingIcon({
    required bool isCurrent,
    required bool isCached,
    required bool isGenerating,
    required bool isQueued,
    required double progress,
    required Color fgColor,
  }) {
    if (isCurrent && widget.status.state == AudiobookState.playing) {
      return Container(
        decoration: BoxDecoration(
          color: _getStateColor(),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
      );
    }

    if (isGenerating) {
      return Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(Colors.amber),
            ),
          ),
          Text(
            '${(progress * 100).toInt()}',
            style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    if (isCached) {
      return const Icon(Icons.check_circle, size: 22, color: Colors.green);
    }

    if (isQueued) {
      return const Icon(Icons.schedule, size: 22, color: Colors.orange);
    }

    return Icon(
      Icons.music_note_outlined,
      size: 22,
      color: fgColor.withValues(alpha: 0.3),
    );
  }

  Widget _buildQueuedJobItem(GenerationJob job, Color fgColor) {
    final title =
        (widget.chapterTitles != null &&
            job.chapterIndex < widget.chapterTitles!.length)
        ? widget.chapterTitles![job.chapterIndex]
        : 'Chapter ${job.chapterIndex + 1}';

    final isGenerating = job.status == JobStatus.generating;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: isGenerating ? job.progress : null,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      isGenerating ? Colors.amber : Colors.orange,
                    ),
                  ),
                ),
                if (isGenerating)
                  Text(
                    '${(job.progress * 100).toInt()}',
                    style: const TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(color: fgColor, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isGenerating
                      ? 'Generating ${(job.progress * 100).toInt()}%'
                      : 'Queued #${_bgGenerator.queuedJobs.indexOf(job) + 1}',
                  style: TextStyle(
                    color: isGenerating ? Colors.amber : Colors.orange,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          if (job.startedAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                _formatElapsedTime(DateTime.now().difference(job.startedAt!)),
                style: TextStyle(
                  fontSize: 9,
                  color: fgColor.withValues(alpha: 0.5),
                ),
              ),
            ),
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              icon: Icon(Icons.close, size: 14, color: Colors.red.shade300),
              onPressed: () => _bgGenerator.cancelJob(job.id),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  String _getItemStatusText(bool isCached, GenerationJob? job) {
    if (job != null) {
      switch (job.status) {
        case JobStatus.generating:
          return 'Generating ${(job.progress * 100).toInt()}%';
        case JobStatus.queued:
          return 'In queue';
        case JobStatus.completed:
        case JobStatus.skipped:
          return 'Ready';
        case JobStatus.failed:
          return 'Failed';
        case JobStatus.cancelled:
          return 'Cancelled';
      }
    }
    return isCached ? 'Ready to play' : 'Not generated';
  }

  Color _getItemStatusColor(bool isCached, GenerationJob? job) {
    if (job != null) {
      switch (job.status) {
        case JobStatus.generating:
          return Colors.amber;
        case JobStatus.queued:
          return Colors.orange;
        case JobStatus.completed:
        case JobStatus.skipped:
          return Colors.green;
        case JobStatus.failed:
          return Colors.red;
        case JobStatus.cancelled:
          return Colors.grey;
      }
    }
    return isCached ? Colors.green : Colors.grey;
  }

  String _formatElapsedTime(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';
    return '${duration.inMinutes}m ${seconds % 60}s';
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildSmallIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 16, color: color),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildCompactBadge(String label, ChapterGenerationState? state) {
    Color badgeColor;
    String statusChar;
    bool showSpinner = false;

    switch (state) {
      case ChapterGenerationState.generating:
        badgeColor = Colors.amber;
        statusChar = '⟳';
        showSpinner = true;
        break;
      case ChapterGenerationState.ready:
        badgeColor = Colors.green;
        statusChar = '✓';
        break;
      case ChapterGenerationState.playing:
        badgeColor = Colors.blue;
        statusChar = '▶';
        break;
      case ChapterGenerationState.queued:
        badgeColor = Colors.orange;
        statusChar = '◷';
        break;
      case ChapterGenerationState.error:
        badgeColor = Colors.red;
        statusChar = '✕';
        break;
      default:
        badgeColor = Colors.grey;
        statusChar = '○';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner)
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 1,
                valueColor: AlwaysStoppedAnimation(badgeColor),
              ),
            )
          else
            Text(statusChar, style: TextStyle(color: badgeColor, fontSize: 8)),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextChapterStatus(AudiobookStatus status, Color fgColor) {
    if (widget.bookId == null) return const SizedBox.shrink();

    return StreamBuilder<GenerationJob>(
      stream: _bgGenerator.jobStatusStream,
      builder: (context, snapshot) {
        final nextChapterIndex = status.currentChapter + 1;
        final jobs = _bgGenerator.allJobs
            .where(
              (j) =>
                  j.bookId == widget.bookId &&
                  j.chapterIndex == nextChapterIndex,
            )
            .toList();

        if (jobs.isEmpty) return const SizedBox.shrink();
        final nextJob = jobs.first;

        if (nextJob.status != JobStatus.generating &&
            nextJob.status != JobStatus.queued) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: const AlwaysStoppedAnimation(Colors.amber),
                  value: nextJob.status == JobStatus.generating
                      ? nextJob.progress
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  nextJob.status == JobStatus.generating
                      ? 'Next: ${(nextJob.progress * 100).toInt()}%'
                      : 'Next: Queued',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== SETTINGS PANEL ====================

  Widget _buildSettingsPanel() {
    final bgColor =
        widget.backgroundColor ?? Colors.black.withValues(alpha: 0.95);
    final fgColor = widget.textColor ?? Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: fgColor, size: 18),
                    onPressed: _toggleSettings,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Playback Speed',
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: _speedOptions.map((speed) {
                      final isSelected = widget.status.playbackSpeed == speed;
                      return GestureDetector(
                        onTap: () => widget.onSpeedChange?.call(speed),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${speed}x',
                            style: TextStyle(
                              color: isSelected ? Colors.white : fgColor,
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Sleep Timer',
                        style: TextStyle(
                          color: fgColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.status.isSleepTimerActive) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: widget.onCancelSleepTimer,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.red, fontSize: 8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: _sleepTimerOptions.map((duration) {
                      return GestureDetector(
                        onTap: () {
                          widget.onSleepTimer?.call(duration);
                          _toggleSettings();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _formatDuration(duration),
                            style: TextStyle(color: fgColor, fontSize: 10),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MINI CONTROLS ====================

  Widget _buildMiniControls() {
    final bgColor =
        widget.backgroundColor ?? Colors.black.withValues(alpha: 0.95);
    final fgColor = widget.textColor ?? Colors.white;
    final status = widget.status;

    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        height: _miniHeight,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: _isDragging
                ? _getStateColor().withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: _isDragging ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            // Status indicator
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _getStateColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                if (status.isProcessing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(_getStateColor()),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            // Chapter info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ch ${status.currentChapter + 1}/${status.totalChapters}',
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: status.playbackProgress,
                      backgroundColor: fgColor.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(_getStateColor()),
                      minHeight: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Next generating indicator
            if (status.isNextChapterGenerating)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  // Bug 4 fix: remove `const` — AlwaysStoppedAnimation(Colors.amber)
                  // is not a const expression in all Flutter versions
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation(Colors.amber),
                  ),
                ),
              ),
            // Play/pause button
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: Icon(
                  status.state == AudiobookState.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: fgColor,
                  size: 20,
                ),
                onPressed: widget.onPlayPause,
                padding: EdgeInsets.zero,
              ),
            ),
            // Stop button
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.red.shade300,
                  size: 16,
                ),
                onPressed: widget.onStop,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== COMMON WIDGETS ====================

  Widget _buildStateIcon() {
    final status = widget.status;
    if (status.isTtsInitializing) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.blue),
        ),
      );
    }
    if (status.isProcessing) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(_getStateColor()),
        ),
      );
    }
    return Icon(
      status.state == AudiobookState.playing
          ? Icons.play_arrow_rounded
          : status.state == AudiobookState.paused
          ? Icons.pause_rounded
          : status.state == AudiobookState.completed
          ? Icons.check_circle_rounded
          : Icons.auto_stories,
      color: _getStateColor(),
      size: 14,
    );
  }

  Widget _buildMainButton(Color color) {
    final status = widget.status;
    final isPlaying = status.state == AudiobookState.playing;
    final isPaused = status.state == AudiobookState.paused;
    final isProcessing = status.isProcessing;

    return GestureDetector(
      onTap: (isPlaying || isPaused) && !isProcessing
          ? widget.onPlayPause
          : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _getStateColor(),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _getStateColor().withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isProcessing
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    double size = 24,
  }) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        icon: Icon(icon, size: size),
        color: onPressed != null ? color : color.withValues(alpha: 0.3),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Color _getStateColor() {
    final status = widget.status;
    if (status.isTtsInitializing) return Colors.blue;
    switch (status.state) {
      case AudiobookState.playing:
        return Colors.green;
      case AudiobookState.paused:
        return Colors.orange;
      case AudiobookState.generating:
      case AudiobookState.loading:
      case AudiobookState.preparing:
      case AudiobookState.initializing:
        return Colors.amber;
      case AudiobookState.error:
        return Colors.red;
      case AudiobookState.completed:
        return Colors.teal;
      case AudiobookState.idle:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '$hours hr${minutes > 0 ? ' $minutes m' : ''}';
    }
    return '$minutes min';
  }

  String _formatRemainingTime(Duration? duration) {
    if (duration == null) return '';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/epub_audiobook_controller.dart';
import '../../speaker_player/services/background_chapter_generator.dart';

class DraggableAudiobookControls extends StatefulWidget {
  final AudiobookStatus status;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onClose;
  final VoidCallback? onPlaylistTap; // ✅ NEW
  final void Function(double speed)? onSpeedChange;
  final void Function(Duration duration)? onSleepTimer;
  final VoidCallback? onCancelSleepTimer;
  final Color? backgroundColor;
  final Color? textColor;
  final Size screenSize;
  final EdgeInsets safeArea;
  final String? bookId; // ✅ NEW - for background generation status

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
    this.onPlaylistTap,
    this.onSpeedChange,
    this.onSleepTimer,
    this.onCancelSleepTimer,
    this.backgroundColor,
    this.textColor,
    this.bookId,
  });

  @override
  State<DraggableAudiobookControls> createState() =>
      _DraggableAudiobookControlsState();
}

class _DraggableAudiobookControlsState extends State<DraggableAudiobookControls>
    with SingleTickerProviderStateMixin {
  late Offset _position;
  late AnimationController _dismissAnimationController;
  late Animation<double> _dismissAnimation;

  bool _isDragging = false;
  bool _isInDismissZone = false;
  bool _isExpanded = true;
  bool _showSettings = false;

  // ✅ NEW: Background generation state
  final _bgGenerator = BackgroundChapterGenerator.instance;

  static const double _controlsWidth = 340.0;
  static const double _controlsHeight = 280.0; // Increased for playlist button
  static const double _miniHeight = 64.0;
  static const double _dismissZoneHeight = 100.0;

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

    _position = Offset(
      (widget.screenSize.width - _controlsWidth) / 2,
      widget.screenSize.height - _controlsHeight - widget.safeArea.bottom - 80,
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
  }

  @override
  void dispose() {
    _dismissAnimationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() => _isDragging = true);
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;
      final height = _isExpanded ? _controlsHeight : _miniHeight;
      _position = Offset(
        _position.dx.clamp(0, widget.screenSize.width - _controlsWidth),
        _position.dy.clamp(
          widget.safeArea.top,
          widget.screenSize.height - height - widget.safeArea.bottom,
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
  }

  void _snapToEdge() {
    final centerX = widget.screenSize.width / 2;
    final newX = _position.dx + _controlsWidth / 2 < centerX
        ? 16.0
        : widget.screenSize.width - _controlsWidth - 16;

    setState(() => _position = Offset(newX, _position.dy));
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      _showSettings = false;
    });
    HapticFeedback.selectionClick();
  }

  void _toggleSettings() {
    setState(() => _showSettings = !_showSettings);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dismiss zone
        if (_isDragging)
          Positioned(
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
                  width: _controlsWidth,
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
        borderRadius: BorderRadius.circular(20),
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
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: fgColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getStateColor().withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildStateIcon(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Audiobook',
                            style: TextStyle(
                              color: fgColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (status.ttsModelName != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status.ttsModelName!,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        status.userFacingMessage,
                        style: TextStyle(
                          color: _getStateColor(),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // ✅ NEW: Playlist button
                IconButton(
                  icon: Icon(
                    Icons.queue_music,
                    color: fgColor.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  onPressed: widget.onPlaylistTap,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Playlist',
                ),
                IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: fgColor.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  onPressed: _toggleSettings,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(
                    Icons.expand_more,
                    color: fgColor.withValues(alpha: 0.7),
                  ),
                  onPressed: _toggleExpanded,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // ✅ NEW: Next chapter status
          if (widget.bookId != null) _buildNextChapterStatus(status, fgColor),

          // Chapter info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.currentChapterTitle ??
                            'Chapter ${status.currentChapter + 1}',
                        style: TextStyle(
                          color: fgColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildChapterStatusBadge(
                            'Current',
                            status.currentChapterStatus?.state,
                            fgColor,
                          ),
                          if (status.currentChapter < status.totalChapters - 1)
                            _buildChapterStatusBadge(
                              'Next',
                              status.nextChapterStatus?.state,
                              fgColor,
                            ),
                          if (status.readyChapterCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 10,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${status.readyChapterCount} ready',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (status.detectedLanguage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.detectedLanguage!.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.purple,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: status.playbackProgress,
                    backgroundColor: fgColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(_getStateColor()),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ch. ${status.currentChapter + 1}/${status.totalChapters}',
                      style: TextStyle(
                        color: fgColor.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${status.playbackSpeed}x',
                          style: TextStyle(
                            color: fgColor.withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                        if (status.isSleepTimerActive) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.bedtime,
                            size: 12,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatRemainingTime(status.sleepTimerRemaining),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.skip_previous_rounded,
                onPressed: status.currentChapter > 0 ? widget.onPrevious : null,
                color: fgColor,
              ),
              _buildMainButton(fgColor),
              _buildControlButton(
                icon: Icons.skip_next_rounded,
                onPressed: status.currentChapter < status.totalChapters - 1
                    ? widget.onNext
                    : null,
                color: fgColor,
              ),
              _buildControlButton(
                icon: Icons.stop_rounded,
                onPressed: status.isActive || status.isPaused
                    ? widget.onStop
                    : null,
                color: Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ✅ NEW: Next chapter generation status
  Widget _buildNextChapterStatus(AudiobookStatus status, Color fgColor) {
    if (widget.bookId == null) return const SizedBox.shrink();

    return StreamBuilder<GenerationJob>(
      stream: _bgGenerator.jobStatusStream,
      builder: (context, snapshot) {
        // Find next chapter job
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
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation(Colors.amber),
                  value: nextJob.status == JobStatus.generating
                      ? nextJob.progress
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nextJob.status == JobStatus.generating
                      ? 'Next: Generating ${(nextJob.progress * 100).toInt()}%'
                      : 'Next: Queued for generation',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChapterStatusBadge(
    String label,
    ChapterGenerationState? state,
    Color fgColor,
  ) {
    Color badgeColor;
    String statusText;
    bool showSpinner = false;

    switch (state) {
      case ChapterGenerationState.generating:
        badgeColor = Colors.amber;
        statusText = 'Generating';
        showSpinner = true;
        break;
      case ChapterGenerationState.ready:
        badgeColor = Colors.green;
        statusText = 'Ready';
        break;
      case ChapterGenerationState.playing:
        badgeColor = Colors.blue;
        statusText = 'Playing';
        break;
      case ChapterGenerationState.queued:
        badgeColor = Colors.orange;
        statusText = 'Queued';
        break;
      case ChapterGenerationState.error:
        badgeColor = Colors.red;
        statusText = 'Error';
        break;
      default:
        badgeColor = Colors.grey;
        statusText = 'Idle';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(badgeColor),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            '$label: $statusText',
            style: TextStyle(
              color: badgeColor,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ... (keep all other existing methods: _buildSettingsPanel, _buildMiniControls, etc.)

  Widget _buildSettingsPanel() {
    final bgColor =
        widget.backgroundColor ?? Colors.black.withValues(alpha: 0.95);
    final fgColor = widget.textColor ?? Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: fgColor),
                  onPressed: _toggleSettings,
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Playback Speed',
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _speedOptions.map((speed) {
                    final isSelected = widget.status.playbackSpeed == speed;
                    return GestureDetector(
                      onTap: () => widget.onSpeedChange?.call(speed),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${speed}x',
                          style: TextStyle(
                            color: isSelected ? Colors.white : fgColor,
                            fontSize: 12,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Sleep Timer',
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.status.isSleepTimerActive) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onCancelSleepTimer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.red, fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sleepTimerOptions.map((duration) {
                    return GestureDetector(
                      onTap: () {
                        widget.onSleepTimer?.call(duration);
                        _toggleSettings();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _formatDuration(duration),
                          style: TextStyle(color: fgColor, fontSize: 12),
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
    );
  }

  Widget _buildMiniControls() {
    final bgColor =
        widget.backgroundColor ?? Colors.black.withValues(alpha: 0.95);
    final fgColor = widget.textColor ?? Colors.white;
    final status = widget.status;

    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(32),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStateColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                if (status.isProcessing)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(_getStateColor()),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ch. ${status.currentChapter + 1}/${status.totalChapters}',
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: status.playbackProgress,
                      backgroundColor: fgColor.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(_getStateColor()),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (status.isNextChapterGenerating)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation(Colors.amber),
                  ),
                ),
              ),
            IconButton(
              icon: Icon(
                status.state == AudiobookState.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: fgColor,
                size: 26,
              ),
              onPressed: widget.onPlayPause,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: Colors.red.shade300,
                size: 22,
              ),
              onPressed: widget.onStop,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateIcon() {
    final status = widget.status;
    if (status.isTtsInitializing) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.blue),
        ),
      );
    }
    if (status.isProcessing) {
      return SizedBox(
        width: 18,
        height: 18,
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
      size: 18,
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
        width: 56,
        height: 56,
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
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return IconButton(
      icon: Icon(icon, size: 28),
      color: onPressed != null ? color : color.withValues(alpha: 0.3),
      onPressed: onPressed,
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
      return '$hours hr${minutes > 0 ? ' $minutes min' : ''}';
    }
    return '$minutes min';
  }

  String _formatRemainingTime(Duration? duration) {
    if (duration == null) return '';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}

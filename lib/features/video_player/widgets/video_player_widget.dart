import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/player_media.dart';
import '../models/video_player_state.dart';
import '../providers/video_player_provider.dart';
import '../providers/pip_provider.dart';
import '../../../providers/settings_provider.dart';
import 'gesture_detector_widget.dart';
import 'controls_overlay_widget.dart';
import 'locked_overlay_widget.dart';
import 'up_next_button_widget.dart';
import 'brightness_volume_indicator.dart';
import 'seek_indicator_widget.dart';
import 'speed_indicator_widget.dart';
import 'thumbnail_preview_widget.dart';
import 'network_clock_overlay_widget.dart';

class VideoPlayerWidget extends ConsumerStatefulWidget {
  final PlayerPlaylist playlist;
  final bool autoPlay;
  final bool showPiPButton;
  final bool enableGestures;
  final FutureOr<void> Function()? onBack;
  final Function(String? error)? onError;

  const VideoPlayerWidget({
    super.key,
    required this.playlist,
    this.autoPlay = true,
    this.showPiPButton = true,
    this.enableGestures = true,
    this.onBack,
    this.onError,
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isDisposed = false;
  bool _isExiting = false;

  // Pinch-to-zoom state (YouTube-style: persists after release, pans when zoomed)
  final GlobalKey _videoKey = GlobalKey();
  double _zoomScale = 1.0;
  Offset _zoomOffset = Offset.zero;
  double _pinchStartScale = 1.0;

  // YouTube/X-style vertical swipe to switch playlist items
  double _swipeDy = 0;
  late final AnimationController _swipeReturnController;
  late Animation<double> _swipeReturnAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _swipeReturnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _swipeReturnAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
        parent: _swipeReturnController,
        curve: Curves.easeOutCubic,
      ),
    );
    _swipeReturnAnim.addListener(() {
      if (mounted) setState(() => _swipeDy = _swipeReturnAnim.value);
    });
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (_isDisposed || _isExiting) return;

    try {
      if (widget.playlist.isEmpty) {
        throw Exception('Playlist is empty');
      }

      await ref.read(videoPlayerInitProvider.future);

      if (_isDisposed || !mounted || _isExiting) return;

      final notifier = ref.read(videoPlayerProvider.notifier);
      await notifier.openPlaylist(widget.playlist);

      if (_isDisposed || !mounted || _isExiting) return;

      _resetZoom();

      setState(() {
        _isInitialized = true;
        _hasError = false;
        _errorMessage = null;
        _swipeDy = 0;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ VideoPlayerWidget initialization error: $e');
      debugPrint('Stack: $stackTrace');

      if (!_isDisposed && mounted && !_isExiting) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
        widget.onError?.call(e.toString());
      }
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.playlist != widget.playlist && !_isExiting) {
      _initializePlayer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed || _isExiting) return;

    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      final playerState = ref.read(videoPlayerProvider);

      switch (state) {
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
          if (playerState.mode != PlayerMode.pip &&
              playerState.mode != PlayerMode.background) {
            notifier.pause();
          }
          break;
        case AppLifecycleState.resumed:
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('⚠️ Lifecycle state change error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ FIXED: Back handling
  // ═══════════════════════════════════════════════════════

  Future<bool> _onWillPop() async {
    if (_isDisposed || _isExiting) return true;

    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return true;

      final playerState = ref.read(videoPlayerProvider);

      // Handle fullscreen exit first
      if (playerState.mode == PlayerMode.fullscreen) {
        await notifier.exitFullscreen();
        return false;
      }

      // Handle locked controls
      if (playerState.isLocked) {
        notifier.unlockControls();
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('⚠️ WillPop error: $e');
      return true;
    }
  }

  Future<void> _handleBack() async {
    if (_isDisposed || _isExiting) return;
    _isExiting = true;

    debugPrint('🔙 VideoPlayerWidget back pressed');

    // Check fullscreen/locked first
    final shouldPop = await _onWillPop();
    if (!shouldPop) {
      _isExiting = false;
      return;
    }

    // Call parent's onBack
    if (widget.onBack != null) {
      await widget.onBack!();
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _retryInitialization() {
    if (_isDisposed || _isExiting) return;

    setState(() {
      _hasError = false;
      _errorMessage = null;
      _isInitialized = false;
    });
    _initializePlayer();
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing VideoPlayerWidget...');
    _isDisposed = true;
    _swipeReturnController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPER
  // ═══════════════════════════════════════════════════════

  bool _hasAnyError(VideoPlayerState playerState) {
    return _hasError || playerState.hasError;
  }

  bool _canShowPlayer() {
    if (_isDisposed || _isExiting) return false;

    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      return !notifier.isDisposed && _isInitialized;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Early exit if disposed or exiting
    if (_isDisposed || _isExiting) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final playerState = ref.watch(videoPlayerProvider);
    final pipState = ref.watch(pipProvider);

    if (pipState.isActive) {
      return const SizedBox.shrink();
    }

    final hasAnyError = _hasAnyError(playerState);
    final isReady = _canShowPlayer() && !hasAnyError;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isExiting) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Layer 1: Video Player
            if (isReady)
              _buildVideoPlayer(playerState)
            else
              Container(color: Colors.black),

            // Layer 2: Loading overlay
            if ((playerState.isLoading || !_isInitialized) && !hasAnyError)
              _buildLoadingOverlay(playerState),

            // Layer 3: Buffering indicator
            if (playerState.isBuffering && !playerState.isLoading && isReady)
              _buildBufferingIndicator(),

            // Layer 4: Gesture detector
            if (isReady && widget.enableGestures && !pipState.isNativeActive)
              PlayerGestureDetector(
                enabled: !playerState.isLocked,
                onTap: _handleTap,
                onDoubleTap: _handleDoubleTap,
                onLongPressStart: _handleLongPressStart,
                onLongPressEnd: _handleLongPressEnd,
                onVerticalDrag: _handleVerticalDrag,
                onVerticalDragEnd: _handleVerticalDragEnd,
                onVerticalSwipe: _handleVerticalSwipe,
                onVerticalSwipeEnd: _handleVerticalSwipeEnd,
                onHorizontalDragStart: _handleHorizontalDragStart,
                onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                onHorizontalDragEnd: _handleHorizontalDragEnd,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onScaleEnd: _handleScaleEnd,
              ),

            if (playerState.showSeekPreview &&
                playerState.isSeekingHorizontally)
              ThumbnailPreviewWidget(
                thumbnail: playerState.seekPreviewThumbnail,
                targetPosition: playerState.seekPreviewPosition!,
                seekSeconds: playerState.accumulatedSeekSeconds,
                isVisible: true,
              ),
            // Layer 5: Network speed/data + clock (shown when controls hidden, only for URL sources)
            if (isReady &&
                !playerState.isLocked &&
                !pipState.isNativeActive &&
                playerState.currentUrl.startsWith('http'))
              NetworkClockOverlayWidget(visible: !playerState.showControls),

            // Layer 6: Controls overlay
            if (isReady &&
                playerState.showControls &&
                !playerState.isLocked &&
                !pipState.isNativeActive)
              ControlsOverlayWidget(
                playlist: widget.playlist,
                onBack: _handleBack,
                showPiPButton: widget.showPiPButton,
              ),

            // Layer 6: Locked overlay
            if (playerState.isLocked) const LockedOverlayWidget(),

            // YouTube-style "Up Next" button: top-left, appears in the last
            // 10 seconds when controls are hidden or locked and a next item
            // exists. Placed above the locked overlay so it stays tappable.
            if (isReady &&
                !pipState.isNativeActive &&
                _shouldShowUpNext(playerState) &&
                ref.watch(settingsProvider).showUpNextButton)
              UpNextButtonWidget(
                nextMedia:
                    widget.playlist.items[playerState.currentIndex + 1],
                progress: _upNextProgress(playerState),
                // Right side always; when locked, sit left of the lock button.
                rightOffset: playerState.isLocked ? 76 : 16,
              ),

            // Layer 7: Indicators
            if (playerState.showSeekIndicator)
              SeekIndicatorWidget(
                direction: playerState.seekDirection,
                seconds: playerState.seekSeconds,
              ),

            if (playerState.showBrightnessIndicator)
              BrightnessVolumeIndicator(
                type: IndicatorType.brightness,
                value: playerState.brightness,
              ),

            if (playerState.showVolumeIndicator)
              BrightnessVolumeIndicator(
                type: IndicatorType.volume,
                value: playerState.volume,
              ),

            if (playerState.showSpeedIndicator || playerState.is2xSpeed)
              const SpeedIndicatorWidget(),

            // YouTube/X-style swipe preview indicator (middle-zone switching)
            if (_swipeDy.abs() > 20) _buildSwipeIndicator(),

            // Layer 8: Error overlay (TOP)
            if (hasAnyError) _buildErrorOverlay(playerState),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(VideoPlayerState playerState) {
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);

      if (notifier.isDisposed) {
        return Container(color: Colors.black);
      }

      // ✅ Convert VideoFit to BoxFit
      BoxFit getBoxFit() {
        switch (playerState.videoFit) {
          case VideoFit.contain:
            return BoxFit.contain;
          case VideoFit.cover:
            return BoxFit.cover;
          case VideoFit.fill:
            return BoxFit.fill;
          case VideoFit.fitWidth:
            return BoxFit.fitWidth;
          case VideoFit.fitHeight:
            return BoxFit.fitHeight;
        }
      }

      // ✅ Calculate flip transform
      Widget videoWidget = Video(
        controller: notifier.videoController,
        controls: NoVideoControls,
        fit: getBoxFit(),
      );

      // Apply flips if needed
      if (playerState.isFlippedHorizontally ||
          playerState.isFlippedVertically) {
        videoWidget = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(
              playerState.isFlippedHorizontally ? -1.0 : 1.0,
              playerState.isFlippedVertically ? -1.0 : 1.0,
            ),
          child: videoWidget,
        );
      }

      // Apply pinch-to-zoom transform (YouTube style): scale around center,
      // pan offset keeps the pinch focal point under the fingers.
      if (_zoomScale > 1.0001) {
        videoWidget = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(_zoomOffset.dx, _zoomOffset.dy)
            ..scale(_zoomScale),
          child: videoWidget,
        );
      }

      // Frame matches the video's real aspect ratio (like MX Player/YouTube),
      // so zoom magnifies actual pixels instead of letterbox bars. The outer
      // ClipRect clips at the SCREEN edges, letting zoomed content overflow the
      // frame like MX/YouTube instead of being cut off at the frame bounds.
      double aspectRatio = 16 / 9;
      try {
        final vt = playerState.currentVideoTrack;
        if (vt != null && vt.w != null && vt.h != null && vt.w! > 0 && vt.h! > 0) {
          aspectRatio = vt.w! / vt.h!;
        }
      } catch (_) {}

      final frame = ClipRect(
        child: Center(
          child: AspectRatio(
            key: _videoKey,
            aspectRatio: aspectRatio,
            child: videoWidget,
          ),
        ),
      );

      // YouTube/X-style vertical swipe preview: the frame follows the finger.
      if (_swipeDy != 0) {
        return Transform.translate(
          offset: Offset(0, _swipeDy),
          child: frame,
        );
      }
      return frame;
    } catch (e) {
      debugPrint('❌ Build video player error: $e');
      return Container(color: Colors.black);
    }
  }

  Widget _buildLoadingOverlay(VideoPlayerState playerState) {
    final title = playerState.currentTitle.isNotEmpty
        ? playerState.currentTitle
        : widget.playlist.currentMedia?.title ?? 'Loading...';

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Back button
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _handleBack,
              ),
            ),
          ),
          // Loading indicator
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay(VideoPlayerState playerState) {
    final error = _errorMessage ?? playerState.errorMessage ?? 'Unknown error';

    return GestureDetector(
      onTap: () {}, // Capture taps
      child: Container(
        color: Colors.black.withValues(alpha: 0.95),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _handleBack,
                ),
              ),

              // Error content
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load video',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _handleBack,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Go Back'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _retryInitialization,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
    );
  }

  Widget _buildSwipeIndicator() {
    final isNext = _swipeDy < 0;
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNext
                    ? Icons.keyboard_double_arrow_up_rounded
                    : Icons.keyboard_double_arrow_down_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                isNext ? 'Next video' : 'Previous video',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GESTURE HANDLERS (with safety checks)
  // ═══════════════════════════════════════════════════════

  void _handleTap() {
    if (_isDisposed || _isExiting) return;
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      final playerState = ref.read(videoPlayerProvider);
      if (!playerState.isLocked) {
        notifier.toggleControls();
      }
    } catch (e) {
      debugPrint('⚠️ Handle tap error: $e');
    }
  }

  void _handleDoubleTap(GestureZone zone) {
    if (_isDisposed || _isExiting) return;
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      final settings = notifier.settings;
      final seekDuration = settings.doubleTapSeekDuration;

      switch (zone) {
        case GestureZone.topLeft:
        case GestureZone.bottomLeft:
          notifier.playPrevious();
          HapticFeedback.mediumImpact();
          break;
        case GestureZone.topRight:
        case GestureZone.bottomRight:
          notifier.playNext();
          HapticFeedback.mediumImpact();
          break;
        case GestureZone.centerLeft:
          notifier.seekRelative(-seekDuration);
          HapticFeedback.lightImpact();
          break;
        case GestureZone.centerRight:
          notifier.seekRelative(seekDuration);
          HapticFeedback.lightImpact();
          break;
        case GestureZone.center:
        case GestureZone.topCenter:
        case GestureZone.bottomCenter:
          notifier.playOrPause();
          HapticFeedback.mediumImpact();
          break;
      }
    } catch (e) {
      debugPrint('⚠️ Handle double tap error: $e');
    }
  }

  void _handleLongPressStart(GestureZone zone) {
    if (_isDisposed || _isExiting) return;
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      notifier.enable2xSpeed();
      HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('⚠️ Handle long press start error: $e');
    }
  }

  void _handleLongPressEnd() {
    if (_isDisposed || _isExiting) return;
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      notifier.disable2xSpeed();
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('⚠️ Handle long press end error: $e');
    }
  }

  void _handleHorizontalDragStart() {
    if (_isDisposed || _isExiting) return;
    try {
      // When zoomed, drags pan instead of seeking.
      if (_zoomScale > 1.0001) return;
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      notifier.startHorizontalSeek();
      debugPrint('🎬 Started horizontal seek');
    } catch (e) {
      debugPrint('⚠️ Handle horizontal drag start error: $e');
    }
  }

  void _handleHorizontalDragUpdate(double delta) {
    if (_isDisposed || _isExiting) return;
    try {
      if (_zoomScale > 1.0001) {
        _panVideo(Offset(delta, 0));
        return;
      }
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      notifier.updateHorizontalSeek(delta);
    } catch (e) {
      debugPrint('⚠️ Handle horizontal drag update error: $e');
    }
  }

  void _handleHorizontalDragEnd() {
    if (_isDisposed || _isExiting) return;
    try {
      if (_zoomScale > 1.0001) return;
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      notifier.endHorizontalSeek();
      debugPrint('🎬 Ended horizontal seek');
    } catch (e) {
      debugPrint('⚠️ Handle horizontal drag end error: $e');
    }
  }

  /// Slim edge strips only: left = brightness, right = volume. Middle-zone
  /// swipes are handled by _handleVerticalSwipe/_handleVerticalSwipeEnd.
  void _handleVerticalDrag(double delta, bool isLeftSide, Velocity velocity) {
    if (_isDisposed || _isExiting) return;
    try {
      // When zoomed, vertical drags pan instead of adjusting brightness/volume.
      if (_zoomScale > 1.0001) {
        _panVideo(Offset(0, delta));
        return;
      }
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      final adjustedDelta = -delta / 200;

      if (isLeftSide) {
        notifier.adjustBrightness(adjustedDelta);
      } else {
        notifier.adjustVolume(adjustedDelta);
      }
    } catch (e) {
      debugPrint('⚠️ Handle vertical drag error: $e');
    }
  }

  void _handleVerticalDragEnd(double totalDelta, Velocity velocity) {
    // Edge strips only adjust brightness/volume continuously; nothing to do
    // on release. Item switching lives in _handleVerticalSwipeEnd.
  }

  /// YouTube/X-style drag preview: the video follows the finger while swiping
  /// in the middle zone.
  void _handleVerticalSwipe(double delta) {
    if (_isDisposed || _isExiting) return;
    if (!_swipeSwitchEnabled()) return;
    try {
      if (_zoomScale > 1.0001) {
        _panVideo(Offset(0, delta));
        return;
      }
      if (!mounted) return;
      final maxSwipe = MediaQuery.sizeOf(context).height * 0.3;
      final newDy = (_swipeDy + delta).clamp(-maxSwipe, maxSwipe);
      if (newDy != _swipeDy) {
        setState(() => _swipeDy = newDy);
      }
    } catch (e) {
      debugPrint('⚠️ Handle vertical swipe error: $e');
    }
  }

  /// YouTube/X-style snap: past the threshold the item switches, otherwise the
  /// video springs back to center.
  void _handleVerticalSwipeEnd(double totalDelta) {
    if (_isDisposed || _isExiting) return;
    if (!_swipeSwitchEnabled()) return;
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      if (_zoomScale > 1.0001) return;

      final threshold = MediaQuery.sizeOf(context).height * 0.22;

      if (totalDelta <= -threshold) {
        notifier.playNext();
        HapticFeedback.mediumImpact();
        _resetSwipe();
      } else if (totalDelta >= threshold) {
        notifier.playPrevious();
        HapticFeedback.mediumImpact();
        _resetSwipe();
      } else {
        _springBackSwipe();
      }
    } catch (e) {
      debugPrint('⚠️ Handle vertical swipe end error: $e');
    }
  }

  bool _swipeSwitchEnabled() => ref.read(settingsProvider).swipeToSwitchEnabled;

  void _springBackSwipe() {
    if (!mounted) return;
    _swipeReturnAnim = Tween<double>(begin: _swipeDy, end: 0).animate(
      CurvedAnimation(
        parent: _swipeReturnController,
        curve: Curves.easeOutCubic,
      ),
    );
    _swipeReturnController.forward(from: 0);
  }

  void _resetSwipe() {
    if (!mounted) return;
    _swipeReturnController.stop();
    setState(() => _swipeDy = 0);
  }

  /// "Up Next" shows only when a next item exists AND controls are hidden or
  /// locked AND the current video is within the configured lead time before the
  /// end (default 10s).
  bool _shouldShowUpNext(VideoPlayerState playerState) {
    if (!playerState.canPlayNext) return false;
    if (playerState.showControls && !playerState.isLocked) return false;
    final nextIndex = playerState.currentIndex + 1;
    if (nextIndex >= widget.playlist.items.length) return false;
    if (playerState.duration <= Duration.zero) return false;
    final remaining = playerState.duration - playerState.position;
    final lead = Duration(
      seconds: ref.read(settingsProvider).upNextLeadSeconds,
    );
    if (remaining > lead || remaining <= Duration.zero) {
      return false;
    }
    return true;
  }

  double _upNextProgress(VideoPlayerState playerState) {
    final remaining = playerState.duration - playerState.position;
    final leadMs =
        (ref.read(settingsProvider).upNextLeadSeconds * 1000).toDouble();
    if (leadMs <= 0) return 0.0;
    return (remaining.inMilliseconds / leadMs).clamp(0.0, 1.0);
  }

  void _handleScaleStart() {
    if (_isDisposed || _isExiting) return;
    // Remember the scale when this pinch began so repeated pinches compound.
    _pinchStartScale = _zoomScale;
  }

  void _handleScaleUpdate(double scale, Offset focalPoint) {
    if (_isDisposed || _isExiting) return;
    try {
      if (!mounted) return;
      final oldScale = _zoomScale;
      final newScale = (_pinchStartScale * scale).clamp(1.0, 4.0);
      final screenSize = MediaQuery.sizeOf(context);
      final screenCenter =
          Offset(screenSize.width / 2, screenSize.height / 2);
      setState(() {
        _zoomScale = newScale;
        // Keep the point under the pinch anchored as the scale changes.
        _zoomOffset = _zoomOffset +
            Offset(
              (oldScale - newScale) * (focalPoint.dx - screenCenter.dx),
              (oldScale - newScale) * (focalPoint.dy - screenCenter.dy),
            );
        _clampZoomOffset();
      });
    } catch (e) {
      debugPrint('⚠️ Handle scale update error: $e');
    }
  }

  void _handleScaleEnd() {
    if (_isDisposed || _isExiting) return;
    try {
      if (!mounted) return;
      setState(() {
        _clampZoomOffset();
      });
    } catch (e) {
      debugPrint('⚠️ Handle scale end error: $e');
    }
  }

  void _resetZoom() {
    _zoomScale = 1.0;
    _zoomOffset = Offset.zero;
    _pinchStartScale = 1.0;
  }

  Size _videoSize() {
    try {
      final ctx = _videoKey.currentContext;
      if (ctx == null) return Size.zero;
      final box = ctx.findRenderObject();
      if (box is RenderBox) return box.size;
    } catch (_) {}
    return Size.zero;
  }

  void _clampZoomOffset() {
    final size = _videoSize();
    if (size == Size.zero) return;
    final maxX = (_zoomScale - 1.0) * size.width / 2;
    final maxY = (_zoomScale - 1.0) * size.height / 2;
    var x = _zoomOffset.dx;
    var y = _zoomOffset.dy;
    if (x < -maxX) x = -maxX;
    if (x > maxX) x = maxX;
    if (y < -maxY) y = -maxY;
    if (y > maxY) y = maxY;
    _zoomOffset = Offset(x, y);
  }

  void _panVideo(Offset delta) {
    if (!mounted) return;
    setState(() {
      _zoomOffset =
          Offset(_zoomOffset.dx + delta.dx, _zoomOffset.dy + delta.dy);
      _clampZoomOffset();
    });
  }

  /* void _handleHorizontalDrag(double delta) {
    if (_isDisposed || _isExiting) return;
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      final seconds = (delta / 10).round();
      if (seconds.abs() >= 1) {
        notifier.seekRelative(seconds);
      }
    } catch (e) {
      debugPrint('⚠️ Handle horizontal drag error: $e');
    }
  } */
}

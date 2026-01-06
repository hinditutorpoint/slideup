import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/player_media.dart';
import '../models/video_player_state.dart';
import '../providers/video_player_provider.dart';
import '../providers/pip_provider.dart';
import 'gesture_detector_widget.dart';
import 'controls_overlay_widget.dart';
import 'locked_overlay_widget.dart';
import 'brightness_volume_indicator.dart';
import 'seek_indicator_widget.dart';
import 'speed_indicator_widget.dart';
import 'thumbnail_preview_widget.dart';

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
    with WidgetsBindingObserver {
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isDisposed = false;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

      setState(() {
        _isInitialized = true;
        _hasError = false;
        _errorMessage = null;
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
            if (isReady && widget.enableGestures)
              PlayerGestureDetector(
                enabled: !playerState.isLocked,
                onTap: _handleTap,
                onDoubleTap: _handleDoubleTap,
                onLongPressStart: _handleLongPressStart,
                onLongPressEnd: _handleLongPressEnd,
                onVerticalDrag: _handleVerticalDrag,
                onHorizontalDragStart: _handleHorizontalDragStart,
                onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                onHorizontalDragEnd: _handleHorizontalDragEnd,
              ),

            if (playerState.showSeekPreview &&
                playerState.isSeekingHorizontally)
              ThumbnailPreviewWidget(
                thumbnail: playerState.seekPreviewThumbnail,
                targetPosition: playerState.seekPreviewPosition!,
                seekSeconds: playerState.accumulatedSeekSeconds,
                isVisible: true,
              ),
            // Layer 5: Controls overlay
            if (isReady && playerState.showControls && !playerState.isLocked)
              ControlsOverlayWidget(
                playlist: widget.playlist,
                onBack: _handleBack,
                showPiPButton: widget.showPiPButton,
              ),

            // Layer 6: Locked overlay
            if (playerState.isLocked) const LockedOverlayWidget(),

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

      return Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          panEnabled: true,
          scaleEnabled: true,
          child: AspectRatio(aspectRatio: 16 / 9, child: videoWidget),
        ),
      );
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
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (notifier.isDisposed) return;

      notifier.endHorizontalSeek();
      debugPrint('🎬 Ended horizontal seek');
    } catch (e) {
      debugPrint('⚠️ Handle horizontal drag end error: $e');
    }
  }

  void _handleVerticalDrag(double delta, bool isLeftSide) {
    if (_isDisposed || _isExiting) return;
    try {
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

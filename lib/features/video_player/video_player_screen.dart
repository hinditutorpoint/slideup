import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/player_media.dart';
import 'models/video_player_state.dart';
import 'providers/video_player_provider.dart';
import 'providers/pip_provider.dart';
import 'widgets/video_player_widget.dart';
import 'widgets/pip_widget.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final PlayerPlaylist playlist;
  final bool autoPlay;
  final bool startFullscreen;

  const VideoPlayerScreen({
    super.key,
    required this.playlist,
    this.autoPlay = true,
    this.startFullscreen = false,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with WidgetsBindingObserver {
  bool _isInitialized = false;
  String? _initError;

  // ✅ Exit state management
  bool _isExiting = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (widget.playlist.isEmpty) {
        throw Exception('Playlist is empty');
      }

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      if (widget.startFullscreen) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _initError = null;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ VideoPlayerScreen initialization error: $e');
      debugPrint('Stack: $stackTrace');

      if (mounted) {
        setState(() {
          _isInitialized = false;
          _initError = e.toString();
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't handle lifecycle if exiting or error
    if (_isExiting || _initError != null) return;
    _handleLifecycleChange(state);
  }

  void _handleLifecycleChange(AppLifecycleState state) {
    if (!mounted || _isExiting) return;

    try {
      final playerState = ref.read(videoPlayerProvider);

      switch (state) {
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
          if (playerState.mode != PlayerMode.pip &&
              playerState.mode != PlayerMode.background) {
            _handleBackgroundTransition();
          }
          break;
        case AppLifecycleState.resumed:
          _handleForegroundTransition();
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('⚠️ Lifecycle change error: $e');
    }
  }

  Future<void> _handleBackgroundTransition() async {
    if (_isExiting) return;

    try {
      final playerNotifier = ref.read(videoPlayerProvider.notifier);
      final pipNotifier = ref.read(pipProvider.notifier);
      final playerState = ref.read(videoPlayerProvider);

      if (!playerState.isPlaying) return;

      final isPiPAvailable = await pipNotifier.isPiPAvailable();

      if (isPiPAvailable) {
        await pipNotifier.enableNativePiP();
        playerNotifier.enterPiPMode();
      } else {
        playerNotifier.enterBackgroundMode();
      }
    } catch (e) {
      debugPrint('⚠️ Background transition error: $e');
      try {
        ref.read(videoPlayerProvider.notifier).pause();
      } catch (_) {}
    }
  }

  void _handleForegroundTransition() {
    if (_isExiting) return;

    try {
      final playerState = ref.read(videoPlayerProvider);

      if (playerState.mode == PlayerMode.pip ||
          playerState.mode == PlayerMode.background) {
        ref.read(videoPlayerProvider.notifier).exitPiPMode();
        ref.read(pipProvider.notifier).disablePiP();
      }
    } catch (e) {
      debugPrint('⚠️ Foreground transition error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ FIXED: Safe exit with proper state management
  // ═══════════════════════════════════════════════════════

  Future<void> _safeExit() async {
    if (_isExiting || _hasNavigated) {
      debugPrint('⚠️ Already exiting or navigated');
      return;
    }

    _isExiting = true;
    debugPrint('🔙 Starting safe exit...');

    // ✅ Step 1: Stop player FIRST (but don't wait too long)
    await _stopPlayerWithTimeout();

    // ✅ Step 2: Reset UI
    await _resetSystemUI();

    // ✅ Step 3: Navigate
    if (mounted && !_hasNavigated) {
      _hasNavigated = true;
      debugPrint('🔙 Navigating back...');
      Navigator.of(context).pop();
    }
  }

  /// Stop player with timeout to prevent blocking
  Future<void> _stopPlayerWithTimeout() async {
    try {
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (!notifier.isDisposed) {
        // ✅ Use timeout to prevent hanging
        await notifier.stop().timeout(
          const Duration(milliseconds: 500),
          onTimeout: () {
            debugPrint('⚠️ Stop timeout - continuing anyway');
          },
        );
        debugPrint('✅ Player stopped');
      }
    } catch (e) {
      debugPrint('⚠️ Stop error: $e');
    }
  }

  /// Simple back for error/loading screens
  void _simpleBack() {
    if (_hasNavigated) return;
    _hasNavigated = true;

    debugPrint('🔙 Simple back');
    _resetSystemUI();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleError(String? error) {
    debugPrint('❌ Video player error: $error');
  }

  Future<void> _resetSystemUI() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (e) {
      debugPrint('⚠️ Reset system UI error: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing VideoPlayerScreen...');
    WidgetsBinding.instance.removeObserver(this);

    // ✅ Stop player in dispose (service will handle cleanup)
    _stopPlayerSafely();

    super.dispose();
  }

  void _stopPlayerSafely() async {
    if (_isExiting) return;
    try {
      debugPrint('🧹 Stopping player safely...');
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (!notifier.isDisposed) {
        debugPrint('🧹 Releasing player...');
        await notifier.safeDisposeService();
        debugPrint('🧹 Player released successfully');
      } else {
        debugPrint('🧹 Player already disposed');
      }
    } catch (e) {
      debugPrint('⚠️ Stop in dispose error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // ✅ If already navigating, show black screen
    if (_isExiting || _hasNavigated) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    // Show error screen first
    if (_initError != null) {
      return _buildErrorScreen(_initError!);
    }

    // Only watch providers if no error and not exiting
    final pipState = ref.watch(pipProvider);

    if (pipState.isActive) {
      return _buildPiPOverlay();
    }

    if (!_isInitialized) {
      return _buildLoadingScreen();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isExiting || _hasNavigated) return;
        _safeExit();
      },
      child: VideoPlayerWidget(
        playlist: widget.playlist,
        autoPlay: widget.autoPlay,
        onBack: _safeExit,
        onError: _handleError,
      ),
    );
  }

  Widget _buildPiPOverlay() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PiPWidget(
        onClose: () {
          ref.read(pipProvider.notifier).disablePiP();
          _safeExit();
        },
        onExpand: () {
          ref.read(pipProvider.notifier).disablePiP();
          ref.read(videoPlayerProvider.notifier).exitPiPMode();
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _simpleBack,
        ),
      ),
      extendBodyBehindAppBar: true,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Preparing player...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _simpleBack,
          ),
        ),
        extendBodyBehindAppBar: true,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to initialize player',
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
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _simpleBack,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        child: const Text('Go Back'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _initError = null;
                            _isInitialized = false;
                            _isExiting = false;
                            _hasNavigated = false;
                          });
                          _initialize();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/player_media.dart';
import 'models/video_player_state.dart';
import 'providers/video_player_provider.dart';
import 'providers/pip_provider.dart';
import 'widgets/video_player_widget.dart';
import 'widgets/native_pip_widget.dart';

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

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  bool _isInitialized = false;
  String? _initError;
  bool _isExiting = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════
  // ✅ EXIT & CLEANUP
  // ═══════════════════════════════════════════════════════

  Future<void> _safeExit() async {
    if (_isExiting || _hasNavigated) {
      debugPrint('⚠️ Already exiting or navigated');
      return;
    }

    _isExiting = true;
    debugPrint('🔙 Starting safe exit...');

    await _stopPlayerWithTimeout();
    await _resetSystemUI();

    if (mounted && !_hasNavigated) {
      _hasNavigated = true;
      debugPrint('🔙 Navigating back...');
      Navigator.of(context).pop();
    }
  }

  Future<void> _stopPlayerWithTimeout() async {
    try {
      // Disable auto-pip before stopping
      await ref.read(pipProvider.notifier).updateAutoPiP(isPlaying: false);

      final notifier = ref.read(videoPlayerProvider.notifier);
      if (!notifier.isDisposed) {
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

  void _simpleBack() {
    if (_hasNavigated) return;
    _hasNavigated = true;

    debugPrint('🔙 Simple back');
    _resetSystemUI();

    if (mounted) {
      Navigator.of(context).pop();
    }
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
    _stopPlayerSafely();
    super.dispose();
  }

  void _stopPlayerSafely() async {
    if (_isExiting) return;
    try {
      debugPrint('🧹 Stopping player safely...');
      final notifier = ref.read(videoPlayerProvider.notifier);
      if (!notifier.isDisposed) {
        await notifier.releasePlayer();
        debugPrint('✅ Player released successfully');
      }
    } catch (e) {
      debugPrint('⚠️ Stop in dispose error: $e');
    }
  }

  void _handleError(String? error) {
    debugPrint('❌ Video player error: $error');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isExiting || _hasNavigated) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    if (_initError != null) {
      return _buildErrorScreen(_initError!);
    }

    if (!_isInitialized) {
      return _buildLoadingScreen();
    }

    final pipState = ref.watch(pipProvider);

    // ✅ Sync Auto-PiP with player state
    // NOTE: We always call updateAutoPiP regardless of custom PiP mode
    // so the native system-level PiP (Home button) always works correctly.
    ref.listen<VideoPlayerState>(videoPlayerProvider, (prev, next) {
      if (prev?.isPlaying != next.isPlaying) {
        ref
            .read(pipProvider.notifier)
            .updateAutoPiP(isPlaying: next.isPlaying);
      }
    });

    // ✅ Pop screen when custom PiP is enabled
    ref.listen<PiPStateData>(pipProvider, (prev, next) {
      if (next.isCustomActive && !(prev?.isCustomActive ?? false)) {
        if (mounted && !_isExiting && !_hasNavigated) {
          debugPrint('📺 Custom PiP enabled - popping screen');
          Navigator.of(context).pop();
        }
      }
    });

    // Native PiP (background)
    if (pipState.isNativeActive) {
      return const NativePiPWidget();
    }

    // Normal player
    return _buildMainPlayer();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ UI BUILDERS
  // ═══════════════════════════════════════════════════════

  Widget _buildMainPlayer() {
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

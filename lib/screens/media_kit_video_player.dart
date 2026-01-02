import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'dart:async';

class MediaKitVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? title;
  final List<String>? playlist;
  final int startIndex;

  const MediaKitVideoPlayer({
    super.key,
    required this.videoUrl,
    this.title,
    this.playlist,
    this.startIndex = 0,
  });

  @override
  State<MediaKitVideoPlayer> createState() => _MediaKitVideoPlayerState();
}

class _MediaKitVideoPlayerState extends State<MediaKitVideoPlayer>
    with WidgetsBindingObserver {
  // ✅ Player & Controller
  late final Player _player;
  late final VideoController _controller;

  // ✅ State
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _showControls = true;
  bool _isFullScreen = false;
  bool _hasError = false;
  String? _errorMessage;

  // ✅ Tracks
  List<AudioTrack> _audioTracks = [];
  List<SubtitleTrack> _subtitleTracks = [];
  List<VideoTrack> _videoTracks = [];
  AudioTrack? _currentAudioTrack;
  SubtitleTrack? _currentSubtitleTrack;
  VideoTrack? _currentVideoTrack;

  // ✅ Playback state
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  double _speed = 1.0;
  bool _isPlaying = false;
  bool _isBuffering = false;

  // ✅ Gestures
  double? _currentBrightness;
  double? _currentVolume;
  Timer? _hideControlsTimer;
  Timer? _hideBrightnessTimer;
  Timer? _hideVolumeTimer;

  // ✅ Playlist
  int _currentIndex = 0;
  List<Media> _mediaPlaylist = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.startIndex;
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    debugPrint('🎬 Initializing media_kit player...');

    try {
      await WakelockPlus.enable();
      VolumeController.instance.showSystemUI = false;

      // ✅ Create player with configuration (1.2.0 feature)
      _player = Player(
        configuration: PlayerConfiguration(
          // ✅ New in 1.2.0 - async configuration
          title: widget.title ?? 'Video Player',
          ready: () {
            debugPrint('✅ Player ready callback');
          },
          // Buffer configuration
          bufferSize: 32 * 1024 * 1024, // 32MB buffer
        ),
      );

      // ✅ Create video controller
      _controller = VideoController(
        _player,
        configuration: VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      // ✅ Setup listeners
      _setupListeners();

      // ✅ Build playlist
      _buildPlaylist();

      // ✅ Wait for initialization (1.2.0 feature)
      //await _player.platform.initialize();
      debugPrint('✅ Player initialization complete');

      // ✅ Open media
      await _openMedia();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }

      _showControlsAndScheduleHide();
    } catch (e, stackTrace) {
      debugPrint('❌ Player initialization failed: $e');
      debugPrint('Stack: $stackTrace');

      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _buildPlaylist() {
    if (widget.playlist != null && widget.playlist!.isNotEmpty) {
      _mediaPlaylist = widget.playlist!.map((url) => Media(url)).toList();
    } else {
      _mediaPlaylist = [Media(widget.videoUrl)];
    }
  }

  Future<void> _openMedia() async {
    if (_mediaPlaylist.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      if (_mediaPlaylist.length == 1) {
        // Single video
        await _player.open(_mediaPlaylist.first, play: true);
      } else {
        // Playlist
        await _player.open(
          Playlist(_mediaPlaylist, index: _currentIndex),
          play: true,
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to open media: $e');
      rethrow;
    }
  }

  void _setupListeners() {
    // ✅ Playing state
    _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() => _isPlaying = playing);
        if (playing) {
          _showControlsAndScheduleHide();
        }
      }
    });

    // ✅ Position
    _player.stream.position.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    // ✅ Duration
    _player.stream.duration.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    // ✅ Buffering
    _player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() => _isBuffering = buffering);
      }
    });

    // ✅ Volume
    _player.stream.volume.listen((volume) {
      if (mounted) {
        setState(() => _volume = volume / 100);
      }
    });

    // ✅ Rate/Speed
    _player.stream.rate.listen((rate) {
      if (mounted) {
        setState(() => _speed = rate);
      }
    });

    // ✅ Tracks (audio, subtitle, video)
    _player.stream.tracks.listen((tracks) {
      if (mounted) {
        setState(() {
          _audioTracks = tracks.audio;
          _subtitleTracks = tracks.subtitle;
          _videoTracks = tracks.video;
        });
        debugPrint('📊 Tracks loaded:');
        debugPrint('   Audio: ${_audioTracks.length}');
        debugPrint('   Subtitle: ${_subtitleTracks.length}');
        debugPrint('   Video: ${_videoTracks.length}');
      }
    });

    // ✅ Current track
    _player.stream.track.listen((track) {
      if (mounted) {
        setState(() {
          _currentAudioTrack = track.audio;
          _currentSubtitleTrack = track.subtitle;
          _currentVideoTrack = track.video;
        });
      }
    });

    // ✅ Playlist changes (improved in 1.2.0)
    _player.stream.playlist.listen((playlist) {
      if (mounted) {
        setState(() {
          _currentIndex = playlist.index;
        });
        debugPrint(
          '📋 Playlist index: $_currentIndex/${playlist.medias.length}',
        );
      }
    });

    // ✅ Completed
    _player.stream.completed.listen((completed) {
      if (completed) {
        debugPrint('✅ Playback completed');
        // Auto-play next if playlist
        if (_currentIndex < _mediaPlaylist.length - 1) {
          _playNext();
        }
      }
    });

    // ✅ Error handling
    _player.stream.error.listen((error) {
      debugPrint('❌ Player error: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = error;
        });
        _showError(error);
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYBACK CONTROLS
  // ═══════════════════════════════════════════════════════

  Future<void> _togglePlayPause() async {
    await _player.playOrPause();
  }

  Future<void> _seek(Duration position) async {
    await _player.seek(position);
  }

  void _seekRelative(int seconds) {
    final newPosition = _position + Duration(seconds: seconds);
    final clampedPosition = Duration(
      milliseconds: newPosition.inMilliseconds.clamp(
        0,
        _duration.inMilliseconds,
      ),
    );
    _seek(clampedPosition);
  }

  Future<void> _setVolume(double volume) async {
    await _player.setVolume(volume * 100);
  }

  Future<void> _setSpeed(double speed) async {
    await _player.setRate(speed);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TRACK SELECTION
  // ═══════════════════════════════════════════════════════

  Future<void> _setAudioTrack(AudioTrack track) async {
    await _player.setAudioTrack(track);
    debugPrint(
      '🔊 Audio track set: ${track.title ?? track.language ?? track.id}',
    );
  }

  Future<void> _setSubtitleTrack(SubtitleTrack track) async {
    await _player.setSubtitleTrack(track);
    debugPrint(
      '📝 Subtitle track set: ${track.title ?? track.language ?? track.id}',
    );
  }

  Future<void> _disableSubtitles() async {
    await _player.setSubtitleTrack(SubtitleTrack.no());
    debugPrint('📝 Subtitles disabled');
  }

  Future<void> _loadExternalSubtitle(String path) async {
    await _player.setSubtitleTrack(SubtitleTrack.uri(path));
    debugPrint('📝 External subtitle loaded: $path');
  }

  Future<void> _setVideoTrack(VideoTrack track) async {
    await _player.setVideoTrack(track);
    debugPrint('🎥 Video track set: ${track.title ?? track.id}');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PLAYLIST NAVIGATION
  // ═══════════════════════════════════════════════════════

  Future<void> _playNext() async {
    if (_currentIndex < _mediaPlaylist.length - 1) {
      await _player.next();
    } else {
      _showMessage('This is the last video');
    }
  }

  Future<void> _playPrevious() async {
    if (_currentIndex > 0) {
      await _player.previous();
    } else {
      _showMessage('This is the first video');
    }
  }

  Future<void> _jumpToIndex(int index) async {
    if (index >= 0 && index < _mediaPlaylist.length) {
      await _player.jump(index);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SCREENSHOT (1.2.0 - with libass subtitle support)
  // ═══════════════════════════════════════════════════════

  Future<void> _takeScreenshot() async {
    try {
      // ✅ 1.2.0 feature: includes libass subtitles in screenshot
      final screenshot = await _player.screenshot(format: 'image/png');

      if (screenshot != null) {
        debugPrint('📸 Screenshot captured: ${screenshot.length} bytes');
        _showSuccess('Screenshot captured!');

        // Save to file or gallery
        // await _saveScreenshot(screenshot);
      } else {
        _showError('Failed to capture screenshot');
      }
    } catch (e) {
      debugPrint('❌ Screenshot error: $e');
      _showError('Screenshot failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ FULLSCREEN
  // ═══════════════════════════════════════════════════════

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ GESTURES - BRIGHTNESS & VOLUME
  // ═══════════════════════════════════════════════════════

  Future<void> _adjustBrightness(double delta) async {
    try {
      final current = await ScreenBrightness().current;
      final newValue = (current + delta).clamp(0.0, 1.0);
      await ScreenBrightness().setApplicationScreenBrightness(newValue);

      _hideBrightnessTimer?.cancel();
      setState(() => _currentBrightness = newValue);
      _hideBrightnessTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _currentBrightness = null);
      });
    } catch (e) {
      debugPrint('⚠️ Brightness error: $e');
    }
  }

  Future<void> _adjustVolume(double delta) async {
    try {
      final newValue = (_volume + delta).clamp(0.0, 1.0);
      await _setVolume(newValue);

      _hideVolumeTimer?.cancel();
      setState(() => _currentVolume = newValue);
      _hideVolumeTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _currentVolume = null);
      });
    } catch (e) {
      debugPrint('⚠️ Volume error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ UI HELPERS
  // ═══════════════════════════════════════════════════════

  void _showControlsAndScheduleHide() {
    _hideControlsTimer?.cancel();
    setState(() => _showControls = true);

    if (_isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _showControlsAndScheduleHide();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _player.pause();
    }
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing MediaKitVideoPlayer');

    WidgetsBinding.instance.removeObserver(this);

    _hideControlsTimer?.cancel();
    _hideBrightnessTimer?.cancel();
    _hideVolumeTimer?.cancel();

    _player.dispose();

    WakelockPlus.disable();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
          _toggleFullScreen();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ✅ Video Player
            _buildVideoPlayer(),

            // ✅ Loading/Error overlay
            if (_isLoading || _hasError) _buildLoadingOrError(),

            // ✅ Buffering indicator
            if (_isBuffering && !_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // ✅ Controls overlay
            if (_showControls && _isInitialized) _buildControlsOverlay(),

            // ✅ Brightness indicator
            if (_currentBrightness != null)
              _buildIndicator(
                Icons.brightness_6,
                _currentBrightness!,
                Colors.yellow,
                Alignment.centerLeft,
              ),

            // ✅ Volume indicator
            if (_currentVolume != null)
              _buildIndicator(
                Icons.volume_up,
                _currentVolume!,
                Colors.blue,
                Alignment.centerRight,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized) {
      return Container(color: Colors.black);
    }

    return GestureDetector(
      onTap: _toggleControls,
      onDoubleTapDown: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        final tapX = details.globalPosition.dx;

        if (tapX < screenWidth / 3) {
          _seekRelative(-10);
        } else if (tapX > screenWidth * 2 / 3) {
          _seekRelative(10);
        } else {
          _togglePlayPause();
        }
      },
      onVerticalDragUpdate: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isLeft = details.globalPosition.dx < screenWidth / 2;
        final delta = -details.primaryDelta! / 300;

        if (isLeft) {
          _adjustBrightness(delta);
        } else {
          _adjustVolume(delta);
        }
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 500) {
          _seekRelative(-10);
        } else if (velocity < -500) {
          _seekRelative(10);
        }
      },
      child: Center(
        child: Video(controller: _controller, controls: NoVideoControls),
      ),
    );
  }

  Widget _buildLoadingOrError() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: _hasError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load video',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _errorMessage = null;
                      });
                      _initializePlayer();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading video...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
      child: Column(
        children: [
          // ✅ Top bar
          _buildTopBar(),

          const Spacer(),

          // ✅ Center controls
          _buildCenterControls(),

          const Spacer(),

          // ✅ Bottom bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (_isFullScreen) {
                  _toggleFullScreen();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            Expanded(
              child: Text(
                widget.title ?? 'Video Player',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Settings button
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: Colors.grey[900],
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'speed',
                  child: Row(
                    children: [
                      Icon(Icons.speed, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Playback Speed',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'audio',
                  child: Row(
                    children: [
                      Icon(Icons.audiotrack, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Audio Track',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'subtitle',
                  child: Row(
                    children: [
                      Icon(Icons.subtitles, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Subtitles', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'quality',
                  child: Row(
                    children: [
                      Icon(Icons.high_quality, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Quality', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'screenshot',
                  child: Row(
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Screenshot', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'speed':
                    _showSpeedSelector();
                    break;
                  case 'audio':
                    _showAudioTrackSelector();
                    break;
                  case 'subtitle':
                    _showSubtitleSelector();
                    break;
                  case 'quality':
                    _showQualitySelector();
                    break;
                  case 'screenshot':
                    _takeScreenshot();
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous
        if (_mediaPlaylist.length > 1)
          IconButton(
            icon: Icon(
              Icons.skip_previous,
              color: _currentIndex > 0 ? Colors.white : Colors.white38,
              size: 36,
            ),
            onPressed: _currentIndex > 0 ? _playPrevious : null,
          ),

        const SizedBox(width: 24),

        // Rewind 10s
        IconButton(
          icon: const Icon(Icons.replay_10, color: Colors.white, size: 36),
          onPressed: () => _seekRelative(-10),
        ),

        const SizedBox(width: 24),

        // Play/Pause
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          child: IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 48,
            ),
            onPressed: _togglePlayPause,
          ),
        ),

        const SizedBox(width: 24),

        // Forward 10s
        IconButton(
          icon: const Icon(Icons.forward_10, color: Colors.white, size: 36),
          onPressed: () => _seekRelative(10),
        ),

        const SizedBox(width: 24),

        // Next
        if (_mediaPlaylist.length > 1)
          IconButton(
            icon: Icon(
              Icons.skip_next,
              color: _currentIndex < _mediaPlaylist.length - 1
                  ? Colors.white
                  : Colors.white38,
              size: 36,
            ),
            onPressed: _currentIndex < _mediaPlaylist.length - 1
                ? _playNext
                : null,
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: _position.inMilliseconds.toDouble(),
                    max: _duration.inMilliseconds.toDouble().clamp(
                      1,
                      double.infinity,
                    ),
                    onChanged: (value) {
                      _seek(Duration(milliseconds: value.toInt()));
                    },
                    activeColor: Colors.red,
                    inactiveColor: Colors.white38,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),

            // Bottom buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Speed indicator
                TextButton(
                  onPressed: _showSpeedSelector,
                  child: Text(
                    '${_speed}x',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),

                Row(
                  children: [
                    // Playlist
                    if (_mediaPlaylist.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.playlist_play,
                          color: Colors.white,
                        ),
                        onPressed: _showPlaylistSelector,
                      ),

                    // Fullscreen
                    IconButton(
                      icon: Icon(
                        _isFullScreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFullScreen,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(
    IconData icon,
    double value,
    Color color,
    Alignment alignment,
  ) {
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SELECTORS
  // ═══════════════════════════════════════════════════════

  void _showSpeedSelector() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Playback Speed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...speeds.map(
            (speed) => ListTile(
              leading: Icon(
                (_speed - speed).abs() < 0.01
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Colors.white,
              ),
              title: Text(
                '${speed}x',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                _setSpeed(speed);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAudioTrackSelector() {
    if (_audioTracks.isEmpty) {
      _showMessage('No audio tracks available');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Audio Track',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._audioTracks.map(
            (track) => ListTile(
              leading: Icon(
                _currentAudioTrack?.id == track.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Colors.white,
              ),
              title: Text(
                track.title ?? track.language ?? 'Track ${track.id}',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: track.language != null
                  ? Text(
                      track.language!,
                      style: TextStyle(color: Colors.grey[400]),
                    )
                  : null,
              onTap: () {
                _setAudioTrack(track);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSubtitleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Subtitles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Off option
          ListTile(
            leading: Icon(
              _currentSubtitleTrack == null
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: Colors.white,
            ),
            title: const Text('Off', style: TextStyle(color: Colors.white)),
            onTap: () {
              _disableSubtitles();
              Navigator.pop(context);
            },
          ),
          // Available tracks
          ..._subtitleTracks.map(
            (track) => ListTile(
              leading: Icon(
                _currentSubtitleTrack?.id == track.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Colors.white,
              ),
              title: Text(
                track.title ?? track.language ?? 'Track ${track.id}',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: track.language != null
                  ? Text(
                      track.language!,
                      style: TextStyle(color: Colors.grey[400]),
                    )
                  : null,
              onTap: () {
                _setSubtitleTrack(track);
                Navigator.pop(context);
              },
            ),
          ),
          // Load external
          ListTile(
            leading: const Icon(Icons.add, color: Colors.blue),
            title: const Text(
              'Load External Subtitle',
              style: TextStyle(color: Colors.blue),
            ),
            onTap: () {
              Navigator.pop(context);
              _pickExternalSubtitle();
            },
          ),
        ],
      ),
    );
  }

  void _showQualitySelector() {
    if (_videoTracks.isEmpty) {
      _showMessage('No quality options available');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Video Quality',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._videoTracks.map(
            (track) => ListTile(
              leading: Icon(
                _currentVideoTrack?.id == track.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Colors.white,
              ),
              title: Text(
                track.title ?? '${track.w}x${track.h}' ?? 'Track ${track.id}',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                _setVideoTrack(track);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPlaylistSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Playlist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...List.generate(_mediaPlaylist.length, (index) {
            final media = _mediaPlaylist[index];
            final isPlaying = index == _currentIndex;

            return ListTile(
              leading: Icon(
                isPlaying ? Icons.play_circle_fill : Icons.play_circle_outline,
                color: isPlaying ? Colors.red : Colors.white,
              ),
              title: Text(
                media.uri.split('/').last,
                style: TextStyle(
                  color: isPlaying ? Colors.red : Colors.white,
                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'Video ${index + 1}',
                style: TextStyle(color: Colors.grey[400]),
              ),
              onTap: () {
                Navigator.pop(context);
                _jumpToIndex(index);
              },
            );
          }),
        ],
      ),
    );
  }

  Future<void> _pickExternalSubtitle() async {
    // Implement file picker for subtitles
    _showMessage('File picker not implemented');
  }
}

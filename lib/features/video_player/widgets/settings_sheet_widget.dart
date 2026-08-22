import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../models/video_player_state.dart';
import '../providers/video_player_provider.dart';
import '../../../widgets/editor_chooser_dialog.dart';

class SettingsSheetWidget extends ConsumerWidget {
  const SettingsSheetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SafeBuilder(
      builder: (context) {
        final playerState = ref.watch(videoPlayerProvider);

        // Add null check for player state
        // ignore: unnecessary_null_comparison
        if (playerState == null) {
          return _buildErrorWidget(context, 'Player state is null');
        }

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHandleBar(),
                    _buildTitle(),
                    const Divider(color: Colors.white12, height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _SettingsItem(
                              icon: Icons.speed,
                              title: 'Playback Speed',
                              subtitle: _formatSpeed(playerState.speed),
                              onTap: () =>
                                  _showSpeedSelector(context, ref),
                            ),
                            _SettingsItem(
                              icon: Icons.audiotrack,
                              title: 'Audio Track',
                              subtitle: _getAudioSubtitle(playerState),
                              onTap: () =>
                                  _showAudioTrackSelector(context, ref),
                            ),
                            _SettingsItem(
                              icon: Icons.subtitles,
                              title: 'Subtitles',
                              subtitle: _getSubtitleSubtitle(playerState),
                              onTap: () =>
                                  _showSubtitleSelector(context, ref),
                            ),
                            _SettingsItem(
                              icon: Icons.high_quality,
                              title: 'Quality',
                              subtitle: _getQualitySubtitle(playerState),
                              onTap: () =>
                                  _showQualitySelector(context, ref),
                            ),
                            _SettingsItem(
                              icon: Icons.camera_alt,
                              title: 'Take Screenshot',
                              onTap: () => _takeScreenshot(context, ref),
                            ),
                            _SettingsItem(
                              icon: Icons.loop,
                              title: 'Loop',
                              subtitle:
                                  ref.read(videoPlayerProvider.notifier).settings.loopPlaylist ? 'On' : 'Off',
                              onTap: () => _toggleLoop(context, ref),
                            ),
                            const SizedBox(height: 12),
                            _SettingsItem(
                              icon: Icons.edit,
                              title: 'Edit Video',
                              subtitle: 'Edit video',
                              onTap: () => _editVideo(context, ref),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error) => _buildErrorWidget(context, error),
    );
  }

  void _editVideo(BuildContext context, WidgetRef ref) {
    final playerState = ref.read(videoPlayerProvider);
    final notifier = ref.read(videoPlayerProvider.notifier);
    final videoPath = playerState.currentUrl;
    notifier.pause();
    showEditorChooser(context, videoPath);
  }

  // ═══════════════════════════════════════════════════════
  // UI BUILDERS
  // ═══════════════════════════════════════════════════════

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white38,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTitle() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        'Settings',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, Object error) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900] ?? Colors.grey,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandleBar(),
            const SizedBox(height: 24),
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Settings unavailable',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                color: Colors.grey[400] ?? Colors.grey,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _safePopContext(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SUBTITLE HELPERS
  // ═══════════════════════════════════════════════════════

  String _formatSpeed(double speed) {
    try {
      if ((speed - 1.0).abs() < 0.01) return 'Normal';
      return '${speed}x';
    } catch (e) {
      return 'Normal';
    }
  }

  String _getAudioSubtitle(VideoPlayerState state) {
    try {
      final track = state.currentAudioTrack;
      if (track == null || track.id == 'auto' || track.id == 'no') {
        return 'Default';
      }
      return track.title ??
          _getLanguageName(track.language) ??
          'Track ${track.id}';
    } catch (e) {
      return 'Default';
    }
  }

  String _getSubtitleSubtitle(VideoPlayerState state) {
    try {
      final track = state.currentSubtitleTrack;
      if (track == null || track.id == 'no') return 'Off';
      return track.title ??
          _getLanguageName(track.language) ??
          'Track ${track.id}';
    } catch (e) {
      return 'Off';
    }
  }

  String _getQualitySubtitle(VideoPlayerState state) {
    try {
      final track = state.currentVideoTrack;
      if (track == null || track.id == 'auto' || track.id == 'no') {
        return 'Auto';
      }
      if (track.w != null && track.h != null) {
        return '${track.w}×${track.h}';
      }
      return 'Track ${track.id}';
    } catch (e) {
      return 'Auto';
    }
  }

  String? _getLanguageName(String? code) {
    if (code == null || code.isEmpty) return null;

    const languages = {
      'eng': 'English',
      'en': 'English',
      'hin': 'Hindi',
      'hi': 'Hindi',
      'spa': 'Spanish',
      'es': 'Spanish',
      'fra': 'French',
      'fr': 'French',
      'deu': 'German',
      'de': 'German',
      'jpn': 'Japanese',
      'ja': 'Japanese',
      'kor': 'Korean',
      'ko': 'Korean',
      'chi': 'Chinese',
      'zh': 'Chinese',
      'ara': 'Arabic',
      'ar': 'Arabic',
      'rus': 'Russian',
      'ru': 'Russian',
      'por': 'Portuguese',
      'pt': 'Portuguese',
      'ita': 'Italian',
      'it': 'Italian',
      'tam': 'Tamil',
      'ta': 'Tamil',
      'tel': 'Telugu',
      'te': 'Telugu',
      'ben': 'Bengali',
      'bn': 'Bengali',
      'mar': 'Marathi',
      'mr': 'Marathi',
      'kan': 'Kannada',
      'kn': 'Kannada',
      'mal': 'Malayalam',
      'ml': 'Malayalam',
      'pan': 'Punjabi',
      'pa': 'Punjabi',
      'guj': 'Gujarati',
      'gu': 'Gujarati',
      'und': 'Unknown',
    };

    return languages[code.toLowerCase()] ?? code.toUpperCase();
  }

  // ═══════════════════════════════════════════════════════
  // SPEED SELECTOR
  // ═══════════════════════════════════════════════════════

  void _showSpeedSelector(BuildContext context, WidgetRef ref) {
    try {
      // Get data before closing
      final VideoPlayerState playerState;
      final VideoPlayerNotifier notifier;

      try {
        playerState = ref.read(videoPlayerProvider);
        notifier = ref.read(videoPlayerProvider.notifier);
      } catch (e) {
        debugPrint('❌ Failed to read provider: $e');
        _showMessage(context, 'Player not available', Colors.red);
        return;
      }

      final currentSpeed = playerState.speed;

      // Close current sheet
      _safePopContext(context);

      // Show speed selector after delay
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!context.mounted) return;
        try {
          _safeShowBottomSheet(
            context: context,
            builder: (sheetContext) => _SpeedSelectorSheet(
              currentSpeed: currentSpeed,
              onSpeedSelected: (speed) {
                _safePopContext(sheetContext);
                _safeExecute(() async {
                  await notifier.setSpeed(speed);
                  if (!context.mounted) return;
                  _showMessage(context, 'Speed set to ${speed}x', Colors.green);
                });
              },
            ),
          );
        } catch (e) {
          debugPrint('❌ Failed to show speed selector: $e');
        }
      });
    } catch (e) {
      debugPrint('❌ _showSpeedSelector error: $e');
      _showMessage(context, 'Failed to open speed settings', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════
  // AUDIO TRACK SELECTOR
  // ═══════════════════════════════════════════════════════

  void _showAudioTrackSelector(BuildContext context, WidgetRef ref) {
    try {
      // Get data before closing
      final VideoPlayerState playerState;
      final VideoPlayerNotifier notifier;

      try {
        playerState = ref.read(videoPlayerProvider);
        notifier = ref.read(videoPlayerProvider.notifier);
      } catch (e) {
        debugPrint('❌ Failed to read provider: $e');
        _showMessage(context, 'Player not available', Colors.red);
        return;
      }

      // Filter valid tracks
      final List<AudioTrack> validTracks;
      try {
        final audioTracks = playerState.audioTracks;
        validTracks = audioTracks.where((track) {
          try {
            final id = track.id;
            return id.isNotEmpty && id != 'auto' && id != 'no';
          } catch (e) {
            return false;
          }
        }).toList();
      } catch (e) {
        debugPrint('❌ Failed to filter tracks: $e');
        _showMessage(context, 'Failed to get audio tracks', Colors.red);
        return;
      }

      final currentTrackId = playerState.currentAudioTrack?.id;

      debugPrint('🎵 Audio tracks: ${validTracks.length}');
      for (var track in validTracks) {
        debugPrint('   - ID: ${track.id}, Lang: ${track.language}');
      }

      // Close current sheet
      _safePopContext(context);

      if (validTracks.isEmpty) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!context.mounted) return;
          _showMessage(context, 'No audio tracks available', Colors.blue);
        });
        return;
      }

      // Show audio selector after delay
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!context.mounted) return;
        try {
          _safeShowBottomSheet(
            context: context,
            builder: (sheetContext) => _AudioTrackSelectorSheet(
              tracks: validTracks,
              currentTrackId: currentTrackId,
              onTrackSelected: (track) {
                _safePopContext(sheetContext);
                _safeExecute(() async {
                  debugPrint('🎵 Setting audio track: ${track.id}');
                  await notifier.setAudioTrack(track);
                  if (!context.mounted) return;
                  _showMessage(context, 'Audio track changed', Colors.green);
                });
              },
            ),
          );
        } catch (e) {
          debugPrint('❌ Failed to show audio selector: $e');
        }
      });
    } catch (e) {
      debugPrint('❌ _showAudioTrackSelector error: $e');
      _showMessage(context, 'Failed to open audio settings', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════
  // SUBTITLE SELECTOR
  // ═══════════════════════════════════════════════════════

  void _showSubtitleSelector(BuildContext context, WidgetRef ref) {
    try {
      // Get data before closing
      final VideoPlayerState playerState;
      final VideoPlayerNotifier notifier;

      try {
        playerState = ref.read(videoPlayerProvider);
        notifier = ref.read(videoPlayerProvider.notifier);
      } catch (e) {
        debugPrint('❌ Failed to read provider: $e');
        _showMessage(context, 'Player not available', Colors.red);
        return;
      }

      // Filter valid tracks
      List<SubtitleTrack> validTracks;
      try {
        final subtitleTracks = playerState.subtitleTracks;
        validTracks = subtitleTracks.where((track) {
          try {
            final id = track.id;
            return id != 'auto' && id != 'no';
          } catch (e) {
            return false;
          }
        }).toList();
      } catch (e) {
        debugPrint('❌ Failed to filter tracks: $e');
        validTracks = [];
      }

      final currentTrackId = playerState.currentSubtitleTrack?.id;

      debugPrint('📝 Subtitle tracks: ${validTracks.length}');

      // Close current sheet
      _safePopContext(context);

      // Show subtitle selector after delay
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!context.mounted) return;
        try {
          _safeShowBottomSheet(
            context: context,
            builder: (sheetContext) => _SubtitleSelectorSheet(
              tracks: validTracks,
              currentTrackId: currentTrackId,
              onTrackSelected: (track) {
                _safePopContext(sheetContext);
                _safeExecute(() async {
                  if (track == null) {
                    debugPrint('📝 Disabling subtitles');
                    await notifier.disableSubtitles();
                    if (!context.mounted) return;
                    _showMessage(context, 'Subtitles disabled', Colors.green);
                  } else {
                    debugPrint('📝 Setting subtitle track: ${track.id}');
                    await notifier.setSubtitleTrack(track);
                    if (!context.mounted) return;
                    _showMessage(context, 'Subtitle changed', Colors.green);
                  }
                });
              },
            ),
          );
        } catch (e) {
          debugPrint('❌ Failed to show subtitle selector: $e');
        }
      });
    } catch (e) {
      debugPrint('❌ _showSubtitleSelector error: $e');
      _showMessage(context, 'Failed to open subtitle settings', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════
  // QUALITY SELECTOR
  // ═══════════════════════════════════════════════════════

  void _showQualitySelector(BuildContext context, WidgetRef ref) {
    try {
      // Get data before closing
      final VideoPlayerState playerState;
      final VideoPlayerNotifier notifier;

      try {
        playerState = ref.read(videoPlayerProvider);
        notifier = ref.read(videoPlayerProvider.notifier);
      } catch (e) {
        debugPrint('❌ Failed to read provider: $e');
        _showMessage(context, 'Player not available', Colors.red);
        return;
      }

      // Filter valid tracks
      final List<VideoTrack> validTracks;
      try {
        final videoTracks = playerState.videoTracks;
        validTracks = videoTracks.where((track) {
          try {
            final id = track.id;
            return id.isNotEmpty && id != 'auto' && id != 'no';
          } catch (e) {
            return false;
          }
        }).toList();
      } catch (e) {
        debugPrint('❌ Failed to filter tracks: $e');
        _showMessage(context, 'Failed to get quality options', Colors.red);
        return;
      }

      final currentTrackId = playerState.currentVideoTrack?.id;

      debugPrint('🎬 Video tracks: ${validTracks.length}');
      for (var track in validTracks) {
        debugPrint('   - ID: ${track.id}, ${track.w}x${track.h}');
      }

      // Close current sheet
      _safePopContext(context);

      if (validTracks.isEmpty) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!context.mounted) return;
          _showMessage(context, 'No quality options available', Colors.blue);
        });
        return;
      }

      // Show quality selector after delay
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!context.mounted) return;
        try {
          _safeShowBottomSheet(
            context: context,
            builder: (sheetContext) => _QualitySelectorSheet(
              tracks: validTracks,
              currentTrackId: currentTrackId,
              onTrackSelected: (track) {
                _safePopContext(sheetContext);
                _safeExecute(() async {
                  debugPrint('🎬 Setting video track: ${track.id}');
                  await notifier.setVideoTrack(track);
                  if (!context.mounted) return;
                  _showMessage(context, 'Quality changed', Colors.green);
                });
              },
            ),
          );
        } catch (e) {
          debugPrint('❌ Failed to show quality selector: $e');
        }
      });
    } catch (e) {
      debugPrint('❌ _showQualitySelector error: $e');
      _showMessage(context, 'Failed to open quality settings', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════
  // SCREENSHOT
  // ═══════════════════════════════════════════════════════

  void _takeScreenshot(BuildContext context, WidgetRef ref) {
    try {
      final VideoPlayerNotifier notifier;

      try {
        notifier = ref.read(videoPlayerProvider.notifier);
      } catch (e) {
        debugPrint('❌ Failed to read provider: $e');
        _showMessage(context, 'Player not available', Colors.red);
        return;
      }

      // Close current sheet
      _safePopContext(context);

      // Take screenshot after delay
      Future.delayed(const Duration(milliseconds: 100), () {
        _safeExecute(() async {
          final screenshot = await notifier.takeScreenshot();
          if (screenshot != null) {
            if (!context.mounted) return;
            _showMessage(context, 'Screenshot saved!', Colors.green);
          } else {
            if (!context.mounted) return;
            _showMessage(context, 'Failed to take screenshot', Colors.red);
          }
        });
      });
    } catch (e) {
      debugPrint('❌ _takeScreenshot error: $e');
      _showMessage(context, 'Screenshot failed', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════
  // TOGGLE LOOP
  // ═══════════════════════════════════════════════════════

  void _toggleLoop(BuildContext context, WidgetRef ref) {
    try {
      ref.read(videoPlayerProvider.notifier).toggleLoopPlaylist();
      _showMessage(context, 'Loop toggled', Colors.blue);
    } catch (e) {
      debugPrint('❌ _toggleLoop error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // SAFE UTILITIES
  // ═══════════════════════════════════════════════════════

  void _safePopContext(BuildContext context) {
    try {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('⚠️ Safe pop error: $e');
    }
  }

  void _safeShowBottomSheet({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
  }) {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (sheetContext) {
          try {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                  child: builder(sheetContext),
                ),
              ),
            );
          } catch (e) {
            debugPrint('❌ Sheet builder error: $e');
            return _SheetErrorWidget(
              error: e.toString(),
              onClose: () => _safePopContext(sheetContext),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Show bottom sheet error: $e');
    }
  }

  Future<void> _safeExecute(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('❌ Safe execute error: $e');
    }
  }

  void _showMessage(BuildContext context, String message, Color color) {
    try {
      // Use rootNavigator to get the scaffold
      final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
      if (scaffoldMessenger != null) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: color.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Show message error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// SAFE BUILDER WIDGET
// ═══════════════════════════════════════════════════════

class _SafeBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) builder;
  final Widget Function(BuildContext context, Object error) errorBuilder;

  const _SafeBuilder({required this.builder, required this.errorBuilder});

  @override
  Widget build(BuildContext context) {
    try {
      return builder(context);
    } catch (e) {
      debugPrint('❌ SafeBuilder caught error: $e');
      return errorBuilder(context, e);
    }
  }
}

// ═══════════════════════════════════════════════════════
// SHEET ERROR WIDGET
// ═══════════════════════════════════════════════════════

class _SheetErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onClose;

  const _SheetErrorWidget({required this.error, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Colors.grey[400] ?? Colors.grey,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onClose, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SETTINGS ITEM WIDGET
// ═══════════════════════════════════════════════════════

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: Colors.grey[400] ?? Colors.grey,
                fontSize: 12,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════════════
// SPEED SELECTOR SHEET
// ═══════════════════════════════════════════════════════

class _SpeedSelectorSheet extends StatelessWidget {
  final double currentSpeed;
  final void Function(double) onSpeedSelected;

  const _SpeedSelectorSheet({
    required this.currentSpeed,
    required this.onSpeedSelected,
  });

  static const List<double> speeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(context, 'Playback Speed'),
          const Divider(color: Colors.white12, height: 1),
          ...speeds.map((speed) {
            final isSelected = (currentSpeed - speed).abs() < 0.01;
            return _buildSpeedTile(speed, isSelected);
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSpeedTile(double speed, bool isSelected) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Colors.red : Colors.white54,
      ),
      title: Text(
        speed == 1.0 ? 'Normal' : '${speed}x',
        style: TextStyle(
          color: isSelected ? Colors.red : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () => onSpeedSelected(speed),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white38,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: () {
              try {
                Navigator.of(context).pop();
              } catch (e) {
                debugPrint('⚠️ Pop error: $e');
              }
            },
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// AUDIO TRACK SELECTOR SHEET
// ═══════════════════════════════════════════════════════

class _AudioTrackSelectorSheet extends StatelessWidget {
  final List<AudioTrack> tracks;
  final String? currentTrackId;
  final void Function(AudioTrack) onTrackSelected;

  const _AudioTrackSelectorSheet({
    required this.tracks,
    required this.currentTrackId,
    required this.onTrackSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(context, 'Audio Track'),
          const Divider(color: Colors.white12, height: 1),
          Flexible(
            child: tracks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      try {
                        final track = tracks[index];
                        final isSelected = currentTrackId == track.id;
                        return _buildTrackTile(track, isSelected);
                      } catch (e) {
                        debugPrint('⚠️ Build track tile error: $e');
                        return const SizedBox.shrink();
                      }
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTrackTile(AudioTrack track, bool isSelected) {
    String title;
    try {
      title =
          track.title ??
          _getLanguageName(track.language) ??
          (track.id.isNotEmpty ? 'Track ${track.id}' : 'Unknown Track');
    } catch (e) {
      title = 'Unknown Track';
    }

    String? subtitleText;
    try {
      subtitleText = track.language;
    } catch (e) {
      subtitleText = null;
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Colors.red : Colors.white54,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.red : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: subtitleText != null
          ? Text(
              subtitleText,
              style: TextStyle(color: Colors.grey[400] ?? Colors.grey),
            )
          : null,
      onTap: () => onTrackSelected(track),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.audiotrack, color: Colors.white38, size: 48),
          SizedBox(height: 16),
          Text(
            'No audio tracks available',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  String? _getLanguageName(String? code) {
    if (code == null) return null;
    const languages = {
      'eng': 'English',
      'en': 'English',
      'hin': 'Hindi',
      'hi': 'Hindi',
      'spa': 'Spanish',
      'fra': 'French',
      'deu': 'German',
      'jpn': 'Japanese',
      'und': 'Unknown',
    };
    return languages[code.toLowerCase()] ?? code.toUpperCase();
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white38,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: () {
              try {
                Navigator.of(context).pop();
              } catch (e) {
                debugPrint('⚠️ Pop error: $e');
              }
            },
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SUBTITLE SELECTOR SHEET
// ═══════════════════════════════════════════════════════

class _SubtitleSelectorSheet extends StatelessWidget {
  final List<SubtitleTrack> tracks;
  final String? currentTrackId;
  final void Function(SubtitleTrack?) onTrackSelected;

  const _SubtitleSelectorSheet({
    required this.tracks,
    required this.currentTrackId,
    required this.onTrackSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isOffSelected = currentTrackId == null || currentTrackId == 'no';

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(context, 'Subtitles'),
          const Divider(color: Colors.white12, height: 1),

          // Off option
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(
              isOffSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isOffSelected ? Colors.red : Colors.white54,
            ),
            title: Text(
              'Off',
              style: TextStyle(
                color: isOffSelected ? Colors.red : Colors.white,
                fontWeight: isOffSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onTap: () => onTrackSelected(null),
          ),

          // Subtitle tracks
          if (tracks.isNotEmpty)
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  try {
                    final track = tracks[index];
                    final isSelected = currentTrackId == track.id;
                    return _buildTrackTile(track, isSelected);
                  } catch (e) {
                    debugPrint('⚠️ Build track tile error: $e');
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTrackTile(SubtitleTrack track, bool isSelected) {
    String title;
    try {
      title =
          track.title ??
          _getLanguageName(track.language) ??
          (track.id.isNotEmpty ? 'Track ${track.id}' : 'Unknown Track');
    } catch (e) {
      title = 'Unknown Track';
    }

    String? subtitleText;
    try {
      subtitleText = track.language;
    } catch (e) {
      subtitleText = null;
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Colors.red : Colors.white54,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.red : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: subtitleText != null
          ? Text(
              subtitleText,
              style: TextStyle(color: Colors.grey[400] ?? Colors.grey),
            )
          : null,
      onTap: () => onTrackSelected(track),
    );
  }

  String? _getLanguageName(String? code) {
    if (code == null) return null;
    const languages = {
      'eng': 'English',
      'en': 'English',
      'hin': 'Hindi',
      'hi': 'Hindi',
      'spa': 'Spanish',
      'fra': 'French',
      'deu': 'German',
      'jpn': 'Japanese',
      'und': 'Unknown',
    };
    return languages[code.toLowerCase()] ?? code.toUpperCase();
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white38,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: () {
              try {
                Navigator.of(context).pop();
              } catch (e) {
                debugPrint('⚠️ Pop error: $e');
              }
            },
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// QUALITY SELECTOR SHEET
// ═══════════════════════════════════════════════════════

class _QualitySelectorSheet extends StatelessWidget {
  final List<VideoTrack> tracks;
  final String? currentTrackId;
  final void Function(VideoTrack) onTrackSelected;

  const _QualitySelectorSheet({
    required this.tracks,
    required this.currentTrackId,
    required this.onTrackSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(context, 'Video Quality'),
          const Divider(color: Colors.white12, height: 1),
          Flexible(
            child: tracks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      try {
                        final track = tracks[index];
                        final isSelected = currentTrackId == track.id;
                        return _buildTrackTile(track, isSelected);
                      } catch (e) {
                        debugPrint('⚠️ Build track tile error: $e');
                        return const SizedBox.shrink();
                      }
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTrackTile(VideoTrack track, bool isSelected) {
    String title;
    String? subtitle;

    try {
      if (track.w != null && track.h != null) {
        final h = track.h;
        final w = track.w;
        if (h != null) {
          if (h >= 2160) {
            title = '4K Ultra HD';
          } else if (h >= 1440) {
            title = '1440p QHD';
          } else if (h >= 1080) {
            title = '1080p Full HD';
          } else if (h >= 720) {
            title = '720p HD';
          } else if (h >= 480) {
            title = '480p SD';
          } else if (h >= 360) {
            title = '360p';
          } else {
            title = '${h}p';
          }
          subtitle = w != null ? '$w × $h' : null;
        } else {
          title = 'Track ${track.id}';
        }
      } else {
        title = 'Track ${track.id}';
      }
    } catch (e) {
      title = 'Unknown Quality';
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Colors.red : Colors.white54,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.red : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: Colors.grey[400] ?? Colors.grey),
            )
          : null,
      onTap: () => onTrackSelected(track),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.high_quality, color: Colors.white38, size: 48),
          SizedBox(height: 16),
          Text(
            'No quality options available',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white38,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: () {
              try {
                Navigator.of(context).pop();
              } catch (e) {
                debugPrint('⚠️ Pop error: $e');
              }
            },
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// HELPER FUNCTION TO SHOW SETTINGS SHEET
// ═══════════════════════════════════════════════════════

/// Call this function to show the settings sheet safely
void showSettingsSheet(BuildContext context) {
  try {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        try {
          return const SettingsSheetWidget();
        } catch (e) {
          debugPrint('❌ Settings sheet build error: $e');
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[900] ?? Colors.grey,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load settings',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      try {
                        Navigator.of(sheetContext).pop();
                      } catch (_) {}
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  } catch (e) {
    debugPrint('❌ Show settings sheet error: $e');
  }
}

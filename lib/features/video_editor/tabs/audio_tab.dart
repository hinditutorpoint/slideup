import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/file_picker_service.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';

// ═══════════════════════════════════════════════════════
// ✅ AUDIO TAB STATE
// ═══════════════════════════════════════════════════════

enum AudioMixMode { replace, mix }

class AudioTabState {
  final String? attachedAudioPath;
  final String? attachedAudioName;
  final AudioMixMode mixMode;
  final double attachedVolume;
  final double originalVolume;
  final bool isProcessing;
  final String? error;
  final AudioInfo? audioInfo;

  const AudioTabState({
    this.attachedAudioPath,
    this.attachedAudioName,
    this.mixMode = AudioMixMode.mix,
    this.attachedVolume = 1.0,
    this.originalVolume = 1.0,
    this.isProcessing = false,
    this.error,
    this.audioInfo,
  });

  AudioTabState copyWith({
    String? attachedAudioPath,
    String? attachedAudioName,
    AudioMixMode? mixMode,
    double? attachedVolume,
    double? originalVolume,
    bool? isProcessing,
    String? error,
    AudioInfo? audioInfo,
  }) {
    return AudioTabState(
      attachedAudioPath: attachedAudioPath ?? this.attachedAudioPath,
      attachedAudioName: attachedAudioName ?? this.attachedAudioName,
      mixMode: mixMode ?? this.mixMode,
      attachedVolume: attachedVolume ?? this.attachedVolume,
      originalVolume: originalVolume ?? this.originalVolume,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      audioInfo: audioInfo ?? this.audioInfo,
    );
  }

  AudioTabState clear() {
    return const AudioTabState();
  }
}

// ═══════════════════════════════════════════════════════
// ✅ AUDIO TAB NOTIFIER
// ═══════════════════════════════════════════════════════

class AudioTabNotifier extends StateNotifier<AudioTabState> {
  AudioTabNotifier(this._audioEditService, this._timelineNotifier)
    : super(const AudioTabState());

  final AudioEditService _audioEditService;
  final TimelineNotifier _timelineNotifier;

  void setAttachedAudio(String? path, String? name) {
    if (path == null) {
      state = state.clear();
    } else {
      state = state.copyWith(attachedAudioPath: path, attachedAudioName: name);
      _loadAudioInfo(path);
    }
  }

  Future<void> _loadAudioInfo(String path) async {
    final result = await _audioEditService.getAudioInfo(path);
    if (result.isSuccess) {
      state = state.copyWith(audioInfo: result.requireData);
    }
  }

  void setMixMode(AudioMixMode mode) {
    state = state.copyWith(mixMode: mode);
  }

  void setAttachedVolume(double volume) {
    state = state.copyWith(attachedVolume: volume.clamp(0.0, 2.0));
  }

  void setOriginalVolume(double volume) {
    state = state.copyWith(originalVolume: volume.clamp(0.0, 2.0));
  }

  void addToTimeline() {
    if (state.attachedAudioPath == null || state.audioInfo == null) return;

    _timelineNotifier.addAudioItem(
      audioPath: state.attachedAudioPath!,
      audioDuration: state.audioInfo!.duration,
      title: state.attachedAudioName ?? 'Audio',
      volume: state.attachedVolume,
    );

    // Clear after adding
    state = state.clear();
  }

  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ═══════════════════════════════════════════════════════
// ✅ PROVIDER
// ═══════════════════════════════════════════════════════

final audioTabProvider = StateNotifierProvider<AudioTabNotifier, AudioTabState>(
  (ref) {
    final audioService = ref.watch(audioEditServiceProvider);
    final timelineNotifier = ref.watch(timelineProvider.notifier);
    return AudioTabNotifier(audioService, timelineNotifier);
  },
);

// ═══════════════════════════════════════════════════════
// ✅ AUDIO TAB WIDGET
// ═══════════════════════════════════════════════════════

class AudioTab extends ConsumerWidget {
  const AudioTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioTabProvider);
    final notifier = ref.read(audioTabProvider.notifier);
    final videoEditService = ref.read(videoEditServiceProvider);
    final currentProject = ref.watch(currentProjectProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 300;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error message
              if (state.error != null) ...[
                _buildErrorBanner(state.error!, notifier, isCompact),
                SizedBox(height: isCompact ? 12 : 16),
              ],

              // Attach audio section
              _buildSection(
                title: 'Attach Audio',
                icon: Icons.add_circle_outline,
                isCompact: isCompact,
                child: state.attachedAudioPath != null
                    ? _buildAttachedAudio(context, state, notifier, isCompact)
                    : _buildAttachButton(context, notifier, isCompact),
              ),

              SizedBox(height: isCompact ? 16 : 24),

              // Audio options when attached
              if (state.attachedAudioPath != null) ...[
                _buildSection(
                  title: 'Mix Options',
                  icon: Icons.tune,
                  isCompact: isCompact,
                  child: _buildAudioOptions(state, notifier, isCompact),
                ),

                SizedBox(height: isCompact ? 16 : 24),

                _buildSection(
                  title: 'Volume Control',
                  icon: Icons.volume_up,
                  isCompact: isCompact,
                  child: _buildVolumeControls(state, notifier, isCompact),
                ),

                SizedBox(height: isCompact ? 16 : 24),

                // Add to timeline button
                _buildAddToTimelineButton(notifier, isCompact),

                SizedBox(height: isCompact ? 16 : 24),
              ],

              // Extract audio section
              _buildSection(
                title: 'Extract Audio',
                icon: Icons.download,
                isCompact: isCompact,
                child: _buildExtractButton(
                  context,
                  videoEditService,
                  currentProject,
                  notifier,
                  state,
                  isCompact,
                ),
              ),

              SizedBox(height: isCompact ? 16 : 24),

              // Open full editor section
              _buildSection(
                title: 'Advanced Editing',
                icon: Icons.auto_fix_high,
                isCompact: isCompact,
                child: _buildOpenEditorButton(context, isCompact),
              ),

              SizedBox(height: isCompact ? 16 : 24),

              // Timeline audio items
              _buildTimelineAudioItems(ref, isCompact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner(
    String error,
    AudioTabNotifier notifier,
    bool isCompact,
  ) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: isCompact ? 18 : 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: Colors.red[300],
                fontSize: isCompact ? 11 : 12,
              ),
            ),
          ),
          IconButton(
            onPressed: notifier.clearError,
            icon: Icon(Icons.close, size: isCompact ? 16 : 18),
            color: Colors.red[300],
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required bool isCompact,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey[500], size: isCompact ? 16 : 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 13 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 10 : 12),
        child,
      ],
    );
  }

  Widget _buildAttachButton(
    BuildContext context,
    AudioTabNotifier notifier,
    bool isCompact,
  ) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _pickAudio(context, notifier),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: isCompact ? 16 : 20),
          child: Column(
            children: [
              Icon(
                Icons.music_note,
                color: Colors.white70,
                size: isCompact ? 28 : 32,
              ),
              SizedBox(height: isCompact ? 8 : 10),
              Text(
                'Tap to select audio file',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isCompact ? 12 : 13,
                ),
              ),
              SizedBox(height: isCompact ? 2 : 4),
              Text(
                'MP3, AAC, WAV, FLAC, OGG',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isCompact ? 10 : 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachedAudio(
    BuildContext context,
    AudioTabState state,
    AudioTabNotifier notifier,
    bool isCompact,
  ) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.music_note,
                  color: Colors.green,
                  size: isCompact ? 20 : 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.attachedAudioName ?? 'Audio file',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 12 : 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (state.audioInfo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${state.audioInfo!.formattedDuration} • ${state.audioInfo!.formattedFileSize}',
                        style: TextStyle(
                          color: Colors.green[400],
                          fontSize: isCompact ? 10 : 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  notifier.setAttachedAudio(null, null);
                  HapticFeedback.lightImpact();
                },
                icon: Icon(
                  Icons.close,
                  color: Colors.red[400],
                  size: isCompact ? 18 : 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioOptions(
    AudioTabState state,
    AudioTabNotifier notifier,
    bool isCompact,
  ) {
    return Column(
      children: [
        _buildOptionTile(
          icon: Icons.swap_horiz,
          title: 'Replace original audio',
          subtitle: 'Mute video audio completely',
          isCompact: isCompact,
          isSelected: state.mixMode == AudioMixMode.replace,
          onTap: () {
            notifier.setMixMode(AudioMixMode.replace);
            HapticFeedback.selectionClick();
          },
        ),
        const SizedBox(height: 8),
        _buildOptionTile(
          icon: Icons.merge_type,
          title: 'Mix with original',
          subtitle: 'Blend both audio tracks',
          isCompact: isCompact,
          isSelected: state.mixMode == AudioMixMode.mix,
          onTap: () {
            notifier.setMixMode(AudioMixMode.mix);
            HapticFeedback.selectionClick();
          },
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isCompact,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(isCompact ? 10 : 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Colors.blue.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.blue : Colors.grey[500],
                size: isCompact ? 18 : 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 12 : 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: isCompact ? 10 : 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Colors.blue,
                  size: isCompact ? 18 : 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeControls(
    AudioTabState state,
    AudioTabNotifier notifier,
    bool isCompact,
  ) {
    return Column(
      children: [
        // Attached audio volume
        _buildVolumeSlider(
          label: 'Attached Audio',
          value: state.attachedVolume,
          onChanged: notifier.setAttachedVolume,
          isCompact: isCompact,
          color: Colors.green,
        ),

        if (state.mixMode == AudioMixMode.mix) ...[
          SizedBox(height: isCompact ? 12 : 16),
          // Original video volume
          _buildVolumeSlider(
            label: 'Original Video Audio',
            value: state.originalVolume,
            onChanged: notifier.setOriginalVolume,
            isCompact: isCompact,
            color: Colors.orange,
          ),
        ],
      ],
    );
  }

  Widget _buildVolumeSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required bool isCompact,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: isCompact ? 11 : 12,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                color: color,
                fontSize: isCompact ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 4 : 6),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.1),
            trackHeight: isCompact ? 3 : 4,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: isCompact ? 6 : 8,
            ),
          ),
          child: Slider(value: value, min: 0.0, max: 2.0, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildAddToTimelineButton(AudioTabNotifier notifier, bool isCompact) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          notifier.addToTimeline();
          HapticFeedback.mediumImpact();
        },
        icon: Icon(Icons.add, size: isCompact ? 18 : 20),
        label: Text(
          'Add to Timeline',
          style: TextStyle(fontSize: isCompact ? 13 : 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildExtractButton(
    BuildContext context,
    VideoEditService videoEditService,
    VideoProject? currentProject,
    AudioTabNotifier notifier,
    AudioTabState state,
    bool isCompact,
  ) {
    return Material(
      color: Colors.blue.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: state.isProcessing || currentProject == null
            ? null
            : () => _extractAudio(
                context,
                videoEditService,
                currentProject,
                notifier,
              ),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (state.isProcessing) ...[
                SizedBox(
                  width: isCompact ? 16 : 18,
                  height: isCompact ? 16 : 18,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue,
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.audio_file,
                  color: Colors.blue,
                  size: isCompact ? 20 : 22,
                ),
              ],
              const SizedBox(width: 10),
              Text(
                state.isProcessing
                    ? 'Extracting...'
                    : 'Extract Audio from Video',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenEditorButton(BuildContext context, bool isCompact) {
    return Material(
      color: Colors.purple.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _openFullAudioEditor(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_fix_high,
                    color: Colors.purple,
                    size: isCompact ? 20 : 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Open Audio Editor',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 4 : 6),
              Text(
                'Echo • Compressor • Noise Removal • Vocal Remover',
                style: TextStyle(
                  color: Colors.purple[300],
                  fontSize: isCompact ? 9 : 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineAudioItems(WidgetRef ref, bool isCompact) {
    final audioItems = ref.watch(audioItemsProvider);

    if (audioItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.playlist_play,
              color: Colors.grey[500],
              size: isCompact ? 16 : 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Timeline Audio (${audioItems.length})',
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 13 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 10 : 12),
        ...audioItems.map((item) => _buildAudioItemTile(ref, item, isCompact)),
      ],
    );
  }

  Widget _buildAudioItemTile(
    WidgetRef ref,
    AudioTimelineItem item,
    bool isCompact,
  ) {
    final timelineNotifier = ref.read(timelineProvider.notifier);
    final isSelected = ref.watch(selectedItemProvider)?.id == item.id;

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 6 : 8),
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            item.isMuted ? Icons.volume_off : Icons.volume_up,
            color: item.isMuted ? Colors.grey : Colors.orange,
            size: isCompact ? 18 : 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.isNotEmpty ? item.title : 'Audio Track',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 12 : 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_formatDuration(item.startTime)} - ${_formatDuration(item.endTime)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: isCompact ? 10 : 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              timelineNotifier.selectItem(item.id, TimelineItemType.audio);
              HapticFeedback.selectionClick();
            },
            icon: Icon(
              Icons.edit,
              size: isCompact ? 16 : 18,
              color: Colors.grey[400],
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              timelineNotifier.removeAudioItem(item.id);
              HapticFeedback.lightImpact();
            },
            icon: Icon(
              Icons.delete_outline,
              size: isCompact ? 16 : 18,
              color: Colors.red[400],
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _pickAudio(
    BuildContext context,
    AudioTabNotifier notifier,
  ) async {
    try {
      final result = await FilePickerService.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        notifier.setAttachedAudio(file.path, file.name);
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      notifier.setError('Failed to pick audio: $e');
      debugPrint('❌ Pick audio error: $e');
    }
  }

  Future<void> _extractAudio(
    BuildContext context,
    VideoEditService videoEditService,
    VideoProject project,
    AudioTabNotifier notifier,
  ) async {
    notifier.setProcessing(true);

    final result = await videoEditService.extractAudio(
      inputPath: project.videoPath,
      format: AudioFormat.mp3,
      bitrate: 192,
    );

    notifier.setProcessing(false);

    result.when(
      success: (path) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Audio extracted successfully!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Use',
              textColor: Colors.white,
              onPressed: () {
                notifier.setAttachedAudio(path, 'Extracted Audio.mp3');
              },
            ),
          ),
        );
        HapticFeedback.mediumImpact();
      },
      failure: (error, _) {
        notifier.setError('Failed to extract audio');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to extract audio: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  void _openFullAudioEditor(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Full Audio Editor coming soon!'),
        backgroundColor: Colors.purple,
      ),
    );
  }
}

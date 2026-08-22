import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/file_picker_service.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';
import 'pixabay_music_picker_sheet.dart';
import 'local_audio_browser_sheet.dart';
import 'package:slideup/core/utils/safe_async.dart';

// ═══════════════════════════════════════════════════════
// ✅ AUDIO SHEET (YouCut Style)
// ═══════════════════════════════════════════════════════

class AudioSheet extends ConsumerStatefulWidget {
  const AudioSheet({super.key});

  @override
  ConsumerState<AudioSheet> createState() => _AudioSheetState();
}

class _AudioSheetState extends ConsumerState<AudioSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _audioService = AudioEditService();

  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _processingMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          _buildHandleBar(),

          // Header
          _buildHeader(),

          // Processing indicator
          if (_isProcessing) _buildProcessingIndicator(),

          // Tab bar
          _buildTabBar(),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVideoAudioTab(),
                _buildMusicTab(),
                _buildEffectsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ COMMON WIDGETS
  // ═══════════════════════════════════════════════════════

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.volume_up, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Audio Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF9C27B0).withValues(alpha: 0.2),
            const Color(0xFF7B1FA2).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF9C27B0),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _processingMessage.isNotEmpty
                      ? _processingMessage
                      : 'Processing audio...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _processingProgress,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    color: const Color(0xFF9C27B0),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${(_processingProgress * 100).toInt()}%',
            style: const TextStyle(
              color: Color(0xFF9C27B0),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Video Audio'),
          Tab(text: 'Music'),
          Tab(text: 'Effects'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VIDEO AUDIO TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildVideoAudioTab() {
    final project = ref.watch(currentProjectProvider);

    if (project == null) {
      return _buildNoVideoState();
    }

    final audioSettings = project.videoAudioSettings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mute toggle card
          _buildMuteCard(audioSettings),

          const SizedBox(height: 20),

          // Volume control
          if (!audioSettings.isMuted) _buildVolumeControl(audioSettings),

          const SizedBox(height: 20),

          // Fade controls
          _buildFadeSection(audioSettings),

          const SizedBox(height: 24),

          // Quick presets
          _buildQuickPresets(audioSettings),
        ],
      ),
    );
  }

  Widget _buildMuteCard(VideoAudioSettings settings) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _updateVideoAudio(settings.copyWith(isMuted: !settings.isMuted));
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: settings.isMuted
                  ? [
                      Colors.red.withValues(alpha: 0.15),
                      Colors.red.withValues(alpha: 0.05),
                    ]
                  : [
                      const Color(0xFF9C27B0).withValues(alpha: 0.15),
                      const Color(0xFF9C27B0).withValues(alpha: 0.05),
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: settings.isMuted
                  ? Colors.red.withValues(alpha: 0.3)
                  : const Color(0xFF9C27B0).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: settings.isMuted
                      ? Colors.red.withValues(alpha: 0.2)
                      : const Color(0xFF9C27B0).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  settings.isMuted ? Icons.volume_off : Icons.volume_up,
                  color: settings.isMuted
                      ? Colors.red
                      : const Color(0xFF9C27B0),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.isMuted ? 'Audio Muted' : 'Audio Enabled',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      settings.isMuted
                          ? 'Tap to unmute original audio'
                          : 'Tap to mute original audio',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: !settings.isMuted,
                onChanged: (value) {
                  _updateVideoAudio(settings.copyWith(isMuted: !value));
                  HapticFeedback.lightImpact();
                },
                activeColor: const Color(0xFF9C27B0),
                activeTrackColor: const Color(
                  0xFF9C27B0,
                ).withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeControl(VideoAudioSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Volume',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${(settings.volume * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.volume_mute,
                    size: 22,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 18,
                        ),
                        activeTrackColor: const Color(0xFF9C27B0),
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                        thumbColor: Colors.white,
                        overlayColor: const Color(
                          0xFF9C27B0,
                        ).withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: settings.volume,
                        min: 0.0,
                        max: 2.0,
                        divisions: 40,
                        onChanged: (value) {
                          _updateVideoAudio(settings.copyWith(volume: value));
                        },
                        onChangeEnd: (_) {
                          HapticFeedback.lightImpact();
                        },
                      ),
                    ),
                  ),
                  Icon(
                    Icons.volume_up,
                    size: 22,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '100%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '200%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFadeSection(VideoAudioSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fade Effects',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFadeButton(
                'Fade In',
                Icons.trending_up,
                settings.fadeIn,
                () {
                  _updateVideoAudio(
                    settings.copyWith(fadeIn: !settings.fadeIn),
                  );
                  HapticFeedback.selectionClick();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFadeButton(
                'Fade Out',
                Icons.trending_down,
                settings.fadeOut,
                () {
                  _updateVideoAudio(
                    settings.copyWith(fadeOut: !settings.fadeOut),
                  );
                  HapticFeedback.selectionClick();
                },
              ),
            ),
          ],
        ),

        // Fade duration slider
        if (settings.fadeIn || settings.fadeOut) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Fade Duration',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '${(settings.fadeDuration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                      style: const TextStyle(
                        color: Color(0xFF9C27B0),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    activeTrackColor: const Color(0xFF9C27B0),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: const Color(0xFF9C27B0),
                  ),
                  child: Slider(
                    value: settings.fadeDuration.inMilliseconds.toDouble(),
                    min: 100,
                    max: 5000,
                    divisions: 49,
                    onChanged: (value) {
                      _updateVideoAudio(
                        settings.copyWith(
                          fadeDuration: Duration(milliseconds: value.toInt()),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFadeButton(
    String label,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Material(
      color: isActive
          ? const Color(0xFF9C27B0).withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF9C27B0) : Colors.white54,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFF9C27B0) : Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPresets(VideoAudioSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Presets',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildPresetChip('Normal', Icons.check_circle, () {
              _applyPreset(volume: 1.0, fadeIn: false, fadeOut: false);
            }),
            _buildPresetChip('Boost', Icons.arrow_upward, () {
              _applyPreset(volume: 1.5, fadeIn: false, fadeOut: false);
            }),
            _buildPresetChip('Quiet', Icons.arrow_downward, () {
              _applyPreset(volume: 0.5, fadeIn: false, fadeOut: false);
            }),
            _buildPresetChip('Fade In', Icons.input, () {
              _applyPreset(volume: 1.0, fadeIn: true, fadeOut: false);
            }),
            _buildPresetChip('Fade Out', Icons.output, () {
              _applyPreset(volume: 1.0, fadeIn: false, fadeOut: true);
            }),
            _buildPresetChip('Both Fades', Icons.compare_arrows, () {
              _applyPreset(volume: 1.0, fadeIn: true, fadeOut: true);
            }),
            _buildPresetChip('Mute', Icons.volume_off, () {
              _updateVideoAudio(settings.copyWith(isMuted: true));
            }, color: Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetChip(
    String label,
    IconData icon,
    VoidCallback onTap, {
    Color color = const Color(0xFF9C27B0),
  }) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MUSIC TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildMusicTab() {
    final timelineState = ref.watch(timelineProvider);
    final audioItems = timelineState.audioItems;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add music button
          _buildAddMusicButton(),

          const SizedBox(height: 12),

          // Browse Pixabay stock music
          _buildPixabayMusicButton(),

          const SizedBox(height: 12),

          // Browse device storage (internal / external / removable)
          _buildLocalAudioBrowserButton(),

          const SizedBox(height: 24),

          // Music list
          if (audioItems.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Background Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${audioItems.length} track${audioItems.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...audioItems.map((item) => _buildMusicCard(item)),
          ] else
            _buildNoMusicState(),
        ],
      ),
    );
  }

  Widget _buildAddMusicButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickMusicFile,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.music_note,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Background Music',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose from your device',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPixabayMusicButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => PixabayMusicPickerSheet.show(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00E0FF), Color(0xFF4CAF50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E0FF).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.cloud_download_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Browse Pixabay Music',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Royalty-free stock audio',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalAudioBrowserButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => LocalAudioBrowserSheet.show(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF00E0FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2196F3).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.sd_storage_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Browse Device Storage',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Internal, SD card & removable disk',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMusicCard(AudioTimelineItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF9C27B0).withValues(alpha: 0.3),
                        const Color(0xFF7B1FA2).withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.library_music,
                    color: Color(0xFF9C27B0),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title.isNotEmpty ? item.title : 'Background Music',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(item.effectiveAudioDuration),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 22),
                  color: Colors.red.withValues(alpha: 0.7),
                  onPressed: () => _deleteAudioItem(item.id),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Volume slider
            _buildMusicVolumeSlider(item),

            const SizedBox(height: 12),

            // Control buttons
            Row(
              children: [
                Expanded(
                  child: _buildMusicControl(
                    item.isMuted ? 'Unmute' : 'Mute',
                    item.isMuted ? Icons.volume_off : Icons.volume_up,
                    item.isMuted,
                    () => _toggleAudioMute(item),
                    activeColor: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMusicControl(
                    'Fade In',
                    Icons.trending_up,
                    item.fadeIn,
                    () => _toggleAudioFadeIn(item),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMusicControl(
                    'Fade Out',
                    Icons.trending_down,
                    item.fadeOut,
                    () => _toggleAudioFadeOut(item),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicVolumeSlider(AudioTimelineItem item) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Volume',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            Text(
              '${(item.volume * 100).toInt()}%',
              style: const TextStyle(
                color: Color(0xFF9C27B0),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: const Color(0xFF9C27B0),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: const Color(0xFF9C27B0),
          ),
          child: Slider(
            value: item.volume,
            min: 0.0,
            max: 2.0,
            onChanged: (value) => _updateAudioVolume(item, value),
          ),
        ),
      ],
    );
  }

  Widget _buildMusicControl(
    String label,
    IconData icon,
    bool isActive,
    VoidCallback onTap, {
    Color activeColor = const Color(0xFF9C27B0),
  }) {
    return Material(
      color: isActive
          ? activeColor.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? activeColor : Colors.white54,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? activeColor : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoMusicState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 72,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Text(
              'No background music',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add music to enhance your video',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EFFECTS TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildEffectsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio Effects',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Apply professional effects to your video\'s audio',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          _buildEffectCard(
            'Echo',
            'Add echo/delay effect',
            Icons.graphic_eq,
            const Color(0xFF2196F3),
            () => _applyAudioEffect(AudioEffectType.echo),
          ),
          _buildEffectCard(
            'Compressor',
            'Balance loud and quiet parts',
            Icons.compress,
            const Color(0xFFFF9800),
            () => _applyAudioEffect(AudioEffectType.compressor),
          ),
          _buildEffectCard(
            'Vocal Enhancer',
            'Boost voice clarity',
            Icons.mic,
            const Color(0xFF4CAF50),
            () => _applyAudioEffect(AudioEffectType.vocalEnhancer),
          ),
          _buildEffectCard(
            'Noise Removal',
            'Reduce background noise',
            Icons.noise_control_off,
            const Color(0xFF00BCD4),
            () => _applyAudioEffect(AudioEffectType.noiseRemoval),
          ),
          _buildEffectCard(
            'Bass Boost',
            'Enhance low frequencies',
            Icons.speaker,
            const Color(0xFFE91E63),
            () => _applyAudioEffect(AudioEffectType.bassBoost),
          ),
          _buildEffectCard(
            'Treble Boost',
            'Enhance high frequencies',
            Icons.equalizer,
            const Color(0xFF9C27B0),
            () => _applyAudioEffect(AudioEffectType.trebleBoost),
          ),
          _buildEffectCard(
            'Vocal Remover',
            'Remove vocals (karaoke effect)',
            Icons.mic_off,
            const Color(0xFFF44336),
            () => _applyAudioEffect(AudioEffectType.vocalRemoval),
          ),
        ],
      ),
    );
  }

  Widget _buildEffectCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isProcessing ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: color.withValues(alpha: 0.5),
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPER WIDGETS
  // ═══════════════════════════════════════════════════════

  Widget _buildNoVideoState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 72,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 20),
            Text(
              'No video loaded',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTIONS
  // ═══════════════════════════════════════════════════════

  void _updateVideoAudio(VideoAudioSettings settings) {
    ref.read(projectProvider.notifier).updateVideoAudioSettings(settings);
  }

  void _applyPreset({
    required double volume,
    required bool fadeIn,
    required bool fadeOut,
  }) {
    final project = ref.read(currentProjectProvider);
    if (project == null) return;

    final current = project.videoAudioSettings;
    _updateVideoAudio(
      current.copyWith(
        volume: volume,
        fadeIn: fadeIn,
        fadeOut: fadeOut,
        isMuted: false,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preset applied'),
        backgroundColor: Color(0xFF4CAF50),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _pickMusicFile() async {
    try {
      final result = await FilePickerService.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;

        // Get audio info
        final infoResult = await _audioService.getAudioInfo(path);

        if (infoResult.isSuccess) {
          final info = infoResult.requireData;
          final currentPosition = ref.read(currentPositionProvider);

          // Add to timeline
          ref
              .read(timelineProvider.notifier)
              .addAudioItem(
                audioPath: path,
                title: name,
                startTime: currentPosition,
                audioDuration: info.duration,
              );

          HapticFeedback.mediumImpact();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Music added to timeline'),
                backgroundColor: Color(0xFF4CAF50),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add music: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteAudioItem(String id) {
    ref.read(timelineProvider.notifier).removeAudioItem(id);
    HapticFeedback.lightImpact();
  }

  void _updateAudioVolume(AudioTimelineItem item, double volume) {
    ref
        .read(timelineProvider.notifier)
        .updateAudioItem(item.id, item.copyWith(volume: volume));
  }

  void _toggleAudioMute(AudioTimelineItem item) {
    ref
        .read(timelineProvider.notifier)
        .updateAudioItem(item.id, item.copyWith(isMuted: !item.isMuted));
    HapticFeedback.selectionClick();
  }

  void _toggleAudioFadeIn(AudioTimelineItem item) {
    ref
        .read(timelineProvider.notifier)
        .updateAudioItem(item.id, item.copyWith(fadeIn: !item.fadeIn));
    HapticFeedback.selectionClick();
  }

  void _toggleAudioFadeOut(AudioTimelineItem item) {
    ref
        .read(timelineProvider.notifier)
        .updateAudioItem(item.id, item.copyWith(fadeOut: !item.fadeOut));
    HapticFeedback.selectionClick();
  }

  Future<void> _applyAudioEffect(AudioEffectType effectType) async {
    final project = ref.read(currentProjectProvider);
    if (project == null || project.videoPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No video loaded'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processingMessage = 'Applying ${effectType.name} effect...';
    });

    HapticFeedback.mediumImpact();

    try {
      late Result<String> result;

      switch (effectType) {
        case AudioEffectType.echo:
          result = await _audioService.applyEcho(
            inputPath: project.videoPath,
            onProgress: _onProgress,
          );
          break;
        case AudioEffectType.compressor:
          result = await _audioService.applyCompressor(
            inputPath: project.videoPath,
            onProgress: _onProgress,
          );
          break;
        case AudioEffectType.vocalEnhancer:
          result = await _audioService.enhanceVocals(
            inputPath: project.videoPath,
            onProgress: _onProgress,
          );
          break;
        case AudioEffectType.noiseRemoval:
          result = await _audioService.removeNoise(
            inputPath: project.videoPath,
            onProgress: _onProgress,
          );
          break;
        case AudioEffectType.bassBoost:
          result = await _audioService.applyBassBoost(
            inputPath: project.videoPath,
            onProgress: _onProgress,
          );
          break;
        case AudioEffectType.trebleBoost:
          result = await _audioService.applyTrebleBoost(
            inputPath: project.videoPath,
            onProgress: _onProgress,
          );
          break;
        case AudioEffectType.vocalRemoval:
          result = await _audioService.removeVocals(
            inputPath: project.videoPath,
            onProgress: _onProgress,
          );
          break;
      }

      if (result.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${effectType.name} applied successfully!'),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Effect failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingProgress = 0.0;
          _processingMessage = '';
        });
      }
    }
  }

  void _onProgress(double progress) {
    if (mounted) {
      setState(() => _processingProgress = progress);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

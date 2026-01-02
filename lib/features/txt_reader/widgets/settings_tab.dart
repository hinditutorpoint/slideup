import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/reader_utils.dart';
import '../screens/txt_reader_screen.dart';
import '../../speaker_player/providers/tts_provider.dart';

class SettingsTab extends ConsumerStatefulWidget {
  final TxtReaderScreenState readerState;

  const SettingsTab({super.key, required this.readerState});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  ReaderSettings get settings => widget.readerState.settings;

  void _updateSettings(ReaderSettings newSettings) {
    widget.readerState.updateSettings(newSettings);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final textColor = widget.readerState.getTextColor();
    final safeArea = widget.readerState.safeArea;

    // Watch TTS providers
    final ttsInitialized = ref.watch(ttsInitializedProvider);
    final ttsInitializing = ref.watch(ttsInitializingProvider);
    final currentModel = ref.watch(currentTtsModelProvider);
    final currentSpeed = ref.watch(ttsSpeedProvider);
    final cacheStatsAsync = ref.watch(ttsCacheStatsProvider);

    return ListView(
      padding: EdgeInsets.only(
        top: 12,
        bottom: safeArea.bottom + 20,
        left: 12,
        right: 12,
      ),
      children: [
        // ==================== TTS SECTION ====================
        _buildSectionHeader(
          'Text to Speech',
          Icons.record_voice_over_rounded,
          textColor,
        ),
        const SizedBox(height: 8),

        // TTS Status Card
        _buildTtsStatusCard(
          textColor: textColor,
          isInitialized: ttsInitialized,
          isInitializing: ttsInitializing,
          modelName: currentModel,
        ),

        // TTS Speed Control
        if (ttsInitialized) ...[
          _buildSettingCard(
            icon: Icons.speed_rounded,
            title: 'Playback Speed',
            subtitle: '${currentSpeed.toStringAsFixed(1)}x',
            textColor: textColor,
            trailing: _buildSpeedControl(textColor, currentSpeed),
          ),

          // Speed Presets
          _buildSettingCard(
            icon: Icons.tune_rounded,
            title: 'Speed Presets',
            textColor: textColor,
            isVertical: true,
            trailing: _buildSpeedPresets(textColor, currentSpeed),
          ),

          // Auto-play Next Page
          _buildSwitchCard(
            icon: Icons.skip_next_rounded,
            title: 'Auto-play Next Page',
            subtitle: 'Continue to next page automatically',
            textColor: textColor,
            value: settings.autoPlayNextPage,
            onChanged: (value) {
              _updateSettings(settings.copyWith(autoPlayNextPage: value));
            },
          ),

          // Cache Stats
          _buildCacheStatsCard(textColor, cacheStatsAsync),
        ],

        const SizedBox(height: 20),

        // ==================== AUDIOBOOK SECTION ====================
        _buildSectionHeader('Audiobook', Icons.auto_stories_rounded, textColor),
        const SizedBox(height: 8),

        // Audiobook Mode Toggle
        _buildSwitchCard(
          icon: Icons.play_circle_outline_rounded,
          title: 'Enable Audiobook Mode',
          subtitle: 'Continuously read pages like an audiobook',
          textColor: textColor,
          value: settings.audiobookSettings!.enabled,
          onChanged: (value) {
            _updateSettings(
              settings.copyWith(
                audiobookSettings: settings.audiobookSettings!.copyWith(
                  enabled: value,
                ),
              ),
            );
          },
        ),

        // Auto-translate before speak
        if (settings.audiobookSettings!.enabled) ...[
          _buildSwitchCard(
            icon: Icons.translate_rounded,
            title: 'Auto-translate Pages',
            subtitle: 'Translate each page before speaking',
            textColor: textColor,
            value: settings.audiobookSettings!.autoTranslateBeforeSpeak,
            onChanged: (value) {
              _updateSettings(
                settings.copyWith(
                  audiobookSettings: settings.audiobookSettings!.copyWith(
                    autoTranslateBeforeSpeak: value,
                  ),
                ),
              );
            },
          ),

          // Continue in background
          _buildSwitchCard(
            icon: Icons.phonelink_ring_rounded,
            title: 'Continue in Background',
            subtitle: 'Keep playing when app is minimized',
            textColor: textColor,
            value: settings.audiobookSettings!.continueInBackground,
            onChanged: (value) {
              _updateSettings(
                settings.copyWith(
                  audiobookSettings: settings.audiobookSettings!.copyWith(
                    continueInBackground: value,
                  ),
                ),
              );
            },
          ),

          // Show floating controls
          _buildSwitchCard(
            icon: Icons.picture_in_picture_alt_rounded,
            title: 'Show Floating Controls',
            subtitle: 'Display playback controls overlay',
            textColor: textColor,
            value: settings.audiobookSettings!.showFloatingControls,
            onChanged: (value) {
              _updateSettings(
                settings.copyWith(
                  audiobookSettings: settings.audiobookSettings!.copyWith(
                    showFloatingControls: value,
                  ),
                ),
              );
            },
          ),

          // Delay between pages
          _buildSettingCard(
            icon: Icons.timer_rounded,
            title: 'Delay Between Pages',
            subtitle:
                '${settings.audiobookSettings!.delayBetweenPages.toStringAsFixed(1)} seconds',
            textColor: textColor,
            trailing: SizedBox(
              width: 120,
              child: SliderTheme(
                data: _sliderTheme(context, textColor),
                child: Slider(
                  value: settings.audiobookSettings!.delayBetweenPages,
                  min: 0,
                  max: 3,
                  divisions: 6,
                  onChanged: (value) {
                    _updateSettings(
                      settings.copyWith(
                        audiobookSettings: settings.audiobookSettings!.copyWith(
                          delayBetweenPages: value,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Preload pages count
          _buildSettingCard(
            icon: Icons.download_rounded,
            title: 'Preload Pages',
            subtitle:
                '${settings.audiobookSettings!.preloadPagesCount} pages ahead',
            textColor: textColor,
            trailing: SizedBox(
              width: 120,
              child: SliderTheme(
                data: _sliderTheme(context, textColor),
                child: Slider(
                  value: settings.audiobookSettings!.preloadPagesCount
                      .toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (value) {
                    _updateSettings(
                      settings.copyWith(
                        audiobookSettings: settings.audiobookSettings!.copyWith(
                          preloadPagesCount: value.toInt(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ==================== DISPLAY SECTION ====================
        _buildSectionHeader('Display', Icons.visibility_rounded, textColor),
        const SizedBox(height: 8),

        // Font Size
        _buildSettingCard(
          icon: Icons.text_fields_rounded,
          title: 'Font Size',
          textColor: textColor,
          trailing: _buildFontSizeControl(textColor),
        ),

        // Line Height
        _buildSettingCard(
          icon: Icons.format_line_spacing_rounded,
          title: 'Line Height',
          subtitle: settings.lineHeight.toStringAsFixed(1),
          textColor: textColor,
          trailing: SizedBox(
            width: 120,
            child: SliderTheme(
              data: _sliderTheme(context, textColor),
              child: Slider(
                value: settings.lineHeight,
                min: 1.0,
                max: 2.5,
                divisions: 6,
                onChanged: (value) {
                  _updateSettings(settings.copyWith(lineHeight: value));
                },
              ),
            ),
          ),
        ),

        // Theme
        _buildSettingCard(
          icon: Icons.palette_rounded,
          title: 'Theme',
          textColor: textColor,
          isVertical: true,
          trailing: _buildThemeSelector(textColor),
        ),

        // Text Alignment
        _buildSettingCard(
          icon: Icons.format_align_left_rounded,
          title: 'Text Alignment',
          textColor: textColor,
          isVertical: true,
          trailing: _buildAlignmentSelector(textColor),
        ),

        const SizedBox(height: 20),

        // ==================== TRANSLATION SECTION ====================
        _buildSectionHeader('Translation', Icons.translate_rounded, textColor),
        const SizedBox(height: 8),

        // Target Language
        _buildSettingCard(
          icon: Icons.language_rounded,
          title: 'Target Language',
          subtitle:
              TranslationLanguage.fromCode(
                widget.readerState.targetLanguage,
              )?.name ??
              'English',
          textColor: textColor,
          trailing: TextButton(
            onPressed: widget.readerState.showLanguageSelector,
            child: const Text('Change'),
          ),
        ),

        // Auto Translate
        _buildSwitchCard(
          icon: Icons.auto_awesome_rounded,
          title: 'Auto-translate',
          subtitle: 'Translate pages automatically',
          textColor: textColor,
          value: settings.translationSettings.autoTranslateOnPageChange,
          onChanged: (value) {
            _updateSettings(
              settings.copyWith(
                translationSettings: settings.translationSettings.copyWith(
                  autoTranslateOnPageChange: value,
                ),
              ),
            );
          },
        ),

        // Cache Translations
        _buildSwitchCard(
          icon: Icons.save_rounded,
          title: 'Cache Translations',
          subtitle: 'Save for offline access',
          textColor: textColor,
          value: settings.translationSettings.cacheTranslations,
          onChanged: (value) {
            _updateSettings(
              settings.copyWith(
                translationSettings: settings.translationSettings.copyWith(
                  cacheTranslations: value,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // ==================== READING SECTION ====================
        _buildSectionHeader('Reading', Icons.menu_book_rounded, textColor),
        const SizedBox(height: 8),

        // Keep Screen On
        _buildSwitchCard(
          icon: Icons.visibility_rounded,
          title: 'Keep Screen On',
          subtitle: 'Prevent screen from sleeping',
          textColor: textColor,
          value: settings.keepScreenOn,
          onChanged: (value) {
            _updateSettings(settings.copyWith(keepScreenOn: value));
          },
        ),

        // Show Page Number
        _buildSwitchCard(
          icon: Icons.numbers_rounded,
          title: 'Show Page Number',
          subtitle: 'Display current page info',
          textColor: textColor,
          value: settings.showPageNumber,
          onChanged: (value) {
            _updateSettings(settings.copyWith(showPageNumber: value));
          },
        ),

        // Page Margin
        _buildSettingCard(
          icon: Icons.format_indent_increase_rounded,
          title: 'Page Margin',
          subtitle: '${settings.margin.toInt()} px',
          textColor: textColor,
          trailing: SizedBox(
            width: 120,
            child: SliderTheme(
              data: _sliderTheme(context, textColor),
              child: Slider(
                value: settings.margin,
                min: 8,
                max: 48,
                divisions: 10,
                onChanged: (value) {
                  _updateSettings(settings.copyWith(margin: value));
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ==================== DANGER ZONE ====================
        _buildSectionHeader(
          'Data Management',
          Icons.storage_rounded,
          textColor,
        ),
        const SizedBox(height: 8),

        // Clear TTS Cache
        _buildActionCard(
          icon: Icons.audiotrack_outlined,
          title: 'Clear TTS Cache',
          subtitle: 'Remove all generated audio',
          textColor: textColor,
          actionLabel: 'Clear',
          actionColor: Colors.orange,
          onAction: _clearTtsCache,
        ),

        // Clear Translation Cache
        _buildActionCard(
          icon: Icons.translate_outlined,
          title: 'Clear Translation Cache',
          subtitle: 'Remove saved translations',
          textColor: textColor,
          actionLabel: 'Clear',
          actionColor: Colors.orange,
          onAction: _clearTranslationCache,
        ),

        // Reset All Settings
        _buildActionCard(
          icon: Icons.restart_alt_rounded,
          title: 'Reset Settings',
          subtitle: 'Restore default settings',
          textColor: textColor,
          actionLabel: 'Reset',
          actionColor: Colors.red,
          onAction: _resetSettings,
        ),
      ],
    );
  }

  // ==================== TTS WIDGETS ====================

  Widget _buildTtsStatusCard({
    required Color textColor,
    required bool isInitialized,
    required bool isInitializing,
    required String? modelName,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInitialized
            ? Colors.green.withValues(alpha: 0.08)
            : isInitializing
            ? Colors.orange.withValues(alpha: 0.08)
            : Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInitialized
              ? Colors.green.withValues(alpha: 0.3)
              : isInitializing
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isInitialized
                  ? Colors.green.withValues(alpha: 0.1)
                  : isInitializing
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isInitializing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isInitialized ? Icons.check_circle : Icons.error_outline,
                    color: isInitialized ? Colors.green : Colors.red,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isInitialized
                      ? 'TTS Ready'
                      : isInitializing
                      ? 'Initializing TTS...'
                      : 'TTS Not Available',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (modelName != null)
                  Text(
                    modelName,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  )
                else if (!isInitialized && !isInitializing)
                  Text(
                    'Download a TTS model to enable',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (!isInitialized && !isInitializing)
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/models');
              },
              child: const Text('Download'),
            )
          else if (isInitialized)
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/models');
              },
              child: const Text('Change'),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedControl(Color textColor, double currentSpeed) {
    return SizedBox(
      width: 140,
      child: SliderTheme(
        data: _sliderTheme(context, textColor),
        child: Slider(
          value: currentSpeed,
          min: 0.5,
          max: 2.0,
          divisions: 6,
          onChanged: (value) {
            ref.read(ttsControllerProvider).setSpeed(value);
          },
        ),
      ),
    );
  }

  Widget _buildSpeedPresets(Color textColor, double currentSpeed) {
    final presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((speed) {
        final isSelected = (currentSpeed - speed).abs() < 0.05;
        return GestureDetector(
          onTap: () {
            ref.read(ttsControllerProvider).setSpeed(speed);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : textColor.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              '${speed}x',
              style: TextStyle(
                color: isSelected ? Colors.white : textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCacheStatsCard(
    Color textColor,
    AsyncValue<Map<String, dynamic>> cacheStatsAsync,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storage_rounded,
                size: 20,
                color: textColor.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Text(
                'Audio Cache',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  size: 18,
                  color: textColor.withValues(alpha: 0.5),
                ),
                onPressed: () {
                  ref.invalidate(ttsCacheStatsProvider);
                },
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          cacheStatsAsync.when(
            data: (stats) => Row(
              children: [
                _buildStatItem(
                  icon: Icons.audiotrack,
                  label: 'Files',
                  value: '${stats['entries'] ?? 0}',
                  textColor: textColor,
                ),
                const SizedBox(width: 24),
                _buildStatItem(
                  icon: Icons.storage,
                  label: 'Size',
                  value: stats['formattedSize'] ?? '0 B',
                  textColor: textColor,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showCacheActions(stats),
                  icon: const Icon(Icons.more_horiz, size: 18),
                  label: const Text('Manage'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            loading: () => Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading cache info...',
                  style: TextStyle(color: textColor.withValues(alpha: 0.6)),
                ),
              ],
            ),
            error: (_, __) => Text(
              'Failed to load cache info',
              style: TextStyle(color: Colors.red.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: textColor.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showCacheActions(Map<String, dynamic> stats) {
    final textColor = widget.readerState.getTextColor();

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.readerState.getControlsBackgroundColor(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: widget.readerState.safeArea.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Audio Cache',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${stats['entries']} files • ${stats['formattedSize']}',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.orange),
              title: Text(
                'Clear This Book',
                style: TextStyle(color: textColor),
              ),
              subtitle: Text(
                'Remove cached audio for current book',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _clearBookCache();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: Text(
                'Clear All Cache',
                style: TextStyle(color: textColor),
              ),
              subtitle: Text(
                'Remove all cached audio files',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _clearTtsCache();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.download,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(
                'Pre-generate Pages',
                style: TextStyle(color: textColor),
              ),
              subtitle: Text(
                'Generate audio for upcoming pages',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                widget.readerState.toggleLeftPanel(false);
                await widget.readerState.preGenerateAudio(pagesToGenerate: 5);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== COMMON WIDGETS ====================

  SliderThemeData _sliderTheme(BuildContext context, Color textColor) {
    return SliderThemeData(
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      activeTrackColor: Theme.of(context).primaryColor,
      inactiveTrackColor: textColor.withValues(alpha: 0.2),
      thumbColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color textColor,
    required Widget trailing,
    bool isVertical = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.08)),
      ),
      child: isVertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                trailing,
              ],
            )
          : Row(
              children: [
                Icon(icon, size: 20, color: textColor.withValues(alpha: 0.6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
    );
  }

  Widget _buildSwitchCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color textColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textColor.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color textColor,
    required String actionLabel,
    required Color actionColor,
    required VoidCallback onAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textColor.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: actionColor),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeControl(Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAdjustButton(
          icon: Icons.remove_rounded,
          onTap: settings.fontSize > 12
              ? () => _updateSettings(
                  settings.copyWith(fontSize: settings.fontSize - 2),
                )
              : null,
        ),
        Container(
          width: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${settings.fontSize.toInt()}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              fontSize: 14,
            ),
          ),
        ),
        _buildAdjustButton(
          icon: Icons.add_rounded,
          onTap: settings.fontSize < 36
              ? () => _updateSettings(
                  settings.copyWith(fontSize: settings.fontSize + 2),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildAdjustButton({required IconData icon, VoidCallback? onTap}) {
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isEnabled
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isEnabled
                ? Theme.of(context).primaryColor
                : Theme.of(context).disabledColor,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector(Color textColor) {
    return Row(
      children: [
        _buildThemeOption(
          color: Colors.white,
          label: 'Light',
          themeValue: 'light',
          textColor: textColor,
        ),
        const SizedBox(width: 10),
        _buildThemeOption(
          color: const Color(0xFFF5E6C8),
          label: 'Sepia',
          themeValue: 'sepia',
          textColor: textColor,
        ),
        const SizedBox(width: 10),
        _buildThemeOption(
          color: const Color(0xFF1A1A1A),
          label: 'Dark',
          themeValue: 'dark',
          textColor: textColor,
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required Color color,
    required String label,
    required String themeValue,
    required Color textColor,
  }) {
    final isSelected = settings.theme == themeValue;

    return GestureDetector(
      onTap: () => _updateSettings(settings.copyWith(theme: themeValue)),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.withValues(alpha: 0.3),
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: isSelected
                ? Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Theme.of(context).primaryColor : textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignmentSelector(Color textColor) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'left',
          icon: Icon(Icons.format_align_left_rounded, size: 16),
        ),
        ButtonSegment(
          value: 'center',
          icon: Icon(Icons.format_align_center_rounded, size: 16),
        ),
        ButtonSegment(
          value: 'right',
          icon: Icon(Icons.format_align_right_rounded, size: 16),
        ),
        ButtonSegment(
          value: 'justify',
          icon: Icon(Icons.format_align_justify_rounded, size: 16),
        ),
      ],
      selected: {settings.textAlign},
      onSelectionChanged: (selection) {
        _updateSettings(settings.copyWith(textAlign: selection.first));
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _clearBookCache() async {
    final confirmed = await _showConfirmDialog(
      title: 'Clear Book Cache?',
      content: 'Remove all cached audio for this book?',
    );

    if (confirmed) {
      await ref
          .read(ttsControllerProvider)
          .clearCacheForBook(widget.readerState.identifier);
      widget.readerState.showSnackBar('Book cache cleared');
    }
  }

  Future<void> _clearTtsCache() async {
    final confirmed = await _showConfirmDialog(
      title: 'Clear All TTS Cache?',
      content: 'This will remove all generated audio files.',
    );

    if (confirmed) {
      await ref.read(ttsControllerProvider).clearAllCache();
      widget.readerState.showSnackBar('TTS cache cleared');
    }
  }

  Future<void> _clearTranslationCache() async {
    final confirmed = await _showConfirmDialog(
      title: 'Clear Translation Cache?',
      content: 'This will remove all saved translations.',
    );

    if (confirmed) {
      // Clear translations from storage
      //await widget.readerState.storageManager.clearTranslationCache();
      widget.readerState.showSnackBar('Translation cache cleared');
    }
  }

  Future<void> _resetSettings() async {
    final confirmed = await _showConfirmDialog(
      title: 'Reset All Settings?',
      content: 'This will restore all settings to their default values.',
    );

    if (confirmed) {
      _updateSettings(const ReaderSettings());
      ref.read(ttsControllerProvider).setSpeed(1.0);
      widget.readerState.showSnackBar('Settings reset to defaults');
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

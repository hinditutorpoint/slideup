import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../providers/epub_provider.dart';
import '../services/epub_reader_service.dart';

/// Reading settings bottom sheet
class ReadingSettingsSheet extends ConsumerStatefulWidget {
  final ReaderSettings initialSettings;
  final void Function(ReaderSettings settings)? onSettingsChanged;

  const ReadingSettingsSheet({
    super.key,
    required this.initialSettings,
    this.onSettingsChanged,
  });

  @override
  ConsumerState<ReadingSettingsSheet> createState() =>
      _ReadingSettingsSheetState();
}

class _ReadingSettingsSheetState extends ConsumerState<ReadingSettingsSheet>
    with SingleTickerProviderStateMixin {
  late ReaderSettings _settings;
  late TabController _tabController;

  static const List<Map<String, String>> _languages = [
    {'name': 'Hindi', 'code': 'hi'},
    {'name': 'Spanish', 'code': 'es'},
    {'name': 'French', 'code': 'fr'},
    {'name': 'German', 'code': 'de'},
    {'name': 'Italian', 'code': 'it'},
    {'name': 'Japanese', 'code': 'ja'},
    {'name': 'Korean', 'code': 'ko'},
    {'name': 'Chinese', 'code': 'zh'},
    {'name': 'Russian', 'code': 'ru'},
    {'name': 'Arabic', 'code': 'ar'},
  ];

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReadingSettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSettings != oldWidget.initialSettings) {
      _settings = widget.initialSettings;
    }
  }

  void _updateSettings(ReaderSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    widget.onSettingsChanged?.call(newSettings);
    ref.read(readerNotifierProvider.notifier).updateSettings(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(text: 'Appearance'),
                Tab(text: 'Content'),
                Tab(text: 'Translation'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAppearanceTab(),
                  _buildContentTab(),
                  _buildTranslationTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildThemeSection(),
          const SizedBox(height: 24),
          _buildFontFamilySection(),
          const SizedBox(height: 24),
          _buildFontSizeSection(),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _resetToDefaults,
            child: const Text('Reset to Defaults'),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLineHeightSection(),
          const SizedBox(height: 24),
          _buildMarginSection(),
          const SizedBox(height: 24),
          _buildTogglesSection(),
        ],
      ),
    );
  }

  Widget _buildTranslationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Translation Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildToggleTile(
            title: 'Enable Translation',
            subtitle: 'Translate chapter content automatically',
            value: _settings.translationEnabled,
            onChanged: (value) =>
                _updateSettings(_settings.copyWith(translationEnabled: value)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Target Language',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _languages.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final lang = _languages[index];
                final isSelected = _settings.targetLanguage == lang['code'];
                return ListTile(
                  title: Text(lang['name']!),
                  trailing: isSelected
                      ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                      : null,
                  onTap: () => _updateSettings(
                    _settings.copyWith(targetLanguage: lang['code']!),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Font Size',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${_settings.fontSize.round()}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Decrease button
            _buildCircleButton(
              icon: Icons.text_decrease,
              onPressed: _settings.fontSize > AppConstants.minFontSize
                  ? () => _updateSettings(
                      _settings.copyWith(
                        fontSize:
                            _settings.fontSize - AppConstants.fontSizeStep,
                      ),
                    )
                  : null,
            ),

            // Slider
            Expanded(
              child: Slider(
                value: _settings.fontSize,
                min: AppConstants.minFontSize,
                max: AppConstants.maxFontSize,
                divisions:
                    ((AppConstants.maxFontSize - AppConstants.minFontSize) /
                            AppConstants.fontSizeStep)
                        .round(),
                onChanged: (value) =>
                    _updateSettings(_settings.copyWith(fontSize: value)),
              ),
            ),

            // Increase button
            _buildCircleButton(
              icon: Icons.text_increase,
              onPressed: _settings.fontSize < AppConstants.maxFontSize
                  ? () => _updateSettings(
                      _settings.copyWith(
                        fontSize:
                            _settings.fontSize + AppConstants.fontSizeStep,
                      ),
                    )
                  : null,
            ),
          ],
        ),

        // Preview
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'The quick brown fox jumps over the lazy dog.',
            style: TextStyle(fontSize: _settings.fontSize),
          ),
        ),
      ],
    );
  }

  Widget _buildLineHeightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Line Height',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              _settings.lineHeight.toStringAsFixed(1),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _settings.lineHeight,
          min: AppConstants.minLineHeight,
          max: AppConstants.maxLineHeight,
          divisions:
              ((AppConstants.maxLineHeight - AppConstants.minLineHeight) / 0.1)
                  .round(),
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(lineHeight: value)),
        ),
      ],
    );
  }

  Widget _buildThemeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            // Light theme
            Expanded(
              child: _ThemeButton(
                label: 'Light',
                backgroundColor: AppConstants.lightBackground,
                textColor: AppConstants.lightTextColor,
                isSelected: _settings.theme == ReadingTheme.light,
                onTap: () => _updateSettings(
                  _settings.copyWith(theme: ReadingTheme.light),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Sepia theme
            Expanded(
              child: _ThemeButton(
                label: 'Sepia',
                backgroundColor: AppConstants.sepiaBackground,
                textColor: AppConstants.sepiaTextColor,
                isSelected: _settings.theme == ReadingTheme.sepia,
                onTap: () => _updateSettings(
                  _settings.copyWith(theme: ReadingTheme.sepia),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Dark theme
            Expanded(
              child: _ThemeButton(
                label: 'Dark',
                backgroundColor: AppConstants.darkBackground,
                textColor: AppConstants.darkTextColor,
                isSelected: _settings.theme == ReadingTheme.dark,
                onTap: () => _updateSettings(
                  _settings.copyWith(theme: ReadingTheme.dark),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFontFamilySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Font', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReaderFont.values.map((font) {
            final isSelected = _settings.fontFamily == font;
            return ChoiceChip(
              label: Text(font.displayName),
              selected: isSelected,
              onSelected: (_) =>
                  _updateSettings(_settings.copyWith(fontFamily: font)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMarginSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Margins',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${_settings.margin.round()}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _settings.margin,
          min: 8,
          max: 48,
          divisions: 10,
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(margin: value)),
        ),
      ],
    );
  }

  Widget _buildTogglesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Options', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),

        _buildToggleTile(
          title: 'Keep Screen On',
          subtitle: 'Prevent screen from turning off while reading',
          value: _settings.keepScreenOn,
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(keepScreenOn: value)),
        ),

        _buildToggleTile(
          title: 'Show Progress Bar',
          subtitle: 'Display reading progress at the bottom',
          value: _settings.showProgressBar,
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(showProgressBar: value)),
        ),

        _buildToggleTile(
          title: 'Tap Navigation',
          subtitle: 'Tap left/right edges to change pages',
          value: _settings.enableTapNavigation,
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(enableTapNavigation: value)),
        ),

        _buildToggleTile(
          title: 'Swipe Navigation',
          subtitle: 'Swipe to change chapters',
          value: _settings.enableSwipeNavigation,
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(enableSwipeNavigation: value)),
        ),

        _buildToggleTile(
          title: 'Auto-save Progress',
          subtitle: 'Automatically save reading position',
          value: _settings.autoSaveProgress,
          onChanged: (value) =>
              _updateSettings(_settings.copyWith(autoSaveProgress: value)),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: onPressed != null ? Colors.grey[200] : Colors.grey[100],
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: onPressed != null ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }

  void _resetToDefaults() {
    _updateSettings(const ReaderSettings());
  }
}

class _ThemeButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ThemeButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              'Aa',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: textColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Quick settings toolbar (appears in reader)
class QuickSettingsToolbar extends ConsumerWidget {
  final VoidCallback? onMoreSettings;

  const QuickSettingsToolbar({super.key, this.onMoreSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Decrease font size
            _QuickButton(
              icon: Icons.text_decrease,
              label: 'A-',
              onTap: settings.fontSize > AppConstants.minFontSize
                  ? () => ref
                        .read(readerNotifierProvider.notifier)
                        .decreaseFontSize()
                  : null,
            ),

            // Increase font size
            _QuickButton(
              icon: Icons.text_increase,
              label: 'A+',
              onTap: settings.fontSize < AppConstants.maxFontSize
                  ? () => ref
                        .read(readerNotifierProvider.notifier)
                        .increaseFontSize()
                  : null,
            ),

            // Theme toggle
            _QuickButton(
              icon: _getThemeIcon(settings.theme),
              label: settings.theme.name.capitalize(),
              onTap: () => _cycleTheme(ref, settings.theme),
            ),

            // More settings
            _QuickButton(
              icon: Icons.settings,
              label: 'More',
              onTap: onMoreSettings,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getThemeIcon(ReadingTheme theme) {
    switch (theme) {
      case ReadingTheme.light:
        return Icons.light_mode;
      case ReadingTheme.dark:
        return Icons.dark_mode;
      case ReadingTheme.sepia:
        return Icons.wb_sunny;
    }
  }

  void _cycleTheme(WidgetRef ref, ReadingTheme currentTheme) {
    final themes = ReadingTheme.values;
    final currentIndex = themes.indexOf(currentTheme);
    final nextIndex = (currentIndex + 1) % themes.length;
    ref.read(readerNotifierProvider.notifier).setTheme(themes[nextIndex]);
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: onTap != null ? null : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: onTap != null ? null : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Brightness slider widget
class BrightnessSlider extends ConsumerWidget {
  const BrightnessSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);

    return Row(
      children: [
        const Icon(Icons.brightness_low, size: 20),
        Expanded(
          child: Slider(
            value: settings.brightness,
            min: 0.1,
            max: 1.0,
            onChanged: (value) {
              ref
                  .read(readerNotifierProvider.notifier)
                  .updateSettings(settings.copyWith(brightness: value));
            },
          ),
        ),
        const Icon(Icons.brightness_high, size: 20),
      ],
    );
  }
}

/// Reading progress indicator
class ReadingProgressIndicator extends StatelessWidget {
  final double progress;
  final String? chapterTitle;
  final int currentChapter;
  final int totalChapters;
  final Color? color;
  final double height;

  const ReadingProgressIndicator({
    super.key,
    required this.progress,
    this.chapterTitle,
    required this.currentChapter,
    required this.totalChapters,
    this.color,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation(
              color ?? Theme.of(context).primaryColor,
            ),
            minHeight: height,
          ),
        ),
        const SizedBox(height: 4),

        // Progress text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            Text(
              'Chapter ${currentChapter + 1} of $totalChapters',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }
}

/// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

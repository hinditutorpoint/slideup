import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';

// ═══════════════════════════════════════════════════════
// ✅ VIDEO EFFECT MODEL
// ═══════════════════════════════════════════════════════

class VideoEffect {
  final String id;
  final String name;
  final String category;
  final IconData icon;
  final Color color;
  final ColorGradeSettings settings;
  final String? iconEmoji;

  const VideoEffect({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.color,
    required this.settings,
    this.iconEmoji,
  });

  static const List<VideoEffect> filters = [
    VideoEffect(
      id: 'vintage',
      name: 'Vintage',
      category: 'Mood',
      icon: Icons.photo_camera,
      color: Color(0xFFD4A574),
      iconEmoji: '📷',
      settings: ColorGradeSettings(
        saturation: 0.7,
        contrast: 0.9,
        temperature: 20,
        shadows: 0.1,
      ),
    ),
    VideoEffect(
      id: 'noir',
      name: 'Noir',
      category: 'Mood',
      icon: Icons.movie_filter,
      color: Color(0xFF4A4A4A),
      iconEmoji: '🎬',
      settings: ColorGradeSettings(
        saturation: 0.0,
        contrast: 1.3,
        blacks: -0.1,
      ),
    ),
    VideoEffect(
      id: 'summer',
      name: 'Summer',
      category: 'Season',
      icon: Icons.wb_sunny,
      color: Color(0xFFFFB347),
      iconEmoji: '☀️',
      settings: ColorGradeSettings(
        saturation: 1.2,
        temperature: 25,
        vibrance: 0.2,
      ),
    ),
    VideoEffect(
      id: 'winter',
      name: 'Winter',
      category: 'Season',
      icon: Icons.ac_unit,
      color: Color(0xFF87CEEB),
      iconEmoji: '❄️',
      settings: ColorGradeSettings(
        saturation: 0.85,
        temperature: -30,
        brightness: 0.05,
      ),
    ),
    VideoEffect(
      id: 'cinematic',
      name: 'Cinematic',
      category: 'Film',
      icon: Icons.movie,
      color: Color(0xFFE67E22),
      iconEmoji: '🎥',
      settings: ColorGradeSettings(
        contrast: 1.15,
        saturation: 0.9,
        temperature: 10,
        blacks: 0.1,
        shadows: -0.1,
      ),
    ),
    VideoEffect(
      id: 'teal_orange',
      name: 'Teal & Orange',
      category: 'Film',
      icon: Icons.gradient,
      color: Color(0xFF008080),
      iconEmoji: '🎞️',
      settings: ColorGradeSettings(temperature: 15, tint: -10, saturation: 1.1),
    ),
    VideoEffect(
      id: 'moody',
      name: 'Moody',
      category: 'Mood',
      icon: Icons.cloud,
      color: Color(0xFF6B5B95),
      iconEmoji: '🌧️',
      settings: ColorGradeSettings(
        brightness: -0.1,
        contrast: 1.1,
        saturation: 0.8,
        shadows: 0.15,
      ),
    ),
    VideoEffect(
      id: 'bright',
      name: 'Bright',
      category: 'Light',
      icon: Icons.brightness_high,
      color: Color(0xFFF7DC6F),
      iconEmoji: '✨',
      settings: ColorGradeSettings(
        brightness: 0.15,
        contrast: 1.05,
        vibrance: 0.1,
      ),
    ),
    VideoEffect(
      id: 'fade',
      name: 'Fade',
      category: 'Mood',
      icon: Icons.blur_on,
      color: Color(0xFFAEB6BF),
      iconEmoji: '🌫️',
      settings: ColorGradeSettings(
        contrast: 0.85,
        blacks: 0.2,
        saturation: 0.9,
      ),
    ),
    VideoEffect(
      id: 'dramatic',
      name: 'Dramatic',
      category: 'Mood',
      icon: Icons.flash_on,
      color: Color(0xFFE74C3C),
      iconEmoji: '⚡',
      settings: ColorGradeSettings(
        contrast: 1.3,
        saturation: 1.1,
        shadows: -0.15,
        highlights: -0.1,
      ),
    ),
    VideoEffect(
      id: 'matte',
      name: 'Matte',
      category: 'Film',
      icon: Icons.photo_filter,
      color: Color(0xFF95A5A6),
      iconEmoji: '🎨',
      settings: ColorGradeSettings(
        blacks: 0.15,
        contrast: 0.9,
        saturation: 0.85,
      ),
    ),
    VideoEffect(
      id: 'neon',
      name: 'Neon',
      category: 'Creative',
      icon: Icons.lightbulb,
      color: Color(0xFFFF00FF),
      iconEmoji: '💡',
      settings: ColorGradeSettings(
        saturation: 1.4,
        vibrance: 0.3,
        contrast: 1.1,
      ),
    ),
  ];

  static List<String> get categories {
    return filters.map((f) => f.category).toSet().toList();
  }
}

// ═══════════════════════════════════════════════════════
// ✅ EFFECTS SHEET
// ═══════════════════════════════════════════════════════

class EffectsSheet extends ConsumerStatefulWidget {
  const EffectsSheet({super.key});

  @override
  ConsumerState<EffectsSheet> createState() => _EffectsSheetState();
}

class _EffectsSheetState extends ConsumerState<EffectsSheet> {
  String _selectedCategory = 'All';
  VideoEffect? _selectedEffect;
  double _effectIntensity = 1.0;
  bool _showComparison = false;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(currentProjectProvider);
    final currentSettings = ref.watch(previewColorGradeProvider);

    if (project == null) {
      return _buildNoVideoState();
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          _buildHandleBar(),

          // Preview
          _buildPreviewSection(currentSettings),

          // Header
          _buildHeader(),

          // Category chips
          _buildCategoryChips(),

          // Effects grid
          Expanded(child: _buildEffectsGrid()),

          // Intensity slider (when effect selected)
          if (_selectedEffect != null) _buildIntensitySection(),

          // Action buttons
          _buildActionButtons(project.colorGrade),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PREVIEW
  // ═══════════════════════════════════════════════════════

  Widget _buildPreviewSection(ColorGradeSettings currentSettings) {
    final thumbnails = ref.watch(thumbnailsProvider);

    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _showComparison = !_showComparison);
          HapticFeedback.lightImpact();
        },
        onLongPressStart: (_) => setState(() => _showComparison = true),
        onLongPressEnd: (_) => setState(() => _showComparison = false),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnails.isNotEmpty)
                _showComparison
                    ? _buildSplitComparison(thumbnails.first, currentSettings)
                    : _buildEffectPreview(thumbnails.first, currentSettings)
              else
                _buildPlaceholder(),

              // Effect name overlay
              if (_selectedEffect != null && !_showComparison)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedEffect!.color.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedEffect!.iconEmoji ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedEffect!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Comparison hint
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showComparison ? Icons.compare : Icons.touch_app,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showComparison ? 'Comparing' : 'Hold to compare',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEffectPreview(Uint8List thumbnail, ColorGradeSettings settings) {
    Widget image = Image.memory(
      thumbnail,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );

    if (!settings.isDefault) {
      image = ColorFiltered(
        colorFilter: ColorFilter.matrix(settings.toColorMatrix()),
        child: image,
      );
    }

    return image;
  }

  Widget _buildSplitComparison(
    Uint8List thumbnail,
    ColorGradeSettings settings,
  ) {
    return Stack(
      children: [
        // Split view
        Row(
          children: [
            Expanded(
              child: ClipRect(
                child: Image.memory(
                  thumbnail,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            Expanded(
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(settings.toColorMatrix()),
                child: Image.memory(
                  thumbnail,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ],
        ),

        // Divider
        Center(
          child: Container(
            width: 3,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),

        // Labels
        Positioned(top: 12, left: 12, child: _buildLabel('Original')),
        Positioned(top: 12, right: 12, child: _buildLabel('Effect')),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 48,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 8),
          Text(
            'No preview available',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HEADER & CATEGORIES
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_fix_high,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Effects & Filters',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_selectedEffect != null)
            TextButton(
              onPressed: () {
                setState(() => _selectedEffect = null);
                ref
                    .read(videoEditorProvider.notifier)
                    .setPreviewColorGrade(const ColorGradeSettings());
                HapticFeedback.selectionClick();
              },
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.orange),
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

  Widget _buildCategoryChips() {
    final categories = ['All', ...VideoEffect.categories];

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = category);
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Center(
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EFFECTS GRID
  // ═══════════════════════════════════════════════════════

  Widget _buildEffectsGrid() {
    final filteredEffects = _selectedCategory == 'All'
        ? VideoEffect.filters
        : VideoEffect.filters
              .where((e) => e.category == _selectedCategory)
              .toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: filteredEffects.length + 1, // +1 for "None" option
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildNoneCard();
        }
        final effect = filteredEffects[index - 1];
        return _buildEffectCard(effect);
      },
    );
  }

  Widget _buildNoneCard() {
    final isSelected = _selectedEffect == null;
    final thumbnails = ref.watch(thumbnailsProvider);

    return GestureDetector(
      onTap: () {
        setState(() => _selectedEffect = null);
        ref
            .read(videoEditorProvider.notifier)
            .setPreviewColorGrade(const ColorGradeSettings());
        HapticFeedback.selectionClick();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.green
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: thumbnails.isNotEmpty
                    ? Image.memory(thumbnails.first, fit: BoxFit.cover)
                    : const Center(
                        child: Icon(
                          Icons.block,
                          color: Colors.white24,
                          size: 32,
                        ),
                      ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: isSelected
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              child: Text(
                'None',
                style: TextStyle(
                  color: isSelected ? Colors.green : Colors.white70,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectCard(VideoEffect effect) {
    final isSelected = _selectedEffect?.id == effect.id;
    final thumbnails = ref.watch(thumbnailsProvider);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedEffect = effect;
          _effectIntensity = 1.0;
        });

        // Apply effect preview
        ref
            .read(videoEditorProvider.notifier)
            .setPreviewColorGrade(effect.settings);
        HapticFeedback.selectionClick();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? effect.color
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: effect.color.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnails.isNotEmpty)
                      ColorFiltered(
                        colorFilter: ColorFilter.matrix(
                          effect.settings.toColorMatrix(),
                        ),
                        child: Image.memory(
                          thumbnails.first,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Center(
                        child: Text(
                          effect.iconEmoji ?? '',
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),

                    // Selected check
                    if (isSelected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: effect.color,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? effect.color.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
              ),
              child: Text(
                effect.name,
                style: TextStyle(
                  color: isSelected ? effect.color : Colors.white70,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ INTENSITY SLIDER
  // ═══════════════════════════════════════════════════════

  Widget _buildIntensitySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _selectedEffect!.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedEffect!.color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    _selectedEffect!.iconEmoji ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedEffect!.name} Intensity',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _selectedEffect!.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(_effectIntensity * 100).toInt()}%',
                  style: TextStyle(
                    color: _selectedEffect!.color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              activeTrackColor: _selectedEffect!.color,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayColor: _selectedEffect!.color.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _effectIntensity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() => _effectIntensity = value);

                // Apply interpolated effect
                final baseSettings = _selectedEffect!.settings;
                final interpolatedSettings = _interpolateSettings(
                  const ColorGradeSettings(),
                  baseSettings,
                  value,
                );
                ref
                    .read(videoEditorProvider.notifier)
                    .setPreviewColorGrade(interpolatedSettings);
              },
              onChangeEnd: (_) => HapticFeedback.lightImpact(),
            ),
          ),
        ],
      ),
    );
  }

  ColorGradeSettings _interpolateSettings(
    ColorGradeSettings from,
    ColorGradeSettings to,
    double t,
  ) {
    return ColorGradeSettings(
      brightness: _lerp(from.brightness, to.brightness, t),
      contrast: _lerp(from.contrast, to.contrast, t),
      saturation: _lerp(from.saturation, to.saturation, t),
      hue: _lerp(from.hue, to.hue, t),
      temperature: _lerp(from.temperature, to.temperature, t),
      tint: _lerp(from.tint, to.tint, t),
      vibrance: _lerp(from.vibrance, to.vibrance, t),
      highlights: _lerp(from.highlights, to.highlights, t),
      shadows: _lerp(from.shadows, to.shadows, t),
      whites: _lerp(from.whites, to.whites, t),
      blacks: _lerp(from.blacks, to.blacks, t),
      red: _lerp(from.red, to.red, t),
      green: _lerp(from.green, to.green, t),
      blue: _lerp(from.blue, to.blue, t),
    );
  }

  double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTION BUTTONS
  // ═══════════════════════════════════════════════════════

  Widget _buildActionButtons(ColorGradeSettings savedSettings) {
    final currentSettings = ref.watch(previewColorGradeProvider);
    final hasChanges = currentSettings != savedSettings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectedEffect == null
                    ? null
                    : () {
                        setState(() => _selectedEffect = null);
                        ref
                            .read(videoEditorProvider.notifier)
                            .setPreviewColorGrade(const ColorGradeSettings());
                        HapticFeedback.mediumImpact();
                      },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: hasChanges
                    ? () {
                        ref
                            .read(videoEditorProvider.notifier)
                            .applyColorGrade();
                        Navigator.pop(context);
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _selectedEffect != null
                                  ? '${_selectedEffect!.name} effect applied'
                                  : 'Effect applied',
                            ),
                            backgroundColor: const Color(0xFF4CAF50),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Apply Effect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoVideoState() {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Text(
              'No video loaded',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

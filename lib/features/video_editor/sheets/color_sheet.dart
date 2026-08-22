import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';
import '../../../widgets/color_wheel_widget.dart';

// ═══════════════════════════════════════════════════════
// ✅ COLOR SHEET (YouCut Style with Preview)
// ═══════════════════════════════════════════════════════

class ColorSheet extends ConsumerStatefulWidget {
  const ColorSheet({super.key});

  @override
  ConsumerState<ColorSheet> createState() => _ColorSheetState();
}

class _ColorSheetState extends ConsumerState<ColorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showComparison = false;
  double _filterIntensity = 1.0;
  ColorGradeSettings? _activePresetSettings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(previewColorGradeProvider);
    final project = ref.watch(currentProjectProvider);

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
          // Handle bar
          _buildHandleBar(),

          // Preview section
          _buildPreviewSection(settings, project),

          // Header with tabs
          _buildHeader(settings),

          // Tab bar
          _buildTabBar(),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPresetsTab(settings),
                _buildLightTab(settings),
                _buildColorTab(settings),
                _buildAdvancedTab(settings),
              ],
            ),
          ),

          // Action buttons
          _buildActionButtons(settings, project.colorGrade),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PREVIEW SECTION
  // ═══════════════════════════════════════════════════════

  Widget _buildPreviewSection(
    ColorGradeSettings settings,
    VideoProject project,
  ) {
    final thumbnails = ref.watch(thumbnailsProvider);

    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Before/After preview
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _showComparison = !_showComparison);
                HapticFeedback.lightImpact();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Preview image
                    if (thumbnails.isNotEmpty)
                      _showComparison
                          ? _buildComparisonView(thumbnails.first, settings)
                          : _buildFilteredPreview(thumbnails.first, settings)
                    else
                      const Center(
                        child: Icon(
                          Icons.movie_outlined,
                          color: Colors.white24,
                          size: 40,
                        ),
                      ),

                    // Comparison toggle indicator
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showComparison
                                  ? Icons.compare
                                  : Icons.visibility,
                              size: 12,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showComparison ? 'Comparing' : 'Tap to compare',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Modified indicator
                    if (!settings.isDefault)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Modified',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Quick stats
          _buildQuickStats(settings),
        ],
      ),
    );
  }

  Widget _buildFilteredPreview(
    Uint8List thumbnail,
    ColorGradeSettings settings,
  ) {
    Widget imageWidget = Image.memory(
      thumbnail,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );

    if (!settings.isDefault) {
      imageWidget = ColorFiltered(
        colorFilter: ColorFilter.matrix(settings.toColorMatrix()),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildComparisonView(
    Uint8List thumbnail,
    ColorGradeSettings settings,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Original (left side)
            Positioned.fill(
              child: Row(
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
            ),

            // Divider line
            Center(
              child: Container(
                width: 2,
                height: double.infinity,
                color: Colors.white,
              ),
            ),

            // Labels
            Positioned(
              bottom: 8,
              left: 8,
              child: _buildComparisonLabel('Before'),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: _buildComparisonLabel('After'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComparisonLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQuickStats(ColorGradeSettings settings) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Brightness', settings.brightness, Colors.yellow),
          _buildStatItem('Contrast', settings.contrast - 1, Colors.orange),
          _buildStatItem('Saturation', settings.saturation - 1, Colors.pink),
          _buildStatItem(
            'Temperature',
            settings.temperature / 100,
            Colors.cyan,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, double value, Color color) {
    final isNeutral = value.abs() < 0.01;
    final displayValue = value > 0
        ? '+${(value * 100).toInt()}'
        : '${(value * 100).toInt()}';

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isNeutral ? Colors.grey : color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 9,
            ),
          ),
        ),
        Text(
          isNeutral ? '0' : displayValue,
          style: TextStyle(
            color: isNeutral ? Colors.white38 : color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HEADER & TABS
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

  Widget _buildHeader(ColorGradeSettings settings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.palette, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Color Grading',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!settings.isDefault)
            TextButton.icon(
              onPressed: () {
                ref
                    .read(videoEditorProvider.notifier)
                    .setPreviewColorGrade(const ColorGradeSettings());
                HapticFeedback.selectionClick();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 12),
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

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Presets'),
          Tab(text: 'Light'),
          Tab(text: 'Color'),
          Tab(text: 'Advanced'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PRESETS TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildPresetsTab(ColorGradeSettings settings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: ColorPreset.defaultPresets.length,
            itemBuilder: (context, index) {
              final preset = ColorPreset.defaultPresets[index];
              final isSelected = _isPresetSelected(settings, preset);

              return _buildPresetCard(preset, isSelected);
            },
          ),

          const SizedBox(height: 24),

          // Intensity slider when preset is selected
          if (!settings.isDefault) ...[
            const Text(
              'Intensity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildIntensitySlider(settings),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetCard(ColorPreset preset, bool isSelected) {
    final thumbnails = ref.watch(thumbnailsProvider);

    return GestureDetector(
      onTap: () {
        setState(() {
          _activePresetSettings = preset.settings;
          _filterIntensity = 1.0;
        });
        ref
            .read(videoEditorProvider.notifier)
            .setPreviewColorGrade(preset.settings);
        HapticFeedback.selectionClick();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF6B6B)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Preview thumbnail
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: thumbnails.isNotEmpty
                    ? ColorFiltered(
                        colorFilter: ColorFilter.matrix(
                          preset.settings.toColorMatrix(),
                        ),
                        child: Image.memory(
                          thumbnails.first,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          preset.iconEmoji ?? '🎨',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
              ),
            ),

            // Label
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: isSelected
                  ? const Color(0xFFFF6B6B).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              child: Text(
                preset.name,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFF6B6B) : Colors.white70,
                  fontSize: 10,
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

  Widget _buildIntensitySlider(ColorGradeSettings settings) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                'Effect Strength',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(_filterIntensity * 100).round()}%',
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 12,
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
              activeTrackColor: const Color(0xFFFF6B6B),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _filterIntensity,
              onChanged: (value) {
                setState(() => _filterIntensity = value);
                final base = _activePresetSettings ?? settings;
                final scaled = _scaleColorSettings(base, value);
                _updateSettings(scaled);
              },
            ),
          ),
        ],
      ),
    );
  }

  ColorGradeSettings _scaleColorSettings(
    ColorGradeSettings base,
    double factor,
  ) {
    return base.copyWith(
      brightness: base.brightness * factor,
      contrast: 1.0 + (base.contrast - 1.0) * factor,
      saturation: 1.0 + (base.saturation - 1.0) * factor,
      hue: base.hue * factor,
      red: 1.0 + (base.red - 1.0) * factor,
      green: 1.0 + (base.green - 1.0) * factor,
      blue: 1.0 + (base.blue - 1.0) * factor,
      temperature: base.temperature * factor,
      tint: base.tint * factor,
      vibrance: base.vibrance * factor,
      highlights: base.highlights * factor,
      shadows: base.shadows * factor,
      whites: base.whites * factor,
      blacks: base.blacks * factor,
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ LIGHT TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildLightTab(ColorGradeSettings settings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSliderCard(
            'Brightness',
            Icons.brightness_6,
            settings.brightness,
            -1,
            1,
            0,
            Colors.yellow,
            (v) => _updateSettings(settings.copyWith(brightness: v)),
          ),
          _buildSliderCard(
            'Contrast',
            Icons.contrast,
            settings.contrast,
            0.5,
            2,
            1,
            Colors.orange,
            (v) => _updateSettings(settings.copyWith(contrast: v)),
          ),
          _buildSliderCard(
            'Highlights',
            Icons.wb_sunny,
            settings.highlights,
            -1,
            1,
            0,
            Colors.amber,
            (v) => _updateSettings(settings.copyWith(highlights: v)),
          ),
          _buildSliderCard(
            'Shadows',
            Icons.nights_stay,
            settings.shadows,
            -1,
            1,
            0,
            Colors.indigo,
            (v) => _updateSettings(settings.copyWith(shadows: v)),
          ),
          _buildSliderCard(
            'Whites',
            Icons.wb_iridescent,
            settings.whites,
            -1,
            1,
            0,
            Colors.white70,
            (v) => _updateSettings(settings.copyWith(whites: v)),
          ),
          _buildSliderCard(
            'Blacks',
            Icons.dark_mode,
            settings.blacks,
            -1,
            1,
            0,
            Colors.blueGrey,
            (v) => _updateSettings(settings.copyWith(blacks: v)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ COLOR TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildColorTab(ColorGradeSettings settings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Color Wheel Grading',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: ColorWheelWidget(
              initialColor: Color.fromRGBO(
                (settings.red * 127.5).clamp(0, 255).toInt(),
                (settings.green * 127.5).clamp(0, 255).toInt(),
                (settings.blue * 127.5).clamp(0, 255).toInt(),
                1.0,
              ),
              wheelSize: 220,
              onColorChanged: (color) {
                final newRed = (color.r * 2.0).clamp(0.0, 2.0);
                final newGreen = (color.g * 2.0).clamp(0.0, 2.0);
                final newBlue = (color.b * 2.0).clamp(0.0, 2.0);
                _updateSettings(
                  settings.copyWith(
                    red: newRed,
                    green: newGreen,
                    blue: newBlue,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildSliderCard(
            'Saturation',
            Icons.water_drop,
            settings.saturation,
            0,
            2,
            1,
            Colors.pink,
            (v) => _updateSettings(settings.copyWith(saturation: v)),
          ),
          _buildSliderCard(
            'Vibrance',
            Icons.auto_awesome,
            settings.vibrance,
            -1,
            1,
            0,
            Colors.purple,
            (v) => _updateSettings(settings.copyWith(vibrance: v)),
          ),
          _buildSliderCard(
            'Temperature',
            Icons.thermostat,
            settings.temperature,
            -100,
            100,
            0,
            Colors.cyan,
            (v) => _updateSettings(settings.copyWith(temperature: v)),
          ),
          _buildSliderCard(
            'Tint',
            Icons.colorize,
            settings.tint,
            -100,
            100,
            0,
            Colors.green,
            (v) => _updateSettings(settings.copyWith(tint: v)),
          ),
          _buildSliderCard(
            'Hue',
            Icons.palette,
            settings.hue,
            -180,
            180,
            0,
            Colors.deepPurple,
            (v) => _updateSettings(settings.copyWith(hue: v)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ADVANCED TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildAdvancedTab(ColorGradeSettings settings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RGB Channels',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildSliderCard(
            'Red',
            Icons.circle,
            settings.red,
            0,
            2,
            1,
            Colors.red,
            (v) => _updateSettings(settings.copyWith(red: v)),
          ),
          _buildSliderCard(
            'Green',
            Icons.circle,
            settings.green,
            0,
            2,
            1,
            Colors.green,
            (v) => _updateSettings(settings.copyWith(green: v)),
          ),
          _buildSliderCard(
            'Blue',
            Icons.circle,
            settings.blue,
            0,
            2,
            1,
            Colors.blue,
            (v) => _updateSettings(settings.copyWith(blue: v)),
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════
          // ✅ CHROMA KEY (GREEN SCREEN)
          // ═══════════════════════════════════════════════════
          const Text(
            'Chroma Key',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: settings.chromaKeyEnabled
                  ? const Color(0xFF00E676).withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: settings.chromaKeyEnabled
                    ? const Color(0xFF00E676).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.videocam,
                      size: 18,
                      color: settings.chromaKeyEnabled
                          ? const Color(0xFF00E676)
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Remove background color',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    Switch(
                      value: settings.chromaKeyEnabled,
                      activeTrackColor: const Color(0xFF00E676),
                      onChanged: (v) => _updateSettings(
                        settings.copyWith(chromaKeyEnabled: v),
                      ),
                    ),
                  ],
                ),
                if (settings.chromaKeyEnabled) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Pick a color to remove',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildChromaColorDot(
                        settings,
                        0xFF00FF00,
                        Colors.green,
                      ),
                      _buildChromaColorDot(settings, 0xFF0000FF, Colors.blue),
                      _buildChromaColorDot(
                        settings,
                        0xFFFF0000,
                        Colors.red,
                      ),
                      _buildChromaColorDot(
                        settings,
                        0xFF800080,
                        Colors.purple,
                      ),
                      _buildChromaColorDot(
                        settings,
                        0xFFFFA500,
                        Colors.orange,
                      ),
                      _buildChromaColorDot(
                        settings,
                        0xFFFF69B4,
                        Colors.pink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSliderCard(
                    'Similarity',
                    Icons.tune,
                    settings.chromaKeySimilarity,
                    0.0,
                    1.0,
                    0.2,
                    const Color(0xFF00E676),
                    (v) => _updateSettings(
                      settings.copyWith(chromaKeySimilarity: v),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════════════════
          // ✅ COLOR WHEEL (real, drives RGB channels)
          // ═══════════════════════════════════════════════════
          const Text(
            'Color Wheel',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: ColorWheelWidget(
              initialColor: Color.fromRGBO(
                (settings.red * 127.5).clamp(0, 255).toInt(),
                (settings.green * 127.5).clamp(0, 255).toInt(),
                (settings.blue * 127.5).clamp(0, 255).toInt(),
                1.0,
              ),
              wheelSize: 200,
              onColorChanged: (color) {
                final newRed = (color.r * 2.0).clamp(0.0, 2.0);
                final newGreen = (color.g * 2.0).clamp(0.0, 2.0);
                final newBlue = (color.b * 2.0).clamp(0.0, 2.0);
                _updateSettings(
                  settings.copyWith(
                    red: newRed,
                    green: newGreen,
                    blue: newBlue,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SLIDER CARD
  // ═══════════════════════════════════════════════════════

  Widget _buildChromaColorDot(
    ColorGradeSettings settings,
    int colorValue,
    Color color,
  ) {
    final isSelected = settings.chromaKeyColor == colorValue;
    return GestureDetector(
      onTap: () => _updateSettings(settings.copyWith(chromaKeyColor: colorValue)),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildSliderCard(
    String label,
    IconData icon,
    double value,
    double min,
    double max,
    double defaultValue,
    Color color,
    Function(double) onChanged,
  ) {
    final isDefault = (value - defaultValue).abs() < 0.01;
    final displayValue = _formatValue(value, defaultValue, min, max);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDefault
            ? Colors.white.withValues(alpha: 0.03)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault
              ? Colors.white.withValues(alpha: 0.05)
              : color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDefault ? 0.1 : 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isDefault ? Colors.white38 : color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDefault ? Colors.white54 : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDefault
                      ? Colors.white.withValues(alpha: 0.05)
                      : color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: isDefault ? Colors.white38 : color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isDefault) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    onChanged(defaultValue);
                    HapticFeedback.selectionClick();
                  },
                  child: Icon(
                    Icons.refresh,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: color,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayColor: color.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: (_) => HapticFeedback.lightImpact(),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTION BUTTONS
  // ═══════════════════════════════════════════════════════

  Widget _buildActionButtons(
    ColorGradeSettings previewSettings,
    ColorGradeSettings savedSettings,
  ) {
    final hasChanges = previewSettings != savedSettings;

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
            // Reset button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: previewSettings.isDefault
                    ? null
                    : () {
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

            // Apply button
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
                          const SnackBar(
                            content: Text('Color grading applied'),
                            backgroundColor: Color(0xFF4CAF50),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Apply Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
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

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

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

  void _updateSettings(ColorGradeSettings settings) {
    ref.read(videoEditorProvider.notifier).setPreviewColorGrade(settings);
  }

  bool _isPresetSelected(ColorGradeSettings settings, ColorPreset preset) {
    final p = preset.settings;
    return settings.brightness == p.brightness &&
        settings.contrast == p.contrast &&
        settings.saturation == p.saturation &&
        settings.temperature == p.temperature;
  }

  String _formatValue(
    double value,
    double defaultValue,
    double min,
    double max,
  ) {
    if (defaultValue == 0) {
      if (min == -180 && max == 180) {
        return '${value.toInt()}°';
      }
      final percent = (value * 100).toInt();
      if (percent > 0) return '+$percent';
      return '$percent';
    } else if (defaultValue == 1) {
      final percent = ((value - 1) * 100).round();
      if (percent > 0) return '+$percent%';
      if (percent < 0) return '$percent%';
      return '0%';
    }
    return value.toStringAsFixed(1);
  }
}

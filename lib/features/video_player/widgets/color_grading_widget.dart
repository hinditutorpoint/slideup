import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/video_edit_provider.dart';

class ColorGradingWidget extends ConsumerStatefulWidget {
  final Uint8List? previewImage;
  final Function(ColorGradeSettings settings)? onSettingsChanged;

  const ColorGradingWidget({
    super.key,
    this.previewImage,
    this.onSettingsChanged,
  });

  @override
  ConsumerState<ColorGradingWidget> createState() => _ColorGradingWidgetState();
}

class _ColorGradingWidgetState extends ConsumerState<ColorGradingWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showPresets = true;

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
    final editState = ref.watch(videoEditProvider);
    final colorGrade = editState.colorGrade;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Color Grading',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Reset button
                  TextButton(onPressed: _resetAll, child: const Text('Reset')),
                  // Apply button
                  ElevatedButton(
                    onPressed: () => _applySettings(colorGrade),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),

            // Preview toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ToggleButton(
                  label: 'Presets',
                  isSelected: _showPresets,
                  onTap: () => setState(() => _showPresets = true),
                ),
                const SizedBox(width: 8),
                _ToggleButton(
                  label: 'Manual',
                  isSelected: !_showPresets,
                  onTap: () => setState(() => _showPresets = false),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Content
            SizedBox(
              height: 300,
              child: _showPresets
                  ? _buildPresetsView()
                  : _buildManualView(colorGrade),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsView() {
    final presetsAsync = ref.watch(colorPresetsProvider);

    return presetsAsync.when(
      data: (presets) => GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: presets.length,
        itemBuilder: (context, index) {
          final preset = presets[index];
          return _PresetItem(
            preset: preset,
            previewImage: widget.previewImage,
            onTap: () => _applyPreset(preset),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Text(
          'Failed to load presets',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildManualView(ColorGradeSettings settings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Light'),
              Tab(text: 'Color'),
              Tab(text: 'Effects'),
            ],
            indicatorColor: Colors.red,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
          ),

          const SizedBox(height: 16),

          // Tab content
          SizedBox(
            height: 200,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Light tab
                _buildLightControls(settings),
                // Color tab
                _buildColorControls(settings),
                // Effects tab
                _buildEffectsControls(settings),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightControls(ColorGradeSettings settings) {
    return Column(
      children: [
        _SliderControl(
          label: 'Brightness',
          value: settings.brightness,
          min: -1.0,
          max: 1.0,
          onChanged: (v) =>
              ref.read(videoEditProvider.notifier).updateBrightness(v),
        ),
        _SliderControl(
          label: 'Contrast',
          value: settings.contrast,
          min: 0.0,
          max: 2.0,
          onChanged: (v) =>
              ref.read(videoEditProvider.notifier).updateContrast(v),
        ),
        _SliderControl(
          label: 'Highlights',
          value: settings.highlights,
          min: -1.0,
          max: 1.0,
          onChanged: (v) => _updateSetting((s) => s.copyWith(highlights: v)),
        ),
        _SliderControl(
          label: 'Shadows',
          value: settings.shadows,
          min: -1.0,
          max: 1.0,
          onChanged: (v) => _updateSetting((s) => s.copyWith(shadows: v)),
        ),
      ],
    );
  }

  Widget _buildColorControls(ColorGradeSettings settings) {
    return Column(
      children: [
        _SliderControl(
          label: 'Saturation',
          value: settings.saturation,
          min: 0.0,
          max: 2.0,
          onChanged: (v) =>
              ref.read(videoEditProvider.notifier).updateSaturation(v),
        ),
        _SliderControl(
          label: 'Hue',
          value: settings.hue,
          min: -180.0,
          max: 180.0,
          onChanged: (v) => ref.read(videoEditProvider.notifier).updateHue(v),
        ),
        _SliderControl(
          label: 'Temperature',
          value: settings.temperature,
          min: -100.0,
          max: 100.0,
          activeColor: Colors.orange,
          onChanged: (v) =>
              ref.read(videoEditProvider.notifier).updateTemperature(v),
        ),
        _SliderControl(
          label: 'Tint',
          value: settings.tint,
          min: -100.0,
          max: 100.0,
          activeColor: Colors.green,
          onChanged: (v) => _updateSetting((s) => s.copyWith(tint: v)),
        ),
      ],
    );
  }

  Widget _buildEffectsControls(ColorGradeSettings settings) {
    return Column(
      children: [
        _SliderControl(
          label: 'Red',
          value: settings.red,
          min: 0.0,
          max: 2.0,
          activeColor: Colors.red,
          onChanged: (v) => ref.read(videoEditProvider.notifier).updateRed(v),
        ),
        _SliderControl(
          label: 'Green',
          value: settings.green,
          min: 0.0,
          max: 2.0,
          activeColor: Colors.green,
          onChanged: (v) => ref.read(videoEditProvider.notifier).updateGreen(v),
        ),
        _SliderControl(
          label: 'Blue',
          value: settings.blue,
          min: 0.0,
          max: 2.0,
          activeColor: Colors.blue,
          onChanged: (v) => ref.read(videoEditProvider.notifier).updateBlue(v),
        ),
        _SliderControl(
          label: 'Vibrance',
          value: settings.vibrance,
          min: -1.0,
          max: 1.0,
          onChanged: (v) => _updateSetting((s) => s.copyWith(vibrance: v)),
        ),
      ],
    );
  }

  void _updateSetting(ColorGradeSettings Function(ColorGradeSettings) updater) {
    try {
      final current = ref.read(videoEditProvider).colorGrade;
      final updated = updater(current);
      ref.read(videoEditProvider.notifier).updateColorGrade(updated);
    } catch (e) {
      debugPrint('⚠️ Update setting error: $e');
    }
  }

  void _applyPreset(ColorPreset preset) {
    try {
      ref.read(videoEditProvider.notifier).applyPreset(preset);
      widget.onSettingsChanged?.call(preset.settings);
    } catch (e) {
      debugPrint('⚠️ Apply preset error: $e');
    }
  }

  void _resetAll() {
    try {
      ref.read(videoEditProvider.notifier).resetColorGrade();
    } catch (e) {
      debugPrint('⚠️ Reset error: $e');
    }
  }

  void _applySettings(ColorGradeSettings settings) {
    widget.onSettingsChanged?.call(settings);
    Navigator.pop(context);
  }
}

// ═══════════════════════════════════════════════════════
// ✅ HELPER WIDGETS
// ═══════════════════════════════════════════════════════

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : Colors.white12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _PresetItem extends StatelessWidget {
  final ColorPreset preset;
  final Uint8List? previewImage;
  final VoidCallback onTap;

  const _PresetItem({
    required this.preset,
    this.previewImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: previewImage != null
                    ? ColorFiltered(
                        colorFilter: _buildColorFilter(preset.settings),
                        child: Image.memory(
                          previewImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        ),
                      )
                    : _buildPlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            preset.name,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: _getPresetColor(preset.settings),
      child: const Icon(Icons.palette, color: Colors.white38),
    );
  }

  Color _getPresetColor(ColorGradeSettings settings) {
    // Generate a representative color based on settings
    final hue = (settings.hue + 180) / 360;
    final saturation = settings.saturation.clamp(0.3, 1.0);
    final brightness = (settings.brightness + 1) / 2 * 0.5 + 0.25;

    return HSVColor.fromAHSV(1.0, hue * 360, saturation, brightness).toColor();
  }

  ColorFilter _buildColorFilter(ColorGradeSettings settings) {
    // Simplified color filter - in production use shader or native
    final matrix = <double>[
      settings.red * settings.contrast,
      0,
      0,
      0,
      settings.brightness * 255 * 0.5,
      0,
      settings.green * settings.contrast,
      0,
      0,
      settings.brightness * 255 * 0.5,
      0,
      0,
      settings.blue * settings.contrast,
      0,
      settings.brightness * 255 * 0.5,
      0,
      0,
      0,
      1,
      0,
    ];

    return ColorFilter.matrix(matrix);
  }
}

class _SliderControl extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Color? activeColor;
  final ValueChanged<double> onChanged;

  const _SliderControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value.toStringAsFixed(1);
    final isDefault = (value - _getDefaultValue()).abs() < 0.01;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: isDefault ? Colors.white54 : Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: activeColor ?? Colors.red,
                inactiveTrackColor: Colors.white24,
                thumbColor: activeColor ?? Colors.red,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              displayValue,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  double _getDefaultValue() {
    if (label == 'Contrast' ||
        label == 'Saturation' ||
        label == 'Red' ||
        label == 'Green' ||
        label == 'Blue') {
      return 1.0;
    }
    return 0.0;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';

// ═══════════════════════════════════════════════════════
// ✅ COLOR TAB - Provider-Based (No Required Props!)
// ═══════════════════════════════════════════════════════

class ColorTab extends ConsumerWidget {
  const ColorTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get color grade settings from provider
    final settings = ref.watch(previewColorGradeProvider);
    final project = ref.watch(currentProjectProvider);

    // Handle null project
    if (project == null) {
      return const Center(
        child: Text('No video loaded', style: TextStyle(color: Colors.white54)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 350;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Presets
              _buildPresetsSection(ref, settings, isCompact),
              SizedBox(height: isCompact ? 16 : 20),

              // Sliders
              _buildSlidersSection(ref, settings, isCompact),

              // Apply & Reset buttons
              SizedBox(height: isCompact ? 16 : 20),
              _buildActionButtons(ref, settings, project.colorGrade, isCompact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetsSection(
    WidgetRef ref,
    ColorGradeSettings settings,
    bool isCompact,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Presets',
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 13 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!settings.isDefault)
              TextButton(
                onPressed: () {
                  ref
                      .read(videoEditorProvider.notifier)
                      .setPreviewColorGrade(const ColorGradeSettings());
                  HapticFeedback.selectionClick();
                },
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: isCompact ? 11 : 12,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: isCompact ? 8 : 12),
        SizedBox(
          height: isCompact ? 60 : 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: ColorPreset.defaultPresets.length,
            itemBuilder: (context, index) {
              final preset = ColorPreset.defaultPresets[index];
              final isSelected = _isPresetSelected(settings, preset);

              return GestureDetector(
                onTap: () {
                  ref
                      .read(videoEditorProvider.notifier)
                      .setPreviewColorGrade(preset.settings);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  width: isCompact ? 56 : 64,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Preview color box
                      Container(
                        width: isCompact ? 28 : 32,
                        height: isCompact ? 28 : 32,
                        decoration: BoxDecoration(
                          color: _getPresetColor(preset.settings),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: preset.iconEmoji != null
                            ? Center(
                                child: Text(
                                  preset.iconEmoji!,
                                  style: TextStyle(
                                    fontSize: isCompact ? 14 : 16,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.name,
                        style: TextStyle(
                          color: isSelected ? Colors.blue : Colors.white70,
                          fontSize: isCompact ? 9 : 10,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSlidersSection(
    WidgetRef ref,
    ColorGradeSettings settings,
    bool isCompact,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Light section
        _buildSectionTitle('Light', isCompact),
        _buildSlider(
          ref: ref,
          label: 'Brightness',
          value: settings.brightness,
          min: -1,
          max: 1,
          settings: settings,
          onChanged: (v) =>
              _updateSettings(ref, settings.copyWith(brightness: v)),
          isCompact: isCompact,
        ),
        _buildSlider(
          ref: ref,
          label: 'Contrast',
          value: settings.contrast,
          min: 0.5,
          max: 2,
          defaultValue: 1,
          settings: settings,
          onChanged: (v) =>
              _updateSettings(ref, settings.copyWith(contrast: v)),
          isCompact: isCompact,
        ),
        _buildSlider(
          ref: ref,
          label: 'Highlights',
          value: settings.highlights,
          min: -1,
          max: 1,
          settings: settings,
          onChanged: (v) =>
              _updateSettings(ref, settings.copyWith(highlights: v)),
          isCompact: isCompact,
        ),
        _buildSlider(
          ref: ref,
          label: 'Shadows',
          value: settings.shadows,
          min: -1,
          max: 1,
          settings: settings,
          onChanged: (v) => _updateSettings(ref, settings.copyWith(shadows: v)),
          isCompact: isCompact,
        ),

        SizedBox(height: isCompact ? 12 : 16),

        // Color section
        _buildSectionTitle('Color', isCompact),
        _buildSlider(
          ref: ref,
          label: 'Saturation',
          value: settings.saturation,
          min: 0,
          max: 2,
          defaultValue: 1,
          settings: settings,
          onChanged: (v) =>
              _updateSettings(ref, settings.copyWith(saturation: v)),
          isCompact: isCompact,
        ),
        _buildSlider(
          ref: ref,
          label: 'Temperature',
          value: settings.temperature,
          min: -100,
          max: 100,
          settings: settings,
          activeColor: Colors.orange,
          onChanged: (v) =>
              _updateSettings(ref, settings.copyWith(temperature: v)),
          isCompact: isCompact,
        ),
        _buildSlider(
          ref: ref,
          label: 'Vibrance',
          value: settings.vibrance,
          min: -1,
          max: 1,
          settings: settings,
          onChanged: (v) =>
              _updateSettings(ref, settings.copyWith(vibrance: v)),
          isCompact: isCompact,
        ),
        _buildSlider(
          ref: ref,
          label: 'Hue',
          value: settings.hue,
          min: -180,
          max: 180,
          settings: settings,
          activeColor: Colors.purple,
          onChanged: (v) => _updateSettings(ref, settings.copyWith(hue: v)),
          isCompact: isCompact,
        ),

        SizedBox(height: isCompact ? 12 : 16),

        // RGB section
        _buildSectionTitle('RGB Channels', isCompact),
        _buildSlider(
          ref: ref,
          label: 'Red',
          value: settings.red,
          min: 0,
          max: 2,
          defaultValue: 1,
          settings: settings,
          activeColor: Colors.red,
          onChanged: (v) => _updateSettings(ref, settings.copyWith(red: v)),
          isCompact: isCompact,
        ),
        _buildSlider(
          ref: ref,
          label: 'Green',
          value: settings.green,
          min: 0,
          max: 2,
          defaultValue: 1,
          settings: settings,
          activeColor: Colors.green,
          onChanged: (v) => _updateSettings(ref, settings.copyWith(green: v)),
          isCompact: isCompact,
        ),
        _buildSlider(
          ref: ref,
          label: 'Blue',
          value: settings.blue,
          min: 0,
          max: 2,
          defaultValue: 1,
          settings: settings,
          activeColor: Colors.blue,
          onChanged: (v) => _updateSettings(ref, settings.copyWith(blue: v)),
          isCompact: isCompact,
        ),

        SizedBox(height: isCompact ? 12 : 16),

        // Tone section
        _buildSectionTitle('Tone', isCompact),
        _buildSlider(
          ref: ref,
          label: 'Whites',
          value: settings.whites,
          min: -1,
          max: 1,
          settings: settings,
          onChanged: (v) => _updateSettings(ref, settings.copyWith(whites: v)),
          isCompact: isCompact,
        ),
        _buildSlider(
          ref: ref,
          label: 'Blacks',
          value: settings.blacks,
          min: -1,
          max: 1,
          settings: settings,
          onChanged: (v) => _updateSettings(ref, settings.copyWith(blacks: v)),
          isCompact: isCompact,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 6 : 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: isCompact ? 12 : 14,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required WidgetRef ref,
    required String label,
    required double value,
    required double min,
    required double max,
    required ColorGradeSettings settings,
    required Function(double) onChanged,
    required bool isCompact,
    double defaultValue = 0,
    Color? activeColor,
  }) {
    final isDefault = (value - defaultValue).abs() < 0.01;
    final displayValue = _formatSliderValue(value, defaultValue);

    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 6 : 10),
      child: Row(
        children: [
          // Label
          SizedBox(
            width: isCompact ? 70 : 80,
            child: Text(
              label,
              style: TextStyle(
                color: isDefault
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white,
                fontSize: isCompact ? 11 : 12,
              ),
            ),
          ),

          // Slider
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: isCompact ? 2 : 3,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: isCompact ? 5 : 6,
                ),
                overlayShape: RoundSliderOverlayShape(
                  overlayRadius: isCompact ? 10 : 12,
                ),
                activeTrackColor: activeColor ?? Colors.blue,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                thumbColor: activeColor ?? Colors.blue,
                overlayColor: (activeColor ?? Colors.blue).withValues(
                  alpha: 0.1,
                ),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),

          // Value display
          SizedBox(
            width: isCompact ? 36 : 42,
            child: Text(
              displayValue,
              style: TextStyle(
                color: isDefault
                    ? Colors.white.withValues(alpha: 0.4)
                    : activeColor ?? Colors.blue,
                fontSize: isCompact ? 10 : 11,
                fontWeight: isDefault ? FontWeight.normal : FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // Reset button for individual slider
          if (!isDefault) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                onChanged(defaultValue);
                HapticFeedback.selectionClick();
              },
              child: Icon(
                Icons.refresh,
                size: isCompact ? 14 : 16,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ] else ...[
            SizedBox(width: isCompact ? 18 : 20),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    WidgetRef ref,
    ColorGradeSettings previewSettings,
    ColorGradeSettings savedSettings,
    bool isCompact,
  ) {
    final hasChanges = previewSettings != savedSettings;
    final isDefault = previewSettings.isDefault;

    return Row(
      children: [
        // Reset button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isDefault
                ? null
                : () {
                    ref
                        .read(videoEditorProvider.notifier)
                        .setPreviewColorGrade(const ColorGradeSettings());
                    HapticFeedback.mediumImpact();
                  },
            icon: Icon(Icons.refresh, size: isCompact ? 16 : 18),
            label: Text(
              'Reset',
              style: TextStyle(fontSize: isCompact ? 12 : 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDefault ? Colors.grey : Colors.white70,
              side: BorderSide(
                color: isDefault
                    ? Colors.grey.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.3),
              ),
              padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 12),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Apply button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: hasChanges
                ? () {
                    ref.read(videoEditorProvider.notifier).applyColorGrade();
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(ref.context).showSnackBar(
                      const SnackBar(
                        content: Text('Color grading applied'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                : null,
            icon: Icon(Icons.check, size: isCompact ? 16 : 18),
            label: Text(
              'Apply',
              style: TextStyle(fontSize: isCompact ? 12 : 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasChanges ? Colors.blue : Colors.grey,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 12),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  void _updateSettings(WidgetRef ref, ColorGradeSettings newSettings) {
    ref.read(videoEditorProvider.notifier).setPreviewColorGrade(newSettings);
  }

  bool _isPresetSelected(ColorGradeSettings settings, ColorPreset preset) {
    final p = preset.settings;
    return settings.brightness == p.brightness &&
        settings.contrast == p.contrast &&
        settings.saturation == p.saturation &&
        settings.hue == p.hue &&
        settings.temperature == p.temperature;
  }

  Color _getPresetColor(ColorGradeSettings s) {
    // Generate a representative color for the preset
    final hue = (s.hue + 180) / 360;
    final sat = s.saturation.clamp(0.3, 1.0);
    final val = (s.brightness + 1) / 2 * 0.5 + 0.25;
    return HSVColor.fromAHSV(1, hue * 360, sat, val.clamp(0.2, 0.8)).toColor();
  }

  String _formatSliderValue(double value, double defaultValue) {
    if (defaultValue == 0) {
      if (value > 0) return '+${value.toStringAsFixed(1)}';
      return value.toStringAsFixed(1);
    } else if (defaultValue == 1) {
      // Show as percentage difference
      final percent = ((value - 1) * 100).round();
      if (percent > 0) return '+$percent%';
      if (percent < 0) return '$percent%';
      return '0%';
    }
    return value.toStringAsFixed(1);
  }
}

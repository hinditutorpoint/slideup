import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/video_edit_settings.dart';

class ColorTab extends StatelessWidget {
  final ColorGradeSettings settings;
  final Function(ColorGradeSettings) onSettingsChanged;

  const ColorTab({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 350;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Presets
              _buildPresetsSection(isCompact),
              SizedBox(height: isCompact ? 16 : 20),

              // Sliders
              _buildSlidersSection(isCompact),

              // Reset
              SizedBox(height: isCompact ? 12 : 16),
              Center(
                child: TextButton.icon(
                  onPressed: settings.isDefault
                      ? null
                      : () {
                          onSettingsChanged(const ColorGradeSettings());
                          HapticFeedback.mediumImpact();
                        },
                  icon: Icon(
                    Icons.refresh,
                    size: isCompact ? 16 : 18,
                    color: settings.isDefault
                        ? Colors.grey[700]
                        : Colors.white70,
                  ),
                  label: Text(
                    'Reset All',
                    style: TextStyle(
                      color: settings.isDefault
                          ? Colors.grey[700]
                          : Colors.white70,
                      fontSize: isCompact ? 12 : 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetsSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Presets',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),
        SizedBox(
          height: isCompact ? 60 : 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: ColorPreset.defaultPresets.length,
            itemBuilder: (context, index) {
              final preset = ColorPreset.defaultPresets[index];
              final isSelected = _isPresetSelected(preset);

              return GestureDetector(
                onTap: () {
                  onSettingsChanged(preset.settings);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  width: isCompact ? 56 : 64,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.red : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isCompact ? 28 : 32,
                        height: isCompact ? 28 : 32,
                        decoration: BoxDecoration(
                          color: _getPresetColor(preset.settings),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.name,
                        style: TextStyle(
                          color: isSelected ? Colors.red : Colors.white,
                          fontSize: isCompact ? 9 : 10,
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

  Widget _buildSlidersSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Light
        _buildSectionTitle('Light', isCompact),
        _buildSlider('Brightness', settings.brightness, -1, 1, (v) {
          onSettingsChanged(settings.copyWith(brightness: v));
        }, isCompact),
        _buildSlider(
          'Contrast',
          settings.contrast,
          0.5,
          2,
          (v) {
            onSettingsChanged(settings.copyWith(contrast: v));
          },
          isCompact,
          defaultValue: 1,
        ),
        _buildSlider('Highlights', settings.highlights, -1, 1, (v) {
          onSettingsChanged(settings.copyWith(highlights: v));
        }, isCompact),
        _buildSlider('Shadows', settings.shadows, -1, 1, (v) {
          onSettingsChanged(settings.copyWith(shadows: v));
        }, isCompact),

        SizedBox(height: isCompact ? 12 : 16),

        // Color
        _buildSectionTitle('Color', isCompact),
        _buildSlider(
          'Saturation',
          settings.saturation,
          0,
          2,
          (v) {
            onSettingsChanged(settings.copyWith(saturation: v));
          },
          isCompact,
          defaultValue: 1,
        ),
        _buildSlider(
          'Temperature',
          settings.temperature,
          -100,
          100,
          (v) {
            onSettingsChanged(settings.copyWith(temperature: v));
          },
          isCompact,
          activeColor: Colors.orange,
        ),
        _buildSlider('Hue', settings.hue, -180, 180, (v) {
          onSettingsChanged(settings.copyWith(hue: v));
        }, isCompact),

        SizedBox(height: isCompact ? 12 : 16),

        // RGB
        _buildSectionTitle('RGB', isCompact),
        _buildSlider(
          'Red',
          settings.red,
          0,
          2,
          (v) {
            onSettingsChanged(settings.copyWith(red: v));
          },
          isCompact,
          defaultValue: 1,
          activeColor: Colors.red,
        ),
        _buildSlider(
          'Green',
          settings.green,
          0,
          2,
          (v) {
            onSettingsChanged(settings.copyWith(green: v));
          },
          isCompact,
          defaultValue: 1,
          activeColor: Colors.green,
        ),
        _buildSlider(
          'Blue',
          settings.blue,
          0,
          2,
          (v) {
            onSettingsChanged(settings.copyWith(blue: v));
          },
          isCompact,
          defaultValue: 1,
          activeColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 6 : 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: isCompact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    bool isCompact, {
    double defaultValue = 0,
    Color? activeColor,
  }) {
    final isDefault = (value - defaultValue).abs() < 0.01;

    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 6 : 10),
      child: Row(
        children: [
          SizedBox(
            width: isCompact ? 70 : 80,
            child: Text(
              label,
              style: TextStyle(
                color: isDefault ? Colors.grey[500] : Colors.white,
                fontSize: isCompact ? 11 : 12,
              ),
            ),
          ),
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
            width: isCompact ? 32 : 38,
            child: Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: isCompact ? 10 : 11,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  bool _isPresetSelected(ColorPreset preset) {
    final s = settings;
    final p = preset.settings;
    return s.brightness == p.brightness &&
        s.contrast == p.contrast &&
        s.saturation == p.saturation &&
        s.hue == p.hue;
  }

  Color _getPresetColor(ColorGradeSettings s) {
    final hue = (s.hue + 180) / 360;
    final sat = s.saturation.clamp(0.3, 1.0);
    final val = (s.brightness + 1) / 2 * 0.5 + 0.25;
    return HSVColor.fromAHSV(1, hue * 360, sat, val).toColor();
  }
}

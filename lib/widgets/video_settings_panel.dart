import 'package:flutter/material.dart';
import '../models/video_settings.dart';

class VideoSettingsPanel extends StatefulWidget {
  final VideoSettings settings;
  final Function(VideoSettings) onSettingsChanged;

  const VideoSettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<VideoSettingsPanel> createState() => _VideoSettingsPanelState();
}

class _VideoSettingsPanelState extends State<VideoSettingsPanel> {
  late VideoSettings _currentSettings;

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Video Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _resetSettings,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),

          const Divider(),

          // Settings content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Brightness
                _buildSliderSetting(
                  'Brightness',
                  Icons.brightness_6,
                  _currentSettings.brightness,
                  -1.0,
                  1.0,
                  (value) => _updateSettings(
                    _currentSettings.copyWith(brightness: value),
                  ),
                ),

                // Contrast
                _buildSliderSetting(
                  'Contrast',
                  Icons.contrast,
                  _currentSettings.contrast,
                  -1.0,
                  1.0,
                  (value) => _updateSettings(
                    _currentSettings.copyWith(contrast: value),
                  ),
                ),

                // Saturation
                _buildSliderSetting(
                  'Saturation',
                  Icons.palette,
                  _currentSettings.saturation,
                  -1.0,
                  1.0,
                  (value) => _updateSettings(
                    _currentSettings.copyWith(saturation: value),
                  ),
                ),

                // Hue
                _buildSliderSetting(
                  'Hue',
                  Icons.color_lens,
                  _currentSettings.hue,
                  -180,
                  180,
                  (value) =>
                      _updateSettings(_currentSettings.copyWith(hue: value)),
                ),

                const Divider(height: 32),

                // Hardware Decoder
                _buildSwitchSetting(
                  'Hardware Decoder',
                  Icons.memory,
                  _currentSettings.hardwareDecoder,
                  (value) => _updateSettings(
                    _currentSettings.copyWith(hardwareDecoder: value),
                  ),
                ),

                // PiP Mode
                _buildSwitchSetting(
                  'Picture-in-Picture',
                  Icons.picture_in_picture,
                  _currentSettings.pipEnabled,
                  (value) => _updateSettings(
                    _currentSettings.copyWith(pipEnabled: value),
                  ),
                ),

                // Playback Speed
                _buildSpeedSelector(),

                const Divider(height: 32),

                // Subtitle Settings
                _buildSwitchSetting(
                  'Subtitles',
                  Icons.subtitles,
                  _currentSettings.subtitlesEnabled,
                  (value) => _updateSettings(
                    _currentSettings.copyWith(subtitlesEnabled: value),
                  ),
                ),

                if (_currentSettings.subtitlesEnabled) ...[
                  _buildSliderSetting(
                    'Subtitle Size',
                    Icons.text_fields,
                    _currentSettings.subtitleSize,
                    12,
                    32,
                    (value) => _updateSettings(
                      _currentSettings.copyWith(subtitleSize: value),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Apply button
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting(
    String label,
    IconData icon,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSwitchSetting(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildSpeedSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, size: 20),
              const SizedBox(width: 12),
              const Text('Playback Speed', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: PlaybackSpeed.values.map((speed) {
              final isSelected = _currentSettings.speed == speed;
              return ChoiceChip(
                label: Text(speed.label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    _updateSettings(_currentSettings.copyWith(speed: speed));
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _updateSettings(VideoSettings newSettings) {
    setState(() => _currentSettings = newSettings);
    widget.onSettingsChanged(newSettings);
  }

  void _resetSettings() {
    _updateSettings(const VideoSettings());
  }
}

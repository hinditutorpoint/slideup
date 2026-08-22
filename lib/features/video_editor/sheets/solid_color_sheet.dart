import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class SolidColorSheet extends ConsumerStatefulWidget {
  const SolidColorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SolidColorSheet(),
    );
  }

  @override
  ConsumerState<SolidColorSheet> createState() => _SolidColorSheetState();
}

class _SolidColorSheetState extends ConsumerState<SolidColorSheet> {
  Color _selectedColor = Colors.black;
  double _opacity = 1.0;
  double _durationSec = 5.0;

  static const _presetColors = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
    Color(0xFF0F3460),
    Color(0xFF533483),
    Color(0xFFE94560),
    Color(0xFF2C3E50),
    Color(0xFF3498DB),
    Color(0xFF2ECC71),
    Color(0xFFF39C12),
    Color(0xFF8E44AD),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildColorPresets(),
                  const SizedBox(height: 16),
                  _buildCustomColorRow(),
                  const SizedBox(height: 16),
                  _buildOpacitySlider(),
                  const SizedBox(height: 12),
                  _buildDurationSlider(),
                  const SizedBox(height: 16),
                  _buildPreview(),
                  const SizedBox(height: 16),
                  _buildAddButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        const Icon(Icons.color_lens, color: Colors.purpleAccent, size: 20),
        const SizedBox(width: 8),
        const Text(
          'Blank / Solid Color Layer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );

  Widget _buildColorPresets() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Preset Colors',
        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _presetColors.map((color) {
          final isSelected = _selectedColor.toARGB32() == color.toARGB32();
          return GestureDetector(
            onTap: () => setState(() => _selectedColor = color),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.grey[700]!,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          );
        }).toList(),
      ),
    ],
  );

  Widget _buildCustomColorRow() => Row(
    children: [
      const Text(
        'Custom Color',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const Spacer(),
      GestureDetector(
        onTap: _pickCustomColor,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _selectedColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[600]!),
            gradient: _selectedColor == Colors.transparent
                ? const LinearGradient(
                    colors: [Colors.white, Colors.grey],
                    stops: [0.5, 0.5],
                  )
                : null,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '#${_selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
        style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'monospace'),
      ),
    ],
  );

  Widget _buildOpacitySlider() => _buildSlider(
    label: 'Opacity',
    value: _opacity,
    min: 0,
    max: 1,
    display: '${(_opacity * 100).round()}%',
    onChanged: (v) => setState(() => _opacity = v),
  );

  Widget _buildDurationSlider() => _buildSlider(
    label: 'Duration',
    value: _durationSec,
    min: 1,
    max: 60,
    display: '${_durationSec.round()}s',
    onChanged: (v) => setState(() => _durationSec = v),
  );

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Spacer(),
            Text(display, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _selectedColor,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
            inactiveTrackColor: Colors.grey[700],
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Preview',
        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Opacity(
            opacity: _opacity,
            child: Container(
              color: _selectedColor,
              child: Center(
                child: Text(
                  'SOLID COLOR',
                  style: TextStyle(
                    color: _selectedColor.computeLuminance() > 0.5
                        ? Colors.black54
                        : Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildAddButton() => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: _addLayer,
      icon: const Icon(Icons.add, size: 18),
      label: const Text(
        'Add to Timeline',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedColor.computeLuminance() > 0.5
            ? Colors.grey[800]
            : _selectedColor,
        foregroundColor: _selectedColor.computeLuminance() > 0.5
            ? Colors.white
            : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  Future<void> _pickCustomColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (_) => _ColorPickerDialog(initialColor: _selectedColor),
    );
    if (color != null) {
      setState(() => _selectedColor = color);
    }
  }

  void _addLayer() {
    final duration = Duration(milliseconds: (_durationSec * 1000).round());
    ref.read(timelineProvider.notifier).addSolidColorItem(
      colorValue: _selectedColor.toARGB32(),
      duration: duration,
      opacity: _opacity,
    );
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Solid color layer added (${_durationSec.round()}s)'),
        backgroundColor: _selectedColor.computeLuminance() > 0.5 ? Colors.grey[800] : _selectedColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const _ColorPickerDialog({required this.initialColor});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(
      text: widget.initialColor.toARGB32().toRadixString(16).substring(2).toUpperCase(),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: const Text('Pick Color', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!),
            ),
          ),
          const SizedBox(height: 16),
          _buildSlider('H', _hsv.hue, 0, 360, (v) {
            setState(() => _hsv = _hsv.withHue(v));
          }),
          _buildSlider('S', _hsv.saturation, 0, 1, (v) {
            setState(() => _hsv = _hsv.withSaturation(v));
          }),
          _buildSlider('V', _hsv.value, 0, 1, (v) {
            setState(() => _hsv = _hsv.withValue(v));
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('#', style: TextStyle(color: Colors.grey, fontSize: 14)),
              Expanded(
                child: TextField(
                  controller: _hexController,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'RRGGBB',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (hex) {
                    if (hex.length == 6) {
                      final val = int.parse(hex, radix: 16) | 0xFF000000;
                      setState(() => _hsv = HSVColor.fromColor(Color(val)));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, color),
          style: ElevatedButton.styleFrom(backgroundColor: color),
          child: const Text('Select'),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _hsv.toColor(),
              thumbColor: Colors.white,
              inactiveTrackColor: Colors.grey[700],
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value == min || value == max
                ? value.round().toString()
                : value.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

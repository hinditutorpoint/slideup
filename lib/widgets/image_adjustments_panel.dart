import 'package:flutter/material.dart';
import 'dart:io';
import '../models/media_file.dart';
import '../helpers/image_helper.dart';

class ImageAdjustmentsPanel extends StatefulWidget {
  final MediaFile image;
  final Function(String) onSave;

  const ImageAdjustmentsPanel({
    super.key,
    required this.image,
    required this.onSave,
  });

  @override
  State<ImageAdjustmentsPanel> createState() => _ImageAdjustmentsPanelState();
}

class _ImageAdjustmentsPanelState extends State<ImageAdjustmentsPanel> {
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
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
          const Text(
            'Adjust Image',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Preview
          Expanded(
            child: Center(
              child: ColorFiltered(
                colorFilter: ImageHelper.getColorFilter(
                  brightness: _brightness,
                  contrast: _contrast,
                  saturation: _saturation,
                ),
                child: Image.file(
                  File(widget.image.path),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildSlider(
                  'Brightness',
                  Icons.brightness_6,
                  _brightness,
                  (value) => setState(() => _brightness = value),
                ),
                const SizedBox(height: 16),
                _buildSlider(
                  'Contrast',
                  Icons.contrast,
                  _contrast,
                  (value) => setState(() => _contrast = value),
                ),
                const SizedBox(height: 16),
                _buildSlider(
                  'Saturation',
                  Icons.palette,
                  _saturation,
                  (value) => setState(() => _saturation = value),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _brightness = 0;
                            _contrast = 0;
                            _saturation = 0;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveAdjustedImage,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    IconData icon,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label),
            const Spacer(),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
        Slider(
          value: value,
          min: -1.0,
          max: 1.0,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _saveAdjustedImage() async {
    setState(() => _isSaving = true);

    try {
      final adjustedPath = await ImageHelper.applyImageAdjustments(
        imagePath: widget.image.path,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
      );

      if (adjustedPath != null) {
        widget.onSave(adjustedPath);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to save adjusted image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
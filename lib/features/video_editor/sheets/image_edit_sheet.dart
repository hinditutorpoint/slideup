import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'package:slideup/core/utils/safe_async.dart';

class ImageEditSheet extends ConsumerStatefulWidget {
  final String inputPath;
  final String imageName;
  final void Function(String outputPath) onResult;

  const ImageEditSheet({
    super.key,
    required this.inputPath,
    required this.imageName,
    required this.onResult,
  });

  @override
  ConsumerState<ImageEditSheet> createState() => _ImageEditSheetState();
}

class _ImageEditSheetState extends ConsumerState<ImageEditSheet> {
  bool _isProcessing = false;
  double _progress = 0.0;
  String _progressLabel = '';

  ImageShape _selectedShape = ImageShape.circle;
  int _shapeColor = 0xFFFF0000;
  double _shapeSize = 0.4;
  bool _shapeFilled = true;

  static const _shapeColors = <int, String>{
    0xFFFF0000: 'Red',
    0xFF00FF00: 'Green',
    0xFF0000FF: 'Blue',
    0xFFFFFF00: 'Yellow',
    0xFFFF00FF: 'Magenta',
    0xFF00FFFF: 'Cyan',
    0xFFFFFFFF: 'White',
    0xFF000000: 'Black',
  };

  Future<void> _run(Future<Result<String>> Function() action) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });
    HapticFeedback.mediumImpact();

    try {
      final result = await action();
      if (result.isSuccess && mounted) {
        final output = result.requireData;
        _showSnack('Image edited successfully');
        Navigator.pop(context);
        widget.onResult(output);
      } else if (mounted) {
        final err = result.error;
        final message = err is ImageEditError ? err.message : '$err';
        _showSnack('Edit failed: $message');
      }
    } catch (e) {
      if (mounted) _showSnack('Edit failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _progress = 0.0;
          _progressLabel = '';
        });
      }
    }
  }

  void _onProgress(double p) {
    if (mounted) setState(() => _progress = p);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.startsWith('Edit failed')
            ? Colors.red
            : const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.imageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isProcessing)
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: _progress.clamp(0.0, 1.0),
                          color: const Color(0xFF4CAF50),
                          backgroundColor: Colors.white10,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _progressLabel.isEmpty
                              ? 'Processing ${(_progress * 100).toInt()}%'
                              : _progressLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  _buildToolCard(
                    'Remove Background',
                    'Remove solid-color background from the image',
                    Icons.auto_fix_high,
                    const Color(0xFF4CAF50),
                    onTap: () {
                      setState(() => _progressLabel = 'Removing background...');
                      _run(() => ref
                          .read(imageEditServiceProvider)
                          .removeBackground(
                            inputPath: widget.inputPath,
                            tolerance: 30,
                            onProgress: _onProgress,
                          ));
                    },
                  ),
                  _buildToolCard(
                    'Auto Enhance',
                    'Improve color and contrast automatically',
                    Icons.auto_awesome,
                    const Color(0xFF2196F3),
                    onTap: () {
                      setState(() => _progressLabel = 'Enhancing image...');
                      _run(() => ref
                          .read(imageEditServiceProvider)
                          .autoEnhance(
                            inputPath: widget.inputPath,
                            onProgress: _onProgress,
                          ));
                    },
                  ),
                  _buildToolCard(
                    'Add Shape',
                    'Overlay a rectangle, circle or other shape',
                    Icons.crop_square,
                    const Color(0xFFFF9800),
                    onTap: () {
                      setState(() => _progressLabel = 'Adding shape...');
                      _run(() => ref
                          .read(imageEditServiceProvider)
                          .addShape(
                            inputPath: widget.inputPath,
                            config: ShapeConfig(
                              shape: _selectedShape,
                              color: _shapeColor,
                              x: 0.5,
                              y: 0.5,
                              width: _shapeSize,
                              height: _shapeSize,
                              filled: _shapeFilled,
                            ),
                            onProgress: _onProgress,
                          ));
                    },
                  ),
                  _buildShapeControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    String title,
    String description,
    IconData icon,
    Color color, {
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isProcessing ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShapeControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shape Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ImageShape.values.map((shape) {
              final isSelected = _selectedShape == shape;
              return ChoiceChip(
                label: Text(shape.name.toUpperCase()),
                selected: isSelected,
                onSelected: _isProcessing
                    ? null
                    : (v) => setState(() => _selectedShape = shape),
                labelStyle: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
                selectedColor: const Color(0xFFFF9800),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Color',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _shapeColors.entries.map((entry) {
              final isSelected = _shapeColor == entry.key;
              return GestureDetector(
                onTap: _isProcessing
                    ? null
                    : () => setState(() => _shapeColor = entry.key),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(entry.key),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Size',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: _shapeSize,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  activeColor: const Color(0xFFFF9800),
                  onChanged: _isProcessing
                      ? null
                      : (v) => setState(() => _shapeSize = v),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${(_shapeSize * 100).toInt()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'Filled',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Switch(
                value: _shapeFilled,
                activeTrackColor: const Color(0xFFFF9800),
                onChanged: _isProcessing
                    ? null
                    : (v) => setState(() => _shapeFilled = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

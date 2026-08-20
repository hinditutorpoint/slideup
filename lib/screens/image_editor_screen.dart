import 'package:flutter/material.dart';
import 'dart:io';
import '../models/media_file.dart';
import '../widgets/image_adjustments_panel.dart';
import '../widgets/image_filters_panel.dart';
import '../helpers/image_helper.dart';
import '../widgets/image_crop_tool.dart';

class ImageEditorScreen extends StatefulWidget {
  final MediaFile image;

  const ImageEditorScreen({
    super.key,
    required this.image,
  });

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  String _currentImagePath = '';

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.image.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveImage,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.file(
                File(_currentImagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolButton(
                  Icons.tune,
                  'Adjust',
                  () => _showAdjustments(),
                ),
                _buildToolButton(
                  Icons.filter,
                  'Filters',
                  () => _showFilters(),
                ),
                _buildToolButton(
                  Icons.rotate_right,
                  'Rotate',
                  () => _rotateImage(),
                ),
                _buildToolButton(
                  Icons.crop,
                  'Crop',
                  () => _showCropTool(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showAdjustments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ImageAdjustmentsPanel(
        image: widget.image,
        onSave: (path) {
          setState(() => _currentImagePath = path);
        },
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ImageFiltersPanel(
        image: widget.image,
        onFilterApplied: (path) {
          setState(() => _currentImagePath = path);
        },
      ),
    );
  }

  void _rotateImage() async {
    final rotatedPath = await ImageHelper.rotateImage(_currentImagePath, 90);
    if (rotatedPath != null) {
      setState(() => _currentImagePath = rotatedPath);
    }
  }

  void _showCropTool() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageCropTool(
          imagePath: _currentImagePath,
          onCropped: (path) {
            setState(() => _currentImagePath = path);
          },
        ),
      ),
    );
  }

  void _saveImage() async {
    // Save to gallery
    final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedPath = await ImageHelper.saveImageCopy(_currentImagePath, fileName);
    
    if (savedPath != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image saved to: $savedPath'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }
}
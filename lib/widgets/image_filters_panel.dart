import 'package:flutter/material.dart';
import 'dart:io';
import '../models/media_file.dart';
import '../helpers/image_helper.dart';

class ImageFiltersPanel extends StatefulWidget {
  final MediaFile image;
  final Function(String) onFilterApplied;

  const ImageFiltersPanel({
    super.key,
    required this.image,
    required this.onFilterApplied,
  });

  @override
  State<ImageFiltersPanel> createState() => _ImageFiltersPanelState();
}

class _ImageFiltersPanelState extends State<ImageFiltersPanel> {
  ImageFilter _selectedFilter = ImageFilter.none;
  bool _isApplying = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
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
            'Filters',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ImageFilter.values.map((filter) {
                return _buildFilterOption(filter);
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isApplying ? null : _applyFilter,
                child: _isApplying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Apply Filter'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(ImageFilter filter) {
    final isSelected = _selectedFilter == filter;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: _buildFilterPreview(filter),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                _getFilterName(filter),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Theme.of(context).primaryColor : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPreview(ImageFilter filter) {
    final preview = Image.file(
      File(widget.image.path),
      fit: BoxFit.cover,
    );
    final colorFilter = ImageHelper.getFilterPreviewColorFilter(filter);
    if (colorFilter == null) return preview;
    return ColorFiltered(colorFilter: colorFilter, child: preview);
  }

  String _getFilterName(ImageFilter filter) {
    switch (filter) {
      case ImageFilter.none:
        return 'Original';
      case ImageFilter.grayscale:
        return 'Grayscale';
      case ImageFilter.sepia:
        return 'Sepia';
      case ImageFilter.invert:
        return 'Invert';
      case ImageFilter.vintage:
        return 'Vintage';
      case ImageFilter.cool:
        return 'Cool';
      case ImageFilter.warm:
        return 'Warm';
      case ImageFilter.noir:
        return 'Noir';
    }
  }

  Future<void> _applyFilter() async {
    if (_selectedFilter == ImageFilter.none) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isApplying = true);

    try {
      final filteredPath = await ImageHelper.applyFilter(
        widget.image.path,
        _selectedFilter,
      );

      if (filteredPath != null) {
        widget.onFilterApplied(filteredPath);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to apply filter');
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
        setState(() => _isApplying = false);
      }
    }
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'dart:async';
import '../models/media_file.dart';
import '../providers/image_viewer_provider.dart';
import '../providers/media_provider.dart';
import '../widgets/image_viewer_controls.dart';
import '../widgets/image_info_sheet.dart';

import 'image_editor_screen.dart';
import '../helpers/image_helper.dart';
import '../services/database_service.dart';

class ImageViewerScreen extends ConsumerStatefulWidget {
  final MediaFile initialImage;
  final List<MediaFile> images;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.initialImage,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late TransformationController _transformationController;
  Timer? _hideControlsTimer;
  Timer? _slideshowTimer;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformationController = TransformationController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imageViewerProvider.notifier).setIndex(widget.initialIndex);
      ref.read(mediaProvider.notifier).addToRecent(widget.initialImage);
      _startHideControlsTimer();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    _hideControlsTimer?.cancel();
    _slideshowTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !ref.read(imageViewerProvider).isSlideshow) {
        ref.read(imageViewerProvider.notifier).hideControls();
      }
    });
  }

  void _handleTap() {
    ref.read(imageViewerProvider.notifier).toggleControls();
    if (ref.read(imageViewerProvider).showControls) {
      _startHideControlsTimer();
    }
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 2, -position.dy * 2)
        ..scale(3.0);
    }
  }

  void _startSlideshow() {
    ref.read(imageViewerProvider.notifier).toggleSlideshow();
    final state = ref.read(imageViewerProvider);

    if (state.isSlideshow) {
      _slideshowTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        final currentState = ref.read(imageViewerProvider);
        if (currentState.currentIndex < widget.images.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          _stopSlideshow();
        }
      });
      ref.read(imageViewerProvider.notifier).hideControls();
    } else {
      _stopSlideshow();
    }
  }

  void _stopSlideshow() {
    _slideshowTimer?.cancel();
    ref.read(imageViewerProvider.notifier).toggleSlideshow();
    ref.read(imageViewerProvider.notifier).showControls();
    _startHideControlsTimer();
  }

  void _showImageInfo() async {
    final currentImage =
        widget.images[ref.read(imageViewerProvider).currentIndex];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: ImageHelper.getImageInfo(File(currentImage.path)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          return ImageInfoSheet(image: currentImage);
        },
      ),
    );
  }

  void _shareImage() async {
    try {
      final currentImage =
          widget.images[ref.read(imageViewerProvider).currentIndex];

      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Preparing to share...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );

      await ImageHelper.shareImage(currentImage.path, text: currentImage.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteImage() async {
    final currentImage =
        widget.images[ref.read(imageViewerProvider).currentIndex];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: Text(
          'Are you sure you want to delete "${currentImage.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Deleting...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );

        final fileDeleted = await ImageHelper.deleteImage(currentImage.path);

        if (fileDeleted) {
          final db = DatabaseService.instance;
          await db.deleteMediaFile(currentImage.id);
        }

        if (!mounted) return;

        if (fileDeleted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image deleted successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Navigate to next/previous or go back
          if (widget.images.length > 1) {
            final currentIndex = ref.read(imageViewerProvider).currentIndex;

            // Remove deleted image from list
            widget.images.removeAt(currentIndex);

            if (widget.images.isEmpty) {
              // All images deleted, go back
              Navigator.pop(context);
            } else {
              // Adjust index if needed
              if (currentIndex >= widget.images.length) {
                ref
                    .read(imageViewerProvider.notifier)
                    .setIndex(widget.images.length - 1);
              }

              // Rebuild to show next image
              setState(() {});
            }
          } else {
            // Last image, go back
            Navigator.pop(context);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _editImage() async {
    final currentImage =
        widget.images[ref.read(imageViewerProvider).currentIndex];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageEditorScreen(image: currentImage),
      ),
    );
  }

  void _setAsWallpaper() async {
    final currentImage =
        widget.images[ref.read(imageViewerProvider).currentIndex];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set as Wallpaper'),
        content: const Text('Set this image as your device wallpaper?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Set'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Setting wallpaper...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );

        final success = await ImageHelper.setAsWallpaper(currentImage.path);

        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wallpaper set successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to set wallpaper. Please try from your device settings.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /* void _showAdjustmentsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ImageAdjustmentsPanel(
        image: widget.images[ref.read(imageViewerProvider).currentIndex],
        onSave: (adjustedImagePath) {
          // Handle saved image
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image saved to: $adjustedImagePath'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showFiltersPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ImageFiltersPanel(
        image: widget.images[ref.read(imageViewerProvider).currentIndex],
        onFilterApplied: (filteredImagePath) {
          // Handle filtered image
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Filter applied and saved'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  } */

  @override
  Widget build(BuildContext context) {
    final viewerState = ref.watch(imageViewerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: _handleTap,
        child: Stack(
          children: [
            // Main image viewer
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                ref.read(imageViewerProvider.notifier).setIndex(index);
                ref
                    .read(mediaProvider.notifier)
                    .addToRecent(widget.images[index]);
                _transformationController.value = Matrix4.identity();
                _startHideControlsTimer();
              },
              itemBuilder: (context, index) {
                return _buildImageViewer(widget.images[index], viewerState);
              },
            ),

            // Controls overlay
            if (viewerState.showControls || viewerState.isSlideshow)
              ImageViewerControls(
                currentIndex: viewerState.currentIndex,
                totalImages: widget.images.length,
                isSlideshow: viewerState.isSlideshow,
                onClose: () => Navigator.pop(context),
                onPrevious: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                onNext: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                onInfo: _showImageInfo,
                onShare: _shareImage,
                onDelete: _deleteImage,
                onEdit: _editImage,
                onRotate: () => ref.read(imageViewerProvider.notifier).rotate(),
                onSlideshow: _startSlideshow,
                onFullscreen: () {
                  ref.read(imageViewerProvider.notifier).toggleFullscreen();
                  if (viewerState.isFullscreen) {
                    SystemChrome.setEnabledSystemUIMode(
                      SystemUiMode.edgeToEdge,
                    );
                  } else {
                    SystemChrome.setEnabledSystemUIMode(
                      SystemUiMode.immersiveSticky,
                    );
                  }
                },
                onWallpaper: _setAsWallpaper,
              ),

            // Image counter
            if (viewerState.showControls && widget.images.length > 1)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${viewerState.currentIndex + 1} / ${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

            // Slideshow indicator
            if (viewerState.isSlideshow)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.slideshow, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Slideshow',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageViewer(MediaFile image, ImageViewerState viewerState) {
    return Center(
      child: GestureDetector(
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          child: RotatedBox(
            quarterTurns: viewerState.rotation ~/ 90,
            child: ColorFiltered(
              colorFilter: ImageHelper.getColorFilter(
                brightness: viewerState.brightness,
                contrast: viewerState.contrast,
                saturation: viewerState.saturation,
              ),
              child: Hero(
                tag: 'image_${image.id}',
                child: Image.file(
                  File(image.path),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image,
                            size: 80,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Unable to load image',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

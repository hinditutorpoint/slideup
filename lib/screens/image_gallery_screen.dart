import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../models/media_file.dart';
import '../providers/image_gallery_provider.dart';
import '../helpers/image_helper.dart';
import '../services/database_service.dart';
import 'package:share_plus/share_plus.dart';
import 'image_viewer_screen.dart';
import '../services/settings_service.dart';

class ImageGalleryScreen extends ConsumerStatefulWidget {
  const ImageGalleryScreen({super.key});

  @override
  ConsumerState<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends ConsumerState<ImageGalleryScreen> {
  int _crossAxisCount = 3;
  late bool _isGridView;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isGridView = SettingsService.instance.isGridView;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagesAsync = ref.watch(filteredImagesProvider);
    final galleryState = ref.watch(imageGalleryProvider);

    return PopScope(
      canPop: !galleryState.isSelectionMode && !galleryState.isSearchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (galleryState.isSelectionMode) {
            ref.read(imageGalleryProvider.notifier).exitSelectionMode();
          } else if (galleryState.isSearchMode) {
            ref.read(imageGalleryProvider.notifier).exitSearchMode();
            _searchController.clear();
          }
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(galleryState),
        body: imagesAsync.when(
          data: (images) {
            if (images.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text('No images found'),
                  ],
                ),
              );
            }

            return Stack(
              children: [
                _isGridView
                    ? _buildGridView(images, galleryState)
                    : _buildListView(images, galleryState),

                // Bulk action button
                if (galleryState.isSelectionMode)
                  _buildBulkActionButton(images, galleryState),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ImageGalleryState galleryState) {
    if (galleryState.isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(imageGalleryProvider.notifier).exitSelectionMode();
          },
        ),
        title: Text('${galleryState.selectedCount} selected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: () async {
              final images = await ref.read(imagesProvider.future);
              ref.read(imageGalleryProvider.notifier).selectAll(images);
            },
          ),
          IconButton(
            icon: const Icon(Icons.deselect),
            onPressed: () {
              ref.read(imageGalleryProvider.notifier).deselectAll();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final images = await ref.read(imagesProvider.future);
              switch (value) {
                case 'share':
                  _bulkShare(images, galleryState);
                  break;
                case 'delete':
                  _bulkDelete(images, galleryState);
                  break;
                case 'move':
                  _bulkMove(images, galleryState);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 12),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'move',
                child: Row(
                  children: [
                    Icon(Icons.drive_file_move),
                    SizedBox(width: 12),
                    Text('Move'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (galleryState.isSearchMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(imageGalleryProvider.notifier).exitSearchMode();
            _searchController.clear();
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search images...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          onChanged: (value) {
            ref.read(imageGalleryProvider.notifier).setSearchQuery(value);
          },
        ),
        actions: [
          if (galleryState.searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                ref.read(imageGalleryProvider.notifier).setSearchQuery('');
              },
            ),
        ],
      );
    }

    return AppBar(
      title: const Text('Gallery'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(imagesProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gallery refreshed'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
            SettingsService.instance.setIsGridView(_isGridView);
          },
        ),
        if (_isGridView)
          PopupMenuButton<int>(
            icon: const Icon(Icons.grid_3x3),
            onSelected: (value) {
              setState(() {
                _crossAxisCount = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 2, child: Text('2 columns')),
              const PopupMenuItem(value: 3, child: Text('3 columns')),
              const PopupMenuItem(value: 4, child: Text('4 columns')),
              const PopupMenuItem(value: 5, child: Text('5 columns')),
            ],
          ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            ref.read(imageGalleryProvider.notifier).toggleSearchMode();
          },
        ),
      ],
    );
  }

  Widget _buildGridView(
    List<MediaFile> images,
    ImageGalleryState galleryState,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(4).copyWith(bottom: 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _crossAxisCount,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        final isSelected = galleryState.isSelected(image.id);

        return GestureDetector(
          onTap: () => _handleImageTap(image, images, index, galleryState),
          onLongPress: () => _handleImageLongPress(image),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'image_${image.id}',
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 3,
                          )
                        : null,
                  ),
                  child: Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),

              // Selection overlay
              if (galleryState.isSelectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.white.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      isSelected ? Icons.check : Icons.circle_outlined,
                      color: isSelected ? Colors.white : Colors.grey[800],
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListView(
    List<MediaFile> images,
    ImageGalleryState galleryState,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        final isSelected = galleryState.isSelected(image.id);

        return ListTile(
          selected: isSelected,
          selectedTileColor: Theme.of(
            context,
          ).primaryColor.withValues(alpha: 0.1),
          leading: Stack(
            children: [
              Hero(
                tag: 'image_${image.id}',
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[900],
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          )
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(image.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image);
                      },
                    ),
                  ),
                ),
              ),
              if (galleryState.isSelectionMode)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Icon(
                      isSelected ? Icons.check : Icons.circle_outlined,
                      color: isSelected ? Colors.white : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(image.name),
          subtitle: Text(
            '${ImageHelper.formatBytes(image.size)} • ${ImageHelper.getImageFormat(image.path)}',
          ),
          onTap: () => _handleImageTap(image, images, index, galleryState),
          onLongPress: () => _handleImageLongPress(image),
        );
      },
    );
  }

  Widget _buildBulkActionButton(
    List<MediaFile> images,
    ImageGalleryState galleryState,
  ) {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              Icons.share,
              'Share',
              () => _bulkShare(images, galleryState),
            ),
            _buildActionButton(
              Icons.drive_file_move,
              'Move',
              () => _bulkMove(images, galleryState),
            ),
            _buildActionButton(
              Icons.delete,
              'Delete',
              () => _bulkDelete(images, galleryState),
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isDestructive ? Colors.red : null, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDestructive ? Colors.red : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleImageTap(
    MediaFile image,
    List<MediaFile> images,
    int index,
    ImageGalleryState galleryState,
  ) {
    if (galleryState.isSelectionMode) {
      ref.read(imageGalleryProvider.notifier).toggleSelection(image.id);
    } else {
      _openImageViewer(image, images, index);
    }
  }

  void _handleImageLongPress(MediaFile image) {
    ref.read(imageGalleryProvider.notifier).enterSelectionMode();
    ref.read(imageGalleryProvider.notifier).toggleSelection(image.id);
  }

  void _openImageViewer(MediaFile image, List<MediaFile> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(
          initialImage: image,
          images: images,
          initialIndex: index,
        ),
      ),
    ).then((_) {
      // Refresh images after returning
      ref.invalidate(imagesProvider);
    });
  }

  void _bulkShare(
    List<MediaFile> images,
    ImageGalleryState galleryState,
  ) async {
    final selectedImages = images
        .where((img) => galleryState.isSelected(img.id))
        .toList();

    if (selectedImages.isEmpty) return;

    try {
      final paths = selectedImages.map((img) => img.path).toList();

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
        ),
      );

      // Use share_plus for multiple files
      await SharePlus.instance.share(
        ShareParams(
          title: 'Share Images from Slideup',
          files: paths.map((path) => XFile(path)).toList(),
          text: 'Shared ${paths.length} images from Slideup',
        ),
      );

      ref.read(imageGalleryProvider.notifier).exitSelectionMode();
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

  void _bulkMove(List<MediaFile> images, ImageGalleryState galleryState) {
    final selectedCount = galleryState.selectedCount;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Move $selectedCount images - Coming soon')),
    );
  }

  void _bulkDelete(
    List<MediaFile> images,
    ImageGalleryState galleryState,
  ) async {
    final selectedImages = images
        .where((img) => galleryState.isSelected(img.id))
        .toList();

    if (selectedImages.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Images'),
        content: Text(
          'Are you sure you want to delete ${selectedImages.length} image(s)?\n\nThis action cannot be undone.',
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

    if (confirmed != true) return;

    try {
      ref.read(imageGalleryProvider.notifier).setDeleting(true);

      // Show progress dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              ref.read(imageGalleryProvider.notifier).setDeleting(false);
            }
          },
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Deleting ${selectedImages.length} images...'),
              ],
            ),
          ),
        ),
      );

      // Prepare paths and IDs
      final paths = selectedImages.map((img) => img.path).toList();
      final ids = selectedImages.map((img) => img.id).toList();

      // ✅ Delete files AND database records
      final result = await ImageHelper.bulkDeleteImages(paths, imageIds: ids);

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      ref.read(imageGalleryProvider.notifier).setDeleting(false);
      ref.read(imageGalleryProvider.notifier).exitSelectionMode();

      // ✅ Force refresh the provider
      ref.invalidate(imagesProvider);

      // Show result
      if (result.allSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted ${result.successCount} images'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (result.hasFailures) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted ${result.successCount} images, ${result.failedCount} failed',
            ),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Details',
              onPressed: () {
                _showDeleteFailuresDialog(result);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      ref.read(imageGalleryProvider.notifier).setDeleting(false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDeleteFailuresDialog(BulkDeleteResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Failures'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: result.failedPaths.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: Text(
                  result.failedPaths[index].split('/').last,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Provider for images
final imagesProvider = FutureProvider.autoDispose<List<MediaFile>>((ref) async {
  final db = DatabaseService.instance;
  final images = await db.getMediaFilesByType(MediaType.image);

  // ✅ Filter out images whose files don't exist
  final existingImages = <MediaFile>[];
  final deletedIds = <String>[];

  for (final image in images) {
    final file = File(image.path);
    if (await file.exists()) {
      existingImages.add(image);
    } else {
      // File doesn't exist, mark for deletion from DB
      deletedIds.add(image.id);
    }
  }

  // Clean up database records for non-existent files
  if (deletedIds.isNotEmpty) {
    await db.deleteMediaFiles(deletedIds);
  }

  return existingImages;
});

// Filtered images provider
final filteredImagesProvider =
    Provider.autoDispose<AsyncValue<List<MediaFile>>>((ref) {
      final imagesAsync = ref.watch(imagesProvider);
      final galleryState = ref.watch(imageGalleryProvider);
      final searchQuery = galleryState.searchQuery.toLowerCase();

      return imagesAsync.whenData((images) {
        if (searchQuery.isEmpty) return images;
        return images.where((img) {
          return img.name.toLowerCase().contains(searchQuery);
        }).toList();
      });
    });

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/video_edit_settings.dart';
import '../providers/image_picker_provider.dart';

class ImagePickerSheet extends ConsumerStatefulWidget {
  final Function(StockImage) onImageSelected;

  const ImagePickerSheet({super.key, required this.onImageSelected});

  @override
  ConsumerState<ImagePickerSheet> createState() => _ImagePickerSheetState();
}

class _ImagePickerSheetState extends ConsumerState<ImagePickerSheet> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(imagePickerProvider.notifier).loadMoreImages();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(imagePickerProvider.notifier).setSearchQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imagePickerProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 400 ? 4 : 3;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Compact Header
          _buildCompactHeader(state),

          // Search Bar
          _buildCompactSearchBar(state),

          // Category Chips or Downloaded Count
          if (!state.showDownloaded) _buildCategoryChips(state),

          // Main Content
          Expanded(
            child: state.isLoading && state.images.isEmpty
                ? _buildLoadingState()
                : state.error != null
                ? _buildErrorState(state)
                : _buildImageGrid(state, crossAxisCount),
          ),

          // Selected Images Bar
          if (state.selectedImages.isNotEmpty) _buildSelectionBar(state),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🎯 COMPACT HEADER
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactHeader(ImagePickerState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          // Title
          const Text(
            'Add Images',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),

          // View Toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton(
                  'Browse',
                  !state.showDownloaded,
                  () => ref
                      .read(imagePickerProvider.notifier)
                      .toggleViewMode(false),
                ),
                _buildToggleButton(
                  'Downloaded (${state.downloadedImages.length})',
                  state.showDownloaded,
                  () => ref
                      .read(imagePickerProvider.notifier)
                      .toggleViewMode(true),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Refresh
          IconButton(
            onPressed: () {
              if (state.showDownloaded) {
                ref.read(imagePickerProvider.notifier).loadDownloadedImages();
              } else {
                ref
                    .read(imagePickerProvider.notifier)
                    .loadImages(refresh: true);
              }
              HapticFeedback.selectionClick();
            },
            icon: const Icon(Icons.refresh, size: 18),
            color: Colors.white54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),

          // Close
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 18),
            color: Colors.white54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.red : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🔍 COMPACT SEARCH BAR
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactSearchBar(ImagePickerState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: state.showDownloaded
                ? 'Search downloaded...'
                : 'Search images...',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white.withValues(alpha: 0.3),
              size: 18,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 16,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(imagePickerProvider.notifier).setSearchQuery('');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🏷️ CATEGORY CHIPS
  // ═══════════════════════════════════════════════════════

  Widget _buildCategoryChips(ImagePickerState state) {
    return Container(
      height: 32,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: ImageCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final category = ImageCategory.values[index];
          final isSelected = state.selectedCategory == category;

          return GestureDetector(
            onTap: () {
              ref.read(imagePickerProvider.notifier).setCategory(category);
              HapticFeedback.selectionClick();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.red
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Colors.red
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                _formatCategory(category),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatCategory(ImageCategory cat) {
    if (cat == ImageCategory.all) return 'All';
    return cat.name[0].toUpperCase() + cat.name.substring(1);
  }

  // ═══════════════════════════════════════════════════════
  // 🖼️ IMAGE GRID
  // ═══════════════════════════════════════════════════════

  Widget _buildImageGrid(ImagePickerState state, int crossAxisCount) {
    final images = state.filteredImages;

    if (images.isEmpty) {
      return _buildEmptyState(state);
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: images.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= images.length) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.red,
              ),
            ),
          );
        }
        return _buildCompactImageCard(images[index], state);
      },
    );
  }

  Widget _buildCompactImageCard(StockImage image, ImagePickerState state) {
    final isSelected = state.selectedImages.any((i) => i.id == image.id);
    final isDownloading = state.downloadProgress.containsKey(image.id);
    final progress = state.downloadProgress[image.id] ?? 0;

    return GestureDetector(
      onTap: () => _onImageTap(image),
      onLongPress: () => _showImageOptions(image),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              _buildImageWidget(image),

              // Download Progress
              if (isDownloading)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            value: progress,
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Selection Indicator
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),

              // Downloaded Badge
              if (image.isDownloaded && !isSelected)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.download_done,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),

              // Bottom Actions
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Likes
                      if (image.likes > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.favorite,
                              size: 10,
                              color: Colors.red[300],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatNumber(image.likes),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      // Action Button
                      if (!image.isDownloaded && !isDownloading)
                        GestureDetector(
                          onTap: () => _downloadImage(image),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Icon(
                              Icons.download,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      if (image.isDownloaded)
                        GestureDetector(
                          onTap: () => _selectImage(image),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(StockImage image) {
    if (image.localPath != null && image.localPath!.isNotEmpty) {
      return Image.file(
        File(image.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return CachedNetworkImage(
      imageUrl: image.thumbnailUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => _buildPlaceholder(),
      errorWidget: (_, __, ___) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: Icon(Icons.image, color: Colors.grey[700], size: 20),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SELECTION BAR
  // ═══════════════════════════════════════════════════════

  Widget _buildSelectionBar(ImagePickerState state) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(color: Colors.red.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Selected Images Preview
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.selectedImages.length,
              itemBuilder: (context, index) {
                final image = state.selectedImages[index];
                return Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 4),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _buildImageWidget(image),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            ref
                                .read(imagePickerProvider.notifier)
                                .toggleImageSelection(image);
                            HapticFeedback.lightImpact();
                          },
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // Action Buttons
          TextButton(
            onPressed: () {
              ref.read(imagePickerProvider.notifier).clearSelection();
              HapticFeedback.lightImpact();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text(
              'Clear (${state.selectedImages.length})',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () {
              // Add selected images to timeline
              for (final image in state.selectedImages) {
                widget.onImageSelected(image);
              }
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Add', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 📱 STATE WIDGETS
  // ═══════════════════════════════════════════════════════

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: Colors.red));
  }

  Widget _buildErrorState(ImagePickerState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 40),
          const SizedBox(height: 12),
          Text(
            state.error ?? 'Error loading images',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              ref.read(imagePickerProvider.notifier).loadImages(refresh: true);
            },
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ImagePickerState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, color: Colors.grey[700], size: 40),
          const SizedBox(height: 12),
          Text(
            state.searchQuery.isNotEmpty
                ? 'No results for "${state.searchQuery}"'
                : state.showDownloaded
                ? 'No downloaded images'
                : 'No images found',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (state.searchQuery.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Try different keywords',
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 🎬 ACTIONS
  // ═══════════════════════════════════════════════════════

  void _onImageTap(StockImage image) {
    if (image.isDownloaded) {
      ref.read(imagePickerProvider.notifier).toggleImageSelection(image);
      HapticFeedback.selectionClick();
    } else {
      _showImagePreview(image);
    }
  }

  void _selectImage(StockImage image) {
    ref.read(imagePickerProvider.notifier).toggleImageSelection(image);
    widget.onImageSelected(image);
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image added'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _downloadImage(StockImage image) {
    ref.read(imagePickerProvider.notifier).downloadImage(image);
    HapticFeedback.mediumImpact();
  }

  void _showImagePreview(StockImage image) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: image.previewUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => Container(
                  width: 300,
                  height: 300,
                  color: Colors.grey[900],
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
            if (!image.isDownloaded)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _downloadImage(image);
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text(
                      'Download',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showImageOptions(StockImage image) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.preview, color: Colors.white70),
              title: const Text(
                'Preview',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showImagePreview(image);
              },
            ),
            if (!image.isDownloaded)
              ListTile(
                leading: const Icon(Icons.download, color: Colors.white70),
                title: const Text(
                  'Download',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadImage(image);
                },
              ),
            if (image.isDownloaded) ...[
              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.white70),
                title: const Text(
                  'Add to Video',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _selectImage(image);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Download',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(imagePickerProvider.notifier)
                      .deleteDownload(image.id);
                  HapticFeedback.lightImpact();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ═══════════════════════════════════════════════════════
// 🚀 SHOW IMAGE PICKER SHEET
// ═══════════════════════════════════════════════════════

void showImagePickerSheet(
  BuildContext context,
  Function(StockImage) onImageSelected,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ImagePickerSheet(onImageSelected: onImageSelected),
  );
}

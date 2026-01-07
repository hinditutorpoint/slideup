import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/video_edit_settings.dart';
import '../services/pixabay_api_service.dart';

class ImageTab extends StatefulWidget {
  final List<StockImage> selectedImages;
  final Function(List<StockImage>) onImagesChanged;
  final Function(StockImage) onImageSelected;

  const ImageTab({
    super.key,
    required this.selectedImages,
    required this.onImagesChanged,
    required this.onImageSelected,
  });

  @override
  State<ImageTab> createState() => _ImageTabState();
}

class _ImageTabState extends State<ImageTab>
    with SingleTickerProviderStateMixin {
  final PixabayApiService _apiService = PixabayApiService();
  late TabController _categoryController;

  List<StockImage> _images = [];
  List<StockImage> _downloadedImages = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  ImageCategory _selectedCategory = ImageCategory.all;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  int _currentPage = 1;

  final Map<String, double> _downloadProgress = {};
  bool _showDownloaded = false;

  @override
  void initState() {
    super.initState();
    _categoryController = TabController(
      length: ImageCategory.values.length,
      vsync: this,
    );
    _categoryController.addListener(_onCategoryChanged);
    _scrollController.addListener(_onScroll);
    _loadImages();
    _loadDownloadedImages();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onCategoryChanged() {
    if (_categoryController.indexIsChanging) return;
    try {
      setState(() {
        _selectedCategory = ImageCategory.values[_categoryController.index];
        _currentPage = 1;
      });
      _loadImages();
    } catch (e) {
      debugPrint('❌ Category change error: $e');
    }
  }

  void _onScroll() {
    try {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        _loadMoreImages();
      }
    } catch (e) {
      debugPrint('❌ Scroll error: $e');
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = value;
          _currentPage = 1;
        });
        _loadImages();
      }
    });
  }

  Future<void> _loadImages() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final images = await _apiService.fetchImages(
        query: _searchQuery,
        category: _selectedCategory,
        page: 1,
        perPage: 30,
      );

      if (mounted) {
        setState(() {
          _images = images;
          _isLoading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      debugPrint('❌ Load images error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load images';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreImages() async {
    if (_isLoadingMore || _isLoading) return;

    setState(() => _isLoadingMore = true);

    try {
      final images = await _apiService.fetchImages(
        query: _searchQuery,
        category: _selectedCategory,
        page: _currentPage + 1,
        perPage: 30,
      );

      if (images.isNotEmpty && mounted) {
        setState(() {
          _images.addAll(images);
          _currentPage++;
        });
      }
    } catch (e) {
      debugPrint('❌ Load more error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadDownloadedImages() async {
    try {
      final downloaded = await _apiService.getDownloadedImages();
      if (mounted) setState(() => _downloadedImages = downloaded);
    } catch (e) {
      debugPrint('❌ Load downloaded error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 400;
        final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);

        return Column(
          children: [
            _buildHeader(isCompact),
            _buildSearchBar(isCompact),
            if (!_showDownloaded) _buildCategoryTabs(isCompact),
            Expanded(
              child: _showDownloaded
                  ? _buildDownloadedGrid(isCompact, crossAxisCount)
                  : _isLoading
                  ? _buildLoadingState()
                  : _error != null
                  ? _buildErrorState(isCompact)
                  : _buildImagesGrid(isCompact, crossAxisCount),
            ),
            if (widget.selectedImages.isNotEmpty) _buildSelectedBar(isCompact),
          ],
        );
      },
    );
  }

  int _getCrossAxisCount(double width) {
    if (width > 800) return 5;
    if (width > 600) return 4;
    if (width > 400) return 3;
    return 2;
  }

  Widget _buildHeader(bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 6 : 8,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggle('Browse', !_showDownloaded, () {
                  setState(() => _showDownloaded = false);
                  HapticFeedback.selectionClick();
                }, isCompact),
                _buildToggle(
                  'Downloaded (${_downloadedImages.length})',
                  _showDownloaded,
                  () {
                    setState(() => _showDownloaded = true);
                    _loadDownloadedImages();
                    HapticFeedback.selectionClick();
                  },
                  isCompact,
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _showDownloaded ? _loadDownloadedImages : _loadImages,
            icon: Icon(
              Icons.refresh,
              size: isCompact ? 18 : 20,
              color: Colors.white70,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(
    String label,
    bool active,
    VoidCallback onTap,
    bool isCompact,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: active ? Colors.red : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey[400],
            fontSize: isCompact ? 10 : 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 12,
        vertical: isCompact ? 4 : 6,
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: _showDownloaded
              ? 'Search downloaded...'
              : 'Search images (e.g., nature, city, abstract)...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[500],
            size: isCompact ? 18 : 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey[500],
                    size: isCompact ? 18 : 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    if (!_showDownloaded) _loadImages();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white12,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 10),
        ),
        onChanged: _showDownloaded
            ? (v) => setState(() => _searchQuery = v)
            : _onSearchChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: _showDownloaded
            ? null
            : (v) {
                setState(() {
                  _searchQuery = v;
                  _currentPage = 1;
                });
                _loadImages();
              },
      ),
    );
  }

  Widget _buildCategoryTabs(bool isCompact) {
    return SizedBox(
      height: isCompact ? 32 : 36,
      child: TabBar(
        controller: _categoryController,
        isScrollable: true,
        indicatorColor: Colors.red,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[500],
        labelStyle: TextStyle(fontSize: isCompact ? 10 : 11),
        indicatorSize: TabBarIndicatorSize.label,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: ImageCategory.values
            .map((cat) => Tab(text: _formatCategory(cat)))
            .toList(),
      ),
    );
  }

  String _formatCategory(ImageCategory cat) {
    if (cat == ImageCategory.all) return 'All';
    return cat.name[0].toUpperCase() + cat.name.substring(1);
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: Colors.red));
  }

  Widget _buildErrorState(bool isCompact) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[400],
            size: isCompact ? 40 : 48,
          ),
          SizedBox(height: isCompact ? 12 : 16),
          Text(
            _error ?? 'Error',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: isCompact ? 13 : 14,
            ),
          ),
          SizedBox(height: isCompact ? 8 : 12),
          TextButton(onPressed: _loadImages, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildImagesGrid(bool isCompact, int crossAxisCount) {
    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              color: Colors.grey[700],
              size: isCompact ? 40 : 48,
            ),
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No images found',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: isCompact ? 13 : 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              SizedBox(height: isCompact ? 4 : 8),
              Text(
                'Try different keywords',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isCompact ? 11 : 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadImages,
      color: Colors.red,
      child: GridView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(isCompact ? 6 : 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: isCompact ? 4 : 6,
          mainAxisSpacing: isCompact ? 4 : 6,
          childAspectRatio: 1,
        ),
        itemCount: _images.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _images.length) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.red,
                strokeWidth: 2,
              ),
            );
          }
          try {
            return _buildImageCard(_images[index], isCompact);
          } catch (e) {
            debugPrint('❌ Build image error: $e');
            return _placeholder();
          }
        },
      ),
    );
  }

  Widget _buildDownloadedGrid(bool isCompact, int crossAxisCount) {
    var filtered = _downloadedImages;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = _downloadedImages
          .where(
            (i) =>
                i.title.toLowerCase().contains(q) ||
                i.tags.any((t) => t.toLowerCase().contains(q)),
          )
          .toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_done,
              color: Colors.grey[700],
              size: isCompact ? 40 : 48,
            ),
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              _searchQuery.isNotEmpty ? 'No results' : 'No downloaded images',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: isCompact ? 13 : 14,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(isCompact ? 6 : 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isCompact ? 4 : 6,
        mainAxisSpacing: isCompact ? 4 : 6,
        childAspectRatio: 1,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        try {
          return _buildImageCard(
            filtered[index],
            isCompact,
            isDownloadedView: true,
          );
        } catch (e) {
          return _placeholder();
        }
      },
    );
  }

  Widget _buildImageCard(
    StockImage image,
    bool isCompact, {
    bool isDownloadedView = false,
  }) {
    final isSelected = widget.selectedImages.any((i) => i.id == image.id);
    final isDownloading = _downloadProgress.containsKey(image.id);
    final progress = _downloadProgress[image.id] ?? 0;

    return GestureDetector(
      onTap: () => _onImageTap(image),
      onLongPress: () => _showImageActions(image, isDownloadedView),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              _buildImage(image),

              // Download progress
              if (isDownloading)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
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
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Selection indicator
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
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

              // Downloaded indicator
              if (image.isDownloaded && !isDownloadedView && !isSelected)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
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

              // Bottom gradient with info
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
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      if (image.likes > 0) ...[
                        Icon(Icons.favorite, size: 10, color: Colors.red[300]),
                        const SizedBox(width: 2),
                        Text(
                          _formatNumber(image.likes),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (!image.isDownloaded && !isDownloading)
                        GestureDetector(
                          onTap: () => _downloadImage(image),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(4),
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
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
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

  Widget _buildImage(StockImage image) {
    if (image.localPath != null && image.localPath!.isNotEmpty) {
      return Image.file(
        File(image.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return CachedNetworkImage(
      imageUrl: image.thumbnailUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[800],
      child: Icon(Icons.image, color: Colors.grey[600], size: 24),
    );
  }

  Widget _buildSelectedBar(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        border: Border(
          top: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: isCompact ? 36 : 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.selectedImages.length,
                itemBuilder: (context, index) {
                  try {
                    final image = widget.selectedImages[index];
                    return Container(
                      width: isCompact ? 36 : 44,
                      height: isCompact ? 36 : 44,
                      margin: const EdgeInsets.only(right: 6),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: _buildImage(image),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _deselectImage(image),
                              child: Container(
                                padding: const EdgeInsets.all(2),
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
                  } catch (e) {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              widget.onImagesChanged([]);
              HapticFeedback.lightImpact();
            },
            child: Text(
              'Clear (${widget.selectedImages.length})',
              style: TextStyle(fontSize: isCompact ? 11 : 12),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════

  void _onImageTap(StockImage image) {
    try {
      if (image.isDownloaded) {
        _toggleSelection(image);
      } else {
        _showImagePreview(image);
      }
    } catch (e) {
      debugPrint('❌ Image tap error: $e');
    }
  }

  void _toggleSelection(StockImage image) {
    try {
      final list = List<StockImage>.from(widget.selectedImages);
      final index = list.indexWhere((i) => i.id == image.id);

      if (index >= 0) {
        list.removeAt(index);
      } else {
        list.add(image);
      }

      widget.onImagesChanged(list);
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('❌ Toggle selection error: $e');
    }
  }

  void _selectImage(StockImage image) {
    try {
      if (!widget.selectedImages.any((i) => i.id == image.id)) {
        final list = List<StockImage>.from(widget.selectedImages)..add(image);
        widget.onImagesChanged(list);
        widget.onImageSelected(image);
        HapticFeedback.mediumImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image added'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Select image error: $e');
    }
  }

  void _deselectImage(StockImage image) {
    try {
      final list = widget.selectedImages
          .where((i) => i.id != image.id)
          .toList();
      widget.onImagesChanged(list);
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('❌ Deselect error: $e');
    }
  }

  Future<void> _downloadImage(StockImage image) async {
    try {
      setState(() => _downloadProgress[image.id] = 0);

      final result = await _apiService.downloadImage(
        image,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress[image.id] = p);
        },
      );

      setState(() => _downloadProgress.remove(image.id));

      if (result != null) {
        final index = _images.indexWhere((i) => i.id == image.id);
        if (index >= 0 && mounted) {
          setState(() => _images[index] = result);
        }
        await _loadDownloadedImages();
        HapticFeedback.mediumImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Downloaded'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Download error: $e');
      setState(() => _downloadProgress.remove(image.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImagePreview(StockImage image) {
    try {
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
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
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
                      icon: const Icon(Icons.download),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Preview error: $e');
    }
  }

  void _showImageActions(StockImage image, bool isDownloadedView) {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: _buildImage(image),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  image.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'by ${image.photographer}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
                Text(
                  '${image.width} x ${image.height}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
                const SizedBox(height: 16),
                _actionTile(Icons.preview, 'Preview', () {
                  Navigator.pop(ctx);
                  _showImagePreview(image);
                }),
                if (!image.isDownloaded)
                  _actionTile(Icons.download, 'Download', () {
                    Navigator.pop(ctx);
                    _downloadImage(image);
                  }),
                if (image.isDownloaded) ...[
                  _actionTile(Icons.add_circle, 'Add to Video', () {
                    Navigator.pop(ctx);
                    _selectImage(image);
                  }),
                  _actionTile(Icons.delete, 'Delete Download', () {
                    Navigator.pop(ctx);
                    _deleteImage(image);
                  }, isDestructive: true),
                ],
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Show actions error: $e');
    }
  }

  Widget _actionTile(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.white,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteImage(StockImage image) async {
    try {
      final success = await _apiService.deleteImageDownload(image.id);
      if (success) {
        final index = _images.indexWhere((i) => i.id == image.id);
        if (index >= 0 && mounted) {
          setState(
            () => _images[index] = image.copyWith(
              isDownloaded: false,
              localPath: null,
            ),
          );
        }
        await _loadDownloadedImages();

        widget.onImagesChanged(
          widget.selectedImages.where((i) => i.id != image.id).toList(),
        );

        HapticFeedback.lightImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Deleted'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Delete error: $e');
    }
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

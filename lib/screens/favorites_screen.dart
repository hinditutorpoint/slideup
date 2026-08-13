import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/media_file.dart';
import '../providers/favorites_provider.dart';
import '../widgets/media_item_card.dart';
import '../features/video_player/video_player_launcher.dart';
import '../helpers/audio_playback_helper.dart';
import 'pdf_viewer_screen.dart';
import 'image_viewer_screen.dart';
import 'main_screen.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isGridView = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Responsive helpers
  bool get _isTablet => MediaQuery.of(context).size.width >= 600;

  int get _gridCrossAxisCount {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 5;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              if (_isSelectionMode) _buildSelectionBar(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAllFavoritesTab(),
                    _buildVideoFavoritesTab(),
                    _buildAudioFavoritesTab(),
                    _buildImageFavoritesTab(),
                    _buildDocumentFavoritesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _exitSearch,
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search favorites...',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
        ],
      );
    }

    if (_isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectionMode,
        ),
        title: Text('${_selectedIds.length} selected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select All',
            onPressed: _selectAll,
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Remove from Favorites',
            onPressed: _selectedIds.isNotEmpty
                ? _removeSelectedFromFavorites
                : null,
          ),
        ],
      );
    }

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: _handleBack,
      ),
      title: const Text('Favorites'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () {
            setState(() => _isSearching = true);
          },
        ),
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          tooltip: _isGridView ? 'List View' : 'Grid View',
          onPressed: () {
            setState(() => _isGridView = !_isGridView);
          },
        ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'sort_name',
              child: Row(
                children: [
                  Icon(Icons.sort_by_alpha),
                  SizedBox(width: 12),
                  Text('Sort by Name'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'sort_date',
              child: Row(
                children: [
                  Icon(Icons.access_time),
                  SizedBox(width: 12),
                  Text('Sort by Date'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'sort_size',
              child: Row(
                children: [
                  Icon(Icons.storage),
                  SizedBox(width: 12),
                  Text('Sort by Size'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'select',
              child: Row(
                children: [
                  Icon(Icons.checklist),
                  SizedBox(width: 12),
                  Text('Select Items'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 12),
                  Text('Refresh'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Text(
            '${_selectedIds.length} item(s) selected',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _selectedIds.isNotEmpty
                ? _removeSelectedFromFavorites
                : null,
            icon: const Icon(Icons.favorite_border, size: 18),
            label: const Text('Remove'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(icon: Icon(Icons.favorite), text: 'All'),
          Tab(icon: Icon(Icons.videocam), text: 'Videos'),
          Tab(icon: Icon(Icons.audiotrack), text: 'Audio'),
          Tab(icon: Icon(Icons.image), text: 'Images'),
          Tab(icon: Icon(Icons.description), text: 'Documents'),
        ],
      ),
    );
  }

  // ============ Tab Builders ============

  Widget _buildAllFavoritesTab() {
    final favoritesAsync = ref.watch(allFavoritesProvider);

    return favoritesAsync.when(
      data: (favorites) => _buildFavoritesList(favorites, 'No Favorites Yet'),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildVideoFavoritesTab() {
    final favoritesAsync = ref.watch(favoriteVideosProvider);

    return favoritesAsync.when(
      data: (favorites) => _buildFavoritesList(favorites, 'No Favorite Videos'),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildAudioFavoritesTab() {
    final favoritesAsync = ref.watch(favoriteAudiosProvider);

    return favoritesAsync.when(
      data: (favorites) => _buildFavoritesList(favorites, 'No Favorite Audio'),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildImageFavoritesTab() {
    final favoritesAsync = ref.watch(favoriteImagesProvider);

    return favoritesAsync.when(
      data: (favorites) => _buildFavoritesList(favorites, 'No Favorite Images'),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildDocumentFavoritesTab() {
    final favoritesAsync = ref.watch(favoriteDocumentsProvider);

    return favoritesAsync.when(
      data: (favorites) =>
          _buildFavoritesList(favorites, 'No Favorite Documents'),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildFavoritesList(List<MediaFile> favorites, String emptyMessage) {
    // Apply search filter
    final filteredFavorites = _searchQuery.isEmpty
        ? favorites
        : favorites.where((f) {
            final name = path.basename(f.path).toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();

    if (favorites.isEmpty) {
      return _buildEmptyState(emptyMessage);
    }

    if (filteredFavorites.isEmpty) {
      return _buildNoResultsState();
    }

    return Column(
      children: [
        _buildStatsHeader(filteredFavorites),
        Expanded(
          child: _isGridView
              ? _buildGridView(filteredFavorites)
              : _buildListView(filteredFavorites),
        ),
      ],
    );
  }

  Widget _buildStatsHeader(List<MediaFile> favorites) {
    final totalSize = favorites.fold<int>(0, (sum, f) => sum + f.size);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildStatChip(
            Icons.favorite,
            '${favorites.length} Favorites',
            Colors.red,
          ),
          const SizedBox(width: 12),
          _buildStatChip(
            Icons.storage,
            _formatFileSize(totalSize),
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border,
                size: 60,
                color: Colors.red.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(
                fontSize: _isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Mark items as favorite to see them here',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: _isTablet ? 16 : 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<MediaFile> favorites) {
    return GridView.builder(
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridCrossAxisCount,
        crossAxisSpacing: _isTablet ? 16 : 12,
        mainAxisSpacing: _isTablet ? 16 : 12,
        childAspectRatio: 0.75,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        return _buildGridItem(favorites, index);
      },
    );
  }

  Widget _buildListView(List<MediaFile> favorites) {
    return ListView.builder(
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        return _buildListItem(favorites, index);
      },
    );
  }

  Widget _buildGridItem(List<MediaFile> favorites, int index) {
    final file = favorites[index];
    final isSelected = _selectedIds.contains(file.id);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(file.id);
        } else {
          _openFile(favorites, index);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedIds.add(file.id);
          });
        }
      },
      child: Stack(
        children: [
          MediaItemCard(
            mediaFile: file,
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(file.id);
              } else {
                _openFile(favorites, index);
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedIds.add(file.id);
                });
              }
            },
          ),
          // Selection overlay
          if (_isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.white.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          // Favorite indicator
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.favorite, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(List<MediaFile> favorites, int index) {
    final file = favorites[index];
    final isSelected = _selectedIds.contains(file.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (value) => _toggleSelection(file.id),
              ),
            _buildFileThumbnail(file),
          ],
        ),
        title: Text(
          path.basename(file.path),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Icon(
              _getMediaTypeIcon(file.type),
              size: 14,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              _formatFileSize(file.size),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const Spacer(),
            const Icon(Icons.favorite, size: 14, color: Colors.red),
          ],
        ),
        trailing: _isSelectionMode
            ? null
            : IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showFileOptionsSheet(file),
              ),
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(file.id);
          } else {
            _openFile(favorites, index);
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            setState(() {
              _isSelectionMode = true;
              _selectedIds.add(file.id);
            });
          }
        },
      ),
    );
  }

  Widget _buildFileThumbnail(MediaFile file) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _getMediaTypeColor(file.type).withValues(alpha: 0.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildThumbnailContent(file),
      ),
    );
  }

  Widget _buildThumbnailContent(MediaFile file) {
    try {
      if (file.thumbnailPath != null &&
          File(file.thumbnailPath!).existsSync()) {
        return Image.file(
          File(file.thumbnailPath!),
          fit: BoxFit.cover,
          width: 50,
          height: 50,
          errorBuilder: (context, error, stack) => _buildPlaceholderIcon(file),
        );
      }
    } catch (e) {
      // Ignore file access errors
    }
    return _buildPlaceholderIcon(file);
  }

  Widget _buildPlaceholderIcon(MediaFile file) {
    return Center(
      child: Icon(
        _getMediaTypeIcon(file.type),
        color: _getMediaTypeColor(file.type),
        size: 24,
      ),
    );
  }

  // ============ Action Handlers ============

  void _handleMenuAction(String action) {
    try {
      switch (action) {
        case 'sort_name':
          ref
              .read(favoriteSortTypeProvider.notifier)
              .setSortType(FavoriteSortType.name);
          break;
        case 'sort_date':
          ref
              .read(favoriteSortTypeProvider.notifier)
              .setSortType(FavoriteSortType.date);
          break;
        case 'sort_size':
          ref
              .read(favoriteSortTypeProvider.notifier)
              .setSortType(FavoriteSortType.size);
          break;
        case 'select':
          setState(() => _isSelectionMode = true);
          break;
        case 'refresh':
          _refresh();
          break;
      }
    } catch (e) {
      _showError('Action failed: $e');
    }
  }

  void _refresh() {
    try {
      ref.invalidate(allFavoritesProvider);
      ref.invalidate(favoriteVideosProvider);
      ref.invalidate(favoriteAudiosProvider);
      ref.invalidate(favoriteImagesProvider);
      ref.invalidate(favoriteDocumentsProvider);
    } catch (e) {
      _showError('Refresh failed: $e');
    }
  }

  void _exitSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    final currentTabFavorites = _getCurrentTabFavorites();
    currentTabFavorites.whenData((favorites) {
      setState(() {
        if (_selectedIds.length == favorites.length) {
          _selectedIds.clear();
        } else {
          _selectedIds.addAll(favorites.map((f) => f.id));
        }
      });
    });
  }

  AsyncValue<List<MediaFile>> _getCurrentTabFavorites() {
    switch (_tabController.index) {
      case 0:
        return ref.read(allFavoritesProvider);
      case 1:
        return ref.read(favoriteVideosProvider);
      case 2:
        return ref.read(favoriteAudiosProvider);
      case 3:
        return ref.read(favoriteImagesProvider);
      case 4:
        return ref.read(favoriteDocumentsProvider);
      default:
        return ref.read(allFavoritesProvider);
    }
  }

  void _removeSelectedFromFavorites() {
    if (_selectedIds.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Remove from Favorites?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Remove ${_selectedIds.length} item(s) from your favorites?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _performRemoveFromFavorites();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performRemoveFromFavorites() async {
    try {
      final idsToRemove = Set<String>.from(_selectedIds);

      for (final id in idsToRemove) {
        try {
          await ref
              .read(favoritesNotifierProvider.notifier)
              .removeFromFavorites(id);
        } catch (e) {
          debugPrint('Error removing favorite: $e');
        }
      }

      _exitSelectionMode();
      _showSuccess('Removed ${idsToRemove.length} item(s) from favorites');
      _refresh();
    } catch (e) {
      _showError('Failed to remove favorites: $e');
    }
  }

  bool isValidUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;

    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  void _openFile(List<MediaFile> files, int index) {
    try {
      final file = files[index];
      debugPrint('📂 Opening file: ${file.toString()}');
      // Check if file exists
      if (!isValidUrl(file.path) && !File(file.path).existsSync()) {
        _showError('File not found: ${path.basename(file.path)}');
        return;
      }

      switch (file.type) {
        case MediaType.video:
          _openVideo(files, file, index);
          break;
        case MediaType.audio:
          _openAudio(files, file);
          break;
        case MediaType.image:
          _openImage(files, file);
          break;
        case MediaType.document:
          _openDocument(files, file);
          break;
        default:
          _showFileDetailsSheet(file);
          break;
      }
    } catch (e) {
      _showError('Failed to open file: $e');
    }
  }

  void _openVideo(List<MediaFile> files, MediaFile file, int index) {
    try {
      final videoFiles = files.where((f) => f.type == MediaType.video).toList();
      final videoIndex = videoFiles.indexOf(file);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerLauncher.screen(
            url:
                'https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8',
            index: videoIndex >= 0 ? videoIndex : 0,
          ),
        ),
      );
    } catch (e) {
      _showError('Failed to play video: $e');
    }
  }

  void _openAudio(List<MediaFile> files, MediaFile file) {
    try {
      final audioFiles = files.where((f) => f.type == MediaType.audio).toList();
      final audioIndex = audioFiles.indexOf(file);

      AudioPlaybackHelper.playAudio(
        ref,
        file,
        audioFiles,
        startIndex: audioIndex >= 0 ? audioIndex : 0,
      );
    } catch (e) {
      _showError('Failed to play audio: $e');
    }
  }

  void _openImage(List<MediaFile> files, MediaFile file) {
    try {
      final imageFiles = files.where((f) => f.type == MediaType.image).toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ImageViewerScreen(initialImage: file, images: imageFiles),
        ),
      );
    } catch (e) {
      _showError('Failed to open image: $e');
    }
  }

  void _openDocument(List<MediaFile> files, MediaFile file) {
    try {
      if (file.documentType == DocumentType.pdf) {
        final pdfFiles = files
            .where((f) => f.documentType == DocumentType.pdf)
            .toList();
        final pdfIndex = pdfFiles.indexOf(file);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFViewerScreen(
              mediaFile: file,
              playlist: pdfFiles,
              currentIndex: pdfIndex >= 0 ? pdfIndex : 0,
            ),
          ),
        );
      } else {
        _showFileDetailsSheet(file);
      }
    } catch (e) {
      _showError('Failed to open document: $e');
    }
  }

  void _showFileOptionsSheet(MediaFile file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // File info header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFileThumbnail(file),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            path.basename(file.path),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                _formatFileSize(file.size),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.favorite,
                                size: 12,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Favorite',
                                style: TextStyle(
                                  color: Colors.red[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Open'),
                onTap: () {
                  Navigator.pop(context);
                  final currentFavorites = _getCurrentTabFavorites();
                  currentFavorites.whenData((favorites) {
                    final index = favorites.indexOf(file);
                    if (index >= 0) {
                      _openFile(favorites, index);
                    }
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Details'),
                onTap: () {
                  Navigator.pop(context);
                  _showFileDetailsSheet(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Open File Location'),
                onTap: () {
                  Navigator.pop(context);
                  _showSuccess('Location: ${path.dirname(file.path)}');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.favorite_border, color: Colors.red),
                title: const Text(
                  'Remove from Favorites',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ref
                        .read(favoritesNotifierProvider.notifier)
                        .removeFromFavorites(file.id);
                    _showSuccess('Removed from favorites');
                    _refresh();
                  } catch (e) {
                    _showError('Failed to remove: $e');
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileDetailsSheet(MediaFile file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'File Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Name', path.basename(file.path)),
                _buildDetailRow('Type', file.type.name.toUpperCase()),
                _buildDetailRow('Size', _formatFileSize(file.size)),
                _buildDetailRow('Location', path.dirname(file.path)),
                if (file.duration != null)
                  _buildDetailRow(
                    'Duration',
                    _formatDuration(file.duration! as Duration),
                  ),
                if (file.width != null && file.height != null)
                  _buildDetailRow(
                    'Resolution',
                    '${file.width} × ${file.height}',
                  ),
                _buildDetailRow(
                  'Added',
                  _formatDateTime(file.dateAdded ?? DateTime.now()),
                ),
                _buildDetailRow('Modified', _formatDateTime(file.dateModified)),
                _buildDetailRow('Favorite', 'Yes'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // ============ Utility Methods ============

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  IconData _getMediaTypeIcon(MediaType type) {
    switch (type) {
      case MediaType.video:
        return Icons.videocam;
      case MediaType.audio:
        return Icons.audiotrack;
      case MediaType.image:
        return Icons.image;
      case MediaType.document:
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getMediaTypeColor(MediaType type) {
    switch (type) {
      case MediaType.video:
        return Colors.blue;
      case MediaType.audio:
        return Colors.purple;
      case MediaType.image:
        return Colors.green;
      case MediaType.document:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

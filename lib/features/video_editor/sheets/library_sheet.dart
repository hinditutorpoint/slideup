import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/file_picker_service.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path/path.dart' as path;

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';
import 'package:slideup/services/thumbnail_service.dart';

// ═══════════════════════════════════════════════════════
// ✅ LIBRARY SHEET (YouCut Style - Multi-Select)
// ═══════════════════════════════════════════════════════

class LibrarySheet extends ConsumerStatefulWidget {
  final MediaType? filterType; // null = show all
  final bool allowMultiple;
  final int? maxSelection;

  const LibrarySheet({
    super.key,
    this.filterType,
    this.allowMultiple = true,
    this.maxSelection,
  });

  @override
  ConsumerState<LibrarySheet> createState() => _LibrarySheetState();
}

class _LibrarySheetState extends ConsumerState<LibrarySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Media lists
  List<LocalMediaItem> _allMedia = [];
  List<LocalMediaItem> _videos = [];
  List<LocalMediaItem> _images = [];
  List<LocalMediaItem> _audio = [];

  // Albums (device galleries)
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  int _currentPage = 0;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  static const int _pageSize = 60;

  // Selection state
  final Set<String> _selectedIds = {};

  // Loading state
  bool _isLoading = true;
  //bool _isLoadingMore = false;
  String? _error;

  // View mode
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.filterType == null ? 4 : 1,
      vsync: this,
    );
    _loadMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _scanLocalMedia(reset: true);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load media: $e';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _selectedAlbum == null) return;
    setState(() => _isLoadingMore = true);
    try {
      await _scanLocalMedia(reset: false);
    } catch (e) {
      debugPrint('❌ Load more error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _selectAlbum(AssetPathEntity album) {
    if (_selectedAlbum?.id == album.id) return;
    _selectedAlbum = album;
    _loadMedia();
  }

  Future<void> _scanLocalMedia({bool reset = true}) async {
    if (reset) {
      _videos = [];
      _images = [];
      _audio = [];
      _allMedia = [];
      _currentPage = 0;
      _hasMore = false;
      try {
        final perm = await PhotoManager.requestPermissionExtend();
        if (!perm.isAuth) {
          if (mounted) setState(() {});
          return;
        }
        _albums = await PhotoManager.getAssetPathList(type: RequestType.all);
        _selectedAlbum ??= _albums.firstWhere(
          (a) => a.isAll,
          orElse: () => _albums.first,
        );
      } catch (e) {
        debugPrint('❌ Fetch albums error: $e');
        _albums = [];
        _selectedAlbum = null;
      }
    }

    final album = _selectedAlbum;
    if (album == null) {
      if (mounted) setState(() => _allMedia = []);
      return;
    }

    try {
      final assets = await album.getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );

      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;

        final type = _assetType(asset.type);
        final duration = type == MediaType.video
            ? asset.videoDuration
            : type == MediaType.audio
            ? Duration(milliseconds: asset.duration)
            : null;

        Uint8List? thumb;
        if (type != MediaType.audio) {
          thumb = await asset.thumbnailDataWithOption(
            ThumbnailOption(
              size: const ThumbnailSize(240, 240),
              quality: 80,
              format: ThumbnailFormat.jpeg,
            ),
          );
        }

        final assetTitle = asset.title ?? '';
        final item = LocalMediaItem(
          id: asset.id,
          name: assetTitle.isNotEmpty
              ? assetTitle
              : path.basename(file.path),
          path: file.path,
          type: type,
          size: await _safeFileSize(file),
          addedAt: DateTime.now(),
          duration: duration,
          thumbnail: thumb,
        );

        switch (type) {
          case MediaType.video:
            _videos.add(item);
            break;
          case MediaType.image:
            _images.add(item);
            break;
          case MediaType.audio:
            _audio.add(item);
            break;
          default:
            break;
        }
      }

      _currentPage++;
      _hasMore = assets.length >= _pageSize;

      if (mounted) {
        setState(() {
          _allMedia = [..._videos, ..._images, ..._audio];
        });
      }
    } catch (e) {
      debugPrint('❌ Scan local media error: $e');
    }
  }

  MediaType _assetType(AssetType type) {
    switch (type) {
      case AssetType.video:
        return MediaType.video;
      case AssetType.image:
        return MediaType.image;
      case AssetType.audio:
        return MediaType.audio;
      default:
        return MediaType.video;
    }
  }

  Future<int> _safeFileSize(File file) async {
    try {
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

  Future<void> _pickFiles(MediaType type) async {
    try {
      FileType fileType;
      List<String>? allowedExtensions;

      switch (type) {
        case MediaType.video:
          fileType = FileType.video;
          break;
        case MediaType.image:
          fileType = FileType.image;
          break;
        case MediaType.audio:
          fileType = FileType.audio;
          break;
        default:
          fileType = FileType.any;
          allowedExtensions = [
            'mp4',
            'mov',
            'avi',
            'mkv',
            'webm',
            'jpg',
            'jpeg',
            'png',
            'gif',
            'webp',
            'mp3',
            'wav',
            'aac',
            'ogg',
            'flac',
          ];
      }

      final result = await FilePickerService.pickFiles(
        type: fileType,
        allowMultiple: widget.allowMultiple,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.isNotEmpty) {
        final newItems = <LocalMediaItem>[];

        for (final file in result.files) {
          if (file.path == null) continue;

          final mediaType = _getMediaType(file.path!);
          final item = LocalMediaItem(
            id: DateTime.now().millisecondsSinceEpoch.toString() + file.name,
            name: file.name,
            path: file.path!,
            type: mediaType,
            size: file.size,
            addedAt: DateTime.now(),
          );

          // Generate thumbnail for videos
          if (mediaType == MediaType.video) {
            item.thumbnail = await _generateVideoThumbnail(file.path!);
          }

          newItems.add(item);
        }

        setState(() {
          for (final item in newItems) {
            _allMedia.add(item);

            switch (item.type) {
              case MediaType.video:
                _videos.add(item);
                break;
              case MediaType.image:
                _images.add(item);
                break;
              case MediaType.audio:
                _audio.add(item);
                break;
              default:
                break;
            }

            // Auto-select new items
            _selectedIds.add(item.id);
          }
        });

        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('Failed to pick files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Uint8List?> _generateVideoThumbnail(String videoPath) async {
    try {
      final thumbnail = await ThumbnailService.instance
          .generateVideoThumbnailBytes(videoPath, width: 200, quality: 75);
      return thumbnail;
    } catch (e) {
      debugPrint('Failed to generate thumbnail: $e');
      return null;
    }
  }

  MediaType _getMediaType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();

    if (['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'].contains(ext)) {
      return MediaType.video;
    } else if ([
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
    ].contains(ext)) {
      return MediaType.image;
    } else if ([
      '.mp3',
      '.wav',
      '.aac',
      '.ogg',
      '.flac',
      '.m4a',
    ].contains(ext)) {
      return MediaType.audio;
    }

    return MediaType.video; // Default
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          _buildHandleBar(),

          // Header
          _buildHeader(),

          // Album selector
          if (_albums.isNotEmpty) _buildAlbumSelector(),

          // Tab bar (if showing all types)
          if (widget.filterType == null) _buildTabBar(),

          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                ? _buildErrorState()
                : widget.filterType == null
                ? _buildTabContent()
                : _buildMediaList(_getFilteredList()),
          ),

          // Selection bar (when items selected)
          if (_selectedIds.isNotEmpty) _buildSelectionBar(),

          // Bottom action buttons
          _buildBottomActions(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HEADER
  // ═══════════════════════════════════════════════════════

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.folder_open, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Media Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_allMedia.length} items',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // View toggle
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view,
              color: Colors.white70,
            ),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
              HapticFeedback.selectionClick();
            },
          ),

          // Close
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TAB BAR
  // ═══════════════════════════════════════════════════════

  Widget _buildAlbumSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            dropdownColor: const Color(0xFF2A2A2A),
            value: _selectedAlbum?.id,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
            hint: const Text(
              'Select album',
              style: TextStyle(color: Colors.white54),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (id) {
              final match = _albums.cast<AssetPathEntity?>().firstWhere(
                (a) => a?.id == id,
                orElse: () => null,
              );
              if (match != null) _selectAlbum(match);
            },
            items: _albums
                .map(
                  (a) => DropdownMenuItem<String>(
                    value: a.id,
                    child: Text(
                      a.name,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apps, size: 16),
                const SizedBox(width: 4),
                Text('All (${_allMedia.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.movie, size: 16),
                const SizedBox(width: 4),
                Text('Video (${_videos.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image, size: 16),
                const SizedBox(width: 4),
                Text('Image (${_images.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.music_note, size: 16),
                const SizedBox(width: 4),
                Text('Audio (${_audio.length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildMediaList(_allMedia),
        _buildMediaList(_videos),
        _buildMediaList(_images),
        _buildMediaList(_audio),
      ],
    );
  }

  List<LocalMediaItem> _getFilteredList() {
    switch (widget.filterType) {
      case MediaType.video:
        return _videos;
      case MediaType.image:
        return _images;
      case MediaType.audio:
        return _audio;
      default:
        return _allMedia;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MEDIA LIST/GRID
  // ═══════════════════════════════════════════════════════

  Widget _buildMediaList(List<LocalMediaItem> items) {
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) return _buildLoadMoreFooter();
          return _buildGridItem(items[index]);
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) return _buildLoadMoreFooter();
          return _buildListItem(items[index]);
        },
      );
    }
  }

  Widget _buildLoadMoreFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: _loadMore,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
                label: const Text(
                  'Load more',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
      ),
    );
  }

  Widget _buildGridItem(LocalMediaItem item) {
    final isSelected = _selectedIds.contains(item.id);

    return GestureDetector(
      onTap: () => _toggleSelection(item),
      onLongPress: () => _showItemOptions(item),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4CAF50)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            _buildItemThumbnail(item),

            // Type indicator
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getTypeColor(item.type),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getTypeIcon(item.type),
                      size: 10,
                      color: Colors.white,
                    ),
                    if (item.duration != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(item.duration!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),

            // Selection overlay
            if (isSelected)
              Container(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(LocalMediaItem item) {
    final isSelected = _selectedIds.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF4CAF50)
              : Colors.white.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleSelection(item),
          onLongPress: () => _showItemOptions(item),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getTypeColor(item.type).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildItemThumbnail(item),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _getTypeIcon(item.type),
                            size: 12,
                            color: _getTypeColor(item.type),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.type.name.toUpperCase(),
                            style: TextStyle(
                              color: _getTypeColor(item.type),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.sizeFormatted,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                          if (item.duration != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(item.duration!),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Selection checkbox
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4CAF50)
                        : Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4CAF50)
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemThumbnail(LocalMediaItem item) {
    if (item.thumbnail != null) {
      return Image.memory(item.thumbnail!, fit: BoxFit.cover);
    } else if (item.type == MediaType.image) {
      return Image.file(
        File(item.path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(item.type),
      );
    } else {
      return _buildPlaceholder(item.type);
    }
  }

  Widget _buildPlaceholder(MediaType type) {
    return Container(
      color: _getTypeColor(type).withValues(alpha: 0.2),
      child: Center(
        child: Icon(_getTypeIcon(type), size: 28, color: _getTypeColor(type)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SELECTION BAR
  // ═══════════════════════════════════════════════════════

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_selectedIds.length} selected',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _clearSelection,
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _selectAll,
            child: const Text(
              'Select All',
              style: TextStyle(color: Color(0xFF4CAF50)),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BOTTOM ACTIONS
  // ═══════════════════════════════════════════════════════

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Add from device
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showAddOptions(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Media'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Insert selected
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _selectedIds.isNotEmpty ? _insertSelected : null,
                icon: const Icon(Icons.add_to_photos, size: 18),
                label: Text(
                  _selectedIds.isEmpty
                      ? 'Select Items'
                      : 'Insert ${_selectedIds.length} Items',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ STATES
  // ═══════════════════════════════════════════════════════

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF4CAF50)),
          SizedBox(height: 16),
          Text('Loading media...', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMedia,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.folder_open,
                  size: 50,
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No media files',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the button below to add\nmedia from your device',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showAddOptions(),
                icon: const Icon(Icons.add),
                label: const Text('Add Media'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DIALOGS
  // ═══════════════════════════════════════════════════════

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF2D2D2D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Add Media',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              _buildAddOption(
                icon: Icons.movie,
                label: 'Videos',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles(MediaType.video);
                },
              ),
              _buildAddOption(
                icon: Icons.image,
                label: 'Images',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles(MediaType.image);
                },
              ),
              _buildAddOption(
                icon: Icons.music_note,
                label: 'Audio',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles(MediaType.audio);
                },
              ),
              _buildAddOption(
                icon: Icons.folder,
                label: 'All Media',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _pickFiles(MediaType.clip); // Any file
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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

  void _showItemOptions(LocalMediaItem item) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF2D2D2D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Item preview
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _getTypeColor(item.type).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildItemThumbnail(item),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.type.name} • ${item.sizeFormatted}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Actions
              _buildOptionTile(
                icon: Icons.add_to_photos,
                label: 'Insert to Timeline',
                onTap: () {
                  Navigator.pop(context);
                  _insertItem(item);
                },
              ),
              _buildOptionTile(
                icon: Icons.info_outline,
                label: 'View Details',
                onTap: () {
                  Navigator.pop(context);
                  _showItemDetails(item);
                },
              ),
              _buildOptionTile(
                icon: Icons.delete_outline,
                label: 'Remove from List',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _removeItem(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
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

  void _showItemDetails(LocalMediaItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text(
          'Media Details',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', item.name),
            _buildDetailRow('Type', item.type.name.toUpperCase()),
            _buildDetailRow('Size', item.sizeFormatted),
            if (item.duration != null)
              _buildDetailRow('Duration', _formatDuration(item.duration!)),
            _buildDetailRow('Path', item.path),
          ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTIONS
  // ═══════════════════════════════════════════════════════

  void _toggleSelection(LocalMediaItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        if (widget.maxSelection != null &&
            _selectedIds.length >= widget.maxSelection!) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum ${widget.maxSelection} items allowed'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        _selectedIds.add(item.id);
      }
    });
    HapticFeedback.selectionClick();
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
    HapticFeedback.lightImpact();
  }

  void _selectAll() {
    final currentList = _tabController.index == 0
        ? _allMedia
        : _tabController.index == 1
        ? _videos
        : _tabController.index == 2
        ? _images
        : _audio;

    setState(() {
      for (final item in currentList) {
        if (widget.maxSelection != null &&
            _selectedIds.length >= widget.maxSelection!) {
          break;
        }
        _selectedIds.add(item.id);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _removeItem(LocalMediaItem item) {
    setState(() {
      _allMedia.removeWhere((i) => i.id == item.id);
      _videos.removeWhere((i) => i.id == item.id);
      _images.removeWhere((i) => i.id == item.id);
      _audio.removeWhere((i) => i.id == item.id);
      _selectedIds.remove(item.id);
    });
    HapticFeedback.lightImpact();
  }

  void _insertItem(LocalMediaItem item) {
    _insertItems([item]);
  }

  void _insertSelected() {
    final selectedItems = _allMedia
        .where((item) => _selectedIds.contains(item.id))
        .toList();
    _insertItems(selectedItems);
  }

  void _insertItems(List<LocalMediaItem> items) {
    final currentPosition = ref.read(currentPositionProvider);
    Duration insertPosition = currentPosition;

    for (final item in items) {
      switch (item.type) {
        case MediaType.image:
          ref
              .read(timelineProvider.notifier)
              .addImageItem(
                imagePath: item.path,
                startTime: insertPosition,
                duration: const Duration(seconds: 3),
                width: 1920, // Default, should be actual size
                height: 1080,
              );
          insertPosition += const Duration(seconds: 3);
          break;

        case MediaType.audio:
          ref
              .read(timelineProvider.notifier)
              .addAudioItem(
                audioPath: item.path,
                title: item.name,
                startTime: insertPosition,
                audioDuration: item.duration ?? const Duration(seconds: 30),
              );
          insertPosition += item.duration ?? const Duration(seconds: 30);
          break;

        case MediaType.video:
          ref.read(timelineProvider.notifier).addPrimaryClip(
                PrimaryVideoClip(
                  id: item.id,
                  videoPath: item.path,
                  sourceDuration: item.duration ?? const Duration(seconds: 10),
                  thumbnail: item.thumbnail,
                ),
              );
          break;

        default:
          break;
      }
    }

    HapticFeedback.mediumImpact();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${items.length} item(s) added to timeline'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  IconData _getTypeIcon(MediaType type) {
    switch (type) {
      case MediaType.video:
        return Icons.movie;
      case MediaType.audio:
        return Icons.music_note;
      case MediaType.image:
        return Icons.image;
      case MediaType.clip:
        return Icons.content_cut;
    }
  }

  Color _getTypeColor(MediaType type) {
    switch (type) {
      case MediaType.video:
        return Colors.blue;
      case MediaType.audio:
        return Colors.purple;
      case MediaType.image:
        return Colors.green;
      case MediaType.clip:
        return Colors.orange;
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}

// ═══════════════════════════════════════════════════════
// ✅ LOCAL MEDIA ITEM MODEL
// ═══════════════════════════════════════════════════════

class LocalMediaItem {
  final String id;
  final String name;
  final String path;
  final MediaType type;
  final int size;
  final DateTime addedAt;
  final Duration? duration;
  Uint8List? thumbnail;

  LocalMediaItem({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.addedAt,
    this.duration,
    this.thumbnail,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

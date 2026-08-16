import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/playlist.dart';
import '../models/media_file.dart';
import '../services/settings_service.dart';
import '../providers/playlist_provider.dart';
import '../providers/media_provider.dart';
import '../providers/image_provider.dart';
import '../services/file_scanner_service.dart';
import '../services/database_service.dart';
import '../widgets/media_item_card.dart';
import '../features/video_player/video_player_launcher.dart';
import '../helpers/audio_playback_helper.dart';
import 'pdf_viewer_screen.dart';
import 'image_viewer_screen.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  late bool _isGridView;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isGridView = SettingsService.instance.isGridView;
  }

  // Responsive breakpoints
  bool get _isTablet => MediaQuery.of(context).size.width >= 600;
  bool get _isDesktop => MediaQuery.of(context).size.width >= 1024;

  int get _gridCrossAxisCount {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 5;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  double get _gridChildAspectRatio {
    if (_isDesktop) return 0.85;
    if (_isTablet) return 0.8;
    return 0.75;
  }

  @override
  Widget build(BuildContext context) {
    final mediaFiles = ref.watch(
      playlistMediaFilesProvider(widget.playlist.id),
    );

    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            mediaFiles.when(
              data: (files) => _buildContent(files),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(error.toString()),
            ),
            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.playlist.name, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add Media',
          onPressed: _isLoading ? null : _showAddMediaDialog,
        ),
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          tooltip: _isGridView ? 'List View' : 'Grid View',
          onPressed: () {
            setState(() => _isGridView = !_isGridView);
            SettingsService.instance.setIsGridView(_isGridView);
          },
        ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
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
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.clear_all, color: Colors.orange),
                  SizedBox(width: 12),
                  Text('Clear Playlist'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(List<MediaFile> files) {
    if (files.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        if (_errorMessage != null) _buildErrorBanner(),
        _buildPlaylistHeader(files.length),
        Expanded(
          child: _isGridView ? _buildGridView(files) : _buildListView(files),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_add,
              size: _isTablet ? 120 : 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Empty Playlist',
              style: TextStyle(
                fontSize: _isTablet ? 28 : 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add media files to this playlist',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: _isTablet ? 18 : 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showAddMediaDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Files'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickFilesDirectly,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Browse Files'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshPlaylist,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.red[100],
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[700], fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _errorMessage = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Adding files...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistHeader(int itemCount) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_isTablet ? 24 : 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 500;

          if (isWide) {
            return _buildWideHeader(itemCount);
          }
          return _buildCompactHeader(itemCount);
        },
      ),
    );
  }

  Widget _buildWideHeader(int itemCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildPlaylistIcon(size: 100),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.playlist.description != null) ...[
                Text(
                  widget.playlist.description!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildPlayButtons(itemCount),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactHeader(int itemCount) {
    return Column(
      children: [
        _buildPlaylistIcon(size: 100),
        const SizedBox(height: 16),
        if (widget.playlist.description != null) ...[
          Text(
            widget.playlist.description!,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 16),
        _buildPlayButtons(itemCount),
      ],
    );
  }

  Widget _buildPlaylistIcon({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        widget.playlist.isLocked ? Icons.lock : Icons.playlist_play,
        size: size * 0.5,
        color: Colors.white,
      ),
    );
  }

  Widget _buildPlayButtons(int itemCount) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: itemCount > 0 ? _playAll : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Play All'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        OutlinedButton.icon(
          onPressed: itemCount > 0 ? _shufflePlay : null,
          icon: const Icon(Icons.shuffle),
          label: const Text('Shuffle'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildGridView(List<MediaFile> files) {
    return GridView.builder(
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridCrossAxisCount,
        crossAxisSpacing: _isTablet ? 16 : 12,
        mainAxisSpacing: _isTablet ? 16 : 12,
        childAspectRatio: _gridChildAspectRatio,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        return _buildMediaCard(files, index);
      },
    );
  }

  Widget _buildListView(List<MediaFile> files) {
    return ReorderableListView.builder(
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
      itemCount: files.length,
      onReorder: (oldIndex, newIndex) =>
          _onReorderItems(files, oldIndex, newIndex),
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        return _buildListItem(files, index);
      },
    );
  }

  Widget _buildMediaCard(List<MediaFile> files, int index) {
    final file = files[index];

    return GestureDetector(
      onTap: () => _playFile(files, index),
      onLongPress: () => _showFileOptions(file),
      child: MediaItemCard(
        key: ValueKey(file.id),
        mediaFile: file,
        onTap: () => _playFile(files, index),
        onLongPress: () => _showFileOptions(file),
      ),
    );
  }

  Widget _buildListItem(List<MediaFile> files, int index) {
    final file = files[index];

    return Card(
      key: ValueKey(file.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle, color: Colors.grey),
            ),
            const SizedBox(width: 8),
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
            if (file.duration != null) ...[
              const SizedBox(width: 8),
              Text(
                _formatDuration(file.duration! as Duration),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showFileOptions(file),
        ),
        onTap: () => _playFile(files, index),
        onLongPress: () => _showFileOptions(file),
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
    switch (action) {
      case 'refresh':
        _refreshPlaylist();
        break;
      case 'clear':
        _showClearPlaylistDialog();
        break;
    }
  }

  Future<void> _refreshPlaylist() async {
    try {
      ref.invalidate(playlistMediaFilesProvider(widget.playlist.id));
    } catch (e) {
      _showError('Failed to refresh: $e');
    }
  }

  void _onReorderItems(List<MediaFile> files, int oldIndex, int newIndex) {
    try {
      if (oldIndex < newIndex) newIndex--;

      final newMediaIds = files.map((f) => f.id).toList();
      final item = newMediaIds.removeAt(oldIndex);
      newMediaIds.insert(newIndex, item);

      ref
          .read(playlistsProvider.notifier)
          .updatePlaylist(
            widget.playlist.copyWith(
              mediaIds: newMediaIds,
              updatedAt: DateTime.now(),
            ),
          );
    } catch (e) {
      _showError('Failed to reorder: $e');
    }
  }

  void _playFile(List<MediaFile> files, int index) {
    try {
      final file = files[index];

      // Check if file exists
      if (!File(file.path).existsSync()) {
        _showError('File not found: ${path.basename(file.path)}');
        return;
      }

      switch (file.type) {
        case MediaType.video:
          _playVideo(files, file, index);
          break;
        case MediaType.audio:
          _playAudio(files, file);
          break;
        case MediaType.document:
          _openDocument(files, file);
          break;
        case MediaType.image:
          _openImage(files, file);
          break;
        default:
          _showFileDetails(file);
          break;
      }
    } catch (e) {
      _showError('Failed to open file: $e');
    }
  }

  void _playVideo(List<MediaFile> files, MediaFile file, int index) {
    try {
      final videoFiles = files.where((f) => f.type == MediaType.video).toList();
      final videoIndex = videoFiles.indexOf(file);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerLauncher.screen(
            files: videoFiles,
            file: file,
            index: videoIndex >= 0 ? videoIndex : 0,
          ),
        ),
      );
    } catch (e) {
      _showError('Failed to play video: $e');
    }
  }

  void _playAudio(List<MediaFile> files, MediaFile file) {
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
        _showFileDetails(file);
      }
    } catch (e) {
      _showError('Failed to open document: $e');
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

  void _playAll() {
    try {
      final mediaFiles = ref.read(
        playlistMediaFilesProvider(widget.playlist.id),
      );

      mediaFiles.whenData((files) {
        if (files.isEmpty) {
          _showError('Playlist is empty');
          return;
        }

        // Try to play videos first
        final videoFiles = files
            .where((f) => f.type == MediaType.video)
            .toList();
        if (videoFiles.isNotEmpty) {
          _playVideo(files, videoFiles.first, 0);
          return;
        }

        // Then try audio
        final audioFiles = files
            .where((f) => f.type == MediaType.audio)
            .toList();
        if (audioFiles.isNotEmpty) {
          _playAudio(files, audioFiles.first);
          return;
        }

        // Then try PDFs
        final pdfFiles = files
            .where((f) => f.documentType == DocumentType.pdf)
            .toList();
        if (pdfFiles.isNotEmpty) {
          _openDocument(files, pdfFiles.first);
          return;
        }

        // Then try images
        final imageFiles = files
            .where((f) => f.type == MediaType.image)
            .toList();
        if (imageFiles.isNotEmpty) {
          _openImage(files, imageFiles.first);
          return;
        }

        _showError('No playable media found');
      });
    } catch (e) {
      _showError('Failed to play: $e');
    }
  }

  void _shufflePlay() {
    try {
      final mediaFiles = ref.read(
        playlistMediaFilesProvider(widget.playlist.id),
      );

      mediaFiles.whenData((files) {
        if (files.isEmpty) {
          _showError('Playlist is empty');
          return;
        }

        final shuffledFiles = [...files]..shuffle();
        _playFile(shuffledFiles, 0);
      });
    } catch (e) {
      _showError('Failed to shuffle play: $e');
    }
  }

  // ============ Add Media Methods ============

  void _showAddMediaDialog() {
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Add to Playlist',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              _buildAddOption(
                icon: Icons.file_open,
                title: 'Pick Files',
                subtitle: 'Select files from storage',
                onTap: () {
                  Navigator.pop(context);
                  _pickFilesDirectly();
                },
              ),
              _buildAddOption(
                icon: Icons.folder_open,
                title: 'Add Folder',
                subtitle: 'Add all media from a folder',
                onTap: () {
                  Navigator.pop(context);
                  _pickFolder();
                },
              ),
              const Divider(height: 1),
              _buildAddOption(
                icon: Icons.video_library,
                title: 'From Video Library',
                subtitle: 'Add from scanned videos',
                onTap: () {
                  Navigator.pop(context);
                  _showLibraryPicker(MediaType.video);
                },
              ),
              _buildAddOption(
                icon: Icons.library_music,
                title: 'From Audio Library',
                subtitle: 'Add from scanned audio',
                onTap: () {
                  Navigator.pop(context);
                  _showLibraryPicker(MediaType.audio);
                },
              ),
              _buildAddOption(
                icon: Icons.photo_library,
                title: 'From Image Library',
                subtitle: 'Add from scanned images',
                onTap: () {
                  Navigator.pop(context);
                  _showLibraryPicker(MediaType.image);
                },
              ),
              _buildAddOption(
                icon: Icons.description,
                title: 'From Document Library',
                subtitle: 'Add from scanned documents',
                onTap: () {
                  Navigator.pop(context);
                  _showLibraryPicker(MediaType.document);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _pickFilesDirectly() async {
    try {
      setState(() => _isLoading = true);

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          // Video
          'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', '3gp',
          // Audio
          'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma',
          // Images
          'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
          // Documents
          'pdf', 'doc', 'docx', 'txt', 'epub',
        ],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      int addedCount = 0;
      int failedCount = 0;

      for (final platformFile in result.files) {
        try {
          if (platformFile.path == null) continue;

          final file = File(platformFile.path!);
          if (!await file.exists()) continue;

          // Create or get media file
          final mediaFile = await _getOrCreateMediaFile(platformFile.path!);
          if (mediaFile != null) {
            await ref
                .read(playlistsProvider.notifier)
                .addMediaToPlaylist(widget.playlist.id, mediaFile.id);
            addedCount++;
          } else {
            failedCount++;
          }
        } catch (e) {
          failedCount++;
          debugPrint('Error adding file: $e');
        }
      }

      setState(() => _isLoading = false);

      if (mounted) {
        _showSuccess(
          'Added $addedCount file(s)${failedCount > 0 ? ', $failedCount failed' : ''}',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to pick files: $e');
    }
  }

  Future<void> _pickFolder() async {
    try {
      final folderPath = await FilePicker.platform.getDirectoryPath();
      if (folderPath == null) return;

      setState(() => _isLoading = true);

      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        setState(() => _isLoading = false);
        _showError('Folder does not exist');
        return;
      }

      // Scan folder for media files
      final files = await FileScannerService.instance.scanDirectory(folderPath);

      if (files.isEmpty) {
        setState(() => _isLoading = false);
        _showError('No media files found in folder');
        return;
      }

      int addedCount = 0;
      for (final file in files) {
        try {
          await ref
              .read(playlistsProvider.notifier)
              .addMediaToPlaylist(widget.playlist.id, file.id);
          addedCount++;
        } catch (e) {
          debugPrint('Error adding file: $e');
        }
      }

      setState(() => _isLoading = false);

      if (mounted) {
        _showSuccess('Added $addedCount file(s) from folder');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to scan folder: $e');
    }
  }

  Future<MediaFile?> _getOrCreateMediaFile(String filePath) async {
    try {
      final db = DatabaseService.instance;

      // Check if file already exists in database
      final existingFile = await db.getMediaFileByPath(filePath);
      if (existingFile != null) {
        return existingFile;
      }

      // Create new media file entry
      final file = File(filePath);
      final stat = await file.stat();
      final extension = path
          .extension(filePath)
          .toLowerCase()
          .replaceAll('.', '');

      final mediaType = _getMediaTypeFromExtension(extension);
      final documentType = mediaType == MediaType.document
          ? _getDocumentTypeFromExtension(extension)
          : null;

      final mediaFile = MediaFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: filePath,
        name: path.basename(filePath),
        type: mediaType,
        size: stat.size,
        dateAdded: DateTime.now(),
        dateModified: stat.modified,
        documentType: documentType,
      );

      await db.insertMediaFile(mediaFile);
      return mediaFile;
    } catch (e) {
      debugPrint('Error creating media file: $e');
      return null;
    }
  }

  void _showLibraryPicker(MediaType type) {
    showDialog(
      context: context,
      builder: (context) => _LibraryPickerDialog(
        mediaType: type,
        playlistId: widget.playlist.id,
        existingMediaIds: widget.playlist.mediaIds,
        onFilesSelected: (files) async {
          try {
            setState(() => _isLoading = true);

            int addedCount = 0;
            for (final file in files) {
              try {
                await ref
                    .read(playlistsProvider.notifier)
                    .addMediaToPlaylist(widget.playlist.id, file.id);
                addedCount++;
              } catch (e) {
                debugPrint('Error adding file: $e');
              }
            }

            setState(() => _isLoading = false);
            _showSuccess('Added $addedCount file(s)');
          } catch (e) {
            setState(() => _isLoading = false);
            _showError('Failed to add files: $e');
          }
        },
      ),
    );
  }

  // ============ File Options ============

  void _showFileOptions(MediaFile file) {
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
                          Text(
                            _formatFileSize(file.size),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
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
                leading: const Icon(Icons.info_outline),
                title: const Text('File Details'),
                onTap: () {
                  Navigator.pop(context);
                  _showFileDetails(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Open File Location'),
                onTap: () {
                  Navigator.pop(context);
                  _openFileLocation(file);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red,
                ),
                title: const Text(
                  'Remove from Playlist',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeFromPlaylist(file);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileDetails(MediaFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name', path.basename(file.path)),
              _buildDetailRow('Type', file.type.name.toUpperCase()),
              _buildDetailRow('Size', _formatFileSize(file.size)),
              _buildDetailRow('Location', path.dirname(file.path)),
              if (file.duration != null)
                _buildDetailRow(
                  'Duration',
                  _formatDuration(file.duration as Duration),
                ),
              _buildDetailRow(
                'Added',
                _formatDate(file.dateAdded ?? DateTime.now()),
              ),
              _buildDetailRow('Modified', _formatDate(file.dateModified)),
            ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _openFileLocation(MediaFile file) {
    try {
      final directory = path.dirname(file.path);
      _showSuccess('File location: $directory');
    } catch (e) {
      _showError('Failed to open location: $e');
    }
  }

  void _removeFromPlaylist(MediaFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Playlist'),
        content: Text(
          'Remove "${path.basename(file.path)}" from this playlist?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              try {
                ref
                    .read(playlistsProvider.notifier)
                    .removeMediaFromPlaylist(widget.playlist.id, file.id);
                _showSuccess('Removed from playlist');
              } catch (e) {
                _showError('Failed to remove: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showClearPlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Playlist'),
        content: const Text(
          'Remove all items from this playlist? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              try {
                ref
                    .read(playlistsProvider.notifier)
                    .updatePlaylist(
                      widget.playlist.copyWith(
                        mediaIds: [],
                        updatedAt: DateTime.now(),
                      ),
                    );
                _showSuccess('Playlist cleared');
              } catch (e) {
                _showError('Failed to clear playlist: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // ============ Utility Methods ============

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

  MediaType _getMediaTypeFromExtension(String extension) {
    const videoExtensions = [
      'mp4',
      'mkv',
      'avi',
      'mov',
      'wmv',
      'flv',
      'webm',
      '3gp',
      'ts',
      'rmvb',
      'vob',
      'mpeg',
    ];
    const audioExtensions = ['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma'];
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    const documentExtensions = ['pdf', 'doc', 'docx', 'txt', 'epub'];

    if (videoExtensions.contains(extension)) return MediaType.video;
    if (audioExtensions.contains(extension)) return MediaType.audio;
    if (imageExtensions.contains(extension)) return MediaType.image;
    if (documentExtensions.contains(extension)) return MediaType.document;
    return MediaType.other;
  }

  DocumentType? _getDocumentTypeFromExtension(String extension) {
    switch (extension) {
      case 'pdf':
        return DocumentType.pdf;
      case 'doc':
      case 'docx':
        return DocumentType.word;
      case 'txt':
        return DocumentType.text;
      case 'epub':
        return DocumentType.epub;
      default:
        return null;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ============ Library Picker Dialog ============

class _LibraryPickerDialog extends ConsumerStatefulWidget {
  final MediaType mediaType;
  final String playlistId;
  final List<String> existingMediaIds;
  final Function(List<MediaFile>) onFilesSelected;

  const _LibraryPickerDialog({
    required this.mediaType,
    required this.playlistId,
    required this.existingMediaIds,
    required this.onFilesSelected,
  });

  @override
  ConsumerState<_LibraryPickerDialog> createState() =>
      _LibraryPickerDialogState();
}

class _LibraryPickerDialogState extends ConsumerState<_LibraryPickerDialog> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final mediaProvider = _getProviderForType(widget.mediaType);
    final mediaFiles = ref.watch(mediaProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(_getIconForType(widget.mediaType)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Select ${widget.mediaType.name.toUpperCase()}s'),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Search bar
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            const SizedBox(height: 12),
            // File list
            Expanded(
              child: mediaFiles.when(
                data: (files) {
                  // Filter out already added files
                  var availableFiles = files
                      .where((f) => !widget.existingMediaIds.contains(f.id))
                      .toList();

                  // Apply search filter
                  if (_searchQuery.isNotEmpty) {
                    availableFiles = availableFiles
                        .where(
                          (f) => path
                              .basename(f.path)
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()),
                        )
                        .toList();
                  }

                  if (availableFiles.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No files available',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: availableFiles.length,
                    itemBuilder: (context, index) {
                      final file = availableFiles[index];
                      final isSelected = _selectedIds.contains(file.id);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedIds.add(file.id);
                            } else {
                              _selectedIds.remove(file.id);
                            }
                          });
                        },
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _getColorForType(
                              widget.mediaType,
                            ).withValues(alpha: 0.2),
                          ),
                          child: Icon(
                            _getIconForType(widget.mediaType),
                            color: _getColorForType(widget.mediaType),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          path.basename(file.path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _formatFileSize(file.size),
                          style: const TextStyle(fontSize: 12),
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_selectedIds.isNotEmpty)
          TextButton(
            onPressed: () => setState(() => _selectedIds.clear()),
            child: const Text('Clear'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedIds.isEmpty || _isLoading
              ? null
              : () async {
                  try {
                    setState(() => _isLoading = true);

                    final db = DatabaseService.instance;
                    final selectedFiles = <MediaFile>[];

                    for (final id in _selectedIds) {
                      try {
                        final file = await db.getMediaFileById(id);
                        if (file != null) {
                          selectedFiles.add(file);
                        }
                      } catch (e) {
                        debugPrint('Error getting file: $e');
                      }
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    widget.onFilesSelected(selectedFiles);
                  } catch (e) {
                    setState(() => _isLoading = false);
                    debugPrint('Error selecting files: $e');
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Add (${_selectedIds.length})'),
        ),
      ],
    );
  }

  FutureProvider<List<MediaFile>> _getProviderForType(MediaType type) {
    switch (type) {
      case MediaType.video:
        return videosProvider;
      case MediaType.audio:
        return audiosProvider;
      case MediaType.image:
        return imagesProvider;
      case MediaType.document:
        return documentsProvider;
      default:
        return videosProvider;
    }
  }

  IconData _getIconForType(MediaType type) {
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

  Color _getColorForType(MediaType type) {
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
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

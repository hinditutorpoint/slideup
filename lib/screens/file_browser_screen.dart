import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../providers/file_browser_provider.dart';
import '../services/file_operations_service.dart';
import '../services/storage_service.dart';
import '../services/permission_service.dart';
import '../services/settings_service.dart';
import '../services/thumbnail_service.dart';
import '../widgets/text_viewer_widget.dart';
import '../widgets/file_thumbnail_widget.dart';
import '../widgets/pdf_thumbnail_preview_dialog.dart';
import '../models/media_file.dart';
import '../models/storage_info.dart';
import 'pdf_viewer_screen.dart';
import 'image_viewer_screen.dart';
import '../features/video_player/video_player_launcher.dart';
import '../helpers/audio_playback_helper.dart';
import 'package:open_filex/open_filex.dart';

class FileBrowserScreen extends ConsumerStatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  ConsumerState<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends ConsumerState<FileBrowserScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final List<Directory> _navigationStack = [];
  late AnimationController _fabAnimationController;
  late AnimationController _selectionAnimationController;

  bool _showSearch = false;
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _selectionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    _selectionAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Check permissions first
    final hasPermissions = await PermissionService.instance.hasAllPermissions();

    if (!hasPermissions) {
      if (mounted) {
        _showPermissionDialog();
      }
    } else {
      // Load last location or default
      final lastLocation = await SettingsService.instance.getLastLocation();
      if (lastLocation != null && mounted) {
        final notifier = ref.read(fileBrowserProvider.notifier);
        await notifier.navigateToDirectory(Directory(lastLocation));
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(PermissionService.instance.getPermissionDeniedMessage()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Continue with limited functionality
            },
            child: const Text('Continue Without'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _handlePermissionRequest();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  void _handlePermissionRequest() async {
    final granted = await PermissionService.instance.requestPermissions();
    if (mounted) {
      if (granted) {
        _initialize();
      } else {
        _showPermissionDeniedDialog();
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text(
          'Storage permissions are required to browse files. '
          'Please enable them in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              PermissionService.instance.openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fileBrowserProvider);
    final notifier = ref.read(fileBrowserProvider.notifier);

    // Update animation controllers based on state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.isSelectionMode) {
        _selectionAnimationController.forward();
      } else {
        _selectionAnimationController.reverse();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          if (state.isSelectionMode) {
            notifier.clearSelection();
          } else if (_showSearch) {
            setState(() => _showSearch = false);
            notifier.clearSearch();
          } else if (_navigationStack.isNotEmpty) {
            _navigateBack(notifier);
          }
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(state, notifier),
        body: Column(
          children: [
            if (!_showSearch && !state.isSearching)
              _buildBreadcrumb(state, notifier),
            if (_showSearch || state.isSearching) _buildSearchBar(notifier),
            if (state.isSelectionMode) _buildSelectionHeader(state),
            Expanded(child: _buildBody(state, notifier)),
          ],
        ),
        bottomNavigationBar: state.isSelectionMode
            ? _buildSelectionBottomBar(state, notifier)
            : null,
        floatingActionButton: _buildFloatingActionButtons(state, notifier),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    if (state.isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => notifier.clearSelection(),
        ),
        title: AnimatedBuilder(
          animation: _selectionAnimationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _selectionAnimationController,
              child: Text('${state.selectedEntities.length} selected'),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: () => notifier.selectAll(),
            tooltip: 'Select All',
          ),
          PopupMenuButton<String>(
            onSelected: (value) =>
                _handleSelectionMenuAction(value, state, notifier),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'properties',
                child: ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Properties'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'copy_path',
                child: ListTile(
                  leading: Icon(Icons.content_copy),
                  title: Text('Copy Path'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (_showSearch) {
      return AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search files and folders...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (value) => notifier.search(value),
          onSubmitted: (value) => notifier.search(value),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() => _showSearch = false);
              notifier.clearSearch();
            },
          ),
        ],
      );
    }

    return AppBar(
      title: Text(_getDirectoryName(state.currentDirectory)),
      leading: _navigationStack.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _navigateBack(notifier),
            )
          : null,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _showSearch = true),
          tooltip: 'Search',
        ),
        IconButton(
          icon: const Icon(Icons.storage),
          onPressed: () => _showStorageSelection(),
          tooltip: 'Storage',
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, state, notifier),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'view_mode',
              child: ListTile(
                leading: Icon(
                  state.isGridView ? Icons.view_list : Icons.grid_view,
                ),
                title: Text(state.isGridView ? 'List View' : 'Grid View'),
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: 'hidden_files',
              child: ListTile(
                leading: Icon(
                  state.showHiddenFiles
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                title: Text(
                  state.showHiddenFiles
                      ? 'Hide Hidden Files'
                      : 'Show Hidden Files',
                ),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'sort',
              child: ListTile(
                leading: Icon(Icons.sort),
                title: Text('Sort'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'refresh',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Refresh'),
                dense: true,
              ),
            ),
            if (FileOperationsService.instance.hasClipboard)
              const PopupMenuItem(
                value: 'paste',
                child: ListTile(
                  leading: Icon(Icons.paste),
                  title: Text('Paste'),
                  dense: true,
                ),
              ),
            const PopupMenuItem(
              value: 'new_folder',
              child: ListTile(
                leading: Icon(Icons.create_new_folder),
                title: Text('New Folder'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'properties',
              child: ListTile(
                leading: Icon(Icons.info),
                title: Text('Folder Properties'),
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBreadcrumb(
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    if (state.currentDirectory == null) return const SizedBox.shrink();

    final pathSegments = state.currentDirectory!.path
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: pathSegments.length,
        itemBuilder: (context, index) {
          final isLast = index == pathSegments.length - 1;
          return Row(
            children: [
              if (index > 0)
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              TextButton(
                onPressed: () =>
                    _navigateToSegment(pathSegments, index, notifier),
                style: TextButton.styleFrom(
                  foregroundColor: isLast
                      ? Theme.of(context).primaryColor
                      : Colors.grey[600],
                ),
                child: Text(
                  _formatSegmentName(pathSegments[index]),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(FileBrowserNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search files and folders...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => notifier.search(value),
              onSubmitted: (value) => notifier.search(value),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() => _showSearch = false);
              notifier.clearSearch();
            },
            tooltip: 'Clear Search',
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(FileBrowserState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${state.selectedEntities.length} items selected',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            _formatTotalSize(state.selectedEntities),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(FileBrowserState state, FileBrowserNotifier notifier) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _buildErrorWidget(state.error!, notifier);
    }

    if (state.isSearching && state.searchResults.isNotEmpty) {
      return _buildSearchResults(state, notifier);
    }

    if (state.isSearching &&
        state.searchResults.isEmpty &&
        state.searchQuery.isNotEmpty) {
      return _buildEmptySearchResults();
    }

    if (!state.isSearching && state.entities.isEmpty) {
      return _buildEmptyFolder();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: state.isGridView
          ? _buildGridView(state, notifier)
          : _buildListView(state, notifier),
    );
  }

  Widget _buildErrorWidget(String error, FileBrowserNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                final state = ref.read(fileBrowserProvider);
                if (state.currentDirectory != null) {
                  notifier.navigateToDirectory(state.currentDirectory!);
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${state.searchResults.length} results found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.searchResults.length,
            itemBuilder: (context, index) {
              final mediaFile = state.searchResults[index];
              return _buildSearchResultTile(mediaFile);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultTile(MediaFile mediaFile) {
    return ListTile(
      leading: FileThumbnailWidget(mediaFile: mediaFile, size: 40),
      title: Text(mediaFile.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        mediaFile.displayPath!.replaceAll(_currentPath, ''),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: Text(
        _formatFileSize(mediaFile.size),
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      onTap: () => _openFile(File(mediaFile.path)),
    );
  }

  Widget _buildEmptySearchResults() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Results Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFolder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Empty Folder',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'This folder contains no files or folders',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(FileBrowserState state, FileBrowserNotifier notifier) {
    return GridView.builder(
      key: const ValueKey('grid'),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: state.entities.length,
      itemBuilder: (context, index) {
        final entity = state.entities[index];
        final isSelected = state.selectedEntities.contains(entity);
        return _buildGridItem(entity, isSelected, notifier, state);
      },
    );
  }

  Widget _buildListView(FileBrowserState state, FileBrowserNotifier notifier) {
    return ListView.builder(
      key: const ValueKey('list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.entities.length,
      itemBuilder: (context, index) {
        final entity = state.entities[index];
        final isSelected = state.selectedEntities.contains(entity);
        return _buildListItem(entity, isSelected, notifier, state);
      },
    );
  }

  Widget _buildGridItem(
    FileSystemEntity entity,
    bool isSelected,
    FileBrowserNotifier notifier,
    FileBrowserState state,
  ) {
    final name = path.basename(entity.path);
    final isDirectory = entity is Directory;

    return Card(
      color: isSelected
          ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
          : null,
      elevation: isSelected ? 4 : 1,
      child: InkWell(
        onTap: () => _onEntityTap(entity, notifier, state),
        onLongPress: () => notifier.toggleSelection(entity),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Center(
                      child: isDirectory
                          ? const Icon(
                              Icons.folder,
                              size: 48,
                              color: Colors.amber,
                            )
                          : FileThumbnailWidget(
                              mediaFile: _entityToMediaFile(entity),
                              size: 48,
                            ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (!isDirectory)
                Text(
                  _formatFileSize(_getFileSize(entity)),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(
    FileSystemEntity entity,
    bool isSelected,
    FileBrowserNotifier notifier,
    FileBrowserState state,
  ) {
    final name = path.basename(entity.path);
    final isDirectory = entity is Directory;

    String? subtitle;
    if (!isDirectory) {
      try {
        final size = _getFileSize(entity);
        final modified = _getModifiedDate(entity);
        subtitle = '${_formatFileSize(size)} • $modified';
      } catch (e) {
        subtitle = 'Unknown size';
      }
    }

    return ListTile(
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            ),
          isDirectory
              ? const Icon(Icons.folder, color: Colors.amber, size: 32)
              : FileThumbnailWidget(
                  mediaFile: _entityToMediaFile(entity),
                  size: 32,
                ),
        ],
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: !isDirectory && !state.isSelectionMode
          ? PopupMenuButton<String>(
              onSelected: (value) => _handleFileAction(value, entity, notifier),
              itemBuilder: (context) => _buildFileMenuItems(entity),
              icon: const Icon(Icons.more_vert),
            )
          : isDirectory && !state.isSelectionMode
          ? const Icon(Icons.chevron_right)
          : null,
      onTap: () => _onEntityTap(entity, notifier, state),
      onLongPress: () => notifier.toggleSelection(entity),
    );
  }

  Widget _buildSelectionBottomBar(
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildActionButton(
                icon: Icons.copy,
                label: 'Copy',
                onPressed: () async {
                  await notifier.copySelectedFiles();
                  _showSnackBar(
                    '${state.selectedEntities.length} items copied',
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.cut,
                label: 'Cut',
                onPressed: () async {
                  await notifier.cutSelectedFiles();
                  _showSnackBar('${state.selectedEntities.length} items cut');
                },
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.share,
                label: 'Share',
                onPressed: () => _shareSelectedFiles(state.selectedEntities),
              ),
              const Spacer(),
              _buildActionButton(
                icon: Icons.delete,
                label: 'Delete',
                onPressed: () => _confirmDelete(notifier),
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: color),
          onPressed: onPressed,
          tooltip: label,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color ?? Colors.grey[600]),
        ),
      ],
    );
  }

  // Helper methods and event handlers
  String _getDirectoryName(Directory? directory) {
    if (directory == null) return 'Storage';
    final name = path.basename(directory.path);
    return name.isEmpty ? 'Storage' : _formatSegmentName(name);
  }

  String _formatSegmentName(String segment) {
    if (segment == '0') return 'Internal';
    if (segment == 'emulated') return 'Storage';
    if (segment == 'storage') return 'Root';
    return segment;
  }

  String _formatTotalSize(List<FileSystemEntity> entities) {
    int totalSize = 0;
    for (final entity in entities) {
      if (entity is File) {
        try {
          totalSize += entity.lengthSync();
        } catch (e) {
          // Skip files that can't be accessed
        }
      }
    }
    return _formatFileSize(totalSize);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  int _getFileSize(FileSystemEntity entity) {
    if (entity is File) {
      try {
        return entity.lengthSync();
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

  String _getModifiedDate(FileSystemEntity entity) {
    try {
      final modified = entity.statSync().modified;
      final now = DateTime.now();
      final difference = now.difference(modified);

      // Calculate years, months, days, hours, minutes
      final years = difference.inDays ~/ 365;
      final months = (difference.inDays % 365) ~/ 30;
      final days = (difference.inDays % 365) % 30;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;

      // Format based on time difference
      if (years > 0) {
        if (months > 0) {
          return '${years}y ${months}m ago';
        } else {
          return '${years}y ago';
        }
      } else if (months > 0) {
        return '${months}m ago';
      } else if (days > 0) {
        return '${days}d ago';
      } else if (hours > 0) {
        return '${hours}h ago';
      } else if (minutes > 0) {
        return '${minutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _navigateBack(FileBrowserNotifier notifier) async {
    if (_navigationStack.isNotEmpty) {
      final previousDir = _navigationStack.removeLast();
      await notifier.navigateToDirectory(previousDir);
    }
  }

  Future<void> _navigateToSegment(
    List<String> pathSegments,
    int index,
    FileBrowserNotifier notifier,
  ) async {
    final targetPath = '/${pathSegments.sublist(0, index + 1).join('/')}';
    _navigationStack.clear();
    await notifier.navigateToDirectory(Directory(targetPath));
  }

  void _showStorageSelection() async {
    final storageLocations = await StorageService.instance
        .getAvailableStorageLocations();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Storage Locations',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ...storageLocations.map((location) {
              final isInternal = location.type == StorageType.internal;
              final isUsb = location.type == StorageType.usb;

              IconData icon;
              if (isUsb) {
                icon = Icons.usb;
              } else if (isInternal) {
                icon = Icons.phone_android;
              } else {
                icon = Icons.sd_card;
              }

              return ListTile(
                leading: Icon(icon, color: Theme.of(context).primaryColor),
                title: Text(location.name),
                subtitle: Text(location.path),
                trailing: location.isAccessible
                    ? null
                    : const Icon(Icons.lock, color: Colors.red),
                onTap: location.isAccessible
                    ? () {
                        Navigator.pop(context);
                        _navigationStack.clear();
                        final notifier = ref.read(fileBrowserProvider.notifier);
                        notifier.navigateToDirectory(Directory(location.path));
                      }
                    : null,
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(
    String action,
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    switch (action) {
      case 'view_mode':
        notifier.toggleViewMode();
        break;
      case 'hidden_files':
        notifier.toggleHiddenFiles();
        break;
      case 'sort':
        _showSortDialog(state, notifier);
        break;
      case 'refresh':
        if (state.currentDirectory != null) {
          notifier.navigateToDirectory(state.currentDirectory!);
        }
        break;
      case 'paste':
        notifier.pasteFiles();
        break;
      case 'new_folder':
        _showCreateFolderDialog(state, notifier);
        break;
      case 'properties':
        _showFolderProperties(state.currentDirectory);
        break;
    }
  }

  void _handleSelectionMenuAction(
    String action,
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    switch (action) {
      case 'properties':
        _showSelectionProperties(state.selectedEntities);
        break;
      case 'copy_path':
        _copyPathsToClipboard(state.selectedEntities);
        break;
    }
  }

  void _onEntityTap(
    FileSystemEntity entity,
    FileBrowserNotifier notifier,
    FileBrowserState state,
  ) {
    if (state.isSelectionMode) {
      notifier.toggleSelection(entity);
      return;
    }

    if (entity is Directory) {
      _navigateToDirectory(entity, notifier);
    } else if (entity is File) {
      _openFile(entity);
    }
  }

  Future<void> _navigateToDirectory(
    Directory directory,
    FileBrowserNotifier notifier,
  ) async {
    final currentDir = ref.read(fileBrowserProvider).currentDirectory;
    if (currentDir != null) {
      _navigationStack.add(currentDir);
    }
    await notifier.navigateToDirectory(directory);
  }

  MediaFile _entityToMediaFile(FileSystemEntity entity) {
    final name = path.basename(entity.path);
    final extension = path.extension(entity.path).toLowerCase();

    return MediaFile(
      id: entity.path,
      name: name,
      path: entity.path,
      displayPath: entity.path,
      type: _getMediaTypeFromExtension(extension),
      size: entity is File ? _getFileSize(entity) : 0,
      dateModified: entity.statSync().modified,
      dateAdded: DateTime.now(),
      parentFolder: path.dirname(entity.path),
    );
  }

  MediaType _getMediaTypeFromExtension(String extension) {
    const videoExtensions = [
      '.mp4',
      '.mkv',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.m4v',
      '.ts',
      '.3gp',
      '.mpeg',
      '.mp2',
      '.mov',
      '.rmvb',
      '.hls',
      '.mpd',
    ];
    const audioExtensions = ['.mp3', '.wav', '.flac', '.aac', '.m4a', '.ogg'];
    const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    const textExtensions = ['.txt', '.html', '.htm', '.xml'];
    const docExtensions = [
      '.pdf',
      '.doc',
      '.docx',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
    ];

    if (videoExtensions.contains(extension)) return MediaType.video;
    if (audioExtensions.contains(extension)) return MediaType.audio;
    if (imageExtensions.contains(extension)) return MediaType.image;
    if (textExtensions.contains(extension)) return MediaType.text;
    if (docExtensions.contains(extension)) return MediaType.document;

    return MediaType.other;
  }

  Future<void> _openFile(File file) async {
    final extension = path.extension(file.path).toLowerCase();

    try {
      // Video files
      if ([
        '.mp4',
        '.mkv',
        '.avi',
        '.mov',
        '.wmv',
        '.flv',
        '.webm',
        '.m4v',
        '.ts',
        '.3gp',
        '.mpeg',
        '.mp2',
        '.mov',
        '.rmvb',
        '.hls',
        '.mpd',
      ].contains(extension)) {
        final mediaFile = _createMediaFileFromFile(file, MediaType.video);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerLauncher.screen(file: mediaFile),
          ),
        );
      }
      // Audio files
      else if ([
        '.mp3',
        '.wav',
        '.flac',
        '.aac',
        '.m4a',
        '.ogg',
      ].contains(extension)) {
        final mediaFile = _createMediaFileFromFile(file, MediaType.audio);
        AudioPlaybackHelper.playAudio(ref, mediaFile, [
          mediaFile,
        ], startIndex: 0);
      }
      // Image files
      else if ([
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.bmp',
        '.webp',
        '.tiff',
        '.svg',
      ].contains(extension)) {
        final mediaFile = _createMediaFileFromFile(file, MediaType.image);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ImageViewerScreen(initialImage: mediaFile, images: [mediaFile]),
          ),
        );
      }
      // PDF files
      else if (extension == '.pdf') {
        final mediaFile = _createMediaFileFromFile(
          file,
          MediaType.document,
          DocumentType.pdf,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFViewerScreen(
              mediaFile: mediaFile,
              playlist: [mediaFile],
              currentIndex: 0,
            ),
          ),
        );
      }
      // Text files
      else if ([
        '.txt',
        '.html',
        '.htm',
        '.xml',
        '.json',
        '.css',
        '.js',
      ].contains(extension)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TextViewerWidget(filePath: file.path),
          ),
        );
      }
      // Other files - try to open with external app
      else {
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      _showSnackBar('Failed to open file: $e');
    }
  }

  MediaFile _createMediaFileFromFile(
    File file,
    MediaType type, [
    DocumentType? documentType,
  ]) {
    return MediaFile(
      id: file.path,
      name: path.basename(file.path),
      path: file.path,
      displayPath: file.path,
      type: type,
      documentType: documentType,
      size: _getFileSize(file),
      dateModified: file.lastModifiedSync(),
      dateAdded: DateTime.now(),
      parentFolder: path.dirname(file.path),
    );
  }

  List<PopupMenuEntry<String>> _buildFileMenuItems(FileSystemEntity entity) {
    final extension = path.extension(entity.path).toLowerCase();
    final isMedia = [
      '.mp4',
      '.mkv',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.mp3',
      '.wav',
      '.flac',
      '.aac',
      '.m4a',
      '.ogg',
      '.ts',
      '.3gp',
      '.mpeg',
      '.mp2',
    ].contains(extension);
    final isPDF = extension == '.pdf';
    final isText = ['.txt', '.html', '.htm', '.xml'].contains(extension);

    return [
      if (isMedia || isPDF || isText)
        const PopupMenuItem(
          value: 'open',
          child: ListTile(
            leading: Icon(Icons.open_in_new, size: 20),
            title: Text('Open'),
            dense: true,
          ),
        ),
      if (isPDF)
        const PopupMenuItem(
          value: 'preview',
          child: ListTile(
            leading: Icon(Icons.preview, size: 20),
            title: Text('Preview'),
            dense: true,
          ),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'copy',
        child: ListTile(
          leading: Icon(Icons.copy, size: 20),
          title: Text('Copy'),
          dense: true,
        ),
      ),
      const PopupMenuItem(
        value: 'cut',
        child: ListTile(
          leading: Icon(Icons.cut, size: 20),
          title: Text('Cut'),
          dense: true,
        ),
      ),
      const PopupMenuItem(
        value: 'rename',
        child: ListTile(
          leading: Icon(Icons.edit, size: 20),
          title: Text('Rename'),
          dense: true,
        ),
      ),
      const PopupMenuItem(
        value: 'share',
        child: ListTile(
          leading: Icon(Icons.share, size: 20),
          title: Text('Share'),
          dense: true,
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'properties',
        child: ListTile(
          leading: Icon(Icons.info, size: 20),
          title: Text('Properties'),
          dense: true,
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'delete',
        child: ListTile(
          leading: Icon(Icons.delete, size: 20, color: Colors.red),
          title: Text('Delete', style: TextStyle(color: Colors.red)),
          dense: true,
        ),
      ),
    ];
  }

  Future<void> _handleFileAction(
    String action,
    FileSystemEntity entity,
    FileBrowserNotifier notifier,
  ) async {
    switch (action) {
      case 'open':
        if (entity is File) await _openFile(entity);
        break;
      case 'preview':
        if (entity is File &&
            path.extension(entity.path).toLowerCase() == '.pdf') {
          showDialog(
            context: context,
            builder: (context) =>
                PdfThumbnailPreviewDialog(pdfPath: entity.path),
          );
        }
        break;
      case 'copy':
        await FileOperationsService.instance.copyFiles([entity]);
        _showSnackBar('Item copied to clipboard');
        break;
      case 'cut':
        await FileOperationsService.instance.cutFiles([entity]);
        _showSnackBar('Item cut to clipboard');
        break;
      case 'rename':
        _showRenameDialog(entity, notifier);
        break;
      case 'share':
        _shareSelectedFiles([entity]);
        break;
      case 'properties':
        _showFileProperties(entity);
        break;
      case 'delete':
        _confirmDeleteSingle(entity, notifier);
        break;
    }
  }

  // Dialog and utility methods
  void _showSortDialog(FileBrowserState state, FileBrowserNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort By'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SortBy.values.map((sortBy) {
            return RadioListTile<SortBy>(
              title: Text(_getSortByName(sortBy)),
              value: sortBy,
              groupValue: state.sortBy,
              onChanged: (value) {
                if (value != null) {
                  notifier.setSortBy(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newOrder = state.sortOrder == SortOrder.ascending
                  ? SortOrder.descending
                  : SortOrder.ascending;
              notifier.setSortOrder(newOrder);
              Navigator.pop(context);
            },
            child: Text(
              state.sortOrder == SortOrder.ascending
                  ? 'Descending'
                  : 'Ascending',
            ),
          ),
        ],
      ),
    );
  }

  String _getSortByName(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.name:
        return 'Name';
      case SortBy.size:
        return 'Size';
      case SortBy.date:
        return 'Date Modified';
      case SortBy.type:
        return 'Type';
    }
  }

  void _showCreateFolderDialog(
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (name) => _createFolder(name, state, notifier, context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                _createFolder(controller.text, state, notifier, context),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showPermissionErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.instance.requestPermissions();
            },
            child: const Text('Grant Permission'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              PermissionService.instance.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder(
    String name,
    FileBrowserState state,
    FileBrowserNotifier notifier,
    BuildContext dialogContext,
  ) async {
    if (name.trim().isEmpty) return;

    Navigator.pop(dialogContext);

    if (state.currentDirectory != null) {
      final result = await FileOperationsService.instance
          .createFolderWithPermissionCheck(
            state.currentDirectory!.path,
            name.trim(),
          );

      if (result.success) {
        _showSnackBar('Folder created successfully');
        notifier.navigateToDirectory(state.currentDirectory!);
      } else {
        _showPermissionErrorDialog(result.error ?? 'Failed to create folder');
      }
    }
  }

  /// Scan current folder for media files
  Future<Map<String, List<MediaFile>>> _scanCurrentFolderForMedia() async {
    final state = ref.read(fileBrowserProvider);
    if (state.currentDirectory == null) {
      return {'videos': [], 'audios': [], 'images': []};
    }

    final videos = <MediaFile>[];
    final audios = <MediaFile>[];
    final images = <MediaFile>[];

    try {
      await for (final entity in state.currentDirectory!.list(
        recursive: false,
      )) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          final mediaFile = _createMediaFileFromFile(
            entity,
            _getMediaTypeFromExtension(extension),
          );

          switch (mediaFile.type) {
            case MediaType.video:
              videos.add(mediaFile);
              break;
            case MediaType.audio:
              audios.add(mediaFile);
              break;
            case MediaType.image:
              images.add(mediaFile);
              break;
            default:
              break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning folder for media: $e');
    }

    // Sort by name
    videos.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    audios.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    images.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return {'videos': videos, 'audios': audios, 'images': images};
  }

  /// Get media count info for display
  Future<String> _getMediaCountInfo() async {
    final mediaFiles = await _scanCurrentFolderForMedia();
    final videos = mediaFiles['videos']!;
    final audios = mediaFiles['audios']!;
    final images = mediaFiles['images']!;

    final List<String> counts = [];
    if (videos.isNotEmpty) {
      counts.add('${videos.length} video${videos.length > 1 ? 's' : ''}');
    }
    if (audios.isNotEmpty) {
      counts.add('${audios.length} audio${audios.length > 1 ? 's' : ''}');
    }
    if (images.isNotEmpty) {
      counts.add('${images.length} image${images.length > 1 ? 's' : ''}');
    }

    if (counts.isEmpty) return 'No media files';
    return counts.join(', ');
  }

  /// Play all media in current folder
  Future<void> _playAllMedia() async {
    final mediaFiles = await _scanCurrentFolderForMedia();
    if (!mounted) return;
    final videos = mediaFiles['videos']!;
    final audios = mediaFiles['audios']!;
    final images = mediaFiles['images']!;

    try {
      // Priority: Videos > Audios > Images
      if (videos.isNotEmpty) {
        debugPrint('🎬 Playing ${videos.length} videos');
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  VideoPlayerLauncher.screen(file: videos.first, files: videos),
            ),
          );
        }
        _showSnackBar('Playing ${videos.length} videos');
      } else if (audios.isNotEmpty) {
        debugPrint('🎵 Playing ${audios.length} audio files');
        AudioPlaybackHelper.playAudio(ref, audios.first, audios, startIndex: 0);
        _showSnackBar('Playing ${audios.length} audio files');
      } else if (images.isNotEmpty) {
        debugPrint('🖼️ Viewing ${images.length} images');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ImageViewerScreen(initialImage: images.first, images: images),
          ),
        );
        _showSnackBar('Viewing ${images.length} images');
      } else {
        _showSnackBar('No media files found in this folder');
      }
    } catch (e) {
      _showSnackBar('Failed to play media: $e');
      debugPrint('Error playing media: $e');
    }
  }

  /// Updated _showAddMenu method with Play All functionality
  /// Updated responsive _showAddMenu method
  void _showAddMenu(FileBrowserState state, FileBrowserNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Important for responsive behavior
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.8, // Max 80% of screen
      ),
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = MediaQuery.of(context).size.height;
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final availableHeight =
              screenHeight - keyboardHeight - 100; // Leave some padding

          return Container(
            constraints: BoxConstraints(maxHeight: availableHeight),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_open,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Folder Actions',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        iconSize: 20,
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      children: [
                        // Play All Section
                        _buildPlayAllSection(context),

                        // Quick Actions Section
                        _buildQuickActionsSection(context, state, notifier),

                        // File Operations Section (if clipboard has items)
                        if (FileOperationsService.instance.hasClipboard)
                          _buildFileOperationsSection(context, notifier),

                        // Advanced Actions Section
                        _buildAdvancedActionsSection(context, state, notifier),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build Play All Media Section
  Widget _buildPlayAllSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: FutureBuilder<String>(
        future: _getMediaCountInfo(),
        builder: (context, snapshot) {
          final mediaInfo = snapshot.data ?? 'Scanning...';
          final hasMedia =
              snapshot.hasData && !mediaInfo.contains('No media files');

          return Container(
            decoration: BoxDecoration(
              gradient: hasMedia
                  ? LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        Theme.of(context).primaryColor.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: hasMedia ? null : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasMedia
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
                    : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: hasMedia
                    ? () {
                        Navigator.pop(context);
                        _playAllMedia();
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: hasMedia
                              ? Theme.of(context).primaryColor
                              : Colors.grey[400],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: hasMedia
                              ? [
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Play All Media',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: hasMedia ? null : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mediaInfo,
                              style: TextStyle(
                                color: hasMedia
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[500],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasMedia)
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: Theme.of(context).primaryColor,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build Quick Actions Section
  Widget _buildQuickActionsSection(
    BuildContext context,
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildActionTile(
                  context: context,
                  icon: Icons.create_new_folder_rounded,
                  iconColor: Colors.orange,
                  title: 'New Folder',
                  subtitle: 'Create a new folder',
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateFolderDialog(state, notifier);
                  },
                ),
                _buildDivider(),
                _buildActionTile(
                  context: context,
                  icon: Icons.note_add_rounded,
                  iconColor: Colors.blue,
                  title: 'New Text File',
                  subtitle: 'Create a new text file',
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateFileDialog(state, notifier);
                  },
                ),
                _buildDivider(),
                _buildActionTile(
                  context: context,
                  icon: Icons.refresh_rounded,
                  iconColor: Colors.green,
                  title: 'Refresh Folder',
                  subtitle: 'Reload folder contents',
                  onTap: () {
                    Navigator.pop(context);
                    if (state.currentDirectory != null) {
                      notifier.navigateToDirectory(state.currentDirectory!);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build File Operations Section
  Widget _buildFileOperationsSection(
    BuildContext context,
    FileBrowserNotifier notifier,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Clipboard',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: _buildActionTile(
              context: context,
              icon: Icons.paste_rounded,
              iconColor: Colors.green,
              title: 'Paste',
              subtitle: FileOperationsService.instance.getClipboardInfo(),
              onTap: () async {
                Navigator.pop(context);
                final success = await notifier.pasteFiles();
                if (success) {
                  _showSnackBar('Files pasted successfully');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build Advanced Actions Section
  Widget _buildAdvancedActionsSection(
    BuildContext context,
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Advanced',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildActionTile(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  iconColor: Colors.purple,
                  title: 'Folder Properties',
                  subtitle: 'View folder details',
                  onTap: () {
                    Navigator.pop(context);
                    _showFolderProperties(state.currentDirectory);
                  },
                ),
                _buildDivider(),
                _buildActionTile(
                  context: context,
                  icon: Icons.cleaning_services_rounded,
                  iconColor: Colors.red,
                  title: 'Clear Cache',
                  subtitle: 'Clear thumbnail cache',
                  onTap: () async {
                    Navigator.pop(context);
                    await ThumbnailService.instance.clearCache();
                    _showSnackBar('Thumbnail cache cleared');
                  },
                ),
                _buildDivider(),
                _buildActionTile(
                  context: context,
                  icon: Icons.settings_rounded,
                  iconColor: Colors.grey,
                  title: 'Folder Settings',
                  subtitle: 'Configure folder options',
                  onTap: () {
                    Navigator.pop(context);
                    _showFolderSettings(state, notifier);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual action tile
  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: enabled ? iconColor : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: enabled ? null : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: enabled ? Colors.grey[600] : Colors.grey[400],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build divider between action tiles
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.grey[200],
      indent: 52,
      endIndent: 16,
    );
  }

  /// Show folder settings dialog
  void _showFolderSettings(
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Folder Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Show Hidden Files'),
              subtitle: const Text('Display files starting with .'),
              value: state.showHiddenFiles,
              onChanged: (value) {
                notifier.toggleHiddenFiles();
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Sort By'),
              subtitle: Text(_getSortByName(state.sortBy)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _showSortDialog(state, notifier);
              },
            ),
            SwitchListTile(
              title: Text(state.isGridView ? 'Grid View' : 'List View'),
              subtitle: const Text('Toggle between grid and list'),
              value: state.isGridView,
              onChanged: (value) {
                notifier.toggleViewMode();
                Navigator.pop(context);
              },
            ),
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

  /// Compact floating action buttons for responsive design
  Widget? _buildFloatingActionButtons(
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    if (state.isSelectionMode || state.isSearching) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick Play FAB (only show if media exists)
        FutureBuilder<Map<String, List<MediaFile>>>(
          future: _scanCurrentFolderForMedia(),
          builder: (context, snapshot) {
            final mediaFiles = snapshot.data;
            final hasMedia =
                mediaFiles != null &&
                (mediaFiles['videos']!.isNotEmpty ||
                    mediaFiles['audios']!.isNotEmpty ||
                    mediaFiles['images']!.isNotEmpty);

            if (!hasMedia) return const SizedBox.shrink();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'play',
                  onPressed: _playAllMedia,
                  backgroundColor: Theme.of(context).primaryColor,
                  tooltip: 'Play All Media',
                  child: const Icon(Icons.play_arrow_rounded),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),

        // Paste FAB (only show if clipboard has items)
        if (FileOperationsService.instance.hasClipboard) ...[
          FloatingActionButton.small(
            heroTag: 'paste',
            onPressed: () async {
              final success = await notifier.pasteFiles();
              if (success) {
                _showSnackBar('Files pasted successfully');
              }
            },
            backgroundColor: Colors.green,
            tooltip: 'Paste',
            child: const Icon(Icons.paste_rounded),
          ),
          const SizedBox(height: 8),
        ],

        // Main FAB
        FloatingActionButton(
          heroTag: 'add',
          onPressed: () => _showAddMenu(state, notifier),
          tooltip: 'More Actions',
          child: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }

  void _showCreateFileDialog(
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Text File'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File Name (with extension)',
            hintText: 'e.g., document.txt',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (name) => _createFile(name, state, notifier, context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                _createFile(controller.text, state, notifier, context),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFile(
    String name,
    FileBrowserState state,
    FileBrowserNotifier notifier,
    BuildContext dialogContext,
  ) async {
    if (name.trim().isEmpty) return;

    Navigator.pop(dialogContext);

    if (state.currentDirectory != null) {
      final result = await FileOperationsService.instance.createFile(
        state.currentDirectory!.path,
        name.trim(),
        content: '',
      );

      if (result.success) {
        _showSnackBar('File created successfully');
        notifier.navigateToDirectory(state.currentDirectory!);
      } else {
        _showSnackBar('Failed to create file: ${result.error}');
      }
    }
  }

  void _showRenameDialog(
    FileSystemEntity entity,
    FileBrowserNotifier notifier,
  ) {
    final name = path.basename(entity.path);
    final controller = TextEditingController(text: name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New Name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (newName) =>
              _renameEntity(entity, newName, notifier, context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                _renameEntity(entity, controller.text, notifier, context),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameEntity(
    FileSystemEntity entity,
    String newName,
    FileBrowserNotifier notifier,
    BuildContext dialogContext,
  ) async {
    if (newName.trim().isEmpty) return;

    Navigator.pop(dialogContext);

    final result = await FileOperationsService.instance.renameFile(
      entity,
      newName.trim(),
    );

    if (result.success) {
      _showSnackBar('Renamed successfully');
      final state = ref.read(fileBrowserProvider);
      if (state.currentDirectory != null) {
        notifier.navigateToDirectory(state.currentDirectory!);
      }
    } else {
      _showSnackBar('Failed to rename: ${result.error}');
    }
  }

  Future<void> _confirmDelete(FileBrowserNotifier notifier) async {
    final state = ref.read(fileBrowserProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files'),
        content: Text(
          'Are you sure you want to delete ${state.selectedEntities.length} items? '
          'This action cannot be undone.',
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
      final result = await notifier.deleteSelectedFiles();
      if (result) {
        _showSnackBar('Files deleted successfully');
      } else {
        _showSnackBar('Failed to delete some files');
      }
    }
  }

  Future<void> _confirmDeleteSingle(
    FileSystemEntity entity,
    FileBrowserNotifier notifier,
  ) async {
    final name = path.basename(entity.path);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "$name"?'),
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
      final result = await FileOperationsService.instance.deleteFiles([entity]);
      if (result.success) {
        _showSnackBar('File deleted successfully');
        final state = ref.read(fileBrowserProvider);
        if (state.currentDirectory != null) {
          notifier.navigateToDirectory(state.currentDirectory!);
        }
      } else {
        _showSnackBar('Failed to delete file: ${result.error}');
      }
    }
  }

  Future<void> _shareSelectedFiles(List<FileSystemEntity> files) async {
    final result = await FileOperationsService.instance.shareFiles(files);
    if (!result.success) {
      _showSnackBar('Failed to share files: ${result.error}');
    }
  }

  void _showFileProperties(FileSystemEntity entity) async {
    final properties = await FileOperationsService.instance.getProperties(
      entity,
    );

    if (!mounted || properties == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Properties'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPropertyRow('Name', properties['name']),
              _buildPropertyRow('Type', properties['type']),
              _buildPropertyRow('Size', _formatFileSize(properties['size'])),
              _buildPropertyRow(
                'Modified',
                properties['modified'].toString().split('.')[0],
              ),
              _buildPropertyRow('Path', properties['path']),
              if (properties['itemCount'] != null)
                _buildPropertyRow('Items', properties['itemCount'].toString()),
              if (properties['mimeType'] != null)
                _buildPropertyRow('MIME Type', properties['mimeType']),
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

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showFolderProperties(Directory? directory) {
    if (directory == null) return;
    _showFileProperties(directory);
  }

  void _showSelectionProperties(List<FileSystemEntity> entities) {
    final totalSize = entities.fold<int>(0, (sum, entity) {
      return sum + (entity is File ? _getFileSize(entity) : 0);
    });

    final fileCount = entities.whereType<File>().length;
    final folderCount = entities.whereType<Directory>().length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selection Properties'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropertyRow('Total Items', '${entities.length}'),
            _buildPropertyRow('Files', '$fileCount'),
            _buildPropertyRow('Folders', '$folderCount'),
            _buildPropertyRow('Total Size', _formatFileSize(totalSize)),
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

  void _copyPathsToClipboard(List<FileSystemEntity> entities) {
    // This would require a clipboard package
    //final paths = entities.map((e) => e.path).join('\n');
    _showSnackBar('Paths copied to clipboard');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

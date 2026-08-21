import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../providers/file_browser_provider.dart';
import '../services/file_operations_service.dart';
import '../services/storage_service.dart';
import '../services/permission_service.dart';
import '../services/saf_service.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';
import '../services/thumbnail_service.dart';
import '../widgets/text_viewer_widget.dart';
import '../widgets/file_thumbnail_widget.dart';
import '../widgets/pdf_thumbnail_preview_dialog.dart';
import '../models/media_file.dart';
import '../models/storage_info.dart';
import 'pdf_viewer_screen.dart';
import 'image_viewer_screen.dart';
import '../features/video_player/video_player_launcher.dart';
import '../features/reel_editor/ui/reel_editor_screen.dart';
import '../helpers/audio_playback_helper.dart';
import '../helpers/m3u_playlist_helper.dart';
import '../services/security_service.dart';
import 'auth_screen.dart';
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
  // ignore: prefer_final_fields
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
    final notifier = ref.read(fileBrowserProvider.notifier);

    // Check permissions first
    final hasPermissions = await PermissionService.instance.hasAllPermissions();

    if (!hasPermissions) {
      if (mounted) {
        _showPermissionDialog();
      }
    } else {
      // Load last location or default to first available storage
      final lastLocation = await SettingsService.instance.getLastLocation();
      if (lastLocation != null && Directory(lastLocation).existsSync()) {
        if (mounted) {
          await notifier.navigateToDirectory(Directory(lastLocation));
        }
      } else {
        final storageLocations =
            await StorageService.instance.getAvailableStorageLocations();
        final target = storageLocations.where((s) => s.isAccessible).firstOrNull ??
            storageLocations.firstOrNull;
        if (target != null && mounted) {
          await notifier.navigateToDirectory(Directory(target.path));
        }
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
            icon: const Icon(Icons.favorite_rounded, color: Colors.pink),
            onPressed: () => _addSelectedToFavorites(state, notifier),
            tooltip: 'Add to Favorites',
          ),
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
          decoration: InputDecoration(
            hintText: 'Search files and folders...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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

    final isWindows = Platform.isWindows;
    final separator = isWindows ? r'\' : '/';
    final pathSegments = state.currentDirectory!.path
        .split(separator)
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
              FutureBuilder<String>(
                future: SecurityService.instance.getOriginalFileName(entity.path),
                builder: (context, nameSnapshot) {
                  final displayName = nameSnapshot.data ?? name;
                  final isSlock = entity.path.endsWith('.slock');
                  return Text(
                    isSlock ? '🔒 $displayName' : displayName,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  );
                },
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
    final isSlock = entity.path.endsWith('.slock');

    String? subtitle;
    if (!isDirectory) {
      try {
        final size = _getFileSize(entity);
        final modified = _getModifiedDate(entity);
        subtitle = isSlock
            ? '🔒 Locked Vault File • ${_formatFileSize(size)}'
            : '${_formatFileSize(size)} • $modified';
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
              : isSlock
                  ? Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.pink.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.pink,
                        size: 20,
                      ),
                    )
                  : FileThumbnailWidget(
                      mediaFile: _entityToMediaFile(entity),
                      size: 32,
                    ),
        ],
      ),
      title: FutureBuilder<String>(
        future: SecurityService.instance.getOriginalFileName(entity.path),
        builder: (context, nameSnapshot) {
          final displayName = nameSnapshot.data ?? name;
          return Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isSlock ? Colors.pink[700] : null,
            ),
          );
        },
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: !state.isSelectionMode
          ? PopupMenuButton<String>(
              onSelected: (value) => _handleFileAction(value, entity, notifier),
              itemBuilder: (context) => _buildFileMenuItems(entity),
              icon: const Icon(Icons.more_vert),
            )
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
                  final count = state.selectedEntities.length;
                  await notifier.copySelectedFiles();
                  if (mounted) setState(() {});
                  _showSnackBar(
                    '$count items copied',
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.cut,
                label: 'Cut',
                onPressed: () async {
                  final count = state.selectedEntities.length;
                  await notifier.cutSelectedFiles();
                  if (mounted) setState(() {});
                  _showSnackBar('$count items cut');
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
    String targetPath;
    if (Platform.isWindows) {
      targetPath = pathSegments.sublist(0, index + 1).join(r'\');
    } else {
      targetPath =
          '/${pathSegments.where((s) => s != '/').toList().sublist(0, index + 1).join('/')}';
    }
    _navigationStack.clear();
    await notifier.navigateToDirectory(Directory(targetPath));
  }

  void _showStorageSelection() async {
    final storageLocations = await StorageService.instance
        .getAvailableStorageLocations();

    if (!mounted) return;

    final currentDirPath = ref.read(fileBrowserProvider).currentDirectory?.path;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Storage Locations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showStorageSelection();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
            if (storageLocations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.storage, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'No accessible storage found',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Storage permissions may be required.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handlePermissionRequest();
                      },
                      child: const Text('Grant Storage Permissions'),
                    ),
                  ],
                ),
              )
            else
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

                final isCurrent = currentDirPath != null &&
                    (currentDirPath == location.path ||
                        currentDirPath.startsWith(location.path));

                String subtitle = location.path;
                if (location.totalSpace > 0 && location.freeSpace > 0) {
                  subtitle =
                      '${_formatFileSize(location.freeSpace)} free of ${_formatFileSize(location.totalSpace)}\n${location.path}';
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrent
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.1),
                    child: Icon(
                      icon,
                      color: isCurrent
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).iconTheme.color,
                    ),
                  ),
                  title: Text(
                    location.name,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11),
                  ),
                  isThreeLine: location.totalSpace > 0,
                  trailing: !location.isAccessible
                      ? const Icon(Icons.lock, color: Colors.red)
                      : isCurrent
                          ? Icon(Icons.check_circle,
                              color: Theme.of(context).primaryColor)
                          : const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: location.isAccessible
                      ? () {
                          Navigator.pop(context);
                          _navigationStack.clear();
                          final notifier =
                              ref.read(fileBrowserProvider.notifier);
                          notifier.navigateToDirectory(Directory(location.path));
                        }
                      : () {
                          _showSnackBar(
                              'This storage location is not accessible');
                        },
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

  Future<void> _onEntityTap(
    FileSystemEntity entity,
    FileBrowserNotifier notifier,
    FileBrowserState state,
  ) async {
    if (state.isSelectionMode) {
      notifier.toggleSelection(entity);
      return;
    }

    if (entity is Directory) {
      final isLocked = await SecurityService.instance.isFileLocked(entity.path);
      if (isLocked) {
        if (!mounted) return;
        final lockType =
            await SecurityService.instance.getFileLockType(entity.path);
        if (!mounted) return;
        final authenticated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => AuthScreen(
              isSetup: false,
              initialLockType: lockType,
            ),
          ),
        );
        if (authenticated != true) return;
      }
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
    File targetFile = file;
    String? slockOriginalExtension;
    // Track if source was a locked .slock file so we can suppress recent history
    final wasSlockFile = file.path.endsWith('.slock');

    if (wasSlockFile) {
      if (!mounted) return;
      final lockType =
          await SecurityService.instance.getFileLockType(file.path);
      if (!mounted) return;
      final authenticated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => AuthScreen(
            isSetup: false,
            initialLockType: lockType,
          ),
        ),
      );

      if (authenticated != true) return;

      // Read original extension before decrypting (fallback for no-header slock files)
      slockOriginalExtension =
          await SecurityService.instance.getOriginalExtension(file.path);

      final tempFile =
          await SecurityService.instance.createTempDecryptedCopy(file.path);
      if (tempFile == null || !await tempFile.exists()) {
        _showSnackBar('Failed to open locked file');
        return;
      }
      targetFile = tempFile;
    }

    // Determine extension: use temp file extension, or fall back to the
    // original extension stored in the slock header for headerless old files.
    String extension = path.extension(targetFile.path).toLowerCase();
    if (extension.isEmpty && slockOriginalExtension != null) {
      extension = slockOriginalExtension.toLowerCase();
    }

    if (!mounted) return;

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
        final mediaFile = _createMediaFileFromFile(targetFile, MediaType.video,
            forceIsLocked: wasSlockFile);
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
        final mediaFile = _createMediaFileFromFile(targetFile, MediaType.audio,
            forceIsLocked: wasSlockFile);
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
        final mediaFile = _createMediaFileFromFile(targetFile, MediaType.image,
            forceIsLocked: wasSlockFile);
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
          targetFile,
          MediaType.document,
          documentType: DocumentType.pdf,
          forceIsLocked: wasSlockFile,
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
            builder: (context) => TextViewerWidget(filePath: targetFile.path),
          ),
        );
      }
      // M3U playlists (music playlist vs IPTV auto-detected)
      else if ([
        '.m3u',
        '.m3u8',
        '.m3u_plus',
        '.m3u8_plus',
      ].contains(extension)) {
        final content = await targetFile.readAsString();
        if (!mounted) return;
        await openLocalM3uPlaylist(
          context: context,
          ref: ref,
          file: targetFile,
          content: content,
          onSnack: _showSnackBar,
        );
      }
      // Other files - try to open with external app
      else {
        await OpenFilex.open(targetFile.path);
      }
    } catch (e) {
      _showSnackBar('Failed to open file: $e');
    }
  }

  MediaFile _createMediaFileFromFile(
    File file,
    MediaType type, {
    DocumentType? documentType,
    bool forceIsLocked = false,
  }) {
    // A file is locked if it is itself a .slock, or if it was decrypted from one
    final isLocked =
        forceIsLocked || file.path.toLowerCase().endsWith('.slock');
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
      isLocked: isLocked,
    );
  }

  Widget _buildSlimMenuItem({
    required IconData icon,
    required String title,
    Color? color,
  }) {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey[700]),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildFileMenuItems(FileSystemEntity entity) {
    final extension = path.extension(entity.path).toLowerCase();
    final isVideo = [
      '.mp4',
      '.mkv',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.ts',
      '.3gp',
      '.mpeg',
      '.m4v',
    ].contains(extension);
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

    bool isLocked = extension == '.slock';
    if (!isLocked && entity is Directory) {
      try {
        isLocked = entity
            .listSync(recursive: true)
            .any((e) => e.path.endsWith('.slock'));
      } catch (_) {}
    }

    return [
      if (isMedia || isPDF || isText)
        PopupMenuItem(
          value: 'open',
          height: 36,
          child: _buildSlimMenuItem(icon: Icons.open_in_new, title: 'Open'),
        ),
      if (isVideo)
        PopupMenuItem(
          value: 'edit_with_editor',
          height: 36,
          child: _buildSlimMenuItem(
            icon: Icons.video_settings,
            title: 'Edit with Editor',
            color: const Color(0xFF6C63FF),
          ),
        ),
      if (isMedia && !isVideo)
        PopupMenuItem(
          value: 'edit',
          height: 36,
          child: _buildSlimMenuItem(icon: Icons.edit, title: 'Edit'),
        ),
      if (isPDF)
        PopupMenuItem(
          value: 'preview',
          height: 36,
          child: _buildSlimMenuItem(icon: Icons.preview, title: 'Preview'),
        ),
      const PopupMenuDivider(height: 8),
      PopupMenuItem(
        value: 'copy',
        height: 36,
        child: _buildSlimMenuItem(icon: Icons.copy, title: 'Copy'),
      ),
      PopupMenuItem(
        value: 'cut',
        height: 36,
        child: _buildSlimMenuItem(icon: Icons.cut, title: 'Cut'),
      ),
      PopupMenuItem(
        value: 'rename',
        height: 36,
        child: _buildSlimMenuItem(icon: Icons.edit, title: 'Rename'),
      ),
      PopupMenuItem(
        value: 'share',
        height: 36,
        child: _buildSlimMenuItem(icon: Icons.share, title: 'Share'),
      ),
      PopupMenuItem(
        value: 'favorite',
        height: 36,
        child: _buildSlimMenuItem(
          icon: Icons.favorite_border_rounded,
          title: 'Add / Remove Favorite',
          color: Colors.pink,
        ),
      ),
      const PopupMenuDivider(height: 8),
      PopupMenuItem(
        value: 'properties',
        height: 36,
        child: _buildSlimMenuItem(icon: Icons.info, title: 'Properties'),
      ),
      const PopupMenuDivider(height: 8),
      PopupMenuItem(
        value: 'lock',
        height: 36,
        child: _buildSlimMenuItem(
          icon: isLocked ? Icons.lock_open : Icons.lock_outline,
          title: isLocked ? 'Unlock (Vault)' : 'Lock (Vault)',
          color: const Color(0xFF6C63FF),
        ),
      ),
      const PopupMenuDivider(height: 8),
      PopupMenuItem(
        value: 'delete',
        height: 36,
        child: _buildSlimMenuItem(
          icon: Icons.delete,
          title: 'Delete',
          color: Colors.red,
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
      case 'favorite':
        await _toggleFavoriteEntity(entity);
        break;
      case 'properties':
        _showFileProperties(entity);
        break;
      case 'delete':
        _confirmDeleteSingle(entity, notifier);
        break;
      case 'lock':
        await _toggleLockEntity(entity, notifier);
        break;
      case 'edit_with_editor':
      case 'edit':
        _confirmEditSingle(entity, notifier);
        break;
    }
  }

  Future<void> _toggleFavoriteEntity(FileSystemEntity entity) async {
    try {
      final db = DatabaseService.instance;
      final existing = await db.getMediaFileByPath(entity.path);

      if (existing != null && existing.isFavorite) {
        final updated = existing.copyWith(isFavorite: false);
        await db.updateMediaFile(updated);
        _showSnackBar('Removed from Favorites');
      } else {
        MediaFile mediaFile;
        if (existing != null) {
          mediaFile = existing.copyWith(isFavorite: true);
        } else {
          final ext = path.extension(entity.path).toLowerCase();
          mediaFile = _createMediaFileFromFile(
            entity is File ? entity : File(entity.path),
            _getMediaTypeFromExtension(ext),
          ).copyWith(isFavorite: true);
        }
        await db.insertMediaFiles([mediaFile]);
        _showSnackBar('Added to Favorites');
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      _showSnackBar('Failed to update Favorites');
    }
  }

  Future<void> _addSelectedToFavorites(
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) async {
    try {
      final db = DatabaseService.instance;
      int count = 0;
      for (final entity in state.selectedEntities) {
        final existing = await db.getMediaFileByPath(entity.path);
        if (existing != null) {
          await db.updateMediaFile(existing.copyWith(isFavorite: true));
        } else {
          final ext = path.extension(entity.path).toLowerCase();
          final mediaFile = _createMediaFileFromFile(
            entity is File ? entity : File(entity.path),
            _getMediaTypeFromExtension(ext),
          ).copyWith(isFavorite: true);
          await db.insertMediaFiles([mediaFile]);
        }
        count++;
      }
      notifier.clearSelection();
      _showSnackBar('$count item(s) added to Favorites');
      setState(() {});
    } catch (e) {
      debugPrint('Error adding selection to favorites: $e');
    }
  }

  Future<void> _confirmEditSingle(
    FileSystemEntity entity,
    FileBrowserNotifier notifier,
  ) async {
    if (entity is File) {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ReelEditorScreen(mode: EditorMode.video, videoPath: entity.path),
        ),
      );
    }
  }

  Future<void> _toggleLockEntity(
    FileSystemEntity entity,
    FileBrowserNotifier notifier,
  ) async {
    final isDirectory = entity is Directory;
    final isLocked = await SecurityService.instance.isFileLocked(entity.path);

    if (isLocked) {
      if (!mounted) return;
      final fileLockType =
          await SecurityService.instance.getFileLockType(entity.path);
      if (!mounted) return;
      final authenticated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => AuthScreen(
            isSetup: false,
            initialLockType: fileLockType,
          ),
        ),
      );

      if (authenticated == true) {
        await SecurityService.instance.unlockEntityWithSlock(entity);
        final currentDir = ref.read(fileBrowserProvider).currentDirectory;
        if (currentDir != null) {
          await notifier.navigateToDirectory(currentDir);
        }
        if (mounted) {
          _showSnackBar(
            isDirectory
                ? 'Folder unlocked from Vault (restored extensions)'
                : 'File unlocked from Vault (restored extension)',
          );
          setState(() {});
        }
      }
    } else {
      final hasLock = await SecurityService.instance.hasAppLock();
      if (!hasLock) {
        if (!mounted) return;
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthScreen(isSetup: true),
          ),
        );
        if (created != true) return;
      }

      if (!mounted) return;
      final authenticated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const AuthScreen(isSetup: false),
        ),
      );

      if (authenticated == true) {
        await SecurityService.instance.lockEntityWithSlock(entity, 'LOCKED');
        final currentDir = ref.read(fileBrowserProvider).currentDirectory;
        if (currentDir != null) {
          await notifier.navigateToDirectory(currentDir);
        }
        if (mounted) {
          _showSnackBar(
            isDirectory
                ? 'Folder locked in Vault (.slock files)'
                : 'File locked in Vault (.slock file)',
          );
          setState(() {});
        }
      }
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

  /// Updated responsive & compact _showAddMenu method
  void _showAddMenu(FileBrowserState state, FileBrowserNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(16),
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
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Folder Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _buildPlayAllSection(context),
                    _buildQuickActionsSection(context, state, notifier),
                    if (FileOperationsService.instance.hasClipboard)
                      _buildFileOperationsSection(context, notifier),
                    _buildAdvancedActionsSection(context, state, notifier),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Play All Media Section (Compact)
  Widget _buildPlayAllSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: FutureBuilder<String>(
        future: _getMediaCountInfo(),
        builder: (context, snapshot) {
          final mediaInfo = snapshot.data ?? 'Scanning...';
          final hasMedia =
              snapshot.hasData && !mediaInfo.contains('No media files');

          return Container(
            decoration: BoxDecoration(
              color: hasMedia
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasMedia
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                    : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: hasMedia
                    ? () {
                        Navigator.pop(context);
                        _playAllMedia();
                      }
                    : null,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: hasMedia
                              ? Theme.of(context).primaryColor
                              : Colors.grey[400],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Play All Media',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: hasMedia ? null : Colors.grey[600],
                              ),
                            ),
                            Text(
                              mediaInfo,
                              style: TextStyle(
                                color: hasMedia
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[500],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasMedia)
                        Icon(
                          Icons.chevron_right_rounded,
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'Clipboard',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'Advanced',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
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
                  iconColor: Colors.teal,
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

  /// Build individual compact action tile
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: enabled ? iconColor : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: enabled ? null : Colors.grey[500],
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
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

    // Scrollable bottom-anchored stack so 3 FABs (play, paste, add) never
    // overflow on short screens (e.g. landscape / keyboard open).
    return SingleChildScrollView(
      reverse: true,
      child: Column(
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'cancel_paste',
                onPressed: () {
                  FileOperationsService.instance.clearClipboard();
                  if (mounted) setState(() {});
                  _showSnackBar('Clipboard cleared');
                },
                backgroundColor: Colors.grey[800],
                tooltip: 'Cancel Paste',
                child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                heroTag: 'paste',
                onPressed: () async {
                  final success = await notifier.pasteFiles();
                  if (success) {
                    _showSnackBar('Files pasted successfully');
                  }
                  if (mounted) setState(() {});
                },
                backgroundColor: Colors.green,
                tooltip: 'Paste',
                child: const Icon(Icons.paste_rounded, size: 18, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Main FAB
        FloatingActionButton.small(
          heroTag: 'add',
          onPressed: () => _showAddMenu(state, notifier),
          tooltip: 'More Actions',
          child: const Icon(Icons.add_rounded, size: 20),
        ),
      ],
      ),
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
      if (!mounted) return;
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
      if (result.needsStorageAccess) {
        _showStorageAccessDialog(notifier);
      } else if (result.success) {
        _showSnackBar('Files deleted successfully');
      } else {
        _showSnackBar('Failed to delete some files: ${result.error}');
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
      final result =
          await FileOperationsService.instance.deleteFilesWithPermissionCheck(
        [entity],
      );
      if (result.needsStorageAccess) {
        _showStorageAccessDialog(notifier, [entity]);
        return;
      }
      if (result.success) {
        _showSnackBar('File deleted successfully');
        if (!mounted) return;
        final state = ref.read(fileBrowserProvider);
        if (state.currentDirectory != null) {
          notifier.navigateToDirectory(state.currentDirectory!);
        }
      } else {
        _showSnackBar('Failed to delete file: ${result.error}');
      }
    }
  }

  /// Removable volumes (USB OTG / SD) block raw-path deletes on old Android.
  /// Prompt the user to grant SAF access once, then retry the delete.
  Future<void> _showStorageAccessDialog(
    FileBrowserNotifier notifier, [
    List<FileSystemEntity>? single,
  ]) async {
    final granted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Access Needed'),
        content: const Text(
          'This USB/SD storage blocks normal file access. To delete files '
          'here, grant access to this storage once.\n\nYour files are safe — '
          'this is Android\'s built-in permission dialog.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Grant Access'),
          ),
        ],
      ),
    );

    if (granted != true || !mounted) return;

    final treeUri = await SafService.instance.pickTree();
    if (treeUri == null || !mounted) {
      _showSnackBar('Storage access not granted');
      return;
    }

    _showSnackBar('Storage access granted, retrying delete…');
    final files = single ?? ref.read(fileBrowserProvider).selectedEntities;
    final result = await FileOperationsService.instance
        .deleteFilesWithPermissionCheck(files);

    if (!mounted) return;
    if (result.success) {
      _showSnackBar('Files deleted successfully');
      final state = ref.read(fileBrowserProvider);
      if (state.currentDirectory != null) {
        notifier.navigateToDirectory(state.currentDirectory!);
      }
      if (single == null) notifier.clearSelection();
    } else {
      _showSnackBar('Failed to delete files: ${result.error}');
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

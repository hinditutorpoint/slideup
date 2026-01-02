import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/playlist.dart';
import '../providers/playlist_provider.dart';
import 'playlist_detail_screen.dart';
import '../services/security_service.dart';

class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  bool _isGridView = false;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Responsive helpers
  bool get _isTablet => MediaQuery.of(context).size.width >= 600;
  bool get _isDesktop => MediaQuery.of(context).size.width >= 1024;

  int get _gridCrossAxisCount {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 2;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider);

    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: playlists.when(
          data: (playlistList) {
            // Filter playlists based on search
            final filteredList = _searchQuery.isEmpty
                ? playlistList
                : playlistList
                      .where(
                        (p) =>
                            p.name.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            (p.description?.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ??
                                false),
                      )
                      .toList();

            if (playlistList.isEmpty) {
              return _buildEmptyState();
            }

            if (filteredList.isEmpty) {
              return _buildNoResultsState();
            }

            return Column(
              children: [
                _buildStatsBar(playlistList),
                Expanded(
                  child: _isGridView
                      ? _buildGridView(filteredList)
                      : _buildListView(filteredList),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorState(error.toString()),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchQuery = '';
              _searchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search playlists...',
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

    return AppBar(
      title: const Text('Playlists'),
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
              value: 'sort_items',
              child: Row(
                children: [
                  Icon(Icons.format_list_numbered),
                  SizedBox(width: 12),
                  Text('Sort by Items'),
                ],
              ),
            ),
            const PopupMenuDivider(),
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

  Widget _buildStatsBar(List<Playlist> playlists) {
    final totalItems = playlists.fold<int>(
      0,
      (sum, p) => sum + p.mediaIds.length,
    );
    final lockedCount = playlists.where((p) => p.isLocked).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          _buildStatChip(Icons.playlist_play, '${playlists.length} Playlists'),
          const SizedBox(width: 12),
          _buildStatChip(Icons.music_note, '$totalItems Items'),
          if (lockedCount > 0) ...[
            const SizedBox(width: 12),
            _buildStatChip(Icons.lock, '$lockedCount Locked'),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.playlist_play,
                size: 60,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Playlists Yet',
              style: TextStyle(
                fontSize: _isTablet ? 28 : 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create a playlist to organize your media files',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: _isTablet ? 16 : 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showCreatePlaylistSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Create Playlist'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
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
            'No playlists found',
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
              onPressed: () {
                try {
                  ref.read(playlistsProvider.notifier).loadPlaylists();
                } catch (e) {
                  debugPrint('Error refreshing: $e');
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<Playlist> playlists) {
    return ListView.builder(
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        return _buildPlaylistListItem(playlists[index]);
      },
    );
  }

  Widget _buildGridView(List<Playlist> playlists) {
    return GridView.builder(
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridCrossAxisCount,
        crossAxisSpacing: _isTablet ? 16 : 12,
        mainAxisSpacing: _isTablet ? 16 : 12,
        childAspectRatio: 0.85,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        return _buildPlaylistGridItem(playlists[index]);
      },
    );
  }

  Widget _buildPlaylistListItem(Playlist playlist) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openPlaylist(playlist),
        onLongPress: () => _showPlaylistOptionsSheet(playlist),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Playlist Icon
              _buildPlaylistIcon(playlist, size: 60),
              const SizedBox(width: 16),
              // Playlist Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            playlist.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (playlist.isLocked)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.lock,
                              size: 14,
                              color: Colors.orange,
                            ),
                          ),
                      ],
                    ),
                    if (playlist.description != null &&
                        playlist.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        playlist.description!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.music_note,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${playlist.mediaIds.length} ${playlist.mediaIds.length == 1 ? 'item' : 'items'}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(playlist.updatedAt),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // More Options
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showPlaylistOptionsSheet(playlist),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistGridItem(Playlist playlist) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openPlaylist(playlist),
        onLongPress: () => _showPlaylistOptionsSheet(playlist),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Playlist Icon
              Expanded(
                flex: 3,
                child: _buildPlaylistIcon(playlist, size: double.infinity),
              ),
              const SizedBox(height: 12),
              // Playlist Name
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (playlist.isLocked) ...[
                    const Icon(Icons.lock, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      playlist.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Item Count
              Text(
                '${playlist.mediaIds.length} ${playlist.mediaIds.length == 1 ? 'item' : 'items'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistIcon(Playlist playlist, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: playlist.isLocked
              ? [Colors.orange.shade400, Colors.deepOrange.shade600]
              : [
                  Theme.of(context).primaryColor,
                  Theme.of(context).colorScheme.secondary,
                ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                (playlist.isLocked
                        ? Colors.orange
                        : Theme.of(context).primaryColor)
                    .withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        playlist.isLocked ? Icons.lock : Icons.playlist_play,
        color: Colors.white,
        size: size == double.infinity ? 40 : size * 0.5,
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _showCreatePlaylistSheet(),
      icon: const Icon(Icons.add),
      label: const Text('Create'),
    );
  }

  // ============ Action Handlers ============

  void _handleMenuAction(String action) {
    try {
      switch (action) {
        case 'sort_name':
          _showMessage('Sorted by name');
          break;
        case 'sort_date':
          _showMessage('Sorted by date');
          break;
        case 'sort_items':
          _showMessage('Sorted by items count');
          break;
        case 'refresh':
          ref.read(playlistsProvider.notifier).loadPlaylists();
          break;
      }
    } catch (e) {
      _showError('Action failed: $e');
    }
  }

  void _openPlaylist(Playlist playlist) async {
    try {
      if (playlist.isLocked) {
        final unlocked = await _showPasswordVerificationSheet(playlist);
        if (!unlocked) return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailScreen(playlist: playlist),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to open playlist: $e');
    }
  }

  // ============ Bottom Sheet Dialogs ============

  void _showCreatePlaylistSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlaylistFormSheet(
        title: 'Create Playlist',
        submitLabel: 'Create',
        onSubmit: (name, description, isLocked, password) async {
          try {
            await ref
                .read(playlistsProvider.notifier)
                .createPlaylist(
                  name: name,
                  description: description,
                  isLocked: isLocked,
                  password: password,
                );

            if (context.mounted) {
              Navigator.pop(context);
              _showMessage('Playlist created');
            }
          } catch (e) {
            _showError('Failed to create playlist: $e');
          }
        },
      ),
    );
  }

  void _showEditPlaylistSheet(Playlist playlist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlaylistFormSheet(
        title: 'Edit Playlist',
        submitLabel: 'Save',
        initialName: playlist.name,
        initialDescription: playlist.description,
        isEditing: true,
        onSubmit: (name, description, isLocked, password) async {
          try {
            await ref
                .read(playlistsProvider.notifier)
                .updatePlaylist(
                  playlist.copyWith(
                    name: name,
                    description: description,
                    updatedAt: DateTime.now(),
                  ),
                );
            if (context.mounted) {
              Navigator.pop(context);
              _showMessage('Playlist updated');
            }
          } catch (e) {
            _showError('Failed to update playlist: $e');
          }
        },
      ),
    );
  }

  void _showPlaylistOptionsSheet(Playlist playlist) {
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
              // Playlist header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildPlaylistIcon(playlist, size: 50),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${playlist.mediaIds.length} items',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
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
              _buildOptionTile(
                icon: Icons.play_arrow,
                title: 'Open Playlist',
                onTap: () {
                  Navigator.pop(context);
                  _openPlaylist(playlist);
                },
              ),
              _buildOptionTile(
                icon: Icons.edit,
                title: 'Edit Playlist',
                onTap: () {
                  Navigator.pop(context);
                  _showEditPlaylistSheet(playlist);
                },
              ),
              _buildOptionTile(
                icon: playlist.isLocked ? Icons.lock_open : Icons.lock,
                title: playlist.isLocked ? 'Unlock Playlist' : 'Lock Playlist',
                onTap: () {
                  Navigator.pop(context);
                  _togglePlaylistLock(playlist);
                },
              ),
              _buildOptionTile(
                icon: Icons.copy,
                title: 'Duplicate Playlist',
                onTap: () {
                  Navigator.pop(context);
                  _duplicatePlaylist(playlist);
                },
              ),
              const Divider(height: 1),
              _buildOptionTile(
                icon: Icons.delete,
                title: 'Delete Playlist',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(playlist);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  Future<bool> _showPasswordVerificationSheet(Playlist playlist) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PasswordVerificationSheet(
        playlist: playlist,
        onVerified: () {
          Navigator.pop(context, true);
        },
      ),
    );

    return result ?? false;
  }

  void _showSetPasswordSheet(Playlist playlist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SetPasswordSheet(
        onSubmit: (password) async {
          try {
            final hash = SecurityService.instance.hashPassword(password);
            await ref
                .read(playlistsProvider.notifier)
                .updatePlaylist(
                  playlist.copyWith(
                    isLocked: true,
                    passwordHash: hash,
                    updatedAt: DateTime.now(),
                  ),
                );
            if (context.mounted) {
              Navigator.pop(context);
              _showMessage('Playlist locked');
            }
          } catch (e) {
            _showError('Failed to lock playlist: $e');
          }
        },
      ),
    );
  }

  void _togglePlaylistLock(Playlist playlist) async {
    try {
      if (playlist.isLocked) {
        // Unlock - verify password first
        final verified = await _showPasswordVerificationSheet(playlist);
        if (verified) {
          await ref
              .read(playlistsProvider.notifier)
              .updatePlaylist(
                playlist.copyWith(
                  isLocked: false,
                  passwordHash: null,
                  updatedAt: DateTime.now(),
                ),
              );
          _showMessage('Playlist unlocked');
        }
      } else {
        // Lock - set password
        _showSetPasswordSheet(playlist);
      }
    } catch (e) {
      _showError('Failed to toggle lock: $e');
    }
  }

  void _duplicatePlaylist(Playlist playlist) async {
    try {
      await ref
          .read(playlistsProvider.notifier)
          .createPlaylist(
            name: '${playlist.name} (Copy)',
            description: playlist.description,
            isLocked: false,
          );

      // TODO: Copy media items to new playlist

      _showMessage('Playlist duplicated');
    } catch (e) {
      _showError('Failed to duplicate: $e');
    }
  }

  void _showDeleteConfirmation(Playlist playlist) {
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
                    Icons.delete_forever,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delete Playlist?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete "${playlist.name}"?\nThis action cannot be undone.',
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
                          try {
                            await ref
                                .read(playlistsProvider.notifier)
                                .deletePlaylist(playlist.id);
                            if (context.mounted) {
                              Navigator.pop(context);
                              _showMessage('Playlist deleted');
                            }
                          } catch (e) {
                            _showError('Failed to delete: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Delete'),
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

  // ============ Utility Methods ============

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// ============ Playlist Form Sheet ============

class _PlaylistFormSheet extends StatefulWidget {
  final String title;
  final String submitLabel;
  final String? initialName;
  final String? initialDescription;
  final bool isEditing;
  final Future<void> Function(
    String name,
    String? description,
    bool isLocked,
    String? password,
  )
  onSubmit;

  const _PlaylistFormSheet({
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    this.initialName,
    this.initialDescription,
    this.isEditing = false,
  });

  @override
  State<_PlaylistFormSheet> createState() => _PlaylistFormSheetState();
}

class _PlaylistFormSheetState extends State<_PlaylistFormSheet> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  bool _isLocked = false;
  bool _showPassword = false;
  bool _isLoading = false;
  String? _nameError;
  String? _passwordError;

  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    // Auto focus name field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _descriptionFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  bool _validateForm() {
    setState(() {
      _nameError = null;
      _passwordError = null;
    });

    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Please enter a name');
      return false;
    }

    if (_isLocked && !widget.isEditing) {
      if (_passwordController.text.isEmpty) {
        setState(() => _passwordError = 'Please enter a password');
        return false;
      }
      if (_passwordController.text.length < 4) {
        setState(
          () => _passwordError = 'Password must be at least 4 characters',
        );
        return false;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _passwordError = 'Passwords do not match');
        return false;
      }
    }

    return true;
  }

  Future<void> _submit() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      await widget.onSubmit(
        _nameController.text.trim(),
        _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        _isLocked,
        _isLocked ? _passwordController.text : null,
      );
    } catch (e) {
      debugPrint('Error submitting form: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle keyboard visibility
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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

                    // Title
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Name Field
                    TextField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Playlist Name',
                        hintText: 'Enter playlist name',
                        prefixIcon: const Icon(Icons.playlist_play),
                        errorText: _nameError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) {
                        _descriptionFocus.requestFocus();
                      },
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description Field
                    TextField(
                      controller: _descriptionController,
                      focusNode: _descriptionFocus,
                      textInputAction: _isLocked
                          ? TextInputAction.next
                          : TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Enter playlist description',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.description),
                        ),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (_isLocked) {
                          _passwordFocus.requestFocus();
                        } else {
                          _submit();
                        }
                      },
                    ),

                    // Lock Option (only for create)
                    if (!widget.isEditing) ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SwitchListTile(
                          value: _isLocked,
                          onChanged: (value) {
                            setState(() => _isLocked = value);
                            if (value) {
                              Future.delayed(
                                const Duration(milliseconds: 100),
                                () {
                                  _passwordFocus.requestFocus();
                                },
                              );
                            }
                          },
                          title: const Text('Lock Playlist'),
                          subtitle: const Text(
                            'Require password to access',
                            style: TextStyle(fontSize: 12),
                          ),
                          secondary: Icon(
                            _isLocked ? Icons.lock : Icons.lock_open,
                            color: _isLocked ? Colors.orange : Colors.grey,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],

                    // Password Fields
                    if (_isLocked && !widget.isEditing) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _showPassword = !_showPassword);
                            },
                          ),
                          errorText: _passwordError,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (_) {
                          _confirmPasswordFocus.requestFocus();
                        },
                        onChanged: (_) {
                          if (_passwordError != null) {
                            setState(() => _passwordError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocus,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Re-enter password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(widget.submitLabel),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============ Password Verification Sheet ============

class _PasswordVerificationSheet extends StatefulWidget {
  final Playlist playlist;
  final VoidCallback onVerified;

  const _PasswordVerificationSheet({
    required this.playlist,
    required this.onVerified,
  });

  @override
  State<_PasswordVerificationSheet> createState() =>
      _PasswordVerificationSheetState();
}

class _PasswordVerificationSheetState
    extends State<_PasswordVerificationSheet> {
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _showPassword = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _verify() {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final hash = SecurityService.instance.hashPassword(
        _passwordController.text,
      );

      if (hash == widget.playlist.passwordHash) {
        widget.onVerified();
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Incorrect password';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Verification failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Lock Icon
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 36,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Playlist Locked',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter password to access "${widget.playlist.name}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _showPassword = !_showPassword);
                        },
                      ),
                      errorText: _error,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _verify(),
                    onChanged: (_) {
                      if (_error != null) {
                        setState(() => _error = null);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verify,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Unlock'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============ Set Password Sheet ============

class _SetPasswordSheet extends StatefulWidget {
  final Future<void> Function(String password) onSubmit;

  const _SetPasswordSheet({required this.onSubmit});

  @override
  State<_SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<_SetPasswordSheet> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _showPassword = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _passwordFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter password');
      return;
    }

    if (_passwordController.text.length < 4) {
      setState(() => _error = 'Password must be at least 4 characters');
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.onSubmit(_passwordController.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to set password';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Lock Icon
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 36,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Set Password',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a password to lock this playlist',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _showPassword = !_showPassword);
                        },
                      ),
                      errorText: _error,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _confirmFocus.requestFocus(),
                    onChanged: (_) {
                      if (_error != null) {
                        setState(() => _error = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  TextField(
                    controller: _confirmController,
                    focusNode: _confirmFocus,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Lock Playlist'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

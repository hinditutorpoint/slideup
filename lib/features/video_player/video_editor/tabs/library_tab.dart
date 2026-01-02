import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/video_edit_settings.dart';

class LibraryTab extends StatelessWidget {
  final List<MediaItem> items;
  final VoidCallback onRefresh;
  final Function(MediaItem) onDelete;
  final Function(MediaItem) onRename;
  final Function(MediaItem) onShare;
  final Function(MediaItem) onEdit;

  const LibraryTab({
    super.key,
    required this.items,
    required this.onRefresh,
    required this.onDelete,
    required this.onRename,
    required this.onShare,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 300;

        return Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(isCompact ? 10 : 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${items.length} files',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isCompact ? 11 : 12,
                    ),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.white70,
                      size: isCompact ? 18 : 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: items.isEmpty
                  ? _buildEmptyState(isCompact)
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 10 : 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return _buildItem(context, items[index], isCompact);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(bool isCompact) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            color: Colors.grey[700],
            size: isCompact ? 40 : 48,
          ),
          SizedBox(height: isCompact ? 12 : 16),
          Text(
            'No exported files yet',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: isCompact ? 13 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, MediaItem item, bool isCompact) {
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showActions(context, item, isCompact),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 10 : 12),
            child: Row(
              children: [
                // Icon
                Container(
                  width: isCompact ? 40 : 48,
                  height: isCompact ? 40 : 48,
                  decoration: BoxDecoration(
                    color: _getTypeColor(item.type).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTypeIcon(item.type),
                    color: _getTypeColor(item.type),
                    size: isCompact ? 20 : 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 13 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            item.fileSizeFormatted,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: isCompact ? 10 : 11,
                            ),
                          ),
                          if (item.duration != null) ...[
                            Text(
                              ' • ',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              _formatDuration(item.duration!),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: isCompact ? 10 : 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Menu
                Icon(
                  Icons.more_vert,
                  color: Colors.grey[600],
                  size: isCompact ? 18 : 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, MediaItem item, bool isCompact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: isCompact ? 16 : 20),

              // Title
              Text(
                item.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isCompact ? 16 : 20),

              // Actions
              _buildActionTile(
                icon: Icons.play_arrow,
                label: 'Open',
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit(item);
                },
                isCompact: isCompact,
              ),
              _buildActionTile(
                icon: Icons.share,
                label: 'Share',
                onTap: () {
                  Navigator.pop(ctx);
                  onShare(item);
                },
                isCompact: isCompact,
              ),
              _buildActionTile(
                icon: Icons.edit,
                label: 'Rename',
                onTap: () {
                  Navigator.pop(ctx);
                  onRename(item);
                },
                isCompact: isCompact,
              ),
              _buildActionTile(
                icon: Icons.delete,
                label: 'Delete',
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete(item);
                },
                isCompact: isCompact,
                isDestructive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isCompact,
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
          padding: EdgeInsets.symmetric(
            vertical: isCompact ? 12 : 14,
            horizontal: 8,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.white70,
                size: isCompact ? 20 : 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.white,
                  fontSize: isCompact ? 14 : 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

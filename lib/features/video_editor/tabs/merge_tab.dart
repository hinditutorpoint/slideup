import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/video_edit_settings.dart';

class MergeTab extends StatelessWidget {
  final List<MergeItem> mergeQueue;
  final Function(List<MergeItem>) onQueueChanged;
  final VoidCallback onAddVideo;
  final VoidCallback onAddImage;

  const MergeTab({
    super.key,
    required this.mergeQueue,
    required this.onQueueChanged,
    required this.onAddVideo,
    required this.onAddImage,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 300;

        return Column(
          children: [
            // Add buttons
            Padding(
              padding: EdgeInsets.all(isCompact ? 12 : 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildAddButton(
                      icon: Icons.video_library,
                      label: 'Add Video',
                      onTap: onAddVideo,
                      isCompact: isCompact,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAddButton(
                      icon: Icons.image,
                      label: 'Add Image',
                      onTap: onAddImage,
                      isCompact: isCompact,
                    ),
                  ),
                ],
              ),
            ),

            // Queue list or empty state
            Expanded(
              child: mergeQueue.isEmpty
                  ? _buildEmptyState(isCompact)
                  : _buildQueueList(context, isCompact),
            ),

            // Total duration
            if (mergeQueue.isNotEmpty) _buildTotalDuration(isCompact),
          ],
        );
      },
    );
  }

  Widget _buildAddButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isCompact,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: isCompact ? 18 : 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isCompact) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.merge, color: Colors.grey[700], size: isCompact ? 40 : 48),
          SizedBox(height: isCompact ? 12 : 16),
          Text(
            'No items to merge',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: isCompact ? 13 : 14,
            ),
          ),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            'Add videos or images above',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isCompact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(BuildContext context, bool isCompact) {
    return ReorderableListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16),
      itemCount: mergeQueue.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final items = List<MergeItem>.from(mergeQueue);
        final item = items.removeAt(oldIndex);
        items.insert(newIndex, item);
        onQueueChanged(items);
        HapticFeedback.mediumImpact();
      },
      itemBuilder: (context, index) {
        final item = mergeQueue[index];
        return _buildQueueItem(context, item, index, isCompact);
      },
    );
  }

  Widget _buildQueueItem(
    BuildContext context,
    MergeItem item,
    int index,
    bool isCompact,
  ) {
    return Container(
      key: ValueKey(item.id),
      margin: EdgeInsets.only(bottom: isCompact ? 8 : 10),
      padding: EdgeInsets.all(isCompact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Drag handle
          Icon(
            Icons.drag_handle,
            color: Colors.grey[600],
            size: isCompact ? 18 : 20,
          ),
          const SizedBox(width: 8),

          // Thumbnail
          Container(
            width: isCompact ? 50 : 60,
            height: isCompact ? 30 : 36,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: item.thumbnail != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(item.thumbnail!, fit: BoxFit.cover),
                  )
                : Icon(
                    item.type == MediaType.image ? Icons.image : Icons.movie,
                    color: Colors.grey[600],
                    size: isCompact ? 16 : 18,
                  ),
          ),
          const SizedBox(width: 10),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. ${item.type == MediaType.image ? 'Image' : 'Video'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 12 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.duration != null)
                  Text(
                    _formatDuration(item.effectiveDuration),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isCompact ? 10 : 11,
                    ),
                  ),
              ],
            ),
          ),

          // Remove button
          IconButton(
            onPressed: () {
              final items = List<MergeItem>.from(mergeQueue);
              items.removeAt(index);
              onQueueChanged(items);
              HapticFeedback.lightImpact();
            },
            icon: Icon(
              Icons.close,
              color: Colors.red[400],
              size: isCompact ? 18 : 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalDuration(bool isCompact) {
    final total = mergeQueue.fold<Duration>(
      Duration.zero,
      (sum, item) => sum + item.effectiveDuration,
    );

    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${mergeQueue.length} items',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: isCompact ? 11 : 12,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              shape: BoxShape.circle,
            ),
          ),
          Text(
            'Total: ${_formatDuration(total)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

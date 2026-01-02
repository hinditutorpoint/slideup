import 'package:flutter/material.dart';

class ImageViewerControls extends StatelessWidget {
  final int currentIndex;
  final int totalImages;
  final bool isSlideshow;
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onInfo;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onRotate;
  final VoidCallback onSlideshow;
  final VoidCallback onFullscreen;
  final VoidCallback onWallpaper;

  const ImageViewerControls({
    super.key,
    required this.currentIndex,
    required this.totalImages,
    required this.isSlideshow,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
    required this.onInfo,
    required this.onShare,
    required this.onDelete,
    required this.onEdit,
    required this.onRotate,
    required this.onSlideshow,
    required this.onFullscreen,
    required this.onWallpaper,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top bar
        _buildTopBar(context),

        // Navigation arrows (only if multiple images)
        if (totalImages > 1) _buildNavigationArrows(),

        // Bottom controls
        _buildBottomControls(context),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onClose,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: onInfo,
                ),
                IconButton(
                  icon: Icon(
                    isSlideshow ? Icons.pause : Icons.slideshow,
                    color: Colors.white,
                  ),
                  onPressed: onSlideshow,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: Colors.black87,
                  onSelected: (value) {
                    switch (value) {
                      case 'share':
                        onShare();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'rotate':
                        onRotate();
                        break;
                      case 'wallpaper':
                        onWallpaper();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Share', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Edit', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rotate',
                      child: Row(
                        children: [
                          Icon(Icons.rotate_right, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Rotate', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'wallpaper',
                      child: Row(
                        children: [
                          Icon(Icons.wallpaper, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Set as Wallpaper',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
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

  Widget _buildNavigationArrows() {
    return Positioned.fill(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          if (currentIndex > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: onPrevious,
                ),
              ),
            )
          else
            const SizedBox(width: 48),

          // Next button
          if (currentIndex < totalImages - 1)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: onNext,
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: Icons.share,
                  label: 'Share',
                  onPressed: onShare,
                ),
                _buildControlButton(
                  icon: Icons.edit,
                  label: 'Edit',
                  onPressed: onEdit,
                ),
                _buildControlButton(
                  icon: Icons.rotate_right,
                  label: 'Rotate',
                  onPressed: onRotate,
                ),
                _buildControlButton(
                  icon: Icons.delete,
                  label: 'Delete',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

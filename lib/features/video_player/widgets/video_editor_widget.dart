import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/video_edit_provider.dart';
import 'color_grading_widget.dart';

class VideoEditorWidget extends ConsumerStatefulWidget {
  final String videoPath;
  final Duration videoDuration;
  final Function(String outputPath)? onExportComplete;

  const VideoEditorWidget({
    super.key,
    required this.videoPath,
    required this.videoDuration,
    this.onExportComplete,
  });

  @override
  ConsumerState<VideoEditorWidget> createState() => _VideoEditorWidgetState();
}

class _VideoEditorWidgetState extends ConsumerState<VideoEditorWidget> {
  List<Uint8List> _timelineThumbnails = [];
  bool _isLoadingThumbnails = false;

  // Trim state
  double _trimStartPercent = 0.0;
  double _trimEndPercent = 1.0;
  bool _isDraggingStart = false;
  bool _isDraggingEnd = false;

  @override
  void initState() {
    super.initState();
    _initializeEditor();
  }

  Future<void> _initializeEditor() async {
    try {
      // Set video source
      ref
          .read(videoEditProvider.notifier)
          .setVideoSource(widget.videoPath, widget.videoDuration);

      // Load timeline thumbnails
      await _loadTimelineThumbnails();
    } catch (e) {
      debugPrint('⚠️ Initialize editor error: $e');
    }
  }

  Future<void> _loadTimelineThumbnails() async {
    if (_isLoadingThumbnails) return;

    setState(() => _isLoadingThumbnails = true);

    try {
      final thumbnails = await ref
          .read(videoEditProvider.notifier)
          .generateTimelineThumbnails(count: 10);

      if (mounted) {
        setState(() {
          _timelineThumbnails = thumbnails;
          _isLoadingThumbnails = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Load thumbnails error: $e');
      if (mounted) {
        setState(() => _isLoadingThumbnails = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(videoEditProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            _buildHeader(editState),

            const Divider(color: Colors.white12, height: 1),

            // Timeline with trim handles
            _buildTimeline(),

            const SizedBox(height: 16),

            // Action buttons
            _buildActionButtons(),

            const SizedBox(height: 16),

            // Clip markers list
            if (editState.clipMarkers.isNotEmpty)
              _buildClipMarkersList(editState.clipMarkers),

            // Processing indicator
            if (editState.isProcessing) _buildProcessingIndicator(editState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(VideoEditState editState) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text(
            'Video Editor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Trim duration display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _formatTrimDuration(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_getTrimStartDuration()),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                _formatDuration(_getTrimEndDuration()),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Timeline with thumbnails and trim handles
          SizedBox(
            height: 60,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                return Stack(
                  children: [
                    // Thumbnails
                    if (_timelineThumbnails.isNotEmpty)
                      Row(
                        children: _timelineThumbnails.map((thumb) {
                          return Expanded(
                            child: Image.memory(
                              thumb,
                              fit: BoxFit.cover,
                              height: 60,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: Colors.grey[800]),
                            ),
                          );
                        }).toList(),
                      )
                    else if (_isLoadingThumbnails)
                      Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(color: Colors.grey[800]),

                    // Dimmed areas outside trim range
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: width * _trimStartPercent,
                      child: Container(color: Colors.black54),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: width * (1 - _trimEndPercent),
                      child: Container(color: Colors.black54),
                    ),

                    // Trim border
                    Positioned(
                      left: width * _trimStartPercent,
                      right: width * (1 - _trimEndPercent),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.yellow, width: 2),
                        ),
                      ),
                    ),

                    // Start handle
                    _buildTrimHandle(
                      isStart: true,
                      position: width * _trimStartPercent,
                      width: width,
                    ),

                    // End handle
                    _buildTrimHandle(
                      isStart: false,
                      position: width * _trimEndPercent,
                      width: width,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrimHandle({
    required bool isStart,
    required double position,
    required double width,
  }) {
    return Positioned(
      left: isStart ? position - 12 : position - 12,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          setState(() {
            if (isStart) {
              _isDraggingStart = true;
            } else {
              _isDraggingEnd = true;
            }
          });
        },
        onHorizontalDragUpdate: (details) {
          _handleTrimDrag(details, isStart, width);
        },
        onHorizontalDragEnd: (_) {
          setState(() {
            _isDraggingStart = false;
            _isDraggingEnd = false;
          });
          _updateTrimValues();
        },
        child: Container(
          width: 24,
          decoration: BoxDecoration(
            color: Colors.yellow,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.drag_handle, color: Colors.black, size: 16),
        ),
      ),
    );
  }

  void _handleTrimDrag(DragUpdateDetails details, bool isStart, double width) {
    setState(() {
      final delta = details.delta.dx / width;

      if (isStart) {
        _trimStartPercent = (_trimStartPercent + delta).clamp(
          0.0,
          _trimEndPercent - 0.05,
        );
      } else {
        _trimEndPercent = (_trimEndPercent + delta).clamp(
          _trimStartPercent + 0.05,
          1.0,
        );
      }
    });
  }

  void _updateTrimValues() {
    try {
      final startDuration = _getTrimStartDuration();
      final endDuration = _getTrimEndDuration();

      ref.read(videoEditProvider.notifier).setTrimStart(startDuration);
      ref.read(videoEditProvider.notifier).setTrimEnd(endDuration);
    } catch (e) {
      debugPrint('⚠️ Update trim values error: $e');
    }
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.content_cut,
            label: 'Trim',
            onTap: _handleTrim,
          ),
          const SizedBox(width: 12),
          _ActionButton(
            icon: Icons.bookmark_add,
            label: 'Add Clip',
            onTap: _handleAddClip,
          ),
          const SizedBox(width: 12),
          _ActionButton(
            icon: Icons.palette,
            label: 'Color',
            onTap: _handleColorGrading,
          ),
          const SizedBox(width: 12),
          _ActionButton(
            icon: Icons.music_note,
            label: 'Audio',
            onTap: _handleExtractAudio,
          ),
          const SizedBox(width: 12),
          _ActionButton(
            icon: Icons.image,
            label: 'Frames',
            onTap: _handleExtractFrames,
          ),
        ],
      ),
    );
  }

  Widget _buildClipMarkersList(List<ClipMarker> markers) {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: markers.length,
        itemBuilder: (context, index) {
          final marker = markers[index];
          return _ClipMarkerCard(
            marker: marker,
            onTap: () => _handleClipMarkerTap(marker),
            onDelete: () => _handleDeleteClipMarker(marker.id),
          );
        },
      ),
    );
  }

  Widget _buildProcessingIndicator(VideoEditState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: state.processProgress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.processMessage ?? 'Processing...',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                '${(state.processProgress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _handleCancelProcessing,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTION HANDLERS
  // ═══════════════════════════════════════════════════════

  Future<void> _handleTrim() async {
    try {
      final result = await ref
          .read(videoEditProvider.notifier)
          .exportTrimmedVideo();

      if (result != null) {
        _showSuccess('Video trimmed successfully!');
        widget.onExportComplete?.call(result);
      } else {
        _showError('Failed to trim video');
      }
    } catch (e) {
      debugPrint('⚠️ Trim error: $e');
      _showError('Trim failed: $e');
    }
  }

  void _handleAddClip() {
    try {
      ref
          .read(videoEditProvider.notifier)
          .addClipMarker(
            _getTrimStartDuration(),
            _getTrimEndDuration(),
            label: 'Clip ${ref.read(videoEditProvider).clipMarkers.length + 1}',
          );
      _showSuccess('Clip marker added');
    } catch (e) {
      debugPrint('⚠️ Add clip error: $e');
    }
  }

  void _handleColorGrading() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ColorGradingWidget(
        onSettingsChanged: (settings) {
          // Apply color grading
        },
      ),
    );
  }

  Future<void> _handleExtractAudio() async {
    try {
      final result = await ref.read(videoEditProvider.notifier).extractAudio();

      if (result != null) {
        _showSuccess('Audio extracted: $result');
      } else {
        _showError('Failed to extract audio');
      }
    } catch (e) {
      debugPrint('⚠️ Extract audio error: $e');
      _showError('Audio extraction failed');
    }
  }

  Future<void> _handleExtractFrames() async {
    try {
      final frames = await ref.read(videoEditProvider.notifier).extractFrames();

      if (frames.isNotEmpty) {
        _showSuccess('Extracted ${frames.length} frames');
      } else {
        _showError('Failed to extract frames');
      }
    } catch (e) {
      debugPrint('⚠️ Extract frames error: $e');
      _showError('Frame extraction failed');
    }
  }

  void _handleClipMarkerTap(ClipMarker marker) {
    ref.read(videoEditProvider.notifier).setActiveClip(marker);
  }

  void _handleDeleteClipMarker(String id) {
    ref.read(videoEditProvider.notifier).removeClipMarker(id);
  }

  void _handleCancelProcessing() {
    ref.read(videoEditProvider.notifier).cancelProcessing();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  Duration _getTrimStartDuration() {
    return Duration(
      milliseconds: (widget.videoDuration.inMilliseconds * _trimStartPercent)
          .toInt(),
    );
  }

  Duration _getTrimEndDuration() {
    return Duration(
      milliseconds: (widget.videoDuration.inMilliseconds * _trimEndPercent)
          .toInt(),
    );
  }

  String _formatTrimDuration() {
    final start = _getTrimStartDuration();
    final end = _getTrimEndDuration();
    final duration = end - start;
    return _formatDuration(duration);
  }

  String _formatDuration(Duration duration) {
    try {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);

      if (hours > 0) {
        return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Show success error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Show error error: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// ✅ HELPER WIDGETS
// ═══════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClipMarkerCard extends StatelessWidget {
  final ClipMarker marker;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _ClipMarkerCard({required this.marker, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    marker.label ?? 'Clip',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(marker.startTime),
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  Text(
                    '→ ${_formatDuration(marker.endTime)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(marker.duration),
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Delete button
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 12),
                ),
              ),
            ),
            // Color grade indicator
            if (marker.colorGrade != null && !marker.colorGrade!.isDefault)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.palette,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    try {
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }
}

import 'package:file_picker/file_picker.dart';
import '../../../services/file_picker_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';
import '../tabs/merge_tab.dart';

// ═══════════════════════════════════════════════════════
// ✅ MERGE SHEET - Combine videos & images into one video
// ═══════════════════════════════════════════════════════

class MergeSheet extends ConsumerStatefulWidget {
  const MergeSheet({super.key});

  @override
  ConsumerState<MergeSheet> createState() => _MergeSheetState();
}

class _MergeSheetState extends ConsumerState<MergeSheet> {
  final List<MergeItem> _queue = [];
  bool _isMerging = false;
  double _progress = 0;

  Future<void> _addVideo() async {
    try {
      final result = await FilePickerService.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final infoResult = await ref
          .read(videoEditServiceProvider)
          .getVideoInfo(path);

      if (!mounted) return;

      if (infoResult.isFailure) {
        _showSnack('Could not read video info');
        return;
      }

      final info = infoResult.requireData;
      setState(() {
        _queue.add(
          MergeItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            path: path,
            type: MediaType.video,
            duration: info.duration,
          ),
        );
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) _showSnack('Failed to pick video: $e');
    }
  }

  Future<void> _addImage() async {
    try {
      final result = await FilePickerService.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      if (!mounted) return;

      setState(() {
        _queue.add(
          MergeItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            path: path,
            type: MediaType.image,
            duration: const Duration(seconds: 3),
          ),
        );
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) _showSnack('Failed to pick image: $e');
    }
  }

  Future<void> _startMerge() async {
    if (_queue.isEmpty || _isMerging) return;

    setState(() {
      _isMerging = true;
      _progress = 0;
    });

    try {
      final result = await ref.read(videoEditServiceProvider).mergeVideos(
            items: List<MergeItem>.from(_queue),
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );

      if (!mounted) return;

      if (result.isSuccess) {
        _showSnack('Video merged successfully');
        final outputPath = result.requireData;
        try {
          await SharePlus.instance.share(
            ShareParams(files: [XFile(outputPath)]),
          );
        } catch (_) {
          // Sharing failed silently; merge still succeeded
        }
      } else {
        _showSnack('Merge failed: ${result.error}');
      }
    } catch (e) {
      if (mounted) _showSnack('Merge error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isMerging = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Merge Videos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),
          Expanded(
            child: MergeTab(
              mergeQueue: _queue,
              onQueueChanged: (items) => setState(() => _queue
                ..clear()
                ..addAll(items)),
              onAddVideo: _addVideo,
              onAddImage: _addImage,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: _isMerging
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(
                          value: _progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.white10,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${(_progress * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                  : FilledButton.icon(
                      onPressed: _queue.isEmpty ? null : _startMerge,
                      icon: const Icon(Icons.merge, size: 18),
                      label: const Text('Merge & Share'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

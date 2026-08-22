import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/timeline_provider.dart';
import '../tabs/music_tab.dart';

// ═══════════════════════════════════════════════════════
// ✅ PIXABAY STOCK MUSIC PICKER SHEET
// ═══════════════════════════════════════════════════════

class PixabayMusicPickerSheet extends ConsumerStatefulWidget {
  const PixabayMusicPickerSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PixabayMusicPickerSheet(),
    );
  }

  @override
  ConsumerState<PixabayMusicPickerSheet> createState() =>
      _PixabayMusicPickerSheetState();
}

class _PixabayMusicPickerSheetState
    extends ConsumerState<PixabayMusicPickerSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Sheet Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.music_note, color: Color(0xFFE040FB)),
                const SizedBox(width: 8),
                const Text(
                  'Pixabay Stock Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Music browser
          Expanded(
            child: MusicTab(
              selectedMusicPath: null,
              onMusicChanged: (_) {},
              onMusicSelected: _addTrackToTimeline,
            ),
          ),
        ],
      ),
    );
  }

  void _addTrackToTimeline(MusicTrack track) {
    try {
      if (track.localPath == null || track.localPath!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download the track first'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      ref.read(timelineProvider.notifier).addAudioItem(
            audioPath: track.localPath!,
            audioDuration: track.duration,
            title: track.title,
            artist: track.artist,
          );

      HapticFeedback.mediumImpact();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${track.title}" to timeline'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE040FB),
        ),
      );
    } catch (e) {
      debugPrint('❌ Add Pixabay track error: $e');
    }
  }
}

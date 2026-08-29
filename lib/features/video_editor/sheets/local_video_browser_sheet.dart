import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saf/saf.dart';

import '../models/video_edit_settings.dart';
import '../providers/timeline_provider.dart';
import 'package:slideup/services/thumbnail_service.dart';

// ═══════════════════════════════════════════════════════
// ✅ LOCAL VIDEO BROWSER (SAF: internal / external / removable)
// ═══════════════════════════════════════════════════════

class LocalVideoBrowserSheet extends ConsumerStatefulWidget {
  const LocalVideoBrowserSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocalVideoBrowserSheet(),
    );
  }

  @override
  ConsumerState<LocalVideoBrowserSheet> createState() =>
      _LocalVideoBrowserSheetState();
}

class _LocalVideoBrowserSheetState
    extends ConsumerState<LocalVideoBrowserSheet> {
  final Saf _saf = Saf();
  final ThumbnailService _thumbService = ThumbnailService.instance;

  static const List<String> _videoExt = [
    'mp4',
    'mkv',
    'mov',
    'avi',
    'webm',
    'm4v',
    '3gp',
    'flv',
  ];

  /// Last SAF folder the user granted, persisted in the settings box so the
  /// picker is skipped on later sessions (grant itself survives restarts).
  static const String _lastDirKey = 'saf_last_dir_video';

  String? _rootUri;
  String? _currentUri;
  final List<String> _history = [];

  List<SafDocumentFile> _entries = [];
  bool _isLoading = false;
  bool _needsFolder = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreLastFolder();
  }

  Future<void> _restoreLastFolder() async {
    try {
      final saved = Hive.box('settingsBox').get(_lastDirKey) as String?;
      if (saved == null || saved.isEmpty) return;
      // Reuse only while the OS still holds the persisted grant.
      final grants = await _saf.persistedPermissions();
      if (!grants.any((g) => g.uri == saved)) return;
      if (!mounted) return;
      setState(() {
        _rootUri = saved;
        _currentUri = saved;
        _needsFolder = false;
        _history.clear();
      });
      await _load();
    } catch (_) {
      // Fall through to the manual pick screen.
    }
  }

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

          // Title + root picker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.folder_special, color: Color(0xFF6C63FF)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Device Videos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!_needsFolder)
                  TextButton.icon(
                    onPressed: _pickRoot,
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Change'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Path bar + up button
          if (!_needsFolder)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, color: Colors.white70),
                    tooltip: 'Up',
                    onPressed: _history.isEmpty ? null : _goUp,
                  ),
                  Expanded(
                    child: Text(
                      _currentUri ?? '',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1, color: Colors.white12),

          // Body
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_needsFolder) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sd_storage, color: Colors.grey[600], size: 56),
              const SizedBox(height: 16),
              const Text(
                'Select a storage location',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose Internal storage, SD card or any removable disk '
                'to browse its video files.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickRoot,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select Folder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Text(
          'No video files in this folder',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _entries.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, index) {
        final doc = _entries[index];
        if (doc.isDir) {
          return ListTile(
            leading: const Icon(Icons.folder, color: Color(0xFF6C63FF)),
            title: Text(
              doc.name,
              style: const TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => _openFolder(doc),
          );
        }

        return ListTile(
          leading: const Icon(Icons.movie, color: Colors.white70),
          title: Text(
            doc.name,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            _formatSize(doc.length),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          trailing: const Icon(Icons.add_circle_outline, color: Colors.white54),
          onTap: () => _pickVideo(doc),
        );
      },
    );
  }

  Future<void> _pickRoot() async {
    try {
      setState(() {
        _needsFolder = false;
        _isLoading = true;
        _error = null;
      });

      final lastSaved = Hive.box('settingsBox').get(_lastDirKey) as String?;
      final dir = await _saf.pickDirectory(initialUri: lastSaved);
      if (dir == null) {
        if (_rootUri == null) {
          setState(() {
            _needsFolder = true;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
        return;
      }

      _rootUri = dir.uri;
      _currentUri = dir.uri;
      _history.clear();
      Hive.box('settingsBox').put(_lastDirKey, dir.uri);
      await _load();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to open folder: $e';
      });
    }
  }

  Future<void> _load() async {
    if (_currentUri == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final files = await _saf.list(_currentUri!);
      files.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      final visible = files.where((f) => f.isDir || _isVideo(f)).toList();
      if (mounted) {
        setState(() {
          _entries = visible;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to list folder: $e';
        });
      }
    }
  }

  void _openFolder(SafDocumentFile doc) {
    _history.add(_currentUri!);
    _currentUri = doc.uri;
    _load();
  }

  void _goUp() {
    if (_history.isEmpty) return;
    _currentUri = _history.removeLast();
    _load();
  }

  Future<void> _pickVideo(SafDocumentFile doc) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      setState(() => _isLoading = true);

      final appDir = await getExternalStorageDirectory();
      final destDir = Directory(p.join(appDir!.path, 'video_saf'));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      final safeName = doc.name.contains('.') ? doc.name : '${doc.name}.mp4';
      final destPath = p.join(destDir.path, safeName);

      await _saf.copyToLocalFile(doc.uri, destPath);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Gather metadata
      final info = await _thumbService.getVideoInfo(destPath);
      final duration =
          _parseDuration(info?['duration']) ?? Duration.zero;
      Uint8List? thumb;
      try {
        thumb = await _thumbService.generateVideoThumbnailBytes(
          destPath,
          width: 320,
          quality: 75,
        );
      } catch (_) {
        thumb = null;
      }

      if (!mounted) return;
      final asLayer = await _askInsertMode();
      if (asLayer == null || !mounted) return; // cancelled

      final notifier = ref.read(timelineProvider.notifier);
      if (asLayer) {
        notifier.addVideoOverlayItem(
          videoPath: destPath,
          sourceDuration: duration,
          thumbnail: thumb,
        );
        notifier.selectItem(
          ref.read(timelineProvider).videoOverlayItems.last.id,
          TimelineItemType.video,
        );
      } else {
        notifier.addPrimaryClip(
          PrimaryVideoClip(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            videoPath: destPath,
            sourceDuration: duration,
            thumbnail: thumb,
          ),
        );
      }
      HapticFeedback.heavyImpact();
      navigator.pop();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            asLayer
                ? 'Added "${doc.name}" as Overlay Layer'
                : 'Inserted "${doc.name}" to Magnetic Timeline',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF6C63FF),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to add video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Tolerant duration reader: the app-level ThumbnailService returns an
  /// FFmpeg-log string ("HH:mm:ss.ff"), other probes return Duration or
  /// seconds. A hard cast here crashed every SAF video add with
  /// "type 'String' is not a subtype of type 'Duration?'".
  Duration? _parseDuration(dynamic raw) {
    if (raw is Duration) return raw;
    if (raw is num) {
      return Duration(milliseconds: (raw * 1000).round());
    }
    if (raw is String) {
      final parts = raw.split(':');
      try {
        if (parts.length == 3) {
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final s = double.parse(parts[2]);
          return Duration(
            hours: h,
            minutes: m,
            milliseconds: (s * 1000).round(),
          );
        }
        final secs = double.tryParse(raw);
        if (secs != null) {
          return Duration(milliseconds: (secs * 1000).round());
        }
      } catch (_) {}
    }
    return null;
  }

  Future<bool?> _askInsertMode() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'How to add this video?',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: const Text(
          'Main track replaces/extends the magnetic timeline. Overlay layer plays on top of the video (picture-in-picture).',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE040FB),
              side: const BorderSide(color: Color(0xFFE040FB)),
            ),
            icon: const Icon(Icons.layers, size: 16),
            label: const Text('Overlay Layer'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.movie, size: 16),
            label: const Text('Main Track'),
          ),
        ],
      ),
    );
  }

  bool _isVideo(SafDocumentFile doc) {
    if (doc.isDir) return false;
    final ext = p.extension(doc.name).toLowerCase().replaceAll('.', '');
    if (_videoExt.contains(ext)) return true;
    final mime = doc.mimeType?.toLowerCase() ?? '';
    return mime.startsWith('video');
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${units[i]}';
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saf/saf.dart';

import '../providers/timeline_provider.dart';
import '../services/audio_edit_service.dart';

// ═══════════════════════════════════════════════════════
// ✅ LOCAL AUDIO BROWSER (SAF: internal / external / removable)
// ═══════════════════════════════════════════════════════

class LocalAudioBrowserSheet extends ConsumerStatefulWidget {
  const LocalAudioBrowserSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocalAudioBrowserSheet(),
    );
  }

  @override
  ConsumerState<LocalAudioBrowserSheet> createState() =>
      _LocalAudioBrowserSheetState();
}

class _LocalAudioBrowserSheetState
    extends ConsumerState<LocalAudioBrowserSheet> {
  final Saf _saf = Saf();
  final AudioEditService _audioService = AudioEditService();

  static const List<String> _audioExt = [
    'mp3',
    'wav',
    'm4a',
    'aac',
    'flac',
    'ogg',
    'opus',
  ];

  String? _rootUri;
  String? _currentUri;
  final List<String> _history = [];

  List<SafDocumentFile> _entries = [];
  bool _isLoading = false;
  bool _needsFolder = true;
  String? _error;

  /// Last SAF folder the user granted, persisted in the settings box so the
  /// picker is skipped on later sessions (grant itself survives restarts).
  static const String _lastDirKey = 'saf_last_dir_audio';

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
                const Icon(Icons.folder_special, color: Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Device Audio',
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
                'to browse its audio files.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickRoot,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select Folder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
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
          'No audio files in this folder',
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
            leading: const Icon(Icons.folder, color: Color(0xFF4CAF50)),
            title: Text(
              doc.name,
              style: const TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => _openFolder(doc),
          );
        }

        return ListTile(
          leading: const Icon(Icons.audiotrack, color: Colors.white70),
          title: Text(
            doc.name,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            _formatSize(doc.length),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          trailing: const Icon(Icons.add_circle_outline, color: Colors.white54),
          onTap: () => _pickAudio(doc),
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
        // User cancelled
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
      final visible = files.where((f) => f.isDir || _isAudio(f)).toList();
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

  Future<void> _pickAudio(SafDocumentFile doc) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      setState(() => _isLoading = true);

      final appDir = await getExternalStorageDirectory();
      final destDir = Directory(p.join(appDir!.path, 'audio_saf'));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      final safeName = doc.name.contains('.')
          ? doc.name
          : '${doc.name}.mp3';
      final destPath = p.join(destDir.path, safeName);

      await _saf.copyToLocalFile(doc.uri, destPath);

      final infoResult = await _audioService.getAudioInfo(destPath);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (infoResult.isSuccess) {
        final info = infoResult.requireData;

        ref.read(timelineProvider.notifier).addAudioItem(
              audioPath: destPath,
              title: doc.name,
              audioDuration: info.duration,
            );

        HapticFeedback.mediumImpact();
        navigator.pop();

        messenger.showSnackBar(
          SnackBar(
            content: Text('Added "${doc.name}" to timeline'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not read audio file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to add audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isAudio(SafDocumentFile doc) {
    if (doc.isDir) return false;
    final ext = p.extension(doc.name).toLowerCase().replaceAll('.', '');
    if (_audioExt.contains(ext)) return true;
    final mime = doc.mimeType?.toLowerCase() ?? '';
    return mime.startsWith('audio');
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:open_filex/open_filex.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/text_viewer_widget.dart';
import '../core/utils/download_location_helper.dart';
import '../models/media_file.dart';
import '../services/file_operations_service.dart';
import '../services/thumbnail_service.dart';
import '../features/video_player/video_player_launcher.dart';
import '../helpers/audio_playback_helper.dart';
import '../helpers/m3u_playlist_helper.dart';
import 'image_viewer_screen.dart';
import 'pdf_viewer_screen.dart';
import 'main_screen.dart';

class ExtractedFilesScreen extends ConsumerStatefulWidget {
  const ExtractedFilesScreen({super.key});

  @override
  ConsumerState<ExtractedFilesScreen> createState() => _ExtractedFilesScreenState();
}

class _ExtractedFilesScreenState extends ConsumerState<ExtractedFilesScreen> {
  late Directory _filesDir;
  Directory? _downloadScreenshotsDir;
  Directory? _downloadClipsDir;
  bool _isLoading = true;
  String?
  _selectedCategory; // 'screenshots', 'audio', 'frames', 'clips', or null for all

  @override
  void initState() {
    super.initState();
    _initializeFilesDirectory();
  }

  Future<void> _initializeFilesDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _filesDir = Directory('${appDir.path}/files');

      if (!await _filesDir.exists()) {
        await _filesDir.create(recursive: true);
      }

      final downloadDir = await DownloadLocationHelper.configuredDirectory();
      if (downloadDir != null) {
        _downloadScreenshotsDir = Directory('${downloadDir.path}/screenshots');
        if (!await _downloadScreenshotsDir!.exists()) {
          await _downloadScreenshotsDir!.create(recursive: true);
        }

        _downloadClipsDir = Directory('${downloadDir.path}/clips');
        if (!await _downloadClipsDir!.exists()) {
          await _downloadClipsDir!.create(recursive: true);
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error initializing files directory: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<List<FileSystemEntity>> _getFiles() async {
    try {
      if (!await _filesDir.exists()) {
        return [];
      }

      List<FileSystemEntity> allFiles = [];

      if (_selectedCategory == null || _selectedCategory == 'screenshots') {
        // Get screenshots from app documents dir
        final screenshotsDir = Directory('${_filesDir.path}/screenshots');
        if (await screenshotsDir.exists()) {
          final files = await screenshotsDir.list().toList();
          allFiles.addAll(files.whereType<File>());
        }

        // Also get screenshots from download location
        if (_downloadScreenshotsDir != null &&
            await _downloadScreenshotsDir!.exists()) {
          final files = await _downloadScreenshotsDir!.list().toList();
          allFiles.addAll(files.whereType<File>());
        }
      }

      if (_selectedCategory == null || _selectedCategory == 'audio') {
        final audioDir = Directory('${_filesDir.path}/audio');
        if (await audioDir.exists()) {
          final files = await audioDir.list().toList();
          allFiles.addAll(files.whereType<File>());
        }
      }

      if (_selectedCategory == null || _selectedCategory == 'frames') {
        final framesDir = Directory('${_filesDir.path}/frames');
        if (await framesDir.exists()) {
          final subdirs = await framesDir.list().toList();
          for (var subdir in subdirs.whereType<Directory>()) {
            final files = await subdir.list().toList();
            allFiles.addAll(files.whereType<File>());
          }
        }
      }

      if (_selectedCategory == null || _selectedCategory == 'clips') {
        if (_downloadClipsDir != null && await _downloadClipsDir!.exists()) {
          final files = await _downloadClipsDir!.list().toList();
          allFiles.addAll(files.whereType<File>());
        }
      }

      // Sort by modified date (newest first)
      allFiles.sort((a, b) {
        try {
          final aTime = a.statSync().modified;
          final bTime = b.statSync().modified;
          return bTime.compareTo(aTime);
        } catch (e) {
          return 0;
        }
      });

      return allFiles;
    } catch (e) {
      debugPrint('Error getting files: $e');
      return [];
    }
  }

  Future<void> _deleteFile(File file) async {
    try {
      await file.delete();
      setState(() {});
      _showMessage('File deleted');
    } catch (e) {
      _showError('Failed to delete file: $e');
    }
  }

  Future<void> _openFile(File file) async {
    try {
      final extension = path.extension(file.path).toLowerCase();

      // Video files
      if ([
        '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm',
        '.m4v', '.ts', '.3gp', '.mpeg', '.mp2', '.rmvb',
      ].contains(extension)) {
        final mediaFile = MediaFile(
          id: const Uuid().v4(),
          name: path.basename(file.path),
          path: file.path,
          type: MediaType.video,
          size: file.lengthSync(),
          dateModified: file.lastModifiedSync(),
        );
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerLauncher.screen(file: mediaFile),
          ),
        );
        return;
      }

      // Audio files
      if ([
        '.mp3', '.wav', '.flac', '.aac', '.m4a', '.ogg',
      ].contains(extension)) {
        final mediaFile = MediaFile(
          id: const Uuid().v4(),
          name: path.basename(file.path),
          path: file.path,
          type: MediaType.audio,
          size: file.lengthSync(),
          dateModified: file.lastModifiedSync(),
        );
        AudioPlaybackHelper.playAudio(ref, mediaFile, [mediaFile], startIndex: 0);
        return;
      }

      // Image files
      if ([
        '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.tiff', '.svg',
      ].contains(extension)) {
        final mediaFile = MediaFile(
          id: const Uuid().v4(),
          name: path.basename(file.path),
          path: file.path,
          type: MediaType.image,
          size: file.lengthSync(),
          dateModified: file.lastModifiedSync(),
        );
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ImageViewerScreen(initialImage: mediaFile, images: [mediaFile]),
          ),
        );
        return;
      }

      // PDF files
      if (extension == '.pdf') {
        final mediaFile = MediaFile(
          id: const Uuid().v4(),
          name: path.basename(file.path),
          path: file.path,
          type: MediaType.document,
          documentType: DocumentType.pdf,
          size: file.lengthSync(),
          dateModified: file.lastModifiedSync(),
        );
        if (!mounted) return;
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
        return;
      }

      // Text / code files
      if ([
        '.txt', '.html', '.htm', '.xml', '.json', '.css', '.js',
      ].contains(extension)) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TextViewerWidget(filePath: file.path),
          ),
        );
        return;
      }

      // M3U playlists
      if ([
        '.m3u', '.m3u8', '.m3u_plus', '.m3u8_plus',
      ].contains(extension)) {
        final content = await file.readAsString();
        if (!mounted) return;
        await openLocalM3uPlaylist(
          context: context,
          ref: ref,
          file: file,
          content: content,
          onSnack: (msg) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          },
        );
        return;
      }

      // Fallback: try to open with external app
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _showError('Could not open file');
      }
    } catch (e) {
      _showError('Failed to open file: $e');
    }
  }

  Future<void> _deleteAllFiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Files'),
        content: const Text(
          'Delete all extracted files? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (await _filesDir.exists()) {
        await _filesDir.delete(recursive: true);
        await _filesDir.create(recursive: true);
      }
      setState(() {});
      _showMessage('All files deleted');
    } catch (e) {
      _showError('Failed to delete files: $e');
    }
  }

  String _getCategory(String filePath) {
    if (filePath.contains('/screenshots/')) return 'Screenshot';
    if (filePath.contains('/audio/')) return 'Audio';
    if (filePath.contains('/frames/')) return 'Frame';
    return 'Unknown';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Extracted Files')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    void handleBack() {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: handleBack,
          ),
          title: const Text('Extracted Files'),
          elevation: 0,
          actions: [
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () async => await _deleteAllFiles(),
                  child: const Text('Delete All Files'),
                ),
              ],
            ),
          ],
        ),
      body: Column(
        children: [
          // Category tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  _buildCategoryChip('All', null),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Screenshots', 'screenshots'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Clips', 'clips'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Audio', 'audio'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Frames', 'frames'),
                ],
              ),
            ),
          ),
          // File list
          Expanded(
            child: FutureBuilder<List<FileSystemEntity>>(
              future: _getFiles(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final files = snapshot.data ?? [];

                if (files.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.folder_open,
                    title: _selectedCategory == null
                        ? 'No Extracted Files'
                        : 'No $_selectedCategory Files',
                    message: 'Extract media to see files here',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index] as File;
                    return _buildPremiumFileTile(file);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCategoryChip(String label, String? category) {
    final isSelected = _selectedCategory == category;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedCategory = selected ? category : null);
      },
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PREMIUM FILE TILE
  // ═══════════════════════════════════════════════════════

  ({IconData icon, Color color, String label}) _typeInfo(File file) {
    final ext = path.extension(file.path).toLowerCase();
    if (['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.tiff', '.svg']
        .contains(ext)) {
      return (
        icon: Icons.image_outlined,
        color: const Color(0xFF42A5F5),
        label: 'Image',
      );
    }
    if (['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v',
          '.ts', '.3gp'
        ].contains(ext)) {
      return (
        icon: Icons.movie_outlined,
        color: const Color(0xFFAB47BC),
        label: 'Video',
      );
    }
    if (['.mp3', '.wav', '.flac', '.aac', '.m4a', '.ogg'].contains(ext)) {
      return (
        icon: Icons.graphic_eq_rounded,
        color: const Color(0xFF26A69A),
        label: 'Audio',
      );
    }
    if (ext == '.pdf') {
      return (
        icon: Icons.picture_as_pdf_outlined,
        color: const Color(0xFFEF5350),
        label: 'PDF',
      );
    }
    if (['.txt', '.html', '.htm', '.xml', '.json', '.css', '.js']
        .contains(ext)) {
      return (
        icon: Icons.description_outlined,
        color: const Color(0xFFFFB74D),
        label: 'Text',
      );
    }
    return (
      icon: Icons.insert_drive_file_outlined,
      color: Colors.grey,
      label: 'File',
    );
  }

  Widget _buildPremiumFileTile(File file) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fileName = path.basename(file.path);
    final info = _typeInfo(file);
    DateTime modified;
    try {
      modified = file.lastModifiedSync();
    } catch (_) {
      modified = DateTime.now();
    }
    final dateStr = DateFormat('d MMM yyyy • h:mm a').format(modified);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: () => _openFile(file),
          onLongPress: () => _showActionsSheet(file),
          borderRadius: BorderRadius.circular(18),
          splashColor: info.color.withValues(alpha: 0.08),
          highlightColor: info.color.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _FileThumb(file: file, info: info),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text(
                            _formatFileSize(file.lengthSync()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.circle, size: 3, color: cs.outline),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              dateStr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: info.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getCategory(file.path).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: info.color,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.more_vert_rounded,
                      size: 20, color: cs.onSurfaceVariant),
                  onPressed: () => _showActionsSheet(file),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTIONS SHEET
  // ═══════════════════════════════════════════════════════

  void _showActionsSheet(File file) {
    final info = _typeInfo(file);
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: info.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(info.icon, color: info.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      path.basename(file.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _sheetAction(sheetCtx, Icons.open_in_new_rounded, 'Open',
                () => _openFile(file)),
            _sheetAction(sheetCtx, Icons.share_outlined, 'Share',
                () => _shareFile(file)),
            _sheetAction(sheetCtx, Icons.drive_file_rename_outline_rounded,
                'Rename', () => _renameDialog(file)),
            _sheetAction(sheetCtx, Icons.copy_all_rounded, 'Copy path',
                () => _copyPath(file)),
            _sheetAction(sheetCtx, Icons.info_outline_rounded, 'Details',
                () => _showDetails(file)),
            _sheetAction(sheetCtx, Icons.delete_outline_rounded, 'Delete',
              () => _confirmDelete(file),
              color: Colors.redAccent,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetAction(
    BuildContext sheetCtx,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(
        icon,
        size: 21,
        color: color ?? Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style:
            TextStyle(color: color ?? Theme.of(sheetCtx).colorScheme.onSurface, fontSize: 14),
      ),
      onTap: () {
        Navigator.pop(sheetCtx);
        onTap();
      },
    );
  }

  Future<void> _shareFile(File file) async {
    try {
      final result =
          await FileOperationsService.instance.shareFiles([file]);
      if (!result.success) _showError('Failed to share file');
    } catch (e) {
      _showError('Share failed: $e');
    }
  }

  Future<void> _copyPath(File file) async {
    await Clipboard.setData(ClipboardData(text: file.path));
    if (!mounted) return;
    _showMessage('Path copied');
  }

  Future<void> _renameDialog(File file) async {
    final ctrl = TextEditingController(text: path.basename(file.path));
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == path.basename(file.path)) {
      return;
    }
    final result = await FileOperationsService.instance.renameFile(file, newName);
    if (!mounted) return;
    if (result.success) {
      setState(() {});
      _showMessage('Renamed');
    } else {
      _showError(result.error ?? 'Rename failed');
    }
  }

  void _showDetails(File file) {
    final info = _typeInfo(file);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(info.icon, color: info.color, size: 22),
            const SizedBox(width: 10),
            const Expanded(child: Text('File details')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Name', path.basename(file.path)),
            _detailRow('Type', '${info.label} (${path.extension(file.path)})'),
            _detailRow('Size', _formatFileSize(file.lengthSync())),
            _detailRow('Category', _getCategory(file.path)),
            _detailRow(
              'Modified',
              DateFormat('d MMM yyyy, h:mm a').format(_safeModified(file)),
            ),
            _detailRow('Path', file.parent.path),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _safeModified(File file) {
    try {
      return file.lastModifiedSync();
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<void> _confirmDelete(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text(
          '"${path.basename(file.path)}" will be deleted permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteFile(file);
  }
}

// ═══════════════════════════════════════════════════════
// ✅ FILE THUMBNAIL (image preview / video frame / icon)
// ═══════════════════════════════════════════════════════

class _FileThumb extends StatelessWidget {
  final File file;
  final ({IconData icon, Color color, String label}) info;

  const _FileThumb({required this.file, required this.info});

  @override
  Widget build(BuildContext context) {
    final isImage = info.label == 'Image';
    final isVideo = info.label == 'Video';

    Widget content;
    if (isImage) {
      content = Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Icon(info.icon, color: info.color),
      );
    } else if (isVideo) {
      content = _VideoThumb(file: file, info: info);
    } else {
      content = Icon(info.icon, color: info.color, size: 24);
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: (isImage || isVideo)
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : info.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (isVideo)
            Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lazily generates + caches a video frame thumbnail via FFmpeg.
class _VideoThumb extends StatefulWidget {
  final File file;
  final ({IconData icon, Color color, String label}) info;

  const _VideoThumb({required this.file, required this.info});

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  late Future<String?> _thumbFuture;

  @override
  void initState() {
    super.initState();
    _thumbFuture = ThumbnailService.instance.generateVideoThumbnail(
      widget.file.path,
      width: 128,
      height: 128,
      quality: 70,
    );
  }

  @override
  void didUpdateWidget(covariant _VideoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _thumbFuture = ThumbnailService.instance.generateVideoThumbnail(
        widget.file.path,
        width: 128,
        height: 128,
        quality: 70,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _thumbFuture,
      builder: (context, snapshot) {
        final thumbPath = snapshot.data;
        if (snapshot.connectionState == ConnectionState.done &&
            thumbPath != null) {
          final thumbFile = File(thumbPath);
          if (thumbFile.existsSync()) {
            return Image.file(
              thumbFile,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) =>
                  Icon(widget.info.icon, color: widget.info.color),
            );
          }
        }
        return Icon(widget.info.icon, color: widget.info.color, size: 24);
      },
    );
  }
}

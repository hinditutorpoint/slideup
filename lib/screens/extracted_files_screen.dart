import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:open_filex/open_filex.dart';
import 'package:uuid/uuid.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/text_viewer_widget.dart';
import '../core/utils/download_location_helper.dart';
import '../models/media_file.dart';
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
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index] as File;
                    final fileName = path.basename(file.path);
                    final fileSize = _formatFileSize(file.lengthSync());
                    final category = _getCategory(file.path);

                    return ListTile(
                      leading: _getFileIcon(file),
                      title: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fileSize, style: const TextStyle(fontSize: 12)),
                          Text(
                            category,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const Text('Open'),
                            onTap: () {
                              Future.delayed(
                                Duration.zero,
                                () => _openFile(file),
                              );
                            },
                          ),
                          PopupMenuItem(
                            child: const Text('Delete'),
                            onTap: () {
                              Future.delayed(
                                Duration.zero,
                                () => _deleteFile(file),
                              );
                            },
                          ),
                        ],
                      ),
                    );
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

  Widget _getFileIcon(File file) {
    final extension = path.extension(file.path).toLowerCase();

    if ([
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.bmp',
      '.webp',
    ].contains(extension)) {
      return const Icon(Icons.image);
    } else if (['.mp3', '.aac', '.wav', '.flac', '.m4a'].contains(extension)) {
      return const Icon(Icons.audiotrack);
    } else if (['.mp4', '.avi', '.mkv', '.mov'].contains(extension)) {
      return const Icon(Icons.videocam);
    }

    return const Icon(Icons.file_present);
  }
}

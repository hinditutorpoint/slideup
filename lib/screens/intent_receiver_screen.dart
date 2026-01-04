import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../models/media_file.dart';
import '../services/intent_handler_service.dart';
import '../helpers/audio_playback_helper.dart';
import 'image_viewer_screen.dart';
import '../features/video_player/video_player_launcher.dart';
import 'main_screen.dart';

class IntentReceiverScreen extends ConsumerStatefulWidget {
  final String filePath;

  const IntentReceiverScreen({super.key, required this.filePath});

  @override
  ConsumerState<IntentReceiverScreen> createState() =>
      _IntentReceiverScreenState();
}

class _IntentReceiverScreenState extends ConsumerState<IntentReceiverScreen> {
  bool _isLoading = true;
  MediaFile? _openedFile;
  List<MediaFile> _nearbyFiles = [];
  String? _error;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _processIntent();
  }

  @override
  void dispose() {
    // Clean up if needed
    super.dispose();
  }

  /// Safe setState that checks if widget is still mounted
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  /// Safe navigation that prevents multiple navigations
  void _safeNavigate(Widget destination, {bool replace = true}) {
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;

    if (replace) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destination),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination),
      );
    }
  }

  Future<void> _processIntent() async {
    try {
      _safeSetState(() {
        _isLoading = true;
        _error = null;
      });

      debugPrint('📂 Processing file: ${widget.filePath}');

      // Validate file path
      if (widget.filePath.isEmpty) {
        throw FileNotFoundException('Empty file path provided');
      }

      // Check if file exists
      final file = File(widget.filePath);
      final exists = await file.exists();

      if (!mounted) return; // Check after async operation

      if (!exists) {
        throw FileNotFoundException('File not found: ${widget.filePath}');
      }

      // Discover all files in the same directory
      debugPrint('🔍 Discovering nearby files...');
      final nearbyFiles = await IntentHandlerService.discoverNearbyFiles(
        widget.filePath,
      );

      if (!mounted) return; // Check after async operation

      debugPrint('✅ Found ${nearbyFiles.length} files');

      // Handle case where no files found (shouldn't happen normally)
      if (nearbyFiles.isEmpty) {
        // Create single file entry for the opened file
        final singleFile = await _createSingleFileEntry();
        if (singleFile != null) {
          nearbyFiles.add(singleFile);
        } else {
          throw FileProcessingException('Could not process file');
        }
      }

      // Find the index of opened file
      int openedIndex = IntentHandlerService.findFileIndex(
        nearbyFiles,
        widget.filePath,
      );

      // If exact match not found, try matching by name
      if (openedIndex == -1) {
        final fileName = widget.filePath.split('/').last;
        openedIndex = nearbyFiles.indexWhere((f) => f.name == fileName);
      }

      // If still not found, use first file
      if (openedIndex == -1) {
        debugPrint('⚠️ Could not find exact file match, using first file');
        openedIndex = 0;
      }

      if (!mounted) return;

      _safeSetState(() {
        _nearbyFiles = nearbyFiles;
        _openedFile = nearbyFiles[openedIndex];
        _isLoading = false;
      });

      // Small delay to ensure UI is ready, then open file
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted && !_hasNavigated) {
        _openFile();
      }
    } on FileNotFoundException catch (e) {
      debugPrint('❌ File not found: $e');
      _safeSetState(() {
        _error = e.message;
        _isLoading = false;
      });
    } on FileProcessingException catch (e) {
      debugPrint('❌ Processing error: $e');
      _safeSetState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error processing intent: $e');
      debugPrint('Stack trace: $stackTrace');
      _safeSetState(() {
        _error = 'Failed to open file: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Create a MediaFile entry for a single file when directory scan fails
  Future<MediaFile?> _createSingleFileEntry() async {
    try {
      final file = File(widget.filePath);
      final stat = await file.stat();
      final name = widget.filePath.split('/').last;
      final extension = name.contains('.')
          ? '.${name.split('.').last}'.toLowerCase()
          : '';

      return MediaFile(
        id: widget.filePath.hashCode.toString(),
        name: name,
        path: widget.filePath,
        displayPath: widget.filePath,
        type: _getMediaTypeFromExtension(extension),
        documentType: null,
        size: stat.size,
        dateModified: stat.modified,
        dateAdded: stat.changed,
        mimeType: _getMimeType(extension),
        thumbnailPath: null,
        duration: null,
        isLocked: false,
        parentFolder: file.parent.path,
      );
    } catch (e) {
      debugPrint('❌ Error creating single file entry: $e');
      return null;
    }
  }

  MediaType _getMediaTypeFromExtension(String extension) {
    const imageExts = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.heic',
    ];
    const videoExts = [
      '.mp4',
      '.mkv',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.m4v',
      '.3gp',
      '.ts',
    ];
    const audioExts = ['.mp3', '.m4a', '.wav', '.flac', '.ogg', '.aac'];
    const docExts = [
      '.pdf',
      '.doc',
      '.docx',
      '.txt',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
    ];

    if (imageExts.contains(extension)) return MediaType.image;
    if (videoExts.contains(extension)) return MediaType.video;
    if (audioExts.contains(extension)) return MediaType.audio;
    if (docExts.contains(extension)) return MediaType.document;
    return MediaType.other;
  }

  String _getMimeType(String extension) {
    const map = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.mp4': 'video/mp4',
      '.mkv': 'video/x-matroska',
      '.mp3': 'audio/mpeg',
      '.pdf': 'application/pdf',
    };
    return map[extension] ?? 'application/octet-stream';
  }

  void _openFile() {
    if (_openedFile == null || _hasNavigated) return;

    switch (_openedFile!.type) {
      case MediaType.image:
        _openImageViewer();
        break;
      case MediaType.video:
        _openVideoPlayer();
        break;
      case MediaType.audio:
        _openAudioPlayer();
        break;
      case MediaType.document:
        _openDocumentViewer();
        break;
      default:
        _showUnsupportedDialog();
    }
  }

  void _openImageViewer() {
    final imageFiles = _nearbyFiles
        .where((f) => f.type == MediaType.image)
        .toList();

    if (imageFiles.isEmpty) {
      _showError('No images found');
      return;
    }

    int imageIndex = imageFiles.indexWhere((f) => f.id == _openedFile!.id);
    if (imageIndex == -1) imageIndex = 0;

    _safeNavigate(
      ImageViewerScreen(
        initialImage: imageFiles[imageIndex],
        images: imageFiles,
        initialIndex: imageIndex,
      ),
    );
  }

  void _openVideoPlayer() {
    final videoFiles = _nearbyFiles
        .where((f) => f.type == MediaType.video)
        .toList();

    if (videoFiles.isEmpty) {
      _showError('No videos found');
      return;
    }

    int videoIndex = videoFiles.indexWhere((f) => f.id == _openedFile!.id);
    if (videoIndex == -1) videoIndex = 0;

    _safeNavigate(
      VideoPlayerLauncher.screen(files: videoFiles, index: videoIndex),
    );
  }

  void _openAudioPlayer() {
    final audioFiles = _nearbyFiles
        .where((f) => f.type == MediaType.audio)
        .toList();

    if (audioFiles.isEmpty) {
      _showError('No audio files found');
      return;
    }

    int audioIndex = audioFiles.indexWhere((f) => f.id == _openedFile!.id);
    if (audioIndex == -1) audioIndex = 0;

    // Start audio playback
    AudioPlaybackHelper.playAudio(
      ref,
      audioFiles[audioIndex],
      audioFiles,
      startIndex: audioIndex,
    );

    // Navigate to home
    _safeNavigate(const MainScreen());
  }

  void _openDocumentViewer() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening: ${_openedFile!.name}'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );

    // TODO: Implement document viewer
    _safeNavigate(const MainScreen());
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );

    _safeNavigate(const MainScreen());
  }

  void _showUnsupportedDialog() {
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: const Text('Unsupported File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cannot open this file type:'),
            const SizedBox(height: 8),
            Text(
              _openedFile!.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MainScreen()),
              );
            },
            child: const Text('Go to Home'),
          ),
        ],
      ),
    );
  }

  void _goToHome() {
    _safeNavigate(const MainScreen());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goToHome();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_error != null) {
      return _buildErrorView();
    }

    // This shows briefly before navigation
    return _buildLoadingView();
  }

  Widget _buildLoadingView() {
    final fileName = widget.filePath.split('/').last;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated loading indicator
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Opening file...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              // File name
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 32),

              // Cancel button
              TextButton.icon(
                onPressed: _goToHome,
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Failed to open file',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Error message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),

              // File path (truncated)
              Text(
                widget.filePath,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 32),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Retry button
                  OutlinedButton.icon(
                    onPressed: () {
                      _hasNavigated = false;
                      _processIntent();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(width: 16),

                  // Home button
                  ElevatedButton.icon(
                    onPressed: _goToHome,
                    icon: const Icon(Icons.home),
                    label: const Text('Go to Home'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom exceptions for better error handling
class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);

  @override
  String toString() => message;
}

class FileProcessingException implements Exception {
  final String message;
  FileProcessingException(this.message);

  @override
  String toString() => message;
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import '../models/media_file.dart';
import '../services/media_metadata_service.dart';

class IntentHandlerService {
  // Channel names - must match Kotlin
  static const String _methodChannel = 'com.slideup.mediaplayer/intent';
  static const String _eventChannel = 'com.slideup.mediaplayer/intent_stream';

  static const MethodChannel _channel = MethodChannel(_methodChannel);
  static const EventChannel _events = EventChannel(_eventChannel);

  // State
  static String? _initialFilePath;
  static bool _isInitialized = false;
  static StreamSubscription? _subscription;
  static StreamController<String?>? _streamController;

  static StreamController<String?> get _controller {
    if (_streamController == null || _streamController!.isClosed) {
      _streamController = StreamController<String?>.broadcast();
    }
    return _streamController!;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION & LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ IntentHandlerService already initialized');
      return;
    }

    try {
      debugPrint('🚀 Initializing IntentHandlerService...');

      // Subscribe to event stream for warm start intents
      _setupEventStream();

      // Get initial intent for cold start
      try {
        _initialFilePath = await _channel.invokeMethod<String>(
          'getInitialIntent',
        );
        debugPrint('📂 Initial intent from native: $_initialFilePath');
      } catch (e) {
        debugPrint('⚠️ Error getting initial intent: $e');
      }

      _isInitialized = true;
      debugPrint('✅ IntentHandlerService initialized successfully');
    } catch (e, stack) {
      debugPrint('❌ Failed to initialize IntentHandlerService: $e');
      debugPrint('Stack: $stack');
      _isInitialized = true;
    }
  }

  static void _setupEventStream() {
    _subscription?.cancel();
    _subscription = _events.receiveBroadcastStream().listen(
      (dynamic data) {
        debugPrint('📥 Event stream received: $data');
        if (data != null && data is String && data.isNotEmpty) {
          _controller.add(data);
        }
      },
      onError: (error) {
        debugPrint('❌ Event stream error: $error');
        // Try to reconnect after error
        Future.delayed(const Duration(seconds: 1), _setupEventStream);
      },
      onDone: () {
        debugPrint('⚠️ Event stream closed');
      },
    );
    debugPrint('📡 Event stream subscription active');
  }

  static void dispose() {
    debugPrint('🗑️ Disposing IntentHandlerService...');
    _subscription?.cancel();
    _subscription = null;
    _streamController?.close();
    _streamController = null;
    _isInitialized = false;
    _initialFilePath = null;
  }

  static void reset() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
    _initialFilePath = null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTENT HANDLING
  // ══════════════════════════════════════════════════════════════════════════

  static Future<String?> getInitialIntent() async {
    if (!_isInitialized) {
      await initialize();
    }

    final filePath = _initialFilePath;

    if (filePath != null && filePath.isNotEmpty) {
      debugPrint('📂 Consuming initial intent: $filePath');
      _initialFilePath = null;

      try {
        await _channel.invokeMethod('clearIntent');
      } catch (e) {
        debugPrint('⚠️ Error clearing native intent: $e');
      }

      return filePath;
    }

    debugPrint('📂 No initial intent available');
    return null;
  }

  /// Check and get pending intent (for warm start when stream was disconnected)
  static Future<String?> getPendingIntent() async {
    try {
      final pending = await _channel.invokeMethod<String>('getPendingIntent');
      if (pending != null && pending.isNotEmpty) {
        debugPrint('📂 Got pending intent: $pending');
        return pending;
      }
    } catch (e) {
      debugPrint('⚠️ Error getting pending intent: $e');
    }
    return null;
  }

  /// Check if there's a pending intent without consuming it
  static Future<bool> hasPendingIntent() async {
    try {
      final hasPending = await _channel.invokeMethod<bool>('hasPendingIntent');
      return hasPending ?? false;
    } catch (e) {
      debugPrint('⚠️ Error checking pending intent: $e');
      return false;
    }
  }

  /// Call this when app resumes to check for pending intents
  static Future<void> checkPendingIntentOnResume() async {
    debugPrint('🔄 Checking pending intent on resume...');
    final pending = await getPendingIntent();
    if (pending != null) {
      debugPrint('📂 Found pending intent on resume: $pending');
      _controller.add(pending);
    }
  }

  static Stream<String?> get intentStream => _controller.stream;

  static Future<void> clearIntent() async {
    try {
      await _channel.invokeMethod('clearIntent');
      _initialFilePath = null;
      debugPrint('🧹 Intents cleared');
    } catch (e) {
      debugPrint('❌ Error clearing intent: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FILE DISCOVERY
  // ══════════════════════════════════════════════════════════════════════════

  /// Discover all media files in the same directory as the opened file
  static Future<List<MediaFile>> discoverNearbyFiles(
    String filePath, {
    bool extractMetadata = false,
  }) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        debugPrint('❌ File does not exist: $filePath');
        return [];
      }

      final directory = file.parent;

      if (!await directory.exists()) {
        debugPrint('❌ Directory does not exist: ${directory.path}');
        return [];
      }

      debugPrint('🔍 Scanning directory: ${directory.path}');

      final entities = await directory.list().toList();
      final files = entities.whereType<File>().toList();

      debugPrint('📁 Found ${files.length} total files');

      final mediaFiles = <MediaFile>[];

      for (final f in files) {
        try {
          final mediaFile = await _createMediaFileFromPath(
            f.path,
            extractMetadata: extractMetadata,
          );
          if (mediaFile != null) {
            mediaFiles.add(mediaFile);
          }
        } catch (e) {
          debugPrint('⚠️ Skipping file ${f.path}: $e');
        }
      }

      // Sort by name
      mediaFiles.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      debugPrint('✅ Found ${mediaFiles.length} media files');
      return mediaFiles;
    } catch (e) {
      debugPrint('❌ Error discovering nearby files: $e');
      return [];
    }
  }

  /// Discover files of a specific type
  static Future<List<MediaFile>> discoverNearbyFilesByType(
    String filePath,
    MediaType type,
  ) async {
    final allFiles = await discoverNearbyFiles(
      filePath,
      extractMetadata: false,
    );
    return allFiles.where((f) => f.type == type).toList();
  }

  /// Discover files with custom filter
  static Future<List<MediaFile>> discoverNearbyFilesWhere(
    String filePath,
    bool Function(MediaFile) filter,
  ) async {
    final allFiles = await discoverNearbyFiles(filePath);
    return allFiles.where(filter).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FILE INDEX FINDING
  // ══════════════════════════════════════════════════════════════════════════

  /// Find index of a file in a list by path
  static int findFileIndex(List<MediaFile> files, String filePath) {
    // Try exact path match first
    int index = files.indexWhere((file) => file.path == filePath);

    if (index != -1) {
      return index;
    }

    // Try normalized path match
    final normalizedPath = path.normalize(filePath);
    index = files.indexWhere(
      (file) => path.normalize(file.path) == normalizedPath,
    );

    if (index != -1) {
      return index;
    }

    // Try filename match as fallback
    final fileName = path.basename(filePath);
    index = files.indexWhere((file) => file.name == fileName);

    if (index != -1) {
      debugPrint('⚠️ Found file by name match: $fileName');
    }

    return index;
  }

  /// Find index of a file by ID
  static int findFileIndexById(List<MediaFile> files, String id) {
    return files.indexWhere((file) => file.id == id);
  }

  /// Find index of a file by name
  static int findFileIndexByName(List<MediaFile> files, String name) {
    return files.indexWhere(
      (file) => file.name.toLowerCase() == name.toLowerCase(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FILE CREATION & HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Create MediaFile from file path
  static Future<MediaFile?> _createMediaFileFromPath(
    String filePath, {
    bool extractMetadata = true,
  }) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        return null;
      }

      final stat = await file.stat();
      final fileName = path.basename(filePath);
      final extension = path.extension(filePath).toLowerCase();
      final mediaType = getMediaType(extension);

      // Skip unsupported file types
      if (mediaType == MediaType.other) {
        return null;
      }

      // Audio metadata
      String? artist;
      String? album;
      String? genre;
      int? year;
      int? duration;

      // Extract metadata for audio/video files
      if (extractMetadata &&
          (mediaType == MediaType.audio || mediaType == MediaType.video)) {
        try {
          final meta = await MediaMetadataService.getMediaMetadata(filePath);

          artist = MediaMetadataService.getArtist(meta);
          album = MediaMetadataService.getAlbum(meta);
          genre = MediaMetadataService.getGenre(meta);
          year = MediaMetadataService.getYear(meta);
          duration = MediaMetadataService.getDuration(meta) as int?;
        } catch (e) {
          debugPrint('⚠️ Could not extract metadata from $filePath: $e');
        }
      }

      return MediaFile(
        id: filePath.hashCode.toString(),
        name: fileName,
        path: filePath,
        displayPath: filePath,
        type: mediaType,
        documentType: DocumentType.values.firstWhere(
          (dt) =>
              dt.name.toLowerCase() ==
              (_getDocumentType(extension)?.toLowerCase() ?? ''),
          orElse: () => DocumentType.other,
        ),
        size: stat.size,
        dateModified: stat.modified,
        dateAdded: stat.changed,
        mimeType: getMimeType(extension),
        thumbnailPath: null,
        duration: duration,
        isLocked: false,
        parentFolder: file.parent.path,
        artist: artist,
        album: album,
        genre: genre,
        year: year,
        isSelected: false,
      );
    } catch (e) {
      debugPrint('❌ Error creating MediaFile from $filePath: $e');
      return null;
    }
  }

  String? _getTag(Map<String, dynamic> meta, String key) {
    // 1️⃣ Try format tags
    final formatTags = meta['format']?['tags'];
    if (formatTags is Map && formatTags[key] != null) {
      return formatTags[key].toString();
    }

    // 2️⃣ Try stream tags (audio preferred)
    final streams = meta['streams'];
    if (streams is List) {
      for (final s in streams) {
        final tags = s['tags'];
        if (tags is Map && tags[key] != null) {
          return tags[key].toString();
        }
      }
    }

    return null;
  }

  /// Create a single MediaFile from path (public method)
  static Future<MediaFile?> createMediaFile(String filePath) async {
    return _createMediaFileFromPath(filePath, extractMetadata: true);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FILE TYPE DETECTION
  // ══════════════════════════════════════════════════════════════════════════

  /// Supported file extensions by type
  static const List<String> imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif',
    '.tiff',
    '.tif',
  ];

  static const List<String> videoExtensions = [
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
    '.mts',
    '.m2ts',
  ];

  static const List<String> audioExtensions = [
    '.mp3',
    '.m4a',
    '.wav',
    '.flac',
    '.ogg',
    '.aac',
    '.wma',
    '.opus',
    '.aiff',
  ];

  static const List<String> documentExtensions = [
    '.pdf',
    '.doc',
    '.docx',
    '.txt',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.rtf',
    '.odt',
    '.ods',
    '.odp',
  ];

  /// Get MediaType from file extension
  static MediaType getMediaType(String extension) {
    final ext = extension.toLowerCase();

    if (imageExtensions.contains(ext)) return MediaType.image;
    if (videoExtensions.contains(ext)) return MediaType.video;
    if (audioExtensions.contains(ext)) return MediaType.audio;
    if (documentExtensions.contains(ext)) return MediaType.document;

    return MediaType.other;
  }

  /// Get MediaType from file path
  static MediaType getMediaTypeFromPath(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return getMediaType(extension);
  }

  /// Get document type for document files
  static String? _getDocumentType(String extension) {
    const docTypes = {
      '.pdf': 'PDF',
      '.doc': 'Word',
      '.docx': 'Word',
      '.txt': 'Text',
      '.xls': 'Excel',
      '.xlsx': 'Excel',
      '.ppt': 'PowerPoint',
      '.pptx': 'PowerPoint',
      '.rtf': 'Rich Text',
      '.odt': 'OpenDocument',
      '.ods': 'OpenDocument Spreadsheet',
      '.odp': 'OpenDocument Presentation',
    };
    return docTypes[extension.toLowerCase()];
  }

  /// Get MIME type from extension
  static String getMimeType(String extension) {
    const mimeTypes = {
      // Images
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.bmp': 'image/bmp',
      '.heic': 'image/heic',
      '.heif': 'image/heif',
      '.tiff': 'image/tiff',
      '.tif': 'image/tiff',

      // Videos
      '.mp4': 'video/mp4',
      '.mkv': 'video/x-matroska',
      '.avi': 'video/x-msvideo',
      '.mov': 'video/quicktime',
      '.wmv': 'video/x-ms-wmv',
      '.flv': 'video/x-flv',
      '.webm': 'video/webm',
      '.m4v': 'video/x-m4v',
      '.3gp': 'video/3gpp',
      '.ts': 'video/mp2t',

      // Audio
      '.mp3': 'audio/mpeg',
      '.m4a': 'audio/mp4',
      '.wav': 'audio/wav',
      '.flac': 'audio/flac',
      '.ogg': 'audio/ogg',
      '.aac': 'audio/aac',
      '.wma': 'audio/x-ms-wma',
      '.opus': 'audio/opus',
      '.aiff': 'audio/aiff',

      // Documents
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.txt': 'text/plain',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.rtf': 'application/rtf',
    };

    return mimeTypes[extension.toLowerCase()] ?? 'application/octet-stream';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FILE VALIDATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Check if file exists and is accessible
  static Future<bool> isFileAccessible(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      debugPrint('❌ Error checking file accessibility: $e');
      return false;
    }
  }

  /// Check if file is a supported media type
  static bool isSupportedMediaFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return getMediaType(extension) != MediaType.other;
  }

  /// Check if file is video
  static bool isVideoFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return videoExtensions.contains(extension);
  }

  /// Check if file is image
  static bool isImageFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return imageExtensions.contains(extension);
  }

  /// Check if file is audio
  static bool isAudioFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return audioExtensions.contains(extension);
  }

  /// Check if file is document
  static bool isDocumentFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return documentExtensions.contains(extension);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get file name from path
  static String getFileName(String filePath) {
    return path.basename(filePath);
  }

  /// Get file extension from path
  static String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  /// Get parent directory from path
  static String getParentDirectory(String filePath) {
    return path.dirname(filePath);
  }

  /// Get file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get files grouped by type from a directory
  static Future<Map<MediaType, List<MediaFile>>> discoverNearbyFilesGrouped(
    String filePath,
  ) async {
    final allFiles = await discoverNearbyFiles(filePath);

    final grouped = <MediaType, List<MediaFile>>{};

    for (final file in allFiles) {
      grouped.putIfAbsent(file.type, () => []).add(file);
    }

    return grouped;
  }

  /// Get file count by type in directory
  static Future<Map<MediaType, int>> getFileCountsByType(
    String filePath,
  ) async {
    final grouped = await discoverNearbyFilesGrouped(filePath);
    return grouped.map((type, files) => MapEntry(type, files.length));
  }
}

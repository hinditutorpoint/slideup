import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../models/media_file.dart';
import 'media_metadata_service.dart';
import 'thumbnail_service.dart';

class FileScannerService {
  static final FileScannerService instance = FileScannerService._init();
  FileScannerService._init();

  final _uuid = const Uuid();

  // Updated video extensions with streaming formats
  static const _videoExtensions = [
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    '3gp',
    'webm',
    'm4v',
    'mpg',
    'mpeg',
    'ts',
    'm3u8',
    'mpd',
    'f4v',
    'vob',
    'ogv',
    'drc',
    'gifv',
    'mng',
    'qt',
    'yuv',
    'rm',
    'rmvb',
    'asf',
    'amv',
    'mp2',
    'mpe',
    'mpv',
    'm2v',
    'svi',
    '3g2',
    'mxf',
    'roq',
    'nsv',
  ];

  static const _audioExtensions = [
    'mp3',
    'wav',
    'flac',
    'aac',
    'm4a',
    'ogg',
    'wma',
    'opus',
    'aiff',
    'ape',
    'alac',
    'wv',
    'tta',
    'ac3',
    'dts',
    'mka',
    'ra',
    'ram',
    'oga',
    'mogg',
    'mid',
    'midi',
    'mus',
    'psf',
    'spc',
  ];

  static const _documentExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'rtf',
    'odt',
    'ods',
    'odp',
    'pages',
    'numbers',
    'key',
    'epub',
    'mobi',
    'azw',
    'azw3',
    'fb2',
    'lit',
    'lrf',
    'tcr',
    'djvu',
  ];

  static const _imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'svg',
    'heic',
    'heif',
    'tiff',
    'tif',
    'raw',
    'cr2',
    'nef',
    'orf',
    'sr2',
    'ico',
    'psd',
    'ai',
    'eps',
    'ps',
  ];

  // Streaming protocols
  static const _streamingProtocols = [
    'http://',
    'https://',
    'rtsp://',
    'rtmp://',
    'mms://',
    'mmsh://',
  ];

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ (API 33+)
        final statuses = await [
          Permission.videos,
          Permission.audio,
          Permission.photos,
        ].request();

        return statuses.values.every((status) => status.isGranted);
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11-12 (API 30-32)
        var status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      } else {
        // Android 10 and below
        var status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final statuses = await [
        Permission.photos,
        Permission.mediaLibrary,
      ].request();
      return statuses.values.every((status) => status.isGranted);
    }

    return false;
  }

  bool isStreamingUrl(String path) {
    return _streamingProtocols.any(
      (protocol) => path.toLowerCase().startsWith(protocol),
    );
  }

  bool isHLS(String path) {
    return path.toLowerCase().endsWith('.m3u8') ||
        path.toLowerCase().contains('.m3u8?');
  }

  bool isDASH(String path) {
    return path.toLowerCase().endsWith('.mpd') ||
        path.toLowerCase().contains('.mpd?');
  }

  // Protected system directories to skip
  static const _protectedPaths = [
    '.android_secure',
    '.android',
    '.thumbnails',
    '.cache',
    'Android/data',
    'Android/obb',
    'Android/media',
  ];

  bool _isProtectedPath(String path) {
    return _protectedPaths.any((protected) => path.contains(protected));
  }

  Future<List<MediaFile>> scanAllMedia({
    Function(int current, int total)? onProgress,
  }) async {
    final allFiles = <MediaFile>[];

    try {
      final directories = await _getStorageDirectories();
      int totalProcessed = 0;

      for (var directory in directories) {
        if (!await directory.exists()) continue;

        try {
          await for (var entity in directory.list(
            recursive: true,
            followLinks: false,
          )) {
            try {
              // Skip protected system directories
              if (_isProtectedPath(entity.path)) {
                continue;
              }

              if (entity is File) {
                final mediaFile = await _processFile(entity);
                if (mediaFile != null) {
                  allFiles.add(mediaFile);
                }

                totalProcessed++;
                if (onProgress != null && totalProcessed % 10 == 0) {
                  onProgress(totalProcessed, totalProcessed);
                }
              }
            } on PathAccessException catch (e) {
              // Skip directories that can't be accessed
              debugPrint('Skipping inaccessible path: ${e.path}');
              continue;
            } catch (e) {
              debugPrint('Error processing entity: $e');
              continue;
            }
          }
        } on PathAccessException catch (e) {
          // Skip directories that can't be accessed
          debugPrint('Skipping inaccessible directory: ${e.path}');
          continue;
        } catch (e) {
          debugPrint('Error scanning directory ${directory.path}: $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error scanning media: $e');
    }

    return allFiles;
  }

  Future<List<MediaFile>> scanDirectory(
    String directoryPath, {
    bool recursive = false,
    bool skipProtectedPaths = false,
  }) async {
    final files = <MediaFile>[];
    final directory = Directory(directoryPath);

    if (!await directory.exists()) return files;

    try {
      await for (var entity in directory.list(
        recursive: recursive,
        followLinks: false,
      )) {
        try {
          // Skip protected system directories (unless explicitly allowed)
          if (!skipProtectedPaths && _isProtectedPath(entity.path)) {
            continue;
          }

          if (entity is File) {
            final mediaFile = await _processFile(entity);
            if (mediaFile != null) {
              files.add(mediaFile);
            }
          }
        } on PathAccessException catch (e) {
          // Skip items that can't be accessed
          debugPrint('Skipping inaccessible path: ${e.path}');
          continue;
        } catch (e) {
          debugPrint('Error processing entity: $e');
          continue;
        }
      }
    } on PathAccessException catch (e) {
      debugPrint('Error scanning directory: Permission denied for ${e.path}');
    } catch (e) {
      debugPrint('Error scanning directory: $e');
    }

    return files;
  }

  Future<MediaFile?> _processFile(File file) async {
    try {
      final stat = await file.stat();
      final fileName = path.basename(file.path);
      final extension = path
          .extension(file.path)
          .toLowerCase()
          .replaceAll('.', '');

      if (extension.isEmpty) return null;

      final mimeType = lookupMimeType(file.path);
      final mediaType = _getMediaType(extension, mimeType);

      if (mediaType == MediaType.other) return null;

      String? thumbnailPath;
      int? duration;
      String? artist;
      String? album;

      // Generate thumbnail for videos (except streaming formats)
      if (mediaType == MediaType.video &&
          !['m3u8', 'mpd'].contains(extension)) {
        thumbnailPath = await _generateVideoThumbnail(file.path);
      }

      // Extract metadata (artist, album, duration) for audio/video files
      if (mediaType == MediaType.audio || mediaType == MediaType.video) {
        try {
          final meta = await MediaMetadataService.getMediaMetadata(file.path);
          artist = MediaMetadataService.getArtist(meta);
          album = MediaMetadataService.getAlbum(meta);
          duration = MediaMetadataService.getDuration(meta)?.inMilliseconds;
        } catch (e) {
          debugPrint('Error extracting metadata from ${file.path}: $e');
        }
      }

      return MediaFile(
        id: _uuid.v4(),
        name: fileName,
        path: file.path,
        displayPath: _getDisplayPath(file.path),
        type: mediaType,
        documentType: mediaType == MediaType.document
            ? _getDocumentType(extension)
            : null,
        size: stat.size,
        dateModified: stat.modified,
        dateAdded: DateTime.now(),
        mimeType: mimeType,
        thumbnailPath: thumbnailPath,
        duration: duration,
        parentFolder: path.dirname(file.path),
        artist: artist,
        album: album,
      );
    } catch (e) {
      debugPrint('Error processing file ${file.path}: $e');
      return null;
    }
  }

  MediaType _getMediaType(String extension, String? mimeType) {
    if (_videoExtensions.contains(extension)) {
      return MediaType.video;
    } else if (_audioExtensions.contains(extension)) {
      return MediaType.audio;
    } else if (_documentExtensions.contains(extension)) {
      return MediaType.document;
    } else if (_imageExtensions.contains(extension)) {
      return MediaType.image;
    }

    if (mimeType != null) {
      if (mimeType.startsWith('video/')) return MediaType.video;
      if (mimeType.startsWith('audio/')) return MediaType.audio;
      if (mimeType.startsWith('image/')) return MediaType.image;
      if (mimeType.contains('pdf') || mimeType.contains('document')) {
        return MediaType.document;
      }
    }

    return MediaType.other;
  }

  DocumentType _getDocumentType(String extension) {
    switch (extension) {
      case 'pdf':
        return DocumentType.pdf;
      case 'doc':
      case 'docx':
      case 'odt':
      case 'rtf':
      case 'pages':
        return DocumentType.word;
      case 'xls':
      case 'xlsx':
      case 'ods':
      case 'numbers':
        return DocumentType.excel;
      case 'ppt':
      case 'pptx':
      case 'odp':
      case 'key':
        return DocumentType.powerpoint;
      case 'txt':
        return DocumentType.text;
      default:
        return DocumentType.other;
    }
  }

  Future<String?> _generateVideoThumbnail(String videoPath) async {
    try {
      final thumbnailPath = await ThumbnailService.instance
          .generateVideoThumbnail(videoPath);
      return thumbnailPath;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  Future<List<Directory>> _getStorageDirectories() async {
    final directories = <Directory>[];

    if (Platform.isAndroid) {
      // Common Android media directories
      directories.addAll([
        Directory('/storage/emulated/0/DCIM'),
        Directory('/storage/emulated/0/Movies'),
        Directory('/storage/emulated/0/Music'),
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Documents'),
        Directory('/storage/emulated/0/Pictures'),
        Directory('/storage/emulated/0/Videos'),
        Directory('/storage/emulated/0/Audiobooks'),
        Directory('/storage/emulated/0/Podcasts'),
      ]);

      // Check for external SD card
      final externalStorage = Directory('/storage');
      if (await externalStorage.exists()) {
        await for (var entity in externalStorage.list()) {
          if (entity is Directory &&
              !entity.path.contains('emulated') &&
              !entity.path.contains('self')) {
            directories.add(entity);
          }
        }
      }
    } else if (Platform.isIOS) {
      final appDir = await getApplicationDocumentsDirectory();
      directories.add(appDir);
    }

    return directories;
  }

  String _getDisplayPath(String fullPath) {
    if (Platform.isAndroid) {
      return fullPath.replaceAll('/storage/emulated/0/', 'Internal Storage/');
    }
    return fullPath;
  }

  Future<List<Directory>> getAvailableStorageLocations() async {
    final locations = <Directory>[];

    if (Platform.isAndroid) {
      // Internal storage
      final internal = Directory('/storage/emulated/0');
      if (await internal.exists()) {
        locations.add(internal);
      }

      // External SD card
      final storage = Directory('/storage');
      if (await storage.exists()) {
        await for (var entity in storage.list()) {
          if (entity is Directory &&
              !entity.path.contains('emulated') &&
              !entity.path.contains('self')) {
            locations.add(entity);
          }
        }
      }
    }

    return locations;
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/media_file.dart';
import 'supported_extensions_service.dart';

class SearchService {
  static final SearchService instance = SearchService._();
  SearchService._();

  Future<List<MediaFile>> searchFiles({
    required String query,
    required String searchPath,
    List<MediaType>? fileTypes,
    bool caseSensitive = false,
    bool searchContent = false,
    bool recursive = true,
  }) async {
    if (query.trim().isEmpty) return [];

    final results = <MediaFile>[];
    final searchQuery = caseSensitive ? query : query.toLowerCase();

    try {
      final directory = Directory(searchPath);
      if (!await directory.exists()) return results;

      await for (final entity in directory.list(
        recursive: recursive,
        followLinks: false,
      )) {
        if (entity is File) {
          if (!SupportedExtensionsService.instance.isFileSupported(entity.path)) {
            continue;
          }
          final mediaFile = await _checkFileMatch(
            entity,
            searchQuery,
            fileTypes,
            caseSensitive,
            searchContent,
          );

          if (mediaFile != null) {
            results.add(mediaFile);
          }
        }
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }

    return results;
  }

  Future<MediaFile?> _checkFileMatch(
    File file,
    String query,
    List<MediaType>? fileTypes,
    bool caseSensitive,
    bool searchContent,
  ) async {
    try {
      final fileName = path.basename(file.path);
      final searchFileName = caseSensitive ? fileName : fileName.toLowerCase();

      // Check filename match
      if (!searchFileName.contains(query)) {
        // If searching content and it's a text file, check content
        if (searchContent && _isTextFile(file.path)) {
          final content = await file.readAsString();
          final searchContent = caseSensitive ? content : content.toLowerCase();
          if (!searchContent.contains(query)) {
            return null;
          }
        } else {
          return null;
        }
      }

      // Create MediaFile
      final mediaFile = await _createMediaFile(file);

      // Filter by file types if specified
      if (fileTypes != null && !fileTypes.contains(mediaFile.type)) {
        return null;
      }

      return mediaFile;
    } catch (e) {
      debugPrint('Error checking file match: $e');
      return null;
    }
  }

  bool _isTextFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return [
      '.txt',
      '.html',
      '.htm',
      '.xml',
      '.json',
      '.css',
      '.js',
    ].contains(extension);
  }

  Future<MediaFile> _createMediaFile(File file) async {
    final stat = await file.stat();
    final fileName = path.basename(file.path);
    final extension = path
        .extension(file.path)
        .toLowerCase()
        .replaceAll('.', '');

    return MediaFile(
      id: file.path,
      name: fileName,
      path: file.path,
      displayPath: file.path,
      type: _getMediaType(extension),
      documentType: _getDocumentType(extension),
      size: stat.size,
      dateModified: stat.modified,
      dateAdded: DateTime.now(),
      parentFolder: path.dirname(file.path),
    );
  }

  MediaType _getMediaType(String extension) {
    const videoExtensions = [
      'mp4',
      'mkv',
      'avi',
      'mov',
      'wmv',
      'flv',
      'webm',
      '3gp',
      'mpeg',
      'mpg',
      'ts',
      'm4v',
      'f4v',
    ];
    const audioExtensions = ['mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg'];
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    const textExtensions = ['txt', 'html', 'htm', 'xml'];
    const docExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'];

    if (videoExtensions.contains(extension)) return MediaType.video;
    if (audioExtensions.contains(extension)) return MediaType.audio;
    if (imageExtensions.contains(extension)) return MediaType.image;
    if (textExtensions.contains(extension)) return MediaType.text;
    if (docExtensions.contains(extension)) return MediaType.document;

    return MediaType.other;
  }

  DocumentType? _getDocumentType(String extension) {
    switch (extension) {
      case 'pdf':
        return DocumentType.pdf;
      case 'txt':
        return DocumentType.text;
      case 'html':
      case 'htm':
        return DocumentType.web;
      case 'doc':
      case 'docx':
        return DocumentType.word;
      case 'xls':
      case 'xlsx':
        return DocumentType.excel;
      case 'ppt':
      case 'pptx':
        return DocumentType.powerpoint;
      default:
        return null;
    }
  }
}

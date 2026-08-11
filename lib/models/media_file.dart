import 'dart:io';
import 'package:path/path.dart' as p;

enum MediaType { video, audio, document, image, text, web, other }

enum DocumentType { pdf, word, excel, powerpoint, text, web, other, epub }

class MediaFile {
  final String id;
  final String name;
  final String path;
  final String? displayPath;
  final MediaType type;
  final DocumentType? documentType;
  final int size;
  final DateTime dateModified;
  final DateTime? dateAdded;
  final String? mimeType;
  final String? thumbnailPath;
  final int? duration; // For video/audio in milliseconds
  final bool isLocked;
  final String? parentFolder;

  // Audio metadata
  final String? artist;
  final String? album;
  final String? genre;
  final int? year;
  final int? height;
  final int? width;
  final bool isSelected;
  final bool isFavorite;
  final int? lastPosition; // Last playback position in milliseconds

  MediaFile({
    required this.id,
    required this.name,
    required this.path,
    this.displayPath,
    required this.type,
    this.documentType,
    required this.size,
    required this.dateModified,
    this.dateAdded,
    this.mimeType,
    this.thumbnailPath,
    this.duration,
    this.isLocked = false,
    this.parentFolder,
    this.artist,
    this.album,
    this.genre,
    this.year,
    this.height,
    this.width,
    this.isSelected = false,
    this.isFavorite = false,
    this.lastPosition,
  });

  MediaFile copyWith({
    String? id,
    String? name,
    String? path,
    String? displayPath,
    MediaType? type,
    DocumentType? documentType,
    int? size,
    DateTime? dateModified,
    DateTime? dateAdded,
    String? mimeType,
    String? thumbnailPath,
    int? duration,
    bool? isLocked,
    String? parentFolder,
    String? artist,
    String? album,
    String? genre,
    int? year,
    int? height,
    int? width,
    bool? isSelected,
    bool? isFavorite,
    int? lastPosition,
  }) {
    return MediaFile(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      displayPath: displayPath ?? this.displayPath,
      type: type ?? this.type,
      documentType: documentType ?? this.documentType,
      size: size ?? this.size,
      dateModified: dateModified ?? this.dateModified,
      dateAdded: dateAdded ?? this.dateAdded,
      mimeType: mimeType ?? this.mimeType,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
      isLocked: isLocked ?? this.isLocked,
      parentFolder: parentFolder ?? this.parentFolder,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      height: height ?? this.height,
      width: width ?? this.width,
      isSelected: isSelected ?? this.isSelected,
      isFavorite: isFavorite ?? this.isFavorite,
      lastPosition: lastPosition ?? this.lastPosition,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'displayPath': displayPath,
      'type': type.index,
      'documentType': documentType?.index,
      'size': size,
      'dateModified': dateModified.toIso8601String(),
      'dateAdded': dateAdded?.toIso8601String(),
      'mimeType': mimeType,
      'thumbnailPath': thumbnailPath,
      'duration': duration,
      'isLocked': isLocked ? 1 : 0,
      'parentFolder': parentFolder,
      'artist': artist,
      'album': album,
      'genre': genre,
      'year': year,
      'height': height,
      'width': width,
      'isSelected': isSelected ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    return MediaFile(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      displayPath: json['displayPath'] as String?,
      type: MediaType.values[json['type'] as int],
      documentType: json['documentType'] != null
          ? DocumentType.values[json['documentType'] as int]
          : null,
      size: json['size'] as int,
      dateModified: DateTime.parse(json['dateModified'] as String),
      dateAdded: json['dateAdded'] != null
          ? DateTime.parse(json['dateAdded'] as String)
          : null,
      mimeType: json['mimeType'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      duration: json['duration'] as int?,
      isLocked: json['isLocked'] == 1,
      parentFolder: json['parentFolder'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      genre: json['genre'] as String?,
      year: json['year'] as int?,
      height: json['height'] as int?,
      width: json['width'] as int?,
      isSelected: json['isSelected'] == 1,
      isFavorite: json['isFavorite'] == 1,
    );
  }

  static MediaFile? fromFile(File file) {
    try {
      final String filePath = file.path;
      final String name = p.basename(filePath);
      final String ext = p.extension(filePath).toLowerCase();

      // Get file stats
      final FileStat stats = file.statSync();
      final int size = stats.size;
      final DateTime modified = stats.modified;

      // Determine MediaType based on extension
      MediaType type = MediaType.other;
      DocumentType? docType;

      if (_isVideo(ext)) {
        type = MediaType.video;
      } else if (_isAudio(ext)) {
        type = MediaType.audio;
      } else if (_isImage(ext)) {
        type = MediaType.image;
      } else if (_isDocument(ext)) {
        type = MediaType.document;
        docType = _getDocumentType(ext);
      } else if (ext == '.txt' || ext == '.json' || ext == '.xml') {
        type = MediaType.text;
      }

      return MediaFile(
        id: filePath, // Using path as unique ID
        name: name,
        path: filePath,
        size: size,
        dateModified: modified,
        type: type,
        documentType: docType,
        parentFolder: file.parent.path,
        // Defaults for nullable fields
        isLocked: false,
        isSelected: false,
        isFavorite: false,
      );
    } catch (e) {
      // Return null if file doesn't exist or permissions error
      return null;
    }
  }

  // Helper methods for file type detection
  static bool _isVideo(String ext) {
    const types = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm'];
    return types.contains(ext);
  }

  static bool _isAudio(String ext) {
    const types = ['.mp3', '.wav', '.aac', '.m4a', '.flac', '.ogg', '.wma'];
    return types.contains(ext);
  }

  static bool _isImage(String ext) {
    const types = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic'];
    return types.contains(ext);
  }

  static bool _isDocument(String ext) {
    const types = [
      '.pdf',
      '.doc',
      '.docx',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
      '.txt',
      '.epub',
      '.json',
    ];
    return types.contains(ext);
  }

  static DocumentType? _getDocumentType(String ext) {
    switch (ext) {
      case '.pdf':
        return DocumentType.pdf;
      case '.doc':
      case '.docx':
        return DocumentType.word;
      case '.xls':
      case '.xlsx':
        return DocumentType.excel;
      case '.ppt':
      case '.pptx':
        return DocumentType.powerpoint;
      case '.epub':
        return DocumentType.epub;
      case '.txt':
      case '.json':
        return DocumentType.text;
      default:
        return DocumentType.other;
    }
  }

  String get extension => p.extension(path).toLowerCase();

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get durationFormatted {
    if (duration == null) return '';
    final seconds = duration! ~/ 1000;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Get a human-readable file size string with appropriate units
  String get humanReadableSize {
    if (size <= 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    int unitIndex = 0;
    double sizeValue = size.toDouble();

    while (sizeValue >= 1024 && unitIndex < units.length - 1) {
      sizeValue /= 1024;
      unitIndex++;
    }

    if (unitIndex == 0) {
      return '${sizeValue.toInt()} ${units[unitIndex]}';
    } else if (sizeValue < 10) {
      return '${sizeValue.toStringAsFixed(2)} ${units[unitIndex]}';
    } else if (sizeValue < 100) {
      return '${sizeValue.toStringAsFixed(1)} ${units[unitIndex]}';
    } else {
      return '${sizeValue.toStringAsFixed(0)} ${units[unitIndex]}';
    }
  }
}

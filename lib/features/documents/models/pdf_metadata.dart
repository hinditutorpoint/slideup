import 'package:equatable/equatable.dart';
import 'pdf_file.dart';
import '../../video_search/models/thumbnail_file.dart';

class PdfMetadata extends Equatable {
  final String identifier;
  final String title;
  final String? description;
  final String? creator;
  final String? date;
  final String? publisher;
  final String? language;
  final String? subject;
  final int? downloads;
  final int? itemSize;
  final int filesCount;
  final List<PdfFile> documentFiles;
  final List<ThumbnailFile> thumbnails;

  const PdfMetadata({
    required this.identifier,
    required this.title,
    this.description,
    this.creator,
    this.date,
    this.publisher,
    this.language,
    this.subject,
    this.downloads,
    this.itemSize,
    this.filesCount = 0,
    this.documentFiles = const [],
    this.thumbnails = const [],
  });

  String get detailsUrl => 'https://archive.org/details/$identifier';
  String get downloadBaseUrl => 'https://archive.org/download/$identifier';

  String get formattedItemSize {
    if (itemSize == null || itemSize! <= 0) return 'Unknown';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = itemSize!.toDouble();
    var suffixIndex = 0;
    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }

  factory PdfMetadata.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    final filesJson = json['files'] as List<dynamic>? ?? [];

    final documentFiles = <PdfFile>[];
    final thumbnails = <ThumbnailFile>[];

    for (final fileJson in filesJson) {
      if (fileJson is! Map<String, dynamic>) continue;

      final name = fileJson['name']?.toString().toLowerCase() ?? '';
      final format = fileJson['format']?.toString().toLowerCase() ?? '';

      // Skip metadata files
      if (_shouldSkipFile(name)) continue;

      // Document files
      if (_isDocumentFile(name, format)) {
        documentFiles.add(PdfFile.fromJson(fileJson));
      }
      // Image files
      else if (_isImageFile(name, format)) {
        thumbnails.add(ThumbnailFile.fromJson(fileJson));
      }
    }

    // Sort: PDFs first, then by size
    documentFiles.sort((a, b) {
      if (a.isPdf && !b.isPdf) return -1;
      if (!a.isPdf && b.isPdf) return 1;
      return (b.size ?? 0).compareTo(a.size ?? 0);
    });

    return PdfMetadata(
      identifier: _parseString(metadata['identifier']) ?? '',
      title: _parseString(metadata['title']) ?? 'Untitled',
      description: _parseString(metadata['description']),
      creator: _parseCreator(metadata['creator']),
      date: _parseString(metadata['date']),
      publisher: _parseString(metadata['publisher']),
      language: _parseString(metadata['language']),
      subject: _parseSubject(metadata['subject']),
      downloads: _parseInt(json['item']?['downloads']),
      itemSize: _parseInt(json['item_size']),
      filesCount: filesJson.length,
      documentFiles: documentFiles,
      thumbnails: thumbnails,
    );
  }

  static bool _shouldSkipFile(String name) {
    return name.endsWith('_meta.xml') ||
        name.endsWith('_meta.sqlite') ||
        name.endsWith('_files.xml') ||
        name.endsWith('.torrent') ||
        name.endsWith('.odt') ||
        name.endsWith('.mob') ||
        name.endsWith('.kindle') ||
        name.endsWith('.azw') ||
        name.endsWith('.azw3') ||
        name.endsWith('.kfx') ||
        name == '__ia_thumb.jpg';
  }

  static bool _isDocumentFile(String name, String format) {
    const docExtensions = {'.pdf', '.epub', '.txt', '.doc', '.docx', '.rtf'};
    const docFormats = ['pdf', 'text', 'document'];

    for (final ext in docExtensions) {
      if (name.endsWith(ext)) return true;
    }
    for (final fmt in docFormats) {
      if (format.contains(fmt)) return true;
    }
    return false;
  }

  static bool _isImageFile(String name, String format) {
    const imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};
    for (final ext in imageExtensions) {
      if (name.endsWith(ext)) return true;
    }
    return format.contains('image') ||
        format.contains('jpeg') ||
        format.contains('png');
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isNotEmpty ? value : null;
    if (value is List && value.isNotEmpty) return value.first.toString();
    return value.toString();
  }

  static String? _parseCreator(dynamic creator) {
    if (creator == null) return null;
    if (creator is String) return creator;
    if (creator is List && creator.isNotEmpty) return creator.join(', ');
    return null;
  }

  static String? _parseSubject(dynamic subject) {
    if (subject == null) return null;
    if (subject is String) return subject;
    if (subject is List && subject.isNotEmpty) {
      return subject.take(5).join(', ');
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [identifier, title, documentFiles, thumbnails];
}

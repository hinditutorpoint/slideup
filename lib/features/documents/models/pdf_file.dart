import 'package:equatable/equatable.dart';

class PdfFile extends Equatable {
  final String name;
  final String source;
  final String format;
  final int? size;
  final String? mtime;

  const PdfFile({
    required this.name,
    required this.source,
    required this.format,
    this.size,
    this.mtime,
  });

  String getUrl(String identifier) =>
      'https://archive.org/download/$identifier/$name';

  String get extension {
    final lastDot = name.lastIndexOf('.');
    if (lastDot != -1 && lastDot < name.length - 1) {
      return name.substring(lastDot + 1).toUpperCase();
    }
    return 'PDF';
  }

  String get formattedSize {
    if (size == null || size! <= 0) return 'Unknown';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var fileSize = size!.toDouble();
    var suffixIndex = 0;
    while (fileSize >= 1024 && suffixIndex < suffixes.length - 1) {
      fileSize /= 1024;
      suffixIndex++;
    }
    return '${fileSize.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }

  String get displayName {
    if (name.contains('/')) return name.split('/').last;
    return name;
  }

  bool get isOriginal => source.toLowerCase() == 'original';
  bool get isPdf => extension == 'PDF';
  bool get isEpub => extension == 'EPUB';
  bool get isText => extension == 'TXT';

  factory PdfFile.fromJson(Map<String, dynamic> json) {
    return PdfFile(
      name: json['name']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      size: _parseInt(json['size']),
      mtime: json['mtime']?.toString(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [name, source, format, size, mtime];
}

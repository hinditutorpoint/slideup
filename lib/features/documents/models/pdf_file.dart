import 'package:equatable/equatable.dart';
import '../../../../core/constants/languages.dart';

class PdfFile extends Equatable {
  final String name;
  final String source;
  final String format;
  final int? size;
  final String? mtime;
  final String? language;
  final String? title;

  const PdfFile({
    required this.name,
    required this.source,
    required this.format,
    this.size,
    this.mtime,
    this.language,
    this.title,
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
    if (title != null && title!.trim().isNotEmpty) {
      return title!.trim();
    }
    if (name.contains('/')) return name.split('/').last;
    return name;
  }

  bool get isOriginal => source.toLowerCase() == 'original';
  bool get isPdf => extension == 'PDF';
  bool get isEpub => extension == 'EPUB';
  bool get isText => extension == 'TXT';

  /// Matches the file against a given [Language]
  bool matchesLanguage(Language lang, [String? fallbackItemLanguage]) {
    if (lang.code.isEmpty) return true; // All Languages

    final targetCode = lang.code.toLowerCase();
    final targetName = lang.name.toLowerCase();
    final targetNative = lang.nativeName.toLowerCase();

    // 1. Direct language tag in file metadata
    if (language != null && language!.trim().isNotEmpty) {
      final fileLang = language!.toLowerCase().trim();
      if (fileLang == targetCode ||
          fileLang == targetName ||
          fileLang.contains(targetCode)) {
        return true;
      }
    }

    // 2. Check title
    if (title != null && title!.trim().isNotEmpty) {
      final lowerTitle = title!.toLowerCase();
      if (lowerTitle.contains(targetName) ||
          lowerTitle.contains(targetNative) ||
          lowerTitle.contains('($targetCode)') ||
          lowerTitle.contains('[$targetCode]')) {
        return true;
      }
    }

    // 3. Check filename patterns (e.g., _eng., _en., [eng], -english-)
    final lowerName = name.toLowerCase();
    final twoLetterCode = _getTwoLetterCode(targetCode);

    if (lowerName.contains('_$targetCode') ||
        lowerName.contains('-$targetCode') ||
        lowerName.contains('.$targetCode') ||
        lowerName.contains('($targetCode)') ||
        lowerName.contains('[$targetCode]') ||
        lowerName.contains(targetName)) {
      return true;
    }

    if (twoLetterCode != null && twoLetterCode.isNotEmpty) {
      if (lowerName.contains('_$twoLetterCode.') ||
          lowerName.contains('-$twoLetterCode.') ||
          lowerName.contains('_$twoLetterCode') ||
          lowerName.contains('[$twoLetterCode]') ||
          lowerName.contains('($twoLetterCode)')) {
        return true;
      }
    }

    // 4. Fallback to parent item's language if file does not specify another
    if ((language == null || language!.trim().isEmpty) &&
        fallbackItemLanguage != null &&
        fallbackItemLanguage.trim().isNotEmpty) {
      final itemLang = fallbackItemLanguage.toLowerCase().trim();
      if (itemLang == targetCode ||
          itemLang == targetName ||
          itemLang.contains(targetCode)) {
        return true;
      }
    }

    return false;
  }

  static String? _getTwoLetterCode(String code3) {
    const map = {
      'eng': 'en',
      'spa': 'es',
      'fra': 'fr',
      'deu': 'de',
      'ita': 'it',
      'por': 'pt',
      'rus': 'ru',
      'zho': 'zh',
      'jpn': 'ja',
      'kor': 'ko',
      'ara': 'ar',
      'hin': 'hi',
      'ben': 'bn',
      'urd': 'ur',
      'tam': 'ta',
      'tel': 'te',
      'mar': 'mr',
      'guj': 'gu',
      'kan': 'kn',
      'mal': 'ml',
      'pan': 'pa',
      'tha': 'th',
      'vie': 'vi',
      'ind': 'id',
      'msa': 'ms',
      'tur': 'tr',
      'pol': 'pl',
      'nld': 'nl',
      'swe': 'sv',
      'nor': 'no',
      'dan': 'da',
      'fin': 'fi',
      'ces': 'cs',
      'ell': 'el',
      'heb': 'he',
      'ron': 'ro',
      'hun': 'hu',
      'ukr': 'uk',
      'cat': 'ca',
      'lat': 'la',
      'san': 'sa',
      'per': 'fa',
    };
    return map[code3];
  }

  factory PdfFile.fromJson(Map<String, dynamic> json) {
    return PdfFile(
      name: json['name']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      format: json['format']?.toString() ?? '',
      size: _parseInt(json['size']),
      mtime: json['mtime']?.toString(),
      language: json['language']?.toString() ?? json['lang']?.toString(),
      title: json['title']?.toString(),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [name, source, format, size, mtime, language, title];
}

import 'dart:math';

/// Detected language result
class DetectedLanguage {
  final String code;
  final String name;
  final double confidence;

  const DetectedLanguage({
    required this.code,
    required this.name,
    required this.confidence,
  });

  @override
  String toString() =>
      'DetectedLanguage($code, $name, ${(confidence * 100).toStringAsFixed(1)}%)';
}

/// Language detection service using Unicode ranges and word patterns
class LanguageDetectionService {
  static final LanguageDetectionService _instance =
      LanguageDetectionService._();
  static LanguageDetectionService get instance => _instance;

  LanguageDetectionService._();

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN DETECTION METHOD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Detect language from text
  /// Returns detected language or null if unable to detect
  DetectedLanguage? detect(String text) {
    if (text.trim().isEmpty) return null;

    // First try Unicode-based detection (best for CJK, Arabic, etc.)
    final unicodeResult = _detectByUnicode(text);

    // If non-Latin script with good confidence, use it
    if (unicodeResult != null && unicodeResult.confidence > 0.3) {
      return unicodeResult;
    }

    // For Latin scripts, use word pattern detection
    final patternResult = _detectByPatterns(text);

    if (patternResult != null && patternResult.confidence > 0.1) {
      return patternResult;
    }

    // Fallback to Unicode result or default to English
    if (unicodeResult != null) {
      return unicodeResult;
    }

    // Default fallback
    return const DetectedLanguage(code: 'en', name: 'English', confidence: 0.3);
  }

  /// Detect language code with fallback
  String detectCode(String text, {String fallback = 'en'}) {
    return detect(text)?.code ?? fallback;
  }

  /// Get language name from code
  String getLanguageName(String code) {
    return _languageNames[code.toLowerCase()] ?? code;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UNICODE-BASED DETECTION
  // ═══════════════════════════════════════════════════════════════════════════

  DetectedLanguage? _detectByUnicode(String text) {
    final counts = <String, int>{};
    int totalChars = 0;

    for (final rune in text.runes) {
      final script = _getScript(rune);
      if (script != null) {
        counts[script] = (counts[script] ?? 0) + 1;
        totalChars++;
      }
    }

    if (totalChars == 0) return null;

    // Find dominant script
    String? dominantScript;
    int maxCount = 0;

    for (final entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominantScript = entry.key;
      }
    }

    if (dominantScript == null) return null;

    final confidence = maxCount / totalChars;
    final langInfo = _scriptToLanguage[dominantScript];

    if (langInfo != null && confidence > 0.2) {
      return DetectedLanguage(
        code: langInfo['code']!,
        name: langInfo['name']!,
        confidence: confidence,
      );
    }

    // Latin script - need pattern detection
    if (dominantScript == 'latin') {
      return DetectedLanguage(
        code: 'en', // Placeholder, will be refined by pattern detection
        name: 'Latin',
        confidence: confidence * 0.5, // Lower confidence for Latin
      );
    }

    return null;
  }

  String? _getScript(int rune) {
    // Chinese (CJK Unified Ideographs)
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF) ||
        (rune >= 0x20000 && rune <= 0x2A6DF) ||
        (rune >= 0xF900 && rune <= 0xFAFF)) {
      return 'han';
    }

    // Japanese Hiragana & Katakana
    if ((rune >= 0x3040 && rune <= 0x309F) ||
        (rune >= 0x30A0 && rune <= 0x30FF)) {
      return 'japanese';
    }

    // Korean Hangul
    if ((rune >= 0xAC00 && rune <= 0xD7AF) ||
        (rune >= 0x1100 && rune <= 0x11FF) ||
        (rune >= 0x3130 && rune <= 0x318F)) {
      return 'hangul';
    }

    // Arabic
    if ((rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F)) {
      return 'arabic';
    }

    // Hebrew
    if (rune >= 0x0590 && rune <= 0x05FF) {
      return 'hebrew';
    }

    // Thai
    if (rune >= 0x0E00 && rune <= 0x0E7F) {
      return 'thai';
    }

    // Devanagari (Hindi)
    if (rune >= 0x0900 && rune <= 0x097F) {
      return 'devanagari';
    }

    // Tamil
    if (rune >= 0x0B80 && rune <= 0x0BFF) {
      return 'tamil';
    }

    // Bengali
    if (rune >= 0x0980 && rune <= 0x09FF) {
      return 'bengali';
    }

    // Cyrillic (Russian, Ukrainian, etc.)
    if (rune >= 0x0400 && rune <= 0x04FF) {
      return 'cyrillic';
    }

    // Greek
    if (rune >= 0x0370 && rune <= 0x03FF) {
      return 'greek';
    }

    // Latin (A-Z, a-z, extended Latin)
    if ((rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A) ||
        (rune >= 0x00C0 && rune <= 0x024F)) {
      return 'latin';
    }

    return null;
  }

  static const _scriptToLanguage = {
    'han': {'code': 'zh', 'name': 'Chinese'},
    'japanese': {'code': 'ja', 'name': 'Japanese'},
    'hangul': {'code': 'ko', 'name': 'Korean'},
    'arabic': {'code': 'ar', 'name': 'Arabic'},
    'hebrew': {'code': 'he', 'name': 'Hebrew'},
    'thai': {'code': 'th', 'name': 'Thai'},
    'devanagari': {'code': 'hi', 'name': 'Hindi'},
    'tamil': {'code': 'ta', 'name': 'Tamil'},
    'bengali': {'code': 'bn', 'name': 'Bengali'},
    'cyrillic': {'code': 'ru', 'name': 'Russian'},
    'greek': {'code': 'el', 'name': 'Greek'},
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // PATTERN-BASED DETECTION (For Latin languages)
  // ═══════════════════════════════════════════════════════════════════════════

  DetectedLanguage? _detectByPatterns(String text) {
    // Extract words
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toSet();

    if (words.isEmpty) return null;

    final scores = <String, double>{};

    for (final entry in _languagePatterns.entries) {
      final lang = entry.key;
      final patterns = entry.value;

      int matches = 0;
      for (final pattern in patterns) {
        if (words.contains(pattern)) matches++;
      }

      if (matches > 0) {
        scores[lang] = matches / patterns.length;
      }
    }

    if (scores.isEmpty) return null;

    // Find best match
    String? bestLang;
    double bestScore = 0;

    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestLang = entry.key;
      }
    }

    if (bestLang == null || bestScore < 0.03) return null;

    return DetectedLanguage(
      code: bestLang,
      name: _languageNames[bestLang] ?? bestLang,
      confidence: min(bestScore * 3, 0.95),
    );
  }

  static const _languagePatterns = <String, List<String>>{
    'en': [
      'the',
      'and',
      'is',
      'in',
      'to',
      'of',
      'a',
      'for',
      'on',
      'with',
      'that',
      'this',
      'are',
      'was',
      'have',
      'be',
      'at',
      'or',
      'an',
      'not',
      'you',
      'it',
      'from',
      'by',
      'as',
      'but',
      'what',
      'which',
      'we',
      'can',
    ],
    'de': [
      'der',
      'die',
      'und',
      'in',
      'den',
      'von',
      'zu',
      'das',
      'mit',
      'sich',
      'des',
      'auf',
      'für',
      'ist',
      'im',
      'dem',
      'nicht',
      'ein',
      'eine',
      'als',
      'auch',
      'es',
      'an',
      'werden',
      'aus',
      'er',
      'hat',
      'dass',
      'sie',
      'nach',
    ],
    'fr': [
      'le',
      'la',
      'de',
      'et',
      'les',
      'des',
      'en',
      'un',
      'du',
      'une',
      'que',
      'est',
      'pour',
      'qui',
      'dans',
      'ce',
      'il',
      'pas',
      'plus',
      'par',
      'sur',
      'se',
      'au',
      'avec',
      'ne',
      'sont',
      'tout',
      'nous',
      'mais',
      'ou',
    ],
    'es': [
      'de',
      'la',
      'que',
      'el',
      'en',
      'y',
      'a',
      'los',
      'del',
      'se',
      'las',
      'por',
      'un',
      'para',
      'con',
      'no',
      'una',
      'su',
      'al',
      'es',
      'lo',
      'como',
      'pero',
      'sus',
      'le',
      'ya',
      'o',
      'este',
      'si',
      'porque',
    ],
    'pt': [
      'de',
      'a',
      'o',
      'que',
      'e',
      'do',
      'da',
      'em',
      'um',
      'para',
      'com',
      'uma',
      'os',
      'no',
      'se',
      'na',
      'por',
      'mais',
      'as',
      'dos',
    ],
    'it': [
      'di',
      'che',
      'e',
      'la',
      'il',
      'un',
      'a',
      'per',
      'in',
      'una',
      'del',
      'le',
      'della',
      'non',
      'da',
      'con',
      'i',
      'si',
      'come',
      'sono',
    ],
    'nl': [
      'de',
      'het',
      'van',
      'en',
      'een',
      'in',
      'is',
      'dat',
      'op',
      'te',
      'voor',
      'met',
      'zijn',
      'die',
      'niet',
      'aan',
      'om',
      'ook',
      'als',
      'maar',
    ],
    'pl': [
      'i',
      'w',
      'nie',
      'na',
      'do',
      'to',
      'jest',
      'z',
      'co',
      'jak',
      'ale',
      'po',
      'tak',
      'za',
      'od',
      'o',
      'tylko',
      'czy',
      'go',
      'tym',
    ],
    'ru': [
      'и',
      'в',
      'не',
      'на',
      'я',
      'что',
      'он',
      'с',
      'как',
      'это',
      'но',
      'по',
      'к',
      'у',
      'же',
      'вы',
      'за',
      'бы',
      'так',
      'все',
    ],
    'tr': ['ve', 'bir', 'bu', 'da', 'de', 'ile', 'mi', 'ne', 'o', 'var'],
    'vi': [
      'và',
      'là',
      'của',
      'có',
      'trong',
      'được',
      'cho',
      'không',
      'này',
      'với',
    ],
    'id': [
      'dan',
      'yang',
      'di',
      'ini',
      'dengan',
      'untuk',
      'tidak',
      'dari',
      'dalam',
      'adalah',
    ],
  };

  static const _languageNames = {
    'en': 'English',
    'de': 'German',
    'fr': 'French',
    'es': 'Spanish',
    'pt': 'Portuguese',
    'it': 'Italian',
    'nl': 'Dutch',
    'pl': 'Polish',
    'ru': 'Russian',
    'tr': 'Turkish',
    'vi': 'Vietnamese',
    'id': 'Indonesian',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ar': 'Arabic',
    'he': 'Hebrew',
    'th': 'Thai',
    'hi': 'Hindi',
    'ta': 'Tamil',
    'bn': 'Bengali',
    'el': 'Greek',
  };
}

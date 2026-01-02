import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TranslationApiService {
  // Singleton pattern
  static final TranslationApiService _instance = TranslationApiService._();
  static TranslationApiService get instance => _instance;
  TranslationApiService._();

  /// Detects language based on script
  String detectSourceLang(String text) {
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      return 'hi';
    }
    // Arabic
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) {
      return 'ar';
    }
    // Chinese
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
      return 'zh';
    }
    // Japanese (Hiragana, Katakana)
    if (RegExp(r'[\u3040-\u30ff]').hasMatch(text)) {
      return 'ja';
    }
    // Korean
    if (RegExp(r'[\uac00-\ud7af]').hasMatch(text)) {
      return 'ko';
    }
    // Russian (Cyrillic)
    if (RegExp(r'[\u0400-\u04FF]').hasMatch(text)) {
      return 'ru';
    }
    // Thai
    if (RegExp(r'[\u0E00-\u0E7F]').hasMatch(text)) {
      return 'th';
    }
    // Default to English
    return 'en';
  }

  /// Fetches translation from MyMemory API
  Future<String?> translate(String text, String targetLang) async {
    final sourceLang = detectSourceLang(text);

    // API requires a valid email for more usage, but works without one for testing
    // Using a public email or leaving generic
    final uri = Uri.https('api.mymemory.translated.net', '/get', {
      'q': text,
      'langpair': '$sourceLang|$targetLang',
    });

    try {
      debugPrint('Translating via API: $sourceLang -> $targetLang');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // MyMemory response structure
        final translatedText = data['responseData']?['translatedText'];

        // Check status (200 in JSON body means success)
        if (data['responseStatus'] == 200 && translatedText != null) {
          return translatedText.toString();
        }

        // Sometimes matches are returned even if status isn't 200
        if (translatedText != null && translatedText.toString().isNotEmpty) {
          return translatedText.toString();
        }
      }
      debugPrint('Translation API Error: ${response.body}');
    } catch (e) {
      debugPrint('Translation Exception: $e');
    }
    return null;
  }
}

//import 'package:http/http.dart' as http;
//import 'dart:convert';
import '../models/subtitle_segment.dart';
import 'package:flutter/foundation.dart';

class TranslationService {
  static final TranslationService instance = TranslationService._();
  TranslationService._();

  // Dummy API - replace with actual API later
  //static const String _apiUrl = 'https://api.example.com/translate';
  //static const String _apiKey = 'YOUR_API_KEY'; // Add your API key

  /// Translate single text
  Future<String?> translateText({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'auto',
  }) async {
    try {
      // Dummy implementation for now
      debugPrint('🌍 Translating: "$text" to $targetLanguage');
      await Future.delayed(const Duration(milliseconds: 300));

      // Return dummy translation
      return '[$targetLanguage] $text';

      /* Real implementation with API:
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'text': text,
          'source': sourceLanguage,
          'target': targetLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['translatedText'];
      }

      return null;
      */
    } catch (e) {
      debugPrint('❌ Error translating text: $e');
      return null;
    }
  }

  /// Translate subtitle segments
  Future<List<SubtitleSegment>> translateSubtitles({
    required List<SubtitleSegment> segments,
    required String targetLanguage,
    String sourceLanguage = 'auto',
  }) async {
    final translatedSegments = <SubtitleSegment>[];

    debugPrint(
      '🌍 Translating ${segments.length} segments to $targetLanguage...',
    );

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];

      debugPrint('Translating segment ${i + 1}/${segments.length}');

      final translated = await translateText(
        text: segment.text,
        targetLanguage: targetLanguage,
        sourceLanguage: sourceLanguage,
      );

      translatedSegments.add(
        segment.copyWith(text: translated ?? segment.text),
      );

      // Small delay to avoid API rate limits
      if (i < segments.length - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    debugPrint('✅ Translation complete');
    return translatedSegments;
  }

  /// Batch translate (more efficient for APIs that support it)
  Future<List<SubtitleSegment>> batchTranslateSubtitles({
    required List<SubtitleSegment> segments,
    required String targetLanguage,
    String sourceLanguage = 'auto',
  }) async {
    try {
      // Combine all texts
      final texts = segments.map((s) => s.text).toList();

      debugPrint('🌍 Batch translating ${texts.length} segments...');

      // Dummy batch translation
      await Future.delayed(const Duration(seconds: 2));

      final translatedSegments = <SubtitleSegment>[];
      for (var i = 0; i < segments.length; i++) {
        translatedSegments.add(
          segments[i].copyWith(text: '[$targetLanguage] ${segments[i].text}'),
        );
      }

      debugPrint('✅ Batch translation complete');
      return translatedSegments;

      /* Real batch API implementation:
      final response = await http.post(
        Uri.parse('$_apiUrl/batch'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'texts': texts,
          'source': sourceLanguage,
          'target': targetLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedTexts = data['translations'] as List;
        
        final translatedSegments = <SubtitleSegment>[];
        for (var i = 0; i < segments.length; i++) {
          translatedSegments.add(segments[i].copyWith(
            text: translatedTexts[i],
          ));
        }
        
        return translatedSegments;
      }

      return segments;
      */
    } catch (e) {
      debugPrint('❌ Error in batch translation: $e');
      return segments;
    }
  }

  /// Get supported languages
  Future<List<String>> getSupportedLanguages() async {
    // Mock data
    return [
      'en', // English
      'es', // Spanish
      'fr', // French
      'de', // German
      'it', // Italian
      'pt', // Portuguese
      'ru', // Russian
      'ja', // Japanese
      'ko', // Korean
      'zh', // Chinese
      'ar', // Arabic
      'hi', // Hindi
    ];
  }

  /// Get language name
  String getLanguageName(String code) {
    const languageNames = {
      'en': 'English',
      'es': 'Español',
      'fr': 'Français',
      'de': 'Deutsch',
      'it': 'Italiano',
      'pt': 'Português',
      'ru': 'Русский',
      'ja': '日本語',
      'ko': '한국어',
      'zh': '中文',
      'ar': 'العربية',
      'hi': 'हिन्दी',
    };

    return languageNames[code] ?? code.toUpperCase();
  }
}

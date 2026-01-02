import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class VideoPlayerInit {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ VideoPlayer already initialized');
      return;
    }

    try {
      debugPrint('🎬 Initializing MediaKit...');

      // Initialize MediaKit
      MediaKit.ensureInitialized();

      _isInitialized = true;
      debugPrint('✅ MediaKit initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ MediaKit initialization failed: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  static bool get isInitialized => _isInitialized;
}

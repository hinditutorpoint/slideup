import 'package:flutter/foundation.dart';

class Logger {
  static const String _prefix = '🎬 SMP';

  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix $tagStr: $message');
    }
  }

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix ❌ $tagStr: $message');
      if (error != null) print('Error: $error');
      if (stackTrace != null) print('StackTrace: $stackTrace');
    }
  }

  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix ℹ️ $tagStr: $message');
    }
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix ⚠️ $tagStr: $message');
    }
  }

  static void success(String message, {String? tag}) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      print('$_prefix ✅ $tagStr: $message');
    }
  }
}

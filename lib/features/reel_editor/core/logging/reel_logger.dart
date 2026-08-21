import 'package:flutter/foundation.dart';

/// Structured logging md:31 — projectId/operation/metadata/ffmpeg/error, never sensitive
class ReelLogger {
  static void log(String projectId, String op, Map<String, dynamic> meta) {
    if (kDebugMode) debugPrint('[Reel:$projectId][$op] $meta');
  }
  static void error(String projectId, String op, Object e, {String code = 'unknown'}) {
    if (kDebugMode) debugPrint('[Reel ERR:$projectId][$op][$code] $e');
  }
  // creative: export trace with device info
  static void exportTrace(String projectId, List<String> cmd, Duration dur) {
    log(projectId, 'export', {'cmdArgs': cmd.length, 'durationMs': dur.inMilliseconds, 'fps': 30});
  }
}

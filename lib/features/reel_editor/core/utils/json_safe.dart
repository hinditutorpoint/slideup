/// Reused from video_edit_settings.dart:201-237 — safe parsing guards md:944-971
extension SafeJsonParsing on Map<String, dynamic> {
  T? safeGet<T>(String key, [T? fallback]) {
    try {
      final v = this[key];
      if (v is T) return v;
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  Duration safeDuration(String key, [Duration fallback = Duration.zero]) {
    try {
      final v = this[key];
      if (v is int) return Duration(milliseconds: v.clamp(0, 86400000 * 365));
      if (v is double) {
        if (v.isNaN || v.isInfinite) return fallback;
        return Duration(milliseconds: v.round().clamp(0, 86400000 * 365));
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}

double clampDouble(double v, double min, double max, double fallback) {
  if (v.isNaN || v.isInfinite) return fallback;
  return v.clamp(min, max).toDouble();
}

int clampInt(int v, int min, int max, int fallback) {
  try {
    return v.clamp(min, max);
  } catch (_) {
    return fallback;
  }
}

T safeEnum<T>(List<T> values, dynamic raw, T fallback) {
  try {
    if (raw is int && raw >= 0 && raw < values.length) return values[raw];
    return fallback;
  } catch (_) {
    return fallback;
  }
}

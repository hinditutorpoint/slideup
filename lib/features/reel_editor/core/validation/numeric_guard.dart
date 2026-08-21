/// Guards md:944-972 — never allow NaN/Infinity/negative to reach render/export
class NumericGuard {
  static bool isValidDouble(double v) => !v.isNaN && !v.isInfinite;
  static bool isValidDuration(Duration d) => d.inMilliseconds >= 0 && d.inMilliseconds <= 86400000 * 24 * 7;
  static bool isValidScale(double s) => isValidDouble(s) && s > 0 && s <= 10;
  static bool isValidOpacity(double o) => isValidDouble(o) && o >= 0 && o <= 1;
  static bool isValidVolume(double v) => isValidDouble(v) && v >= 0 && v <= 2;
  static bool isValidSpeed(double s) => isValidDouble(s) && s >= 0.25 && s <= 4.0;

  static Duration sanitizeDuration(Duration d, [Duration fallback = Duration.zero]) {
    if (!isValidDuration(d)) return fallback;
    return d;
  }

  static double sanitizeDouble(double v, double min, double max, double fallback) {
    if (!isValidDouble(v)) return fallback;
    return v.clamp(min, max).toDouble();
  }

  static double sanitizeOpacity(double v) => sanitizeDouble(v, 0, 1, 1);
  static double sanitizeScale(double v) => sanitizeDouble(v, 0.1, 10, 1);
  static double sanitizeVolume(double v) => sanitizeDouble(v, 0, 2, 1);
  static double sanitizeSpeed(double v) => sanitizeDouble(v, 0.25, 4, 1);
}

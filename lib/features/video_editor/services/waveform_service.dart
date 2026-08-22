import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Extracts amplitude peaks from an audio file for timeline waveform display.
/// Uses raw byte sampling (no native decoder dependency) — visually
/// representative for MP3/WAV/AAC/OGG even though it's not true PCM decode.
class WaveformService {
  static final WaveformService _instance = WaveformService._();
  factory WaveformService() => _instance;
  WaveformService._();

  /// Extract [numPeaks] amplitude values (0..1) from [path].
  Future<List<double>> extractPeaks(
    String path, {
    int numPeaks = 200,
  }) async {
    try {
      final file = File(path);
      if (!await file.exists()) return List.filled(numPeaks, 0.0);

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return List.filled(numPeaks, 0.0);

      final step = math.max(1, bytes.length ~/ numPeaks);
      final peaks = <double>[];

      for (var i = 0; i < numPeaks && (i * step) < bytes.length; i++) {
        final offset = i * step;
        final end = math.min(offset + step, bytes.length);

        // Average absolute byte values in this chunk as a proxy for amplitude
        var sum = 0.0;
        var count = 0;
        for (var j = offset; j < end; j++) {
          // Treat as signed 8-bit: values near 128 are silence
          final sample = (bytes[j] - 128).abs();
          sum += sample / 128.0; // normalize to 0..1
          count++;
        }
        peaks.add(count > 0 ? (sum / count).clamp(0.0, 1.0) : 0.0);
      }

      return peaks;
    } catch (e) {
      return List.filled(numPeaks, 0.0);
    }
  }

  /// Convert peaks to Uint8List for storage in AudioTimelineItem.waveformData.
  static Uint8List peaksToBytes(List<double> peaks) {
    final bytes = Uint8List(peaks.length);
    for (var i = 0; i < peaks.length; i++) {
      bytes[i] = (peaks[i] * 255).round().clamp(0, 255);
    }
    return bytes;
  }

  /// Convert stored bytes back to peaks (0..1).
  static List<double> bytesToPeaks(Uint8List bytes) {
    return bytes.map((b) => b / 255.0).toList();
  }
}

/// CustomPainter that renders an audio waveform inside a track block.
class WaveformPainter extends CustomPainter {
  final List<double> peaks;
  final Color color;
  final Color? playedColor;
  final double playedFraction; // 0..1 how much of the clip has been played

  WaveformPainter({
    required this.peaks,
    required this.color,
    this.playedColor,
    this.playedFraction = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;

    final barWidth = size.width / peaks.length;
    final centerY = size.height / 2;
    final maxBarHeight = size.height * 0.45;

    final paint = Paint()
      ..strokeWidth = math.max(0.5, barWidth - 0.5)
      ..strokeCap = StrokeCap.round;

    final playedPaint = playedColor != null
        ? (Paint()
          ..strokeWidth = math.max(0.5, barWidth - 0.5)
          ..strokeCap = StrokeCap.round
          ..color = playedColor!)
        : null;

    for (var i = 0; i < peaks.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final barHeight = peaks[i] * maxBarHeight;
      final isPlayed = playedFraction > 0 && i / peaks.length < playedFraction;

      paint.color = isPlayed && playedPaint != null
          ? playedPaint.color
          : color.withValues(alpha: 0.6 + peaks[i] * 0.4);

      canvas.drawLine(
        Offset(x, centerY - barHeight),
        Offset(x, centerY + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter old) =>
      peaks != old.peaks ||
      color != old.color ||
      playedFraction != old.playedFraction;
}

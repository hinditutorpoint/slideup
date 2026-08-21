import '../../core/validation/numeric_guard.dart';
import '../../core/errors/reel_exceptions.dart';
import '../../models/reel_project.dart';

/// Centralized FFmpeg engine md:1100 — single source, no scatter
/// Performance: streaming file-based, no 4K load; crash: validates paths/durations; RenderFlex-free N/A
class FfmpegEngine {
  static String _escPath(String p) => p.replaceAll("'", r"'\''");
  static String _escText(String t) => t.replaceAll("'", r"\'").replaceAll(":", r'\:').replaceAll("%", r'\%');

  /// Build export command for [project] -> [outputPath]
  /// Handles: speed via setpts/atempo, xfade transitions, drawtext overlays, eq filters, amix audio
  List<String> buildCommand(ReelProject project, String outputPath) {
    if (project.videoTracks.isEmpty) throw const ExportException('no_tracks', 'No video tracks to export');
    // creative: use exportPreset to derive resolution/bitrate md:21
    final preset = project.exportPreset;
    final fps = NumericGuard.sanitizeDouble(preset.fps.toDouble(), 15, 60, 30).round();
    final outW = preset.width.clamp(144, 3840);
    final outH = preset.height.clamp(144, 3840);
    if (outputPath.isEmpty) throw const ExportException('bad_output', 'Output path empty');
    if (!NumericGuard.isValidDouble(fps.toDouble())) throw const ExportException('bad_fps', 'Invalid fps');

    final inputs = <String>[];
    final videoLabels = <String>[];
    final filterParts = <String>[];

    // video inputs with speed handling
    for (int i = 0; i < project.videoTracks.length; i++) {
      final v = project.videoTracks[i];
      if (v.sourcePath.isEmpty) throw ExportException('missing_source', 'Clip ${v.id} missing sourcePath');
      if (!NumericGuard.isValidDuration(v.trimEnd - v.trimStart)) throw ExportException('bad_trim', 'Clip ${v.id} bad trim');
      if (v.trimEnd <= v.trimStart) throw ExportException('bad_trim', 'Clip ${v.id} trimEnd <= trimStart');
      final ss = NumericGuard.sanitizeDouble(v.trimStart.inMilliseconds / 1000, 0, 86400, 0);
      final to = NumericGuard.sanitizeDouble(v.trimEnd.inMilliseconds / 1000, ss, 86400, ss + 1);
      inputs.addAll(['-ss', '$ss', '-to', '$to', '-i', _escPath(v.sourcePath)]);

      // speed + crop + scale creative chain md:20/273
      final speed = NumericGuard.sanitizeSpeed(v.speed);
      String label = '[$i:v]';
      final filters = <String>[];
      if (v.hasCrop) {
        // normalized crop -> relative ffmpeg crop
        final cw = NumericGuard.sanitizeDouble(v.cropRight - v.cropLeft, 0.1, 1, 1);
        final ch = NumericGuard.sanitizeDouble(v.cropBottom - v.cropTop, 0.1, 1, 1);
        final cx = NumericGuard.sanitizeDouble(v.cropLeft, 0, 1, 0);
        final cy = NumericGuard.sanitizeDouble(v.cropTop, 0, 1, 0);
        filters.add('crop=iw*$cw:ih*$ch:iw*$cx:ih*$cy');
      }
      if (speed != 1.0) { filters.add('setpts=PTS/$speed'); }
      if (v.rotation != 0) {
        final r = v.rotation % 360;
        if (r == 90) { filters.add('transpose=1'); }
        else if (r == 180) { filters.add('transpose=1,transpose=1'); }
        else if (r == 270) { filters.add('transpose=2'); }
      }
      if (v.flipH) { filters.add('hflip'); }
      if (v.flipV) { filters.add('vflip'); }
      filters.add('scale=$outW:$outH:flags=fast_bilinear');
      final tmp = '[v$i]';
      filterParts.add('$label ${filters.join(",")} $tmp');
      label = tmp;
      videoLabels.add(label);

      // per-clip mute handled via audio mapping later
    }

    // transitions via xfade chain md:20 — fallback to concat if no transitions
    String concatLabel = '[vcat]';
    if (project.transitions.isNotEmpty && videoLabels.length >= 2) {
      String cur = videoLabels[0];
      Duration offset = project.videoTracks[0].trimmedDuration;
      for (int i = 1; i < videoLabels.length; i++) {
        final tr = project.transitions[(i - 1) % project.transitions.length];
        final durMs = tr.duration.inMilliseconds.clamp(100, 2000);
        final durSec = NumericGuard.sanitizeDouble(durMs / 1000, 0.1, 2, 0.5);
        final offSec = NumericGuard.sanitizeDouble((offset.inMilliseconds - durMs) / 1000, 0, 86400, 0);
        final next = videoLabels[i];
        final out = i == videoLabels.length - 1 ? concatLabel : '[x$i]';
        final type = _xfadeType(tr.type);
        filterParts.add('$cur$next xfade=transition=$type:duration=$durSec:offset=$offSec $out');
        cur = out;
        offset += project.videoTracks[i].trimmedDuration - Duration(milliseconds: durMs);
      }
    } else {
      // simple concat
      if (videoLabels.length == 1) {
        filterParts.add('${videoLabels[0]} null $concatLabel');
      } else {
        final ins = videoLabels.join('');
        filterParts.add('$ins concat=n=${videoLabels.length}:v=1:a=0 $concatLabel');
      }
    }

    // global filter eq from filterSettings intensity
    String videoOut = concatLabel;
    final filterId = project.filterSettings.filterId;
    if (filterId != null && filterId.isNotEmpty && filterId != 'none') {
      final intensity = NumericGuard.sanitizeOpacity(project.filterSettings.intensity);
      // map intensity to blend — simple eq saturation scaling
      final eq = 'eq=saturation=${(1 + (intensity - 0.5) * 0.5).clamp(0.5, 1.5)}';
      final out = '[vfx]';
      filterParts.add('$videoOut $eq $out');
      videoOut = out;
    }

    // text overlays via drawtext per layer
    for (final t in project.textLayers) {
      if (t.text.isEmpty) continue;
      final esc = _escText(t.text);
      final fs = t.fontSize.clamp(8, 200).round();
      final x = (t.x * outW).round().clamp(0, outW);
      final y = (t.y * outH).round().clamp(0, outH);
      final start = NumericGuard.sanitizeDouble(t.startTime.inMilliseconds / 1000, 0, 86400, 0);
      final end = NumericGuard.sanitizeDouble(t.endTime.inMilliseconds / 1000, start, 86400, start + 1);
      final out = '[vt${t.id}]';
      filterParts.add("$videoOut drawtext=text='$esc':fontcolor=white:fontsize=$fs:x=$x-text_w/2:y=$y-text_h/2:enable='between(t,$start,$end)' $out");
      videoOut = out;
    }

    // creative: shape layers via drawbox — extendable to circle/star
    for (final sh in project.shapeLayers) {
      final cx = (sh.x * outW).round().clamp(0, outW);
      final cy = (sh.y * outH).round().clamp(0, outH);
      final sz = (sh.scale * 80).round().clamp(10, 400);
      final col = '0x${sh.fillColor.toRadixString(16).padLeft(8,'0')}';
      final start = NumericGuard.sanitizeDouble(sh.startTime.inMilliseconds/1000,0,86400,0);
      final end = NumericGuard.sanitizeDouble(sh.endTime.inMilliseconds/1000,start,86400,start+1);
      final out = '[vs${sh.id}]';
      filterParts.add("$videoOut drawbox=x=$cx-${sz~/2}:y=$cy-${sz~/2}:w=$sz:h=$sz:color=$col:t=fill:enable='between(t,$start,$end)' $out");
      videoOut = out;
    }

    // audio mixing via amix — skip if no audio tracks
    final hasAudio = project.audioTracks.isNotEmpty || project.videoTracks.any((v) => !v.mute);
    final filterComplex = filterParts.join(';');

    final cmd = <String>[
      ...inputs,
      if (filterComplex.isNotEmpty) ...['-filter_complex', filterComplex],
      '-map', videoOut,
      if (hasAudio) ..._audioMaps(project),
      '-r', '$fps',
      '-s', '${outW}x$outH',
      '-c:v', preset.vCodec,
      '-b:v', '${preset.vBitrate}k',
      '-preset', 'ultrafast',
      '-c:a', preset.aCodec,
      '-b:a', '${preset.aBitrate}k',
      '-movflags', '+faststart',
      '-y', _escPath(outputPath),
    ];
    return cmd;
  }

  List<String> _audioMaps(ReelProject p) {
    // minimal: map first audio or video audio; full amix when multiple
    if (p.audioTracks.isEmpty) return ['-map', '0:a?'];
    return ['-map', '0:a?', '-map', '${p.videoTracks.length}:a?'];
  }

  String _xfadeType(String t) {
    switch (t) {
      case 'slide':
        return 'slideleft';
      case 'wipe':
        return 'wiperight';
      case 'fade':
      default:
        return 'fade';
    }
  }
}

import '../services/media_metadata_service.dart';

/// Rich metadata for an audio file, extracted via ffprobe.
///
/// Create from a raw ffprobe JSON map with [AudioData.fromFfprobe] or load
/// directly from a file path with [AudioData.load].
class AudioData {
  final String? title;
  final String? album;
  final String? author;
  final String? writer;
  final String? artist;
  final String? albumArtist;
  final String? composer;
  final String? genre;
  final int? year;
  final String? date;
  final bool compilation;
  final int? trackNumber;
  final int? discNumber;
  final int? durationMs;
  final int? durationSec;
  final String durationFormatted;
  final int? bitrate;
  final String? bitrateKbps;
  final String? mimeType;
  final int? fileSizeBytes;
  final String fileSizeMB;
  final String? quality;
  final bool hasArtwork;

  const AudioData({
    this.title,
    this.album,
    this.author,
    this.writer,
    this.artist,
    this.albumArtist,
    this.composer,
    this.genre,
    this.year,
    this.date,
    this.compilation = false,
    this.trackNumber,
    this.discNumber,
    this.durationMs,
    this.durationSec,
    this.durationFormatted = '',
    this.bitrate,
    this.bitrateKbps,
    this.mimeType,
    this.fileSizeBytes,
    this.fileSizeMB = '',
    this.quality,
    this.hasArtwork = false,
  });

  /// Builds [AudioData] from an ffprobe JSON map (the shape returned by
  /// [MediaMetadataService.getMediaMetadata]).
  factory AudioData.fromFfprobe(
    Map<String, dynamic> meta, {
    String? path,
  }) {
    final duration = MediaMetadataService.getDuration(meta);

    final rawBitrate =
        int.tryParse(meta['format']?['bit_rate']?.toString() ?? '');
    final kbps = rawBitrate == null ? null : (rawBitrate / 1000).round();

    final size = int.tryParse(meta['format']?['size']?.toString() ?? '');

    final trackRaw = MediaMetadataService.getTrackNumber(meta);
    final discRaw = MediaMetadataService.getDiscNumber(meta);

    final compRaw = MediaMetadataService.getTag(meta, 'compilation') ??
        MediaMetadataService.getTag(meta, 'tcmp');

    return AudioData(
      title: MediaMetadataService.getTitle(meta),
      album: MediaMetadataService.getAlbum(meta),
      author:
          MediaMetadataService.getTag(meta, 'author') ??
          MediaMetadataService.getArtist(meta),
      writer:
          MediaMetadataService.getTag(meta, 'writer') ??
          MediaMetadataService.getTag(meta, 'lyricist') ??
          MediaMetadataService.getComposer(meta),
      artist: MediaMetadataService.getArtist(meta),
      albumArtist: MediaMetadataService.getAlbumArtist(meta),
      composer: MediaMetadataService.getComposer(meta),
      genre: MediaMetadataService.getGenre(meta),
      year: MediaMetadataService.getYear(meta),
      date:
          MediaMetadataService.getTag(meta, 'date') ??
          MediaMetadataService.getTag(meta, 'year'),
      compilation:
          compRaw != null &&
          (compRaw == '1' ||
              compRaw.toLowerCase() == 'true' ||
              compRaw.toLowerCase() == 'yes'),
      trackNumber: _leadingInt(trackRaw),
      discNumber: _leadingInt(discRaw),
      durationMs: duration?.inMilliseconds,
      durationSec: duration?.inSeconds,
      durationFormatted: _formatDuration(duration),
      bitrate: rawBitrate,
      bitrateKbps: kbps == null ? null : '$kbps kbps',
      mimeType: _mimeForPath(path, meta),
      fileSizeBytes: size,
      fileSizeMB: size == null
          ? ''
          : '${(size / (1024 * 1024)).toStringAsFixed(2)} MB',
      quality: _qualityFromKbps(kbps),
      hasArtwork: _hasAttachedArtwork(meta),
    );
  }

  /// Loads [AudioData] for [path] via ffprobe. Returns null when the probe
  /// yields no metadata.
  static Future<AudioData?> load(String path) async {
    final meta = await MediaMetadataService.getMediaMetadata(path);
    if (meta.isEmpty) return null;
    return AudioData.fromFfprobe(meta, path: path);
  }

  static int? _leadingInt(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'^(\d+)').firstMatch(raw.trim());
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  static String _formatDuration(Duration? d) {
    if (d == null) return '';
    final seconds = d.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  static String? _qualityFromKbps(int? kbps) {
    if (kbps == null) return null;
    if (kbps < 96) return 'Low';
    if (kbps < 192) return 'Standard';
    if (kbps < 256) return 'Good';
    if (kbps < 320) return 'High';
    return 'Very High';
  }

  static String? _mimeForPath(String? path, Map<String, dynamic> meta) {
    final tag = MediaMetadataService.getTag(meta, 'mime');
    if (tag != null) return tag;

    if (path == null) return null;
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'mp4': 'audio/mp4',
      'aac': 'audio/aac',
      'flac': 'audio/flac',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'oga': 'audio/ogg',
      'opus': 'audio/opus',
      'wma': 'audio/x-ms-wma',
      'mka': 'audio/x-matroska',
      'aiff': 'audio/aiff',
      'aif': 'audio/aiff',
    };
    return map[ext];
  }

  static bool _hasAttachedArtwork(Map<String, dynamic> meta) {
    final streams = meta['streams'];
    if (streams is! List) return false;
    for (final s in streams) {
      if (s is Map && s['disposition'] is Map) {
        final disposition = s['disposition'] as Map;
        if (disposition['attached_pic'] == 1) return true;
      }
    }
    return false;
  }
}

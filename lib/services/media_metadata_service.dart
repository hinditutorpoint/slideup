import 'dart:convert';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'thumbnail_service.dart';

class MediaMetadataService {
  MediaMetadataService._(); // no instance

  // -------------------------------
  // Public API
  // -------------------------------
  static Future<Map<String, dynamic>> getMediaMetadata(String path) async {
    try {
      final session = await FFprobeKit.execute(
        '-v quiet -print_format json -show_format -show_streams "$path"',
      );

      final output = await session.getOutput();

      if (output == null || output.isEmpty) {
        return {};
      }

      return jsonDecode(output) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // -------------------------------
  // Tag helpers
  // -------------------------------
  static String? getTag(Map<String, dynamic> meta, String key) {
    String? read(Map<String, dynamic>? tags) {
      if (tags == null || tags.isEmpty) return null;

      // Exact match first (ID3v2, MP4, etc.)
      final direct = tags[key];
      if (direct != null) return direct.toString();

      // Case-insensitive fallback: ffprobe reports Vorbis/FLAC comments in
      // UPPERCASE (ARTIST, ALBUM, TITLE...) so an exact lookup misses them.
      final lowerKey = key.toLowerCase();
      for (final entry in tags.entries) {
        if (entry.key.toLowerCase() == lowerKey) {
          return entry.value.toString();
        }
      }

      return null;
    }

    // 1️⃣ format.tags
    final formatTags = meta['format']?['tags'];
    final fromFormat = read(
      formatTags is Map ? Map<String, dynamic>.from(formatTags) : null,
    );
    if (fromFormat != null) {
      return fromFormat;
    }

    // 2️⃣ streams[].tags (audio first)
    final streams = meta['streams'];
    if (streams is List) {
      for (final s in streams) {
        final tags = s['tags'];
        if (tags is Map) {
          final value = read(Map<String, dynamic>.from(tags));
          if (value != null) {
            return value;
          }
        }
      }
    }

    return null;
  }

  // -------------------------------
  // Convenience getters
  // -------------------------------
  static Duration? getDuration(Map<String, dynamic> meta) {
    final d = meta['format']?['duration'];
    if (d == null) return null;

    final seconds = double.tryParse(d.toString());
    if (seconds == null) return null;

    return Duration(milliseconds: (seconds * 1000).round());
  }

  static int? getYear(Map<String, dynamic> meta) {
    final date = getTag(meta, 'date') ?? getTag(meta, 'year');

    if (date == null || date.length < 4) return null;

    return int.tryParse(date.substring(0, 4));
  }

  static String? getArtist(Map<String, dynamic> meta) => getTag(meta, 'artist');

  static String? getAlbum(Map<String, dynamic> meta) => getTag(meta, 'album');

  static String? getGenre(Map<String, dynamic> meta) => getTag(meta, 'genre');

  static String? getTitle(Map<String, dynamic> meta) => getTag(meta, 'title');

  static String? getComment(Map<String, dynamic> meta) =>
      getTag(meta, 'comment');

  static String? getComposer(Map<String, dynamic> meta) =>
      getTag(meta, 'composer');

  static String? getTrackNumber(Map<String, dynamic> meta) =>
      getTag(meta, 'track');

  static String? getDiscNumber(Map<String, dynamic> meta) =>
      getTag(meta, 'disc');

  static String? getAlbumArtist(Map<String, dynamic> meta) =>
      getTag(meta, 'album_artist');

  static String? getPublisher(Map<String, dynamic> meta) =>
      getTag(meta, 'publisher');

  static String? getCopyright(Map<String, dynamic> meta) =>
      getTag(meta, 'copyright');

  static String? getLyrics(Map<String, dynamic> meta) => getTag(meta, 'lyrics');

  static String? getEncoder(Map<String, dynamic> meta) =>
      getTag(meta, 'encoder');

  static String? getLanguage(Map<String, dynamic> meta) =>
      getTag(meta, 'language');

  static String? getDescription(Map<String, dynamic> meta) =>
      getTag(meta, 'description');

  static String? getDurationString(Map<String, dynamic> meta) {
    final duration = getDuration(meta);
    if (duration == null) return null;

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String? getBitrate(Map<String, dynamic> meta) {
    final bitrate = meta['format']?['bit_rate'];
    if (bitrate == null) return null;

    return bitrate.toString();
  }

  static String? getCodec(Map<String, dynamic> meta) {
    final streams = meta['streams'];
    if (streams is List && streams.isNotEmpty) {
      final codec = streams[0]['codec_name'];
      if (codec != null) {
        return codec.toString();
      }
    }
    return null;
  }

  static String? getResolution(Map<String, dynamic> meta) {
    final streams = meta['streams'];
    if (streams is List) {
      for (final s in streams) {
        if (s['codec_type'] == 'video') {
          final width = s['width'];
          final height = s['height'];
          if (width != null && height != null) {
            return '${width}x$height';
          }
        }
      }
    }
    return null;
  }

  static String? getFrameRate(Map<String, dynamic> meta) {
    final streams = meta['streams'];
    if (streams is List) {
      for (final s in streams) {
        if (s['codec_type'] == 'video') {
          final r = s['r_frame_rate'];
          if (r != null) {
            return r.toString();
          }
        }
      }
    }
    return null;
  }

  static String? getSampleRate(Map<String, dynamic> meta) {
    final streams = meta['streams'];
    if (streams is List) {
      for (final s in streams) {
        if (s['codec_type'] == 'audio') {
          final rate = s['sample_rate'];
          if (rate != null) {
            return rate.toString();
          }
        }
      }
    }
    return null;
  }

  static String? getChannels(Map<String, dynamic> meta) {
    final streams = meta['streams'];
    if (streams is List) {
      for (final s in streams) {
        if (s['codec_type'] == 'audio') {
          final channels = s['channels'];
          if (channels != null) {
            return channels.toString();
          }
        }
      }
    }
    return null;
  }

  static Uint8List? getAlbumArt(Map<String, dynamic> meta) {
    final streams = meta['streams'];
    if (streams is List) {
      for (final s in streams) {
        if (s['disposition'] != null &&
            s['disposition']['attached_pic'] == 1 &&
            s['codec_type'] == 'video') {
          final data = s['data'];
          if (data != null && data is String) {
            return base64Decode(data);
          }
        }
      }
    }
    return null;
  }

  static Future<String?> getThumbnail(String path) async {
    try {
      return await ThumbnailService.instance.getThumbnail(path);
    } catch (e) {
      return null;
    }
  }
}

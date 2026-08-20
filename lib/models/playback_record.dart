import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Always-on playback/access record.
///
/// Unlike `recent_files`, entries here are written even when the
/// "Recent History" setting is off, so "Ask to Resume Last Position" keeps
/// working. Each record is keyed by a stable [mediaKey] (content fingerprint
/// for local files, the URL for network streams) so renaming or moving a file
/// still resolves to the same history via [fileHash].
class PlaybackRecord {
  final String id;
  final String mediaKey;
  final String? mediaId;
  final String path;
  final String? title;
  final int mediaType;
  final DateTime lastPlayedAt;
  final int? lastPosition;
  final int? duration;
  final int playCount;
  final String? fileHash;
  final int? fileSize;
  final DateTime? dateModified;

  const PlaybackRecord({
    required this.id,
    required this.mediaKey,
    this.mediaId,
    required this.path,
    this.title,
    required this.mediaType,
    required this.lastPlayedAt,
    this.lastPosition,
    this.duration,
    this.playCount = 1,
    this.fileHash,
    this.fileSize,
    this.dateModified,
  });

  PlaybackRecord copyWith({
    String? id,
    String? mediaKey,
    String? mediaId,
    String? path,
    String? title,
    int? mediaType,
    DateTime? lastPlayedAt,
    int? lastPosition,
    int? duration,
    int? playCount,
    String? fileHash,
    int? fileSize,
    DateTime? dateModified,
  }) {
    return PlaybackRecord(
      id: id ?? this.id,
      mediaKey: mediaKey ?? this.mediaKey,
      mediaId: mediaId ?? this.mediaId,
      path: path ?? this.path,
      title: title ?? this.title,
      mediaType: mediaType ?? this.mediaType,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      lastPosition: lastPosition ?? this.lastPosition,
      duration: duration ?? this.duration,
      playCount: playCount ?? this.playCount,
      fileHash: fileHash ?? this.fileHash,
      fileSize: fileSize ?? this.fileSize,
      dateModified: dateModified ?? this.dateModified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaKey': mediaKey,
      'mediaId': mediaId,
      'path': path,
      'title': title,
      'mediaType': mediaType,
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
      'lastPosition': lastPosition,
      'duration': duration,
      'playCount': playCount,
      'fileHash': fileHash,
      'fileSize': fileSize,
      'dateModified': dateModified?.toIso8601String(),
    };
  }

  factory PlaybackRecord.fromJson(Map<String, dynamic> json) {
    return PlaybackRecord(
      id: json['id'] as String,
      mediaKey: json['mediaKey'] as String,
      mediaId: json['mediaId'] as String?,
      path: json['path'] as String,
      title: json['title'] as String?,
      mediaType: json['mediaType'] as int,
      lastPlayedAt: DateTime.parse(json['lastPlayedAt'] as String),
      lastPosition: json['lastPosition'] as int?,
      duration: json['duration'] as int?,
      playCount: json['playCount'] as int? ?? 1,
      fileHash: json['fileHash'] as String?,
      fileSize: json['fileSize'] as int?,
      dateModified: json['dateModified'] != null
          ? DateTime.tryParse(json['dateModified'] as String)
          : null,
    );
  }

  /// Stable key for a local file: its sampled content fingerprint.
  /// For network URLs the URL itself is used.
  static Future<String> resolveMediaKey(String pathOrUrl) async {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return 'url:$pathOrUrl';
    }
    return 'fp:${await computeFileFingerprint(File(pathOrUrl))}';
  }

  /// Dependency-free sampled fingerprint: FNV-1a 64 over the first and last
  /// 64 KB plus the file size. Cheap (reads ~128 KB) yet stable across a
  /// rename or move since the content is unchanged.
  static Future<String> computeFileFingerprint(File file) async {
    try {
      if (!await file.exists()) return 'none';
      final length = await file.length();
      if (length <= 0) return 'empty';
      const sample = 64 * 1024;
      final buf = BytesBuilder();
      final raf = await file.open();
      try {
        if (length > sample * 2) {
          buf.add(await raf.read(sample));
          await raf.setPosition(length - sample);
          buf.add(await raf.read(sample));
        } else {
          buf.add(await raf.read(length));
        }
      } finally {
        await raf.close();
      }
      return '${length}_${_fnv1a64(buf.toBytes())}';
    } catch (_) {
      return 'none';
    }
  }

  static String _fnv1a64(Uint8List bytes) {
    var hash = 0xcbf29ce484222325;
    for (final b in bytes) {
      hash ^= b;
      hash *= 0x100000001b3;
      hash &= 0xffffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static String fileNameFromPath(String pathOrUrl) {
    try {
      final uri = Uri.parse(pathOrUrl);
      if (uri.hasScheme) {
        final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (seg.isNotEmpty) return seg.last;
      }
    } catch (_) {}
    return p.basename(pathOrUrl);
  }
}
import 'dart:io';

import '../models/conversion_models.dart';

/// Pure output file-name helpers. Safe filename generation is security
/// relevant: we always derive names from a validated basename — never from
/// user-supplied raw paths — and reject path-traversal inputs.
class OutputNaming {
  OutputNaming._();

  static bool _hasInvalidExtensions(String name) =>
      name.contains('.') && name.endsWith('.mp3.mp4');

  /// Strips the final extension: `movie.mkv` -> `movie`.
  static String basename(String fileName) {
    final clean = fileName.trim();
    if (clean.isEmpty) return 'output';
    final dot = clean.lastIndexOf('.');
    if (dot <= 0) return clean;
    return clean.substring(0, dot);
  }

  /// `movie.mkv` + MP4 -> `movie.mp4` (never `movie.mkv.mp4`).
  static String outputFileName(String sourceName, ContainerFormat target) {
    final base = basename(sourceName);
    return '$base.${target.extension}';
  }

  /// Appends ` (n)` before the extension until the path is free.
  /// `movie.mp4` -> `movie (1).mp4` -> `movie (2).mp4` ...
  static String uniqueFilePath(String dirPath, String fileName) {
    final candidate = fileName;
    final extDot = candidate.lastIndexOf('.');
    final base = extDot > 0 ? candidate.substring(0, extDot) : candidate;
    final ext = extDot > 0 ? candidate.substring(extDot) : '';
    var name = candidate;
    var n = 1;
    while (File('$dirPath${Platform.pathSeparator}$name').existsSync()) {
      name = '$base ($n)$ext';
      n++;
      if (n > 10000) break; // safety valve
    }
    return '$dirPath${Platform.pathSeparator}$name';
  }

  /// Rejects file names that could escape the output directory or inject
  /// arguments. Returns an error string or `null` when valid.
  static String? validateFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '.' || trimmed == '..') {
      return 'File name cannot be empty';
    }
    if (trimmed.contains('/') || trimmed.contains('\\')) {
      return 'File name cannot contain path separators';
    }
    if (trimmed.contains('..')) {
      return 'File name cannot contain ".."';
    }
    if (trimmed.startsWith('-')) {
      return 'File name cannot start with "-"';
    }
    if (_hasInvalidExtensions(trimmed)) return 'Invalid output name';
    for (final codeUnit in trimmed.codeUnits) {
      if (codeUnit < 32) {
        return 'File name contains invalid characters';
      }
    }
    return null;
  }

  /// True when a conversion from [before] to [after] would produce the same
  /// file (e.g. mp4 -> mp4 with the same output name and folder).
  static bool wouldOverwriteSource(String sourcePath, String outputPath) {
    try {
      final s = File(sourcePath).absolute.path;
      final o = File(outputPath).absolute.path;
      return s == o;
    } catch (_) {
      return sourcePath == outputPath;
    }
  }
}
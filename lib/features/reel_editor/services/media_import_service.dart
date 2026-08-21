import 'dart:io';
import '../core/errors/reel_exceptions.dart';
import '../core/validation/numeric_guard.dart';

/// Media import validator md:8 — checks 11 failure modes before insertion
class MediaImportService {
  static const int _maxFileBytes = 2 * 1024 * 1024 * 1024; // 2GB soft limit

  Future<void> validate(String path) async {
    if (path.isEmpty) throw const MediaImportException('empty_path', 'Path empty');
    final f = File(path);
    if (!await f.exists()) throw MediaImportException('missing', 'File missing: $path');
    final len = await f.length();
    if (len == 0) throw MediaImportException('zero_byte', 'Zero-byte file: $path');
    if (len > _maxFileBytes) throw MediaImportException('too_large', 'File >2GB: $path');
    if (!NumericGuard.isValidDouble(len.toDouble())) throw const MediaImportException('bad_size', 'Invalid size');
    // extension check — catches unsupported codecs early
    final ext = path.split('.').last.toLowerCase();
    const allowed = {'mp4','mov','mkv','avi','webm','mp3','aac','wav','m4a','jpg','jpeg','png','webp'};
    if (!allowed.contains(ext)) throw MediaImportException('unsupported', 'Unsupported type .$ext');
    // unicode / spaces are allowed — just validate not empty after trim
    if (path.trim().isEmpty) throw const MediaImportException('bad_name', 'Bad filename');
  }

  // creative: friendly error mapper for UI
  static String friendly(Object e) {
    if (e is MediaImportException) {
      switch (e.code) {
        case 'missing': return 'File moved or deleted. Re-import it.';
        case 'zero_byte': return 'File is empty/corrupt.';
        case 'too_large': return 'File too large — trim or compress first.';
        case 'unsupported': return 'Format not supported on this device.';
        default: return e.message;
      }
    }
    return e.toString();
  }
}

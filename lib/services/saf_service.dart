import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin bridge to the native Storage Access Framework (SAF) channel.
///
/// Removable volumes (USB OTG / SD card) on older Android versions block raw
/// file-path writes, so deletes/moves must go through SAF after the user
/// grants access to the volume's document tree once.
class SafService {
  SafService._();

  static final SafService instance = SafService._();

  static const MethodChannel _channel = MethodChannel(
    'com.slideup.mediaplayer/saf',
  );

  bool get _isAndroid => Platform.isAndroid;

  /// Deletes [filePath] through SAF.
  ///
  /// Returns one of:
  /// - `'ok'` — deleted successfully
  /// - `'needs_tree'` — no persisted grant for this volume; call [pickTree] first
  /// - `'error'` — deletion failed
  Future<String> deleteFile(String filePath) async {
    if (!_isAndroid) return 'error';
    try {
      final result = await _channel.invokeMethod<String>('deleteFile', {
        'path': filePath,
      });
      return result ?? 'error';
    } catch (e) {
      debugPrint('❌ SAF deleteFile error: $e');
      return 'error';
    }
  }

  /// Opens the system folder picker so the user can grant access to a
  /// removable volume. Returns the persisted tree URI, or null if cancelled.
  Future<String?> pickTree() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('pickTree');
    } catch (e) {
      debugPrint('❌ SAF pickTree error: $e');
      return null;
    }
  }
}
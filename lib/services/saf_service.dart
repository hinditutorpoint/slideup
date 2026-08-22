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

  /// Stores a tree URI (e.g. granted through the `saf` plugin's
  /// [Saf.pickDirectory]) into the persisted registry so [deleteFile] can
  /// reuse it. Returns the removable volume root id, or null if the URI is
  /// not a removable-volume tree.
  Future<String?> storeTree(String treeUri) async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('storeTree', {
        'treeUri': treeUri,
      });
    } catch (e) {
      debugPrint('❌ SAF storeTree error: $e');
      return null;
    }
  }

  /// True when a persisted tree grant already exists for [filePath]'s
  /// removable volume, so callers can reuse it instead of re-prompting.
  Future<bool> hasTree(String filePath) async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasTree', {
            'path': filePath,
          }) ??
          false;
    } catch (e) {
      debugPrint('❌ SAF hasTree error: $e');
      return false;
    }
  }

  /// Returns volume root ids (e.g. `XXXX-XXXX`) that have a persisted tree
  /// grant, so Dart-side routing can use SAF after an app restart.
  Future<Set<String>> getStoredTrees() async {
    if (!_isAndroid) return {};
    try {
      final roots = await _channel.invokeListMethod<String>('getStoredTrees');
      return roots?.toSet() ?? {};
    } catch (e) {
      debugPrint('❌ SAF getStoredTrees error: $e');
      return {};
    }
  }

  /// Writes [bytes] to [filePath] through SAF (removable) or direct I/O (emulated).
  ///
  /// Returns one of:
  /// - `'ok'` — written successfully
  /// - `'needs_tree'` — removable volume but no persisted grant; call [pickTree] first
  /// - `'error'` — write failed
  Future<String> writeFile(String filePath, Uint8List bytes) async {
    if (!_isAndroid) return 'error';
    try {
      final result = await _channel.invokeMethod<String>('writeFile', {
        'path': filePath,
        'bytes': bytes,
      });
      return result ?? 'error';
    } catch (e) {
      debugPrint('❌ SAF writeFile error: $e');
      return 'error';
    }
  }

  /// Opens the system "All files access" settings page directly.
  /// Useful when the normal `Permission.manageExternalStorage.request()`
  /// is blocked by OEM restrictions (Xiaomi, Huawei, etc.).
  Future<void> openManageStorageSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openManageStorageSettings');
    } catch (e) {
      debugPrint('❌ SAF openManageStorageSettings error: $e');
    }
  }
}
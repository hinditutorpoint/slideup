import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FilePickerService {
  static const _storage = FlutterSecureStorage();
  static const _lastDirKey = 'last_file_picker_directory';

  static Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = false,
  }) async {
    final lastDir = await _storage.read(key: _lastDirKey);
    debugPrint('[FilePicker] pickFiles start: type=$type '
        'ext=$allowedExtensions multi=$allowMultiple initialDir=$lastDir');

    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      withData: withData,
      initialDirectory: lastDir,
    );

    if (result == null) {
      debugPrint('[FilePicker] result is NULL (user cancelled or plugin error)');
    } else {
      for (final f in result.files) {
        debugPrint('[FilePicker] picked: name=${f.name} size=${f.size} '
            'path=${f.path} identifier=${f.identifier}');
        if (f.path == null || f.path!.isEmpty) {
          debugPrint('[FilePicker] WARNING: picked file has NULL/empty path '
              '(SAF document without cached copy?)');
        }
      }
    }

    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        final dir = File(path).parent.path;
        await _storage.write(key: _lastDirKey, value: dir);
      }
    }

    return result;
  }

  static Future<String?> getDirectoryPath() async {
    final lastDir = await _storage.read(key: _lastDirKey);

    final result = await FilePicker.platform.getDirectoryPath(
      initialDirectory: lastDir,
    );

    if (result != null) {
      await _storage.write(key: _lastDirKey, value: result);
    }

    return result;
  }
}

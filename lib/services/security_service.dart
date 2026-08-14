import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum AppLockType {
  password,
  pin,
  pattern,
}

extension AppLockTypeExtension on AppLockType {
  String get displayName {
    switch (this) {
      case AppLockType.password:
        return 'Password';
      case AppLockType.pin:
        return 'PIN (Number)';
      case AppLockType.pattern:
        return 'Pattern';
    }
  }

  String get keyName => name;

  static AppLockType fromString(String? value) {
    switch (value) {
      case 'pin':
        return AppLockType.pin;
      case 'pattern':
        return AppLockType.pattern;
      case 'password':
      default:
        return AppLockType.password;
    }
  }
}

class SecurityService {
  static final SecurityService instance = SecurityService._init();

  final _secureStorage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  SecurityService._init();

  static const String _appPasswordKey = 'app_password';
  static const String _appPinKey = 'app_pin';
  static const String _appPatternKey = 'app_pattern';
  static const String _appLockTypeKey = 'app_lock_type';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _securityQuestionKey = 'security_question';
  static const String _securityAnswerKey = 'security_answer';
  static const String _fileLocksKey = 'file_locks';

  // Hash credential using SHA-256
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Security Question Management
  Future<void> setSecurityQuestion(String question, String answer) async {
    try {
      await _secureStorage.write(key: _securityQuestionKey, value: question);
      final hashedAnswer = hashPassword(answer.trim().toLowerCase());
      await _secureStorage.write(key: _securityAnswerKey, value: hashedAnswer);
    } catch (e) {
      debugPrint('⚠️ SecurityService.setSecurityQuestion error: $e');
    }
  }

  Future<String?> getSecurityQuestion() async {
    try {
      return await _secureStorage.read(key: _securityQuestionKey);
    } catch (e) {
      debugPrint('⚠️ SecurityService.getSecurityQuestion error: $e');
      return null;
    }
  }

  Future<bool> hasSecurityQuestion() async {
    try {
      final question = await _secureStorage.read(key: _securityQuestionKey);
      return question != null && question.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifySecurityAnswer(String answer) async {
    try {
      final storedHash = await _secureStorage.read(key: _securityAnswerKey);
      if (storedHash == null) return false;

      final inputHash = hashPassword(answer.trim().toLowerCase());
      return storedHash == inputHash;
    } catch (e) {
      debugPrint('⚠️ SecurityService.verifySecurityAnswer error: $e');
      return false;
    }
  }

  // App Lock Type Management
  Future<AppLockType> getAppLockType() async {
    try {
      final typeStr = await _secureStorage.read(key: _appLockTypeKey);
      if (typeStr != null) {
        return AppLockTypeExtension.fromString(typeStr);
      }
      // Fallback check based on set credential keys
      final hasPin = await _secureStorage.read(key: _appPinKey) != null;
      if (hasPin) return AppLockType.pin;

      final hasPattern = await _secureStorage.read(key: _appPatternKey) != null;
      if (hasPattern) return AppLockType.pattern;

      return AppLockType.password;
    } catch (e) {
      debugPrint('⚠️ SecurityService.getAppLockType error: $e');
      return AppLockType.password;
    }
  }

  Future<void> setAppLockType(AppLockType type) async {
    try {
      await _secureStorage.write(key: _appLockTypeKey, value: type.keyName);
    } catch (e) {
      debugPrint('⚠️ SecurityService.setAppLockType error: $e');
    }
  }

  // General App Lock Check
  Future<bool> hasAppLock() async {
    try {
      final password = await _secureStorage.read(key: _appPasswordKey);
      final pin = await _secureStorage.read(key: _appPinKey);
      final pattern = await _secureStorage.read(key: _appPatternKey);
      return (password != null && password.isNotEmpty) ||
          (pin != null && pin.isNotEmpty) ||
          (pattern != null && pattern.isNotEmpty);
    } catch (e) {
      debugPrint('⚠️ SecurityService.hasAppLock error: $e');
      return false;
    }
  }

  // Legacy & Password Management
  Future<void> setAppPassword(String password) async {
    try {
      final hashedPassword = hashPassword(password);
      await _secureStorage.write(key: _appPasswordKey, value: hashedPassword);
      await setAppLockType(AppLockType.password);
    } catch (e) {
      debugPrint('⚠️ SecurityService.setAppPassword error: $e');
    }
  }

  Future<bool> hasAppPassword() async {
    return hasAppLock();
  }

  Future<bool> verifyAppPassword(String password) async {
    try {
      final inputHash = hashPassword(password);
      final storedHash = await _secureStorage.read(key: _appPasswordKey);
      if (storedHash != null && storedHash == inputHash) return true;

      final pinHash = await _secureStorage.read(key: _appPinKey);
      if (pinHash != null && pinHash == inputHash) return true;

      return false;
    } catch (e) {
      debugPrint('⚠️ SecurityService.verifyAppPassword error: $e');
      return false;
    }
  }

  // PIN (Number) Management
  Future<void> setAppPin(String pin) async {
    try {
      final hashedPin = hashPassword(pin);
      await _secureStorage.write(key: _appPinKey, value: hashedPin);
      await setAppLockType(AppLockType.pin);
    } catch (e) {
      debugPrint('⚠️ SecurityService.setAppPin error: $e');
    }
  }

  Future<bool> verifyAppPin(String pin) async {
    try {
      final inputHash = hashPassword(pin);
      final storedHash = await _secureStorage.read(key: _appPinKey);
      if (storedHash != null && storedHash == inputHash) return true;

      final passHash = await _secureStorage.read(key: _appPasswordKey);
      if (passHash != null && passHash == inputHash) return true;

      return false;
    } catch (e) {
      debugPrint('⚠️ SecurityService.verifyAppPin error: $e');
      return false;
    }
  }

  // Pattern Management
  Future<void> setAppPattern(List<int> pattern) async {
    try {
      final patternStr = pattern.join('-');
      final hashedPattern = hashPassword(patternStr);
      await _secureStorage.write(key: _appPatternKey, value: hashedPattern);
      await setAppLockType(AppLockType.pattern);
    } catch (e) {
      debugPrint('⚠️ SecurityService.setAppPattern error: $e');
    }
  }

  Future<bool> verifyAppPattern(List<int> pattern) async {
    try {
      final storedHash = await _secureStorage.read(key: _appPatternKey);
      if (storedHash == null) return false;

      final patternStr = pattern.join('-');
      final inputHash = hashPassword(patternStr);
      return storedHash == inputHash;
    } catch (e) {
      debugPrint('⚠️ SecurityService.verifyAppPattern error: $e');
      return false;
    }
  }

  Future<void> removeAppPassword() async {
    await removeAppLock();
  }

  Future<void> removeAppLock() async {
    try {
      await _secureStorage.delete(key: _appPasswordKey);
      await _secureStorage.delete(key: _appPinKey);
      await _secureStorage.delete(key: _appPatternKey);
      await _secureStorage.delete(key: _appLockTypeKey);
      await _secureStorage.delete(key: _securityQuestionKey);
      await _secureStorage.delete(key: _securityAnswerKey);
    } catch (e) {
      debugPrint('⚠️ SecurityService.removeAppLock error: $e');
    }
  }

  // Biometric Authentication
  Future<bool> canUseBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _secureStorage.read(key: _biometricEnabledKey);
      return enabled == 'true';
    } catch (e) {
      debugPrint('⚠️ SecurityService.isBiometricEnabled error: $e');
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _secureStorage.write(
        key: _biometricEnabledKey,
        value: enabled.toString(),
      );
    } catch (e) {
      debugPrint('⚠️ SecurityService.setBiometricEnabled error: $e');
    }
  }

  Future<bool> authenticateWithBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Slideup Media Player',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  static const String slockExtension = '.slock';

  // File Lock Management
  Future<void> setFileLock(String fileId, String password) async {
    final locks = await _getFileLocks();
    locks[fileId] = hashPassword(password);
    await _saveFileLocks(locks);
  }

  Future<bool> isFileLocked(String fileId) async {
    if (fileId.endsWith(slockExtension)) return true;
    final locks = await _getFileLocks();
    return locks.containsKey(fileId);
  }

  /// Retrieves the original file extension for a `.slock` file from secure storage
  static const List<int> _slockMagicBytes = [
    0x53,
    0x4C,
    0x4F,
    0x43,
    0x4B,
    0x5F,
    0x56,
    0x31
  ]; // "SLOCK_V1"

  /// Reads embedded metadata from a `.slock` file if present
  Future<Map<String, dynamic>?> readSlockEmbeddedHeader(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final length = await file.length();
      if (length < 10) return null; // Magic (8) + Length (2)

      final raf = await file.open(mode: FileMode.read);
      try {
        final magic = await raf.read(8);
        if (!_listEquals(magic, _slockMagicBytes)) {
          return null;
        }

        final lenBytes = await raf.read(2);
        final jsonLen = (lenBytes[0] << 8) | lenBytes[1];

        if (length < 10 + jsonLen) return null;

        final jsonBytes = await raf.read(jsonLen);
        final jsonStr = utf8.decode(jsonBytes);
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        map['_headerOffset'] = 10 + jsonLen;
        return map;
      } finally {
        await raf.close();
      }
    } catch (e) {
      debugPrint('⚠️ Error reading embedded slock header: $e');
      return null;
    }
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Retrieves the lock type ('pin', 'pattern', 'password') for a locked .slock file
  Future<AppLockType> getFileLockType(String filePath) async {
    final embeddedMeta = await readSlockEmbeddedHeader(filePath);
    if (embeddedMeta != null && embeddedMeta['lockType'] != null) {
      return AppLockTypeExtension.fromString(
        embeddedMeta['lockType'] as String,
      );
    }
    return await getAppLockType();
  }

  List<int> _deriveCipherKey(String password, String salt) {
    final bytes = utf8.encode('$password:$salt:slock_vault_cipher_v1');
    return sha256.convert(bytes).bytes;
  }

  Stream<List<int>> _transformStream(
    Stream<List<int>> stream,
    List<int> key,
  ) async* {
    int keyIndex = 0;
    final keyLen = key.length;

    await for (final chunk in stream) {
      final transformed = Uint8List(chunk.length);
      for (int i = 0; i < chunk.length; i++) {
        transformed[i] = chunk[i] ^ key[keyIndex % keyLen];
        keyIndex++;
      }
      yield transformed;
    }
  }

  /// Embeds security header (original name, extension, password hash, salt & lockType) and encrypts payload
  Future<File?> writeSlockFileWithHeader({
    required File inputFile,
    required String targetPath,
    required String origExt,
    required String password,
    String? origName,
  }) async {
    try {
      final salt = DateTime.now().millisecondsSinceEpoch.toString();
      final saltedHash = hashPassword('$password:$salt');
      final currentLockType = await getAppLockType();
      final fullName = origName ?? p.basename(inputFile.path);

      final metaObj = {
        'v': 1,
        'name': fullName,
        'ext': origExt,
        'salt': salt,
        'hash': saltedHash,
        'lockType': currentLockType.keyName,
        'enc': true,
        'created': DateTime.now().toIso8601String(),
      };

      final jsonBytes = utf8.encode(jsonEncode(metaObj));
      final jsonLen = jsonBytes.length;
      final lenBytes = [(jsonLen >> 8) & 0xFF, jsonLen & 0xFF];

      final tempPath = '$targetPath.tmp';
      final outputFile = File(tempPath);
      final sink = outputFile.openWrite();

      // Write Header
      sink.add(_slockMagicBytes);
      sink.add(lenBytes);
      sink.add(jsonBytes);

      // Encrypt Payload Bytes
      final cipherKey = _deriveCipherKey(password, salt);
      final encryptedStream = _transformStream(inputFile.openRead(), cipherKey);
      await sink.addStream(encryptedStream);
      await sink.flush();
      await sink.close();

      if (await inputFile.exists() && inputFile.path != targetPath) {
        await inputFile.delete();
      }
      return await outputFile.rename(targetPath);
    } catch (e) {
      debugPrint('⚠️ Error writing embedded slock header: $e');
      return null;
    }
  }

  Future<String?> _getStoredCredential() async {
    final password = await _secureStorage.read(key: _appPasswordKey);
    if (password != null && password.isNotEmpty) return password;
    final pin = await _secureStorage.read(key: _appPinKey);
    if (pin != null && pin.isNotEmpty) return pin;
    final pattern = await _secureStorage.read(key: _appPatternKey);
    if (pattern != null && pattern.isNotEmpty) return pattern;
    return null;
  }

  /// Restores original file from .slock file by stripping header and decrypting payload
  Future<File?> restoreSlockFileFromHeader({
    required File slockFile,
    required String restoredPath,
    String? password,
    bool deleteOriginal = true,
  }) async {
    try {
      final meta = await readSlockEmbeddedHeader(slockFile.path);
      if (meta == null || meta['_headerOffset'] == null) {
        if (deleteOriginal) {
          return await slockFile.rename(restoredPath);
        } else {
          return await slockFile.copy(restoredPath);
        }
      }

      final headerOffset = meta['_headerOffset'] as int;
      final tempPath = '$restoredPath.tmp';
      final outputFile = File(tempPath);
      final sink = outputFile.openWrite();

      final isEncrypted = meta['enc'] == true;
      final salt = meta['salt'] as String? ?? '';
      final expectedHash = meta['hash'] as String?;

      String passToUse = password ?? '';
      if (passToUse.isEmpty && isEncrypted && salt.isNotEmpty) {
        if (expectedHash != null) {
          if (hashPassword('LOCKED:$salt') == expectedHash ||
              expectedHash == hashPassword('LOCKED')) {
            passToUse = 'LOCKED';
          } else {
            final appPass = await _secureStorage.read(key: _appPasswordKey);
            if (appPass != null &&
                (hashPassword('$appPass:$salt') == expectedHash ||
                    expectedHash == hashPassword(appPass))) {
              passToUse = appPass;
            } else {
              final appPin = await _secureStorage.read(key: _appPinKey);
              if (appPin != null &&
                  (hashPassword('$appPin:$salt') == expectedHash ||
                      expectedHash == hashPassword(appPin))) {
                passToUse = appPin;
              } else {
                passToUse = 'LOCKED';
              }
            }
          }
        } else {
          passToUse = 'LOCKED';
        }
      }

      if (isEncrypted && salt.isNotEmpty) {
        final cipherKey = _deriveCipherKey(passToUse, salt);
        final decryptedStream = _transformStream(
          slockFile.openRead(headerOffset),
          cipherKey,
        );
        await sink.addStream(decryptedStream);
      } else {
        await sink.addStream(slockFile.openRead(headerOffset));
      }

      await sink.flush();
      await sink.close();

      if (deleteOriginal && await slockFile.exists()) {
        await slockFile.delete();
      }
      return await outputFile.rename(restoredPath);
    } catch (e) {
      debugPrint('⚠️ Error restoring slock file from header: $e');
      return null;
    }
  }

  /// Clears old temporary decrypted media cache files
  Future<void> clearTempCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final list = tempDir.listSync();
        for (final entity in list) {
          if (entity is File && p.basename(entity.path).startsWith('cache_')) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error clearing temp cache: $e');
    }
  }

  /// Creates a temporary decrypted copy of a .slock file in cache for in-app media viewing
  Future<File?> createTempDecryptedCopy(
    String slockPath, {
    String? password,
  }) async {
    try {
      await clearTempCache(); // Automatically purge previous view cache
      final embeddedMeta = await readSlockEmbeddedHeader(slockPath);

      // Determine the correct original name with extension.
      // Priority: embedded 'name' field (full name like 'video.mp4'),
      // then build from basenameWithoutExtension + 'ext' field,
      // then fallback to legacy meta storage.
      String name;
      if (embeddedMeta != null && embeddedMeta['name'] != null) {
        name = embeddedMeta['name'] as String;
        // If name has no extension but 'ext' is available, append it
        if (p.extension(name).isEmpty && embeddedMeta['ext'] != null) {
          name = '$name${embeddedMeta['ext']}'; 
        }
      } else {
        // Old format: no embedded header — try legacy meta map for extension
        final origExt = await getOriginalExtension(slockPath);
        final baseName = p.basenameWithoutExtension(slockPath);
        name = origExt != null && origExt.isNotEmpty ? '$baseName$origExt' : baseName;
      }

      final tempDir = await getTemporaryDirectory();
      final cachePath = p.join(tempDir.path, 'cache_$name');

      final cacheFile = File(cachePath);
      if (await cacheFile.exists()) {
        try {
          await cacheFile.delete();
        } catch (_) {}
      }

      return await restoreSlockFileFromHeader(
        slockFile: File(slockPath),
        restoredPath: cachePath,
        password: password,
        deleteOriginal: false,
      );
    } catch (e) {
      debugPrint('⚠️ SecurityService.createTempDecryptedCopy error: $e');
      return null;
    }
  }

  /// Retrieves the original file extension for a `.slock` file
  Future<String?> getOriginalExtension(String filePath) async {
    if (!filePath.endsWith(slockExtension)) {
      return p.extension(filePath);
    }
    // 1. Try reading embedded header (persistent across app uninstalls!)
    final embeddedMeta = await readSlockEmbeddedHeader(filePath);
    if (embeddedMeta != null && embeddedMeta['ext'] != null) {
      return embeddedMeta['ext'] as String;
    }
    // 2. Fallback to local secure storage meta map
    final metaMap = await _getSlockMetaMap();
    final meta = metaMap[filePath];
    if (meta != null && meta['origExt'] != null && meta['origExt']!.isNotEmpty) {
      return meta['origExt'];
    }
    return null;
  }

  static const String _slockMetaKey = 'slock_meta_map';

  Future<Map<String, Map<String, String>>> _getSlockMetaMap() async {
    try {
      final jsonStr = await _secureStorage.read(key: _slockMetaKey);
      if (jsonStr == null) return {};
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = <String, Map<String, String>>{};
      decoded.forEach((key, value) {
        if (value is Map) {
          result[key] = value.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      });
      return result;
    } catch (e) {
      debugPrint('⚠️ SecurityService._getSlockMetaMap error: $e');
      return {};
    }
  }

  Future<void> _saveSlockMetaMap(Map<String, Map<String, String>> metaMap) async {
    try {
      final jsonStr = jsonEncode(metaMap);
      await _secureStorage.write(key: _slockMetaKey, value: jsonStr);
    } catch (e) {
      debugPrint('⚠️ SecurityService._saveSlockMetaMap error: $e');
    }
  }

  /// Retrieves the original display file name for a `.slock` file
  Future<String> getOriginalFileName(String filePath) async {
    if (!filePath.endsWith(slockExtension)) {
      return p.basename(filePath);
    }
    final embeddedMeta = await readSlockEmbeddedHeader(filePath);
    if (embeddedMeta != null && embeddedMeta['name'] != null) {
      return embeddedMeta['name'] as String;
    }
    final metaMap = await _getSlockMetaMap();
    final meta = metaMap[filePath];
    if (meta != null && meta['origPath'] != null && meta['origPath']!.isNotEmpty) {
      return p.basename(meta['origPath']!);
    }
    final nameNoExt = p.basenameWithoutExtension(filePath);
    if (nameNoExt.startsWith('.')) {
      final ext = embeddedMeta?['ext'] ?? meta?['origExt'] ?? '';
      return '${nameNoExt.substring(1)}$ext';
    }
    return nameNoExt;
  }

  /// Locks a file or folder on disk by REPLACING extensions with `.slock` and prefixing with dot to hide from external apps
  Future<String?> lockEntityWithSlock(
    FileSystemEntity entity,
    String password,
  ) async {
    try {
      final locks = await _getFileLocks();
      final metaMap = await _getSlockMetaMap();
      final hashedPass = hashPassword(password);

      if (entity is File) {
        final currentPath = entity.path;
        if (currentPath.endsWith(slockExtension)) {
          locks[currentPath] = hashedPass;
          await _saveFileLocks(locks);
          return currentPath;
        }

        final dirPath = p.dirname(currentPath);
        final ext = p.extension(currentPath);
        final origName = p.basename(currentPath);
        final randomId = DateTime.now().microsecondsSinceEpoch.toString();
        final newPath = p.join(dirPath, '.$randomId$slockExtension');

        final newFile = await writeSlockFileWithHeader(
          inputFile: entity,
          targetPath: newPath,
          origExt: ext,
          origName: origName,
          password: password,
        );

        final resultPath = newFile?.path ?? newPath;
        locks[resultPath] = hashedPass;
        metaMap[resultPath] = {
          'origExt': ext,
          'origPath': currentPath,
          'origName': origName,
        };

        await _saveFileLocks(locks);
        await _saveSlockMetaMap(metaMap);
        return resultPath;
      } else if (entity is Directory) {
        final dir = entity;
        locks[dir.path] = hashedPass;

        if (await dir.exists()) {
          final children = dir.listSync(recursive: true);
          for (final child in children) {
            if (child is File && !child.path.endsWith(slockExtension)) {
              try {
                final childDirPath = p.dirname(child.path);
                final childExt = p.extension(child.path);
                final childOrigName = p.basename(child.path);
                final childRandomId =
                    DateTime.now().microsecondsSinceEpoch.toString();
                final newChildPath =
                    p.join(childDirPath, '.$childRandomId$slockExtension');

                final newChildFile = await writeSlockFileWithHeader(
                  inputFile: child,
                  targetPath: newChildPath,
                  origExt: childExt,
                  origName: childOrigName,
                  password: password,
                );

                final resChildPath = newChildFile?.path ?? newChildPath;
                locks[resChildPath] = hashedPass;
                metaMap[resChildPath] = {
                  'origExt': childExt,
                  'origPath': child.path,
                  'origName': childOrigName,
                };
              } catch (e) {
                debugPrint('⚠️ Error locking child file ${child.path}: $e');
              }
            }
          }
        }
        await _saveFileLocks(locks);
        await _saveSlockMetaMap(metaMap);
        return dir.path;
      }
    } catch (e) {
      debugPrint('⚠️ SecurityService.lockEntityWithSlock error: $e');
    }
    return null;
  }

  /// Unlocks a file or folder on disk by restoring `.slock` to original filename and extension
  Future<String?> unlockEntityWithSlock(FileSystemEntity entity) async {
    try {
      final locks = await _getFileLocks();
      final metaMap = await _getSlockMetaMap();

      if (entity is File) {
        final currentPath = entity.path;
        locks.remove(currentPath);

        if (currentPath.endsWith(slockExtension)) {
          final meta = metaMap.remove(currentPath);
          String restoredPath;

          if (meta != null &&
              meta['origPath'] != null &&
              meta['origPath']!.isNotEmpty) {
            restoredPath = meta['origPath']!;
          } else {
            final embeddedMeta = await readSlockEmbeddedHeader(currentPath);
            final origName = embeddedMeta?['name'] as String?;
            final ext = embeddedMeta?['ext'] ?? meta?['origExt'] ?? '';
            final dirPath = p.dirname(currentPath);

            if (origName != null && origName.isNotEmpty) {
              restoredPath = p.join(dirPath, origName);
            } else {
              final nameNoExt = p.basenameWithoutExtension(currentPath);
              final cleanName =
                  nameNoExt.startsWith('.') ? nameNoExt.substring(1) : nameNoExt;
              restoredPath = p.join(dirPath, '$cleanName$ext');
            }
          }

          locks.remove(restoredPath);
          final restoredFile = await restoreSlockFileFromHeader(
            slockFile: entity,
            restoredPath: restoredPath,
          );

          await _saveFileLocks(locks);
          await _saveSlockMetaMap(metaMap);
          return restoredFile?.path ?? restoredPath;
        }

        await _saveFileLocks(locks);
        await _saveSlockMetaMap(metaMap);
        return currentPath;
      } else if (entity is Directory) {
        final dir = entity;
        locks.remove(dir.path);

        if (await dir.exists()) {
          final children = dir.listSync(recursive: true);
          for (final child in children) {
            if (child is File && child.path.endsWith(slockExtension)) {
              try {
                final meta = metaMap.remove(child.path);
                String restoredChildPath;

                if (meta != null &&
                    meta['origPath'] != null &&
                    meta['origPath']!.isNotEmpty) {
                  restoredChildPath = meta['origPath']!;
                } else {
                  final embeddedMeta = await readSlockEmbeddedHeader(child.path);
                  final origName = embeddedMeta?['name'] as String?;
                  final ext = embeddedMeta?['ext'] ?? meta?['origExt'] ?? '';
                  final childDirPath = p.dirname(child.path);

                  if (origName != null && origName.isNotEmpty) {
                    restoredChildPath = p.join(childDirPath, origName);
                  } else {
                    final nameNoExt = p.basenameWithoutExtension(child.path);
                    final cleanName = nameNoExt.startsWith('.')
                        ? nameNoExt.substring(1)
                        : nameNoExt;
                    restoredChildPath = p.join(childDirPath, '$cleanName$ext');
                  }
                }

                locks.remove(child.path);
                locks.remove(restoredChildPath);
                await restoreSlockFileFromHeader(
                  slockFile: child,
                  restoredPath: restoredChildPath,
                );
              } catch (e) {
                debugPrint('⚠️ Error unlocking child file ${child.path}: $e');
              }
            }
          }
        }
        await _saveFileLocks(locks);
        await _saveSlockMetaMap(metaMap);
        return dir.path;
      }
    } catch (e) {
      debugPrint('⚠️ SecurityService.unlockEntityWithSlock error: $e');
    }
    return null;
  }

  Future<bool> verifyFilePassword(String fileId, String password) async {
    // 1. Check embedded header first (works after app uninstall/reinstall!)
    final embeddedMeta = await readSlockEmbeddedHeader(fileId);
    if (embeddedMeta != null &&
        embeddedMeta['hash'] != null &&
        embeddedMeta['salt'] != null) {
      final expectedHash = embeddedMeta['hash'] as String;
      final salt = embeddedMeta['salt'] as String;
      final computedHash = hashPassword('$password:$salt');
      if (computedHash == expectedHash) return true;
      if (expectedHash == hashPassword(password)) return true;
    }

    // 2. Check local file locks
    final locks = await _getFileLocks();
    final storedHash = locks[fileId];
    if (storedHash != null && storedHash == hashPassword(password)) return true;

    // 3. Fallback to active app PIN/password
    if (await verifyAppPassword(password)) return true;
    if (await verifyAppPin(password)) return true;

    return false;
  }

  Future<void> removeFileLock(String fileId) async {
    final locks = await _getFileLocks();
    locks.remove(fileId);
    await _saveFileLocks(locks);
  }

  /// Returns the list of file IDs that currently have a lock set.
  Future<List<String>> getLockedFileIds() async {
    final locks = await _getFileLocks();
    return locks.keys.toList();
  }

  Future<Map<String, String>> _getFileLocks() async {
    try {
      final locksJson = await _secureStorage.read(key: _fileLocksKey);
      if (locksJson == null) return {};

      try {
        final decoded = jsonDecode(locksJson) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      } catch (e) {
        return {};
      }
    } catch (e) {
      debugPrint('⚠️ SecurityService._getFileLocks error: $e');
      return {};
    }
  }

  Future<void> _saveFileLocks(Map<String, String> locks) async {
    try {
      final locksJson = jsonEncode(locks);
      await _secureStorage.write(key: _fileLocksKey, value: locksJson);
    } catch (e) {
      debugPrint('⚠️ SecurityService._saveFileLocks error: $e');
    }
  }

  Future<void> clearAllSecurity() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      debugPrint('⚠️ SecurityService.clearAllSecurity error: $e');
    }
  }
}


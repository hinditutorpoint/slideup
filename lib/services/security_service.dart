import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._init();

  final _secureStorage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  SecurityService._init();

  static const String _appPasswordKey = 'app_password';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _fileLocksKey = 'file_locks';

  // Hash password using SHA-256
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // App Password Management
  Future<void> setAppPassword(String password) async {
    final hashedPassword = hashPassword(password);
    await _secureStorage.write(key: _appPasswordKey, value: hashedPassword);
  }

  Future<bool> hasAppPassword() async {
    final password = await _secureStorage.read(key: _appPasswordKey);
    return password != null && password.isNotEmpty;
  }

  Future<bool> verifyAppPassword(String password) async {
    final storedHash = await _secureStorage.read(key: _appPasswordKey);
    if (storedHash == null) return false;

    final inputHash = hashPassword(password);
    return storedHash == inputHash;
  }

  Future<void> removeAppPassword() async {
    await _secureStorage.delete(key: _appPasswordKey);
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
    final enabled = await _secureStorage.read(key: _biometricEnabledKey);
    return enabled == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(
      key: _biometricEnabledKey,
      value: enabled.toString(),
    );
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

  // File Lock Management
  Future<void> setFileLock(String fileId, String password) async {
    final locks = await _getFileLocks();
    locks[fileId] = hashPassword(password);
    await _saveFileLocks(locks);
  }

  Future<bool> isFileLocked(String fileId) async {
    final locks = await _getFileLocks();
    return locks.containsKey(fileId);
  }

  Future<bool> verifyFilePassword(String fileId, String password) async {
    final locks = await _getFileLocks();
    final storedHash = locks[fileId];
    if (storedHash == null) return false;

    return storedHash == hashPassword(password);
  }

  Future<void> removeFileLock(String fileId) async {
    final locks = await _getFileLocks();
    locks.remove(fileId);
    await _saveFileLocks(locks);
  }

  Future<Map<String, String>> _getFileLocks() async {
    final locksJson = await _secureStorage.read(key: _fileLocksKey);
    if (locksJson == null) return {};

    try {
      final decoded = jsonDecode(locksJson) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return {};
    }
  }

  Future<void> _saveFileLocks(Map<String, String> locks) async {
    final locksJson = jsonEncode(locks);
    await _secureStorage.write(key: _fileLocksKey, value: locksJson);
  }

  Future<void> clearAllSecurity() async {
    await _secureStorage.deleteAll();
  }
}

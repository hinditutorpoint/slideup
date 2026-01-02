import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PreferencesService {
  static PreferencesService? _instance;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  PreferencesService._internal();

  factory PreferencesService() {
    _instance ??= PreferencesService._internal();
    return _instance!;
  }

  // =========================
  // Keys
  // =========================

  static const String _termsAcceptedKey = 'terms_accepted';
  static const String _termsAcceptedVersionKey = 'terms_accepted_version';
  static const String _privacyAcceptedKey = 'privacy_accepted';
  static const String _firstLaunchKey = 'first_launch';
  static const String _viewModeKey = 'view_mode';

  // =========================
  // Versions
  // =========================

  static const int currentTermsVersion = 1;
  static const int currentPrivacyVersion = 1;

  // =========================
  // Helpers
  // =========================

  bool _stringToBool(String? value) => value == 'true';

  String _boolToString(bool value) => value.toString();

  int _stringToInt(String? value) => int.tryParse(value ?? '') ?? 0;

  // =========================
  // First launch
  // =========================

  Future<bool> get isFirstLaunch async {
    final value = await _storage.read(key: _firstLaunchKey);
    return value == null ? true : _stringToBool(value);
  }

  Future<void> setFirstLaunchComplete() async {
    await _storage.write(key: _firstLaunchKey, value: _boolToString(false));
  }

  // =========================
  // Terms & Privacy
  // =========================

  Future<bool> get hasAcceptedTerms async {
    final accepted = _stringToBool(await _storage.read(key: _termsAcceptedKey));
    final version = _stringToInt(
      await _storage.read(key: _termsAcceptedVersionKey),
    );

    return accepted && version >= currentTermsVersion;
  }

  Future<bool> get hasAcceptedPrivacy async {
    return _stringToBool(await _storage.read(key: _privacyAcceptedKey));
  }

  Future<bool> get hasAcceptedAll async {
    return await hasAcceptedTerms && await hasAcceptedPrivacy;
  }

  Future<void> acceptTerms() async {
    await _storage.write(key: _termsAcceptedKey, value: _boolToString(true));
    await _storage.write(
      key: _termsAcceptedVersionKey,
      value: currentTermsVersion.toString(),
    );
  }

  Future<void> acceptPrivacy() async {
    await _storage.write(key: _privacyAcceptedKey, value: _boolToString(true));
  }

  Future<void> acceptAll() async {
    await acceptTerms();
    await acceptPrivacy();
    await setFirstLaunchComplete();
  }

  Future<void> resetAcceptance() async {
    await _storage.delete(key: _termsAcceptedKey);
    await _storage.delete(key: _termsAcceptedVersionKey);
    await _storage.delete(key: _privacyAcceptedKey);
  }

  // =========================
  // View mode
  // =========================

  Future<String> get viewMode async {
    return await _storage.read(key: _viewModeKey) ?? 'grid';
  }

  Future<void> setViewMode(String mode) async {
    await _storage.write(key: _viewModeKey, value: mode);
  }
}

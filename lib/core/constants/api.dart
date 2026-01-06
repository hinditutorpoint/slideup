class Api {
  static const String baseUrl = bool.hasEnvironment('API_BASE_URL')
      ? String.fromEnvironment('API_BASE_URL')
      : '';

  static const String apiKey = bool.hasEnvironment('API_KEY')
      ? String.fromEnvironment('API_KEY')
      : '';
  static const String pixaBayKey = bool.hasEnvironment('PIXABAY_KEY')
      ? String.fromEnvironment('PIXABAY_KEY')
      : '';
  static bool get isConfigured =>
      baseUrl.isNotEmpty && apiKey.isNotEmpty && pixaBayKey.isNotEmpty;
}

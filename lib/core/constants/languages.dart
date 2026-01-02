class Language {
  final String code;
  final String name;
  final String nativeName;

  const Language({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Language &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

class AppLanguages {
  AppLanguages._();

  static const Language all = Language(
    code: '',
    name: 'All Languages',
    nativeName: 'All Languages',
  );

  static const List<Language> supportedLanguages = [
    all,
    Language(code: 'eng', name: 'English', nativeName: 'English'),
    Language(code: 'spa', name: 'Spanish', nativeName: 'Español'),
    Language(code: 'fra', name: 'French', nativeName: 'Français'),
    Language(code: 'deu', name: 'German', nativeName: 'Deutsch'),
    Language(code: 'ita', name: 'Italian', nativeName: 'Italiano'),
    Language(code: 'por', name: 'Portuguese', nativeName: 'Português'),
    Language(code: 'rus', name: 'Russian', nativeName: 'Русский'),
    Language(code: 'zho', name: 'Chinese', nativeName: '中文'),
    Language(code: 'jpn', name: 'Japanese', nativeName: '日本語'),
    Language(code: 'kor', name: 'Korean', nativeName: '한국어'),
    Language(code: 'ara', name: 'Arabic', nativeName: 'العربية'),
    Language(code: 'hin', name: 'Hindi', nativeName: 'हिन्दी'),
    Language(code: 'ben', name: 'Bengali', nativeName: 'বাংলা'),
    Language(code: 'urd', name: 'Urdu', nativeName: 'اردو'),
    Language(code: 'tam', name: 'Tamil', nativeName: 'தமிழ்'),
    Language(code: 'tel', name: 'Telugu', nativeName: 'తెలుగు'),
    Language(code: 'mar', name: 'Marathi', nativeName: 'मराठी'),
    Language(code: 'guj', name: 'Gujarati', nativeName: 'ગુજરાતી'),
    Language(code: 'kan', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
    Language(code: 'mal', name: 'Malayalam', nativeName: 'മലയാളം'),
    Language(code: 'pan', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),
    Language(code: 'tha', name: 'Thai', nativeName: 'ไทย'),
    Language(code: 'vie', name: 'Vietnamese', nativeName: 'Tiếng Việt'),
    Language(code: 'ind', name: 'Indonesian', nativeName: 'Bahasa Indonesia'),
    Language(code: 'msa', name: 'Malay', nativeName: 'Bahasa Melayu'),
    Language(code: 'tur', name: 'Turkish', nativeName: 'Türkçe'),
    Language(code: 'pol', name: 'Polish', nativeName: 'Polski'),
    Language(code: 'nld', name: 'Dutch', nativeName: 'Nederlands'),
    Language(code: 'swe', name: 'Swedish', nativeName: 'Svenska'),
    Language(code: 'nor', name: 'Norwegian', nativeName: 'Norsk'),
    Language(code: 'dan', name: 'Danish', nativeName: 'Dansk'),
    Language(code: 'fin', name: 'Finnish', nativeName: 'Suomi'),
    Language(code: 'ces', name: 'Czech', nativeName: 'Čeština'),
    Language(code: 'ell', name: 'Greek', nativeName: 'Ελληνικά'),
    Language(code: 'heb', name: 'Hebrew', nativeName: 'עברית'),
    Language(code: 'ron', name: 'Romanian', nativeName: 'Română'),
    Language(code: 'hun', name: 'Hungarian', nativeName: 'Magyar'),
    Language(code: 'ukr', name: 'Ukrainian', nativeName: 'Українська'),
    Language(code: 'cat', name: 'Catalan', nativeName: 'Català'),
    Language(code: 'lat', name: 'Latin', nativeName: 'Latina'),
    Language(code: 'san', name: 'Sanskrit', nativeName: 'संस्कृतम्'),
    Language(code: 'per', name: 'Persian', nativeName: 'فارسی'),
  ];

  static Language? getByCode(String code) {
    try {
      return supportedLanguages.firstWhere((lang) => lang.code == code);
    } catch (e) {
      return null;
    }
  }

  static List<Language> search(String query) {
    if (query.isEmpty) return supportedLanguages;

    final lowerQuery = query.toLowerCase();
    return supportedLanguages.where((lang) {
      return lang.name.toLowerCase().contains(lowerQuery) ||
          lang.nativeName.toLowerCase().contains(lowerQuery) ||
          lang.code.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}

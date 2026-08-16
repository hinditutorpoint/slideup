/// iptv-org language playlist catalog.
///
/// Each language maps to `https://iptv-org.github.io/iptv/languages/<code>.m3u`.
class IptvLanguage {
  final String code;
  final String name;

  const IptvLanguage(this.code, this.name);

  String get playlistUrl => 'https://iptv-org.github.io/iptv/languages/$code.m3u';
}

const List<IptvLanguage> kIptvLanguages = [
  IptvLanguage('hin', 'Hindi'),
  IptvLanguage('eng', 'English'),
  IptvLanguage('tam', 'Tamil'),
  IptvLanguage('tel', 'Telugu'),
  IptvLanguage('kan', 'Kannada'),
  IptvLanguage('mal', 'Malayalam'),
  IptvLanguage('ben', 'Bengali'),
  IptvLanguage('mar', 'Marathi'),
  IptvLanguage('guj', 'Gujarati'),
  IptvLanguage('pan', 'Punjabi'),
  IptvLanguage('urd', 'Urdu'),
  IptvLanguage('odo', 'Odia'),
  IptvLanguage('asm', 'Assamese'),
  IptvLanguage('nep', 'Nepali'),
  IptvLanguage('sin', 'Sinhala'),
  IptvLanguage('bod', 'Tibetan'),
  IptvLanguage('fra', 'French'),
  IptvLanguage('deu', 'German'),
  IptvLanguage('spa', 'Spanish'),
  IptvLanguage('por', 'Portuguese'),
  IptvLanguage('ita', 'Italian'),
  IptvLanguage('rus', 'Russian'),
  IptvLanguage('ara', 'Arabic'),
  IptvLanguage('tur', 'Turkish'),
  IptvLanguage('jpn', 'Japanese'),
  IptvLanguage('kor', 'Korean'),
  IptvLanguage('zho', 'Chinese'),
];
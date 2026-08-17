class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({
    required this.time,
    required this.text,
  });

  @override
  String toString() => '[${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}.${(time.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0')}] $text';
}

class LyricsData {
  final bool isSynced;
  final List<LyricLine> lines;
  final String? plainLyrics;
  final String? source;
  final String? trackName;
  final String? artistName;

  const LyricsData({
    required this.isSynced,
    required this.lines,
    this.plainLyrics,
    this.source,
    this.trackName,
    this.artistName,
  });

  bool get isEmpty => lines.isEmpty && (plainLyrics == null || plainLyrics!.trim().isEmpty);
  bool get isNotEmpty => !isEmpty;

  factory LyricsData.empty() {
    return const LyricsData(
      isSynced: false,
      lines: [],
      plainLyrics: null,
    );
  }
}

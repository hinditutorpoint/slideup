// models/subtitle_segment.dart
class SubtitleSegment {
  final Duration start;
  final Duration end;
  final String text;
  final int? index;
  final Map<String, dynamic>? styling;

  const SubtitleSegment({
    required this.start,
    required this.end,
    required this.text,
    this.index,
    this.styling,
  });

  bool isActive(Duration position) {
    return position >= start && position <= end;
  }

  Duration get duration => end - start;

  SubtitleSegment copyWith({
    Duration? start,
    Duration? end,
    String? text,
    int? index,
    Map<String, dynamic>? styling,
  }) {
    return SubtitleSegment(
      start: start ?? this.start,
      end: end ?? this.end,
      text: text ?? this.text,
      index: index ?? this.index,
      styling: styling ?? this.styling,
    );
  }

  @override
  String toString() {
    return 'SubtitleSegment(${_formatTime(start)} -> ${_formatTime(end)}: $text)';
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    String milliseconds = (duration.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$hours:$minutes:$seconds,$milliseconds';
  }
}

import 'video_item.dart';

class VideoSearchResponse {
  final int numFound;
  final int start;
  final List<VideoItem> items;

  const VideoSearchResponse({
    required this.numFound,
    required this.start,
    required this.items,
  });

  bool get hasMore => start + items.length < numFound;

  int get totalPages => (numFound / 20).ceil();

  int get currentPage => (start / 20).floor() + 1;

  factory VideoSearchResponse.fromJson(Map<String, dynamic> json) {
    final response = json['response'] as Map<String, dynamic>?;

    if (response == null) {
      return const VideoSearchResponse(numFound: 0, start: 0, items: []);
    }

    final docs = response['docs'] as List<dynamic>? ?? [];

    return VideoSearchResponse(
      numFound: response['numFound'] as int? ?? 0,
      start: response['start'] as int? ?? 0,
      items: docs
          .map((doc) => VideoItem.fromJson(doc as Map<String, dynamic>))
          .where((item) => item.identifier.isNotEmpty)
          .toList(),
    );
  }

  factory VideoSearchResponse.empty() {
    return const VideoSearchResponse(numFound: 0, start: 0, items: []);
  }
}

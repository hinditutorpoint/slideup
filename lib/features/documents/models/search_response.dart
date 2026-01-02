import 'archive_item.dart';

class SearchResponse {
  final int numFound;
  final int start;
  final List<ArchiveItem> items;

  const SearchResponse({
    required this.numFound,
    required this.start,
    required this.items,
  });

  bool get hasMore => start + items.length < numFound;

  int get totalPages => (numFound / 20).ceil();

  int get currentPage => (start / 20).floor() + 1;

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final response = json['response'] as Map<String, dynamic>?;

    if (response == null) {
      return const SearchResponse(numFound: 0, start: 0, items: []);
    }

    final docs = response['docs'] as List<dynamic>? ?? [];

    return SearchResponse(
      numFound: response['numFound'] as int? ?? 0,
      start: response['start'] as int? ?? 0,
      items: docs
          .map((doc) => ArchiveItem.fromJson(doc as Map<String, dynamic>))
          .where((item) => item.identifier.isNotEmpty)
          .toList(),
    );
  }

  factory SearchResponse.empty() {
    return const SearchResponse(numFound: 0, start: 0, items: []);
  }
}

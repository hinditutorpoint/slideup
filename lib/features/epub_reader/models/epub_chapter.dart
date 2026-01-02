import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'epub_chapter.g.dart';

/// Full EPUB Chapter content model
@HiveType(typeId: 3)
class EpubChapter extends Equatable {
  /// Unique chapter identifier
  @HiveField(0)
  final String id;

  /// Chapter title
  @HiveField(1)
  final String title;

  /// Chapter index in reading order
  @HiveField(2)
  final int index;

  /// HTML content of the chapter
  @HiveField(3)
  final String? htmlContent;

  /// Plain text content (stripped HTML)
  @HiveField(4)
  final String? textContent;

  /// File path within EPUB archive
  @HiveField(5)
  final String href;

  /// Media type (usually application/xhtml+xml)
  @HiveField(6)
  final String? mediaType;

  /// Word count
  @HiveField(7)
  final int wordCount;

  /// Character count
  @HiveField(8)
  final int characterCount;

  /// Estimated reading time in minutes
  @HiveField(9)
  final int estimatedReadingMinutes;

  /// List of images in this chapter
  @HiveField(10)
  final List<ChapterImage> images;

  /// List of internal links in this chapter
  @HiveField(11)
  final List<ChapterLink> links;

  /// CSS styles for this chapter
  @HiveField(12)
  final List<String> styleSheets;

  /// Chapter anchors/bookmarks
  @HiveField(13)
  final List<ChapterAnchor> anchors;

  /// Is chapter loaded into memory
  @HiveField(14)
  final bool isLoaded;

  /// Parent book ID
  @HiveField(15)
  final String bookId;

  /// Base path for resolving relative URLs
  @HiveField(16)
  final String? basePath;

  /// Chapter level in hierarchy (for nested chapters)
  @HiveField(17)
  final int level;

  /// Play order from NCX
  @HiveField(18)
  final int? playOrder;

  /// Custom properties/metadata
  @HiveField(19)
  final Map<String, String>? properties;

  const EpubChapter({
    required this.id,
    required this.title,
    required this.index,
    this.htmlContent,
    this.textContent,
    required this.href,
    this.mediaType,
    this.wordCount = 0,
    this.characterCount = 0,
    this.estimatedReadingMinutes = 0,
    this.images = const [],
    this.links = const [],
    this.styleSheets = const [],
    this.anchors = const [],
    this.isLoaded = false,
    required this.bookId,
    this.basePath,
    this.level = 0,
    this.playOrder,
    this.properties,
  });

  /// Check if chapter has content
  bool get hasContent => htmlContent != null && htmlContent!.isNotEmpty;

  /// Check if chapter has images
  bool get hasImages => images.isNotEmpty;

  /// Check if chapter is empty
  bool get isEmpty => wordCount == 0 && !hasImages;

  /// Get sanitized HTML content
  String get safeHtmlContent => htmlContent ?? '';

  /// Get sanitized text content
  String get safeTextContent => textContent ?? '';

  /// Get preview text (first 200 characters)
  String get previewText {
    if (textContent == null || textContent!.isEmpty) return '';
    final text = textContent!.trim();
    if (text.length <= 200) return text;
    return '${text.substring(0, 200)}...';
  }

  /// Get formatted reading time
  String get formattedReadingTime {
    if (estimatedReadingMinutes < 1) return 'Less than 1 min';
    if (estimatedReadingMinutes == 1) return '1 minute';
    if (estimatedReadingMinutes < 60) return '$estimatedReadingMinutes minutes';
    final hours = estimatedReadingMinutes ~/ 60;
    final mins = estimatedReadingMinutes % 60;
    if (mins == 0) return '$hours hour${hours > 1 ? 's' : ''}';
    return '$hours hr ${mins} min';
  }

  /// Get formatted word count
  String get formattedWordCount {
    if (wordCount < 1000) return '$wordCount words';
    if (wordCount < 1000000) {
      return '${(wordCount / 1000).toStringAsFixed(1)}K words';
    }
    return '${(wordCount / 1000000).toStringAsFixed(2)}M words';
  }

  /// Create from JSON
  factory EpubChapter.fromJson(Map<String, dynamic> json) {
    try {
      return EpubChapter(
        id: json['id'] as String? ?? _generateId(),
        title: json['title'] as String? ?? 'Untitled Chapter',
        index: json['index'] as int? ?? 0,
        htmlContent: json['htmlContent'] as String?,
        textContent: json['textContent'] as String?,
        href: json['href'] as String? ?? '',
        mediaType: json['mediaType'] as String?,
        wordCount: json['wordCount'] as int? ?? 0,
        characterCount: json['characterCount'] as int? ?? 0,
        estimatedReadingMinutes: json['estimatedReadingMinutes'] as int? ?? 0,
        images:
            (json['images'] as List<dynamic>?)
                ?.map((e) => ChapterImage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        links:
            (json['links'] as List<dynamic>?)
                ?.map((e) => ChapterLink.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        styleSheets:
            (json['styleSheets'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        anchors:
            (json['anchors'] as List<dynamic>?)
                ?.map((e) => ChapterAnchor.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        isLoaded: json['isLoaded'] as bool? ?? false,
        bookId: json['bookId'] as String? ?? '',
        basePath: json['basePath'] as String?,
        level: json['level'] as int? ?? 0,
        playOrder: json['playOrder'] as int?,
        properties: (json['properties'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ),
      );
    } catch (e) {
      return EpubChapter(
        id: _generateId(),
        title: 'Error Loading Chapter',
        index: json['index'] as int? ?? 0,
        href: json['href'] as String? ?? '',
        bookId: json['bookId'] as String? ?? '',
      );
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'index': index,
      'htmlContent': htmlContent,
      'textContent': textContent,
      'href': href,
      'mediaType': mediaType,
      'wordCount': wordCount,
      'characterCount': characterCount,
      'estimatedReadingMinutes': estimatedReadingMinutes,
      'images': images.map((e) => e.toJson()).toList(),
      'links': links.map((e) => e.toJson()).toList(),
      'styleSheets': styleSheets,
      'anchors': anchors.map((e) => e.toJson()).toList(),
      'isLoaded': isLoaded,
      'bookId': bookId,
      'basePath': basePath,
      'level': level,
      'playOrder': playOrder,
      'properties': properties,
    };
  }

  /// Convert to lightweight metadata
  Map<String, dynamic> toMetaJson() {
    return {
      'id': id,
      'title': title,
      'index': index,
      'href': href,
      'wordCount': wordCount,
      'estimatedReadingMinutes': estimatedReadingMinutes,
    };
  }

  /// Create a copy with updated fields
  EpubChapter copyWith({
    String? id,
    String? title,
    int? index,
    String? htmlContent,
    String? textContent,
    String? href,
    String? mediaType,
    int? wordCount,
    int? characterCount,
    int? estimatedReadingMinutes,
    List<ChapterImage>? images,
    List<ChapterLink>? links,
    List<String>? styleSheets,
    List<ChapterAnchor>? anchors,
    bool? isLoaded,
    String? bookId,
    String? basePath,
    int? level,
    int? playOrder,
    Map<String, String>? properties,
  }) {
    return EpubChapter(
      id: id ?? this.id,
      title: title ?? this.title,
      index: index ?? this.index,
      htmlContent: htmlContent ?? this.htmlContent,
      textContent: textContent ?? this.textContent,
      href: href ?? this.href,
      mediaType: mediaType ?? this.mediaType,
      wordCount: wordCount ?? this.wordCount,
      characterCount: characterCount ?? this.characterCount,
      estimatedReadingMinutes:
          estimatedReadingMinutes ?? this.estimatedReadingMinutes,
      images: images ?? this.images,
      links: links ?? this.links,
      styleSheets: styleSheets ?? this.styleSheets,
      anchors: anchors ?? this.anchors,
      isLoaded: isLoaded ?? this.isLoaded,
      bookId: bookId ?? this.bookId,
      basePath: basePath ?? this.basePath,
      level: level ?? this.level,
      playOrder: playOrder ?? this.playOrder,
      properties: properties ?? this.properties,
    );
  }

  /// Mark chapter as loaded with content
  EpubChapter withContent({
    required String htmlContent,
    String? textContent,
    List<ChapterImage>? images,
    List<ChapterLink>? links,
  }) {
    // Calculate word count from text content
    final plainText = textContent ?? _stripHtml(htmlContent);
    final words = _countWords(plainText);
    final chars = plainText.length;
    final readingTime = _calculateReadingTime(words);

    return copyWith(
      htmlContent: htmlContent,
      textContent: plainText,
      images: images,
      links: links,
      wordCount: words,
      characterCount: chars,
      estimatedReadingMinutes: readingTime,
      isLoaded: true,
    );
  }

  /// Unload content to free memory
  EpubChapter unloadContent() {
    return copyWith(htmlContent: null, textContent: null, isLoaded: false);
  }

  /// Strip HTML tags from content
  static String _stripHtml(String html) {
    try {
      return html
          .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '')
          .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    } catch (_) {
      return html;
    }
  }

  /// Count words in text
  static int _countWords(String text) {
    try {
      if (text.isEmpty) return 0;
      return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    } catch (_) {
      return 0;
    }
  }

  /// Calculate reading time (average 200 words per minute)
  static int _calculateReadingTime(int wordCount) {
    return (wordCount / 200).ceil();
  }

  static String _generateId() {
    return 'chapter_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  List<Object?> get props => [id, title, index, href, bookId, isLoaded];

  @override
  String toString() =>
      'EpubChapter(id: $id, title: $title, index: $index, loaded: $isLoaded)';
}

/// Image within a chapter
@HiveType(typeId: 4)
class ChapterImage extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String src;

  @HiveField(2)
  final String? alt;

  @HiveField(3)
  final String? title;

  @HiveField(4)
  final int? width;

  @HiveField(5)
  final int? height;

  @HiveField(6)
  final String? mimeType;

  @HiveField(7)
  final String? localPath;

  @HiveField(8)
  final bool isCover;

  const ChapterImage({
    required this.id,
    required this.src,
    this.alt,
    this.title,
    this.width,
    this.height,
    this.mimeType,
    this.localPath,
    this.isCover = false,
  });

  /// Check if image is loaded locally
  bool get isLocal => localPath != null && localPath!.isNotEmpty;

  /// Get display name
  String get displayName => alt ?? title ?? src.split('/').last;

  factory ChapterImage.fromJson(Map<String, dynamic> json) {
    return ChapterImage(
      id: json['id'] as String? ?? '',
      src: json['src'] as String? ?? '',
      alt: json['alt'] as String?,
      title: json['title'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      mimeType: json['mimeType'] as String?,
      localPath: json['localPath'] as String?,
      isCover: json['isCover'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'src': src,
      'alt': alt,
      'title': title,
      'width': width,
      'height': height,
      'mimeType': mimeType,
      'localPath': localPath,
      'isCover': isCover,
    };
  }

  ChapterImage copyWith({
    String? id,
    String? src,
    String? alt,
    String? title,
    int? width,
    int? height,
    String? mimeType,
    String? localPath,
    bool? isCover,
  }) {
    return ChapterImage(
      id: id ?? this.id,
      src: src ?? this.src,
      alt: alt ?? this.alt,
      title: title ?? this.title,
      width: width ?? this.width,
      height: height ?? this.height,
      mimeType: mimeType ?? this.mimeType,
      localPath: localPath ?? this.localPath,
      isCover: isCover ?? this.isCover,
    );
  }

  @override
  List<Object?> get props => [id, src, localPath];
}

/// Link within a chapter
@HiveType(typeId: 5)
class ChapterLink extends Equatable {
  @HiveField(0)
  final String href;

  @HiveField(1)
  final String? text;

  @HiveField(2)
  final LinkType type;

  @HiveField(3)
  final String? targetChapterId;

  @HiveField(4)
  final String? anchor;

  const ChapterLink({
    required this.href,
    this.text,
    this.type = LinkType.internal,
    this.targetChapterId,
    this.anchor,
  });

  /// Check if link is external
  bool get isExternal => type == LinkType.external;

  /// Check if link is internal navigation
  bool get isInternal => type == LinkType.internal;

  /// Check if link is footnote
  bool get isFootnote => type == LinkType.footnote;

  factory ChapterLink.fromJson(Map<String, dynamic> json) {
    return ChapterLink(
      href: json['href'] as String? ?? '',
      text: json['text'] as String?,
      type: LinkType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LinkType.internal,
      ),
      targetChapterId: json['targetChapterId'] as String?,
      anchor: json['anchor'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'href': href,
      'text': text,
      'type': type.name,
      'targetChapterId': targetChapterId,
      'anchor': anchor,
    };
  }

  @override
  List<Object?> get props => [href, type, targetChapterId];
}

/// Link types
@HiveType(typeId: 6)
enum LinkType {
  @HiveField(0)
  internal,

  @HiveField(1)
  external,

  @HiveField(2)
  footnote,

  @HiveField(3)
  endnote,

  @HiveField(4)
  image,

  @HiveField(5)
  unknown,
}

/// Anchor/bookmark within a chapter
@HiveType(typeId: 7)
class ChapterAnchor extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? title;

  @HiveField(2)
  final int? position;

  @HiveField(3)
  final AnchorType type;

  const ChapterAnchor({
    required this.id,
    this.title,
    this.position,
    this.type = AnchorType.generic,
  });

  factory ChapterAnchor.fromJson(Map<String, dynamic> json) {
    return ChapterAnchor(
      id: json['id'] as String? ?? '',
      title: json['title'] as String?,
      position: json['position'] as int?,
      type: AnchorType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AnchorType.generic,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'position': position, 'type': type.name};
  }

  @override
  List<Object?> get props => [id, type];
}

/// Anchor types
@HiveType(typeId: 8)
enum AnchorType {
  @HiveField(0)
  generic,

  @HiveField(1)
  heading,

  @HiveField(2)
  footnote,

  @HiveField(3)
  bookmark,

  @HiveField(4)
  highlight,
}

/// Chapter content wrapper for memory-efficient loading
class ChapterContent {
  final String chapterId;
  final String bookId;
  final String htmlContent;
  final String textContent;
  final List<ChapterImage> images;
  final List<ChapterLink> links;
  final DateTime loadedAt;
  final int sizeBytes;

  ChapterContent({
    required this.chapterId,
    required this.bookId,
    required this.htmlContent,
    required this.textContent,
    this.images = const [],
    this.links = const [],
  }) : loadedAt = DateTime.now(),
       sizeBytes = _calculateSize(htmlContent, textContent);

  static int _calculateSize(String html, String text) {
    return (html.length * 2) + (text.length * 2); // UTF-16 estimation
  }

  /// Check if content is stale (older than 5 minutes)
  bool get isStale =>
      DateTime.now().difference(loadedAt) > const Duration(minutes: 5);

  /// Get memory usage in MB
  double get memorySizeMB => sizeBytes / (1024 * 1024);
}

/// Chapter loading state
enum ChapterLoadingState { idle, loading, loaded, error, unloaded }

/// Chapter with loading state
class ChapterWithState {
  final EpubChapter chapter;
  final ChapterLoadingState state;
  final String? errorMessage;
  final double loadProgress;

  const ChapterWithState({
    required this.chapter,
    this.state = ChapterLoadingState.idle,
    this.errorMessage,
    this.loadProgress = 0.0,
  });

  bool get isLoading => state == ChapterLoadingState.loading;
  bool get isLoaded => state == ChapterLoadingState.loaded;
  bool get hasError => state == ChapterLoadingState.error;

  ChapterWithState copyWith({
    EpubChapter? chapter,
    ChapterLoadingState? state,
    String? errorMessage,
    double? loadProgress,
  }) {
    return ChapterWithState(
      chapter: chapter ?? this.chapter,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      loadProgress: loadProgress ?? this.loadProgress,
    );
  }
}

/// Parsed chapter result
class ParsedChapter {
  final String id;
  final String title;
  final String htmlContent;
  final String textContent;
  final List<ChapterImage> images;
  final List<ChapterLink> links;
  final List<ChapterAnchor> anchors;
  final int wordCount;
  final int characterCount;

  const ParsedChapter({
    required this.id,
    required this.title,
    required this.htmlContent,
    required this.textContent,
    this.images = const [],
    this.links = const [],
    this.anchors = const [],
    required this.wordCount,
    required this.characterCount,
  });

  /// Convert to EpubChapter
  EpubChapter toEpubChapter({
    required int index,
    required String href,
    required String bookId,
    String? basePath,
  }) {
    return EpubChapter(
      id: id,
      title: title,
      index: index,
      htmlContent: htmlContent,
      textContent: textContent,
      href: href,
      wordCount: wordCount,
      characterCount: characterCount,
      estimatedReadingMinutes: (wordCount / 200).ceil(),
      images: images,
      links: links,
      anchors: anchors,
      isLoaded: true,
      bookId: bookId,
      basePath: basePath,
    );
  }
}

import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'reading_progress.dart';

part 'epub_book.g.dart';

/// EPUB Book metadata and content model
@HiveType(typeId: 0)
class EpubBook extends Equatable {
  /// Unique identifier for the book
  @HiveField(0)
  final String id;

  /// Book title
  @HiveField(1)
  final String title;

  /// Book author(s)
  @HiveField(2)
  final String? author;

  /// Publisher name
  @HiveField(3)
  final String? publisher;

  /// Publication date
  @HiveField(4)
  final DateTime? publicationDate;

  /// Book description/summary
  @HiveField(5)
  final String? description;

  /// Language code (e.g., 'en', 'es')
  @HiveField(6)
  final String? language;

  /// ISBN identifier
  @HiveField(7)
  final String? isbn;

  /// Cover image path (local)
  @HiveField(8)
  final String? coverPath;

  /// Cover image URL (remote)
  @HiveField(9)
  final String? coverUrl;

  /// Local file path of the EPUB
  @HiveField(10)
  final String? filePath;

  /// Remote URL of the EPUB
  @HiveField(11)
  final String? sourceUrl;

  /// File size in bytes
  @HiveField(12)
  final int? fileSize;

  /// Total number of chapters
  @HiveField(13)
  final int chapterCount;

  /// List of chapter metadata
  @HiveField(14)
  final List<EpubChapterMeta> chapters;

  /// Book subjects/categories
  @HiveField(15)
  final List<String> subjects;

  /// Rights/copyright information
  @HiveField(16)
  final String? rights;

  /// EPUB version
  @HiveField(17)
  final String? epubVersion;

  /// When the book was added to library
  @HiveField(18)
  final DateTime addedAt;

  /// When the book was last opened
  @HiveField(19)
  final DateTime? lastOpenedAt;

  /// Is the book downloaded locally
  @HiveField(20)
  final bool isDownloaded;

  /// Is the book marked as favorite
  @HiveField(21)
  final bool isFavorite;

  /// Custom tags added by user
  @HiveField(22)
  final List<String> tags;

  /// Reading progress (0.0 to 1.0)
  @HiveField(23)
  final double readingProgress;

  /// Current chapter index
  @HiveField(24)
  final int currentChapterIndex;

  /// Additional metadata
  @HiveField(25)
  final Map<String, String>? metadata;

  /// Table of contents
  @HiveField(26)
  final List<TocEntry>? tableOfContents;

  /// Spine items (reading order)
  @HiveField(27)
  final List<String>? spine;

  const EpubBook({
    required this.id,
    required this.title,
    this.author,
    this.publisher,
    this.publicationDate,
    this.description,
    this.language,
    this.isbn,
    this.coverPath,
    this.coverUrl,
    this.filePath,
    this.sourceUrl,
    this.fileSize,
    this.chapterCount = 0,
    this.chapters = const [],
    this.subjects = const [],
    this.rights,
    this.epubVersion,
    required this.addedAt,
    this.lastOpenedAt,
    this.isDownloaded = false,
    this.isFavorite = false,
    this.tags = const [],
    this.readingProgress = 0.0,
    this.currentChapterIndex = 0,
    this.metadata,
    this.tableOfContents,
    this.spine,
  });

  /// Check if book has cover
  bool get hasCover => coverPath != null || coverUrl != null;

  /// Check if book is from remote source
  bool get isRemote => sourceUrl != null && sourceUrl!.isNotEmpty;

  /// Check if book can be opened
  bool get canOpen => isDownloaded && filePath != null;

  /// Check if reading has started
  bool get hasStartedReading => readingProgress > 0;

  /// Check if book is finished
  bool get isFinished => readingProgress >= 0.99;

  /// Get reading percentage
  int get readingPercentage => (readingProgress * 100).round();

  /// Get formatted file size
  String get formattedFileSize {
    if (fileSize == null) return 'Unknown';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get display author
  String get displayAuthor => author ?? 'Unknown Author';

  /// Get short description
  String get shortDescription {
    if (description == null) return '';
    return description!.length > 150
        ? '${description!.substring(0, 150)}...'
        : description!;
  }

  /// Get current chapter title
  String? get currentChapterTitle {
    if (chapters.isEmpty || currentChapterIndex >= chapters.length) {
      return null;
    }
    return chapters[currentChapterIndex].title;
  }

  /// Create from JSON
  factory EpubBook.fromJson(Map<String, dynamic> json) {
    try {
      return EpubBook(
        id: json['id'] as String? ?? _generateId(),
        title: json['title'] as String? ?? 'Untitled',
        author: json['author'] as String?,
        publisher: json['publisher'] as String?,
        publicationDate: json['publicationDate'] != null
            ? DateTime.tryParse(json['publicationDate'] as String)
            : null,
        description: json['description'] as String?,
        language: json['language'] as String?,
        isbn: json['isbn'] as String?,
        coverPath: json['coverPath'] as String?,
        coverUrl: json['coverUrl'] as String?,
        filePath: json['filePath'] as String?,
        sourceUrl: json['sourceUrl'] as String?,
        fileSize: json['fileSize'] as int?,
        chapterCount: json['chapterCount'] as int? ?? 0,
        chapters:
            (json['chapters'] as List<dynamic>?)
                ?.map(
                  (e) => EpubChapterMeta.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            [],
        subjects:
            (json['subjects'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        rights: json['rights'] as String?,
        epubVersion: json['epubVersion'] as String?,
        addedAt: json['addedAt'] != null
            ? DateTime.parse(json['addedAt'] as String)
            : DateTime.now(),
        lastOpenedAt: json['lastOpenedAt'] != null
            ? DateTime.tryParse(json['lastOpenedAt'] as String)
            : null,
        isDownloaded: json['isDownloaded'] as bool? ?? false,
        isFavorite: json['isFavorite'] as bool? ?? false,
        tags:
            (json['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        readingProgress: (json['readingProgress'] as num?)?.toDouble() ?? 0.0,
        currentChapterIndex: json['currentChapterIndex'] as int? ?? 0,
        metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v.toString()),
        ),
        tableOfContents: (json['tableOfContents'] as List<dynamic>?)
            ?.map((e) => TocEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        spine: (json['spine'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
      );
    } catch (e) {
      // Return minimal book on parse error
      return EpubBook(
        id: _generateId(),
        title: json['title'] as String? ?? 'Untitled',
        addedAt: DateTime.now(),
      );
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'publisher': publisher,
      'publicationDate': publicationDate?.toIso8601String(),
      'description': description,
      'language': language,
      'isbn': isbn,
      'coverPath': coverPath,
      'coverUrl': coverUrl,
      'filePath': filePath,
      'sourceUrl': sourceUrl,
      'fileSize': fileSize,
      'chapterCount': chapterCount,
      'chapters': chapters.map((e) => e.toJson()).toList(),
      'subjects': subjects,
      'rights': rights,
      'epubVersion': epubVersion,
      'addedAt': addedAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      'isDownloaded': isDownloaded,
      'isFavorite': isFavorite,
      'tags': tags,
      'readingProgress': readingProgress,
      'currentChapterIndex': currentChapterIndex,
      'metadata': metadata,
      'tableOfContents': tableOfContents?.map((e) => e.toJson()).toList(),
      'spine': spine,
    };
  }

  /// Create a copy with updated fields
  EpubBook copyWith({
    String? id,
    String? title,
    String? author,
    String? publisher,
    DateTime? publicationDate,
    String? description,
    String? language,
    String? isbn,
    String? coverPath,
    String? coverUrl,
    String? filePath,
    String? sourceUrl,
    int? fileSize,
    int? chapterCount,
    List<EpubChapterMeta>? chapters,
    List<String>? subjects,
    String? rights,
    String? epubVersion,
    DateTime? addedAt,
    DateTime? lastOpenedAt,
    bool? isDownloaded,
    bool? isFavorite,
    List<String>? tags,
    double? readingProgress,
    int? currentChapterIndex,
    Map<String, String>? metadata,
    List<TocEntry>? tableOfContents,
    List<String>? spine,
  }) {
    return EpubBook(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      publicationDate: publicationDate ?? this.publicationDate,
      description: description ?? this.description,
      language: language ?? this.language,
      isbn: isbn ?? this.isbn,
      coverPath: coverPath ?? this.coverPath,
      coverUrl: coverUrl ?? this.coverUrl,
      filePath: filePath ?? this.filePath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      fileSize: fileSize ?? this.fileSize,
      chapterCount: chapterCount ?? this.chapterCount,
      chapters: chapters ?? this.chapters,
      subjects: subjects ?? this.subjects,
      rights: rights ?? this.rights,
      epubVersion: epubVersion ?? this.epubVersion,
      addedAt: addedAt ?? this.addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      readingProgress: readingProgress ?? this.readingProgress,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      metadata: metadata ?? this.metadata,
      tableOfContents: tableOfContents ?? this.tableOfContents,
      spine: spine ?? this.spine,
    );
  }

  /// Update reading progress
  EpubBook updateProgress(ReadingProgress progress) {
    return copyWith(
      readingProgress: progress.overallProgress,
      currentChapterIndex: progress.chapterIndex,
      lastOpenedAt: DateTime.now(),
    );
  }

  /// Mark as downloaded
  EpubBook markAsDownloaded(String localPath) {
    return copyWith(isDownloaded: true, filePath: localPath);
  }

  /// Toggle favorite
  EpubBook toggleFavorite() {
    return copyWith(isFavorite: !isFavorite);
  }

  /// Add tag
  EpubBook addTag(String tag) {
    if (tags.contains(tag)) return this;
    return copyWith(tags: [...tags, tag]);
  }

  /// Remove tag
  EpubBook removeTag(String tag) {
    return copyWith(tags: tags.where((t) => t != tag).toList());
  }

  /// Create empty book
  factory EpubBook.empty() {
    return EpubBook(
      id: _generateId(),
      title: 'Untitled',
      addedAt: DateTime.now(),
    );
  }

  /// Create from URL
  factory EpubBook.fromUrl(String url, {String? title}) {
    final uri = Uri.tryParse(url);
    final fileName = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last.replaceAll('.epub', '')
        : 'Unknown';

    return EpubBook(
      id: _generateId(),
      title: title ?? fileName,
      sourceUrl: url,
      addedAt: DateTime.now(),
      isDownloaded: false,
    );
  }

  static String _generateId() {
    return 'book_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    return List.generate(
      length,
      (index) => chars[(random + index) % chars.length],
    ).join();
  }

  @override
  List<Object?> get props => [
    id,
    title,
    author,
    filePath,
    sourceUrl,
    isDownloaded,
    readingProgress,
    currentChapterIndex,
    isFavorite,
    lastOpenedAt,
  ];

  @override
  String toString() => 'EpubBook(id: $id, title: $title, author: $author)';
}

/// Chapter metadata (lightweight version for book listing)
@HiveType(typeId: 1)
class EpubChapterMeta extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final int index;

  @HiveField(3)
  final String? href;

  @HiveField(4)
  final int? wordCount;

  @HiveField(5)
  final int? estimatedReadingMinutes;

  const EpubChapterMeta({
    required this.id,
    required this.title,
    required this.index,
    this.href,
    this.wordCount,
    this.estimatedReadingMinutes,
  });

  factory EpubChapterMeta.fromJson(Map<String, dynamic> json) {
    return EpubChapterMeta(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Chapter ${json['index'] ?? 0}',
      index: json['index'] as int? ?? 0,
      href: json['href'] as String?,
      wordCount: json['wordCount'] as int?,
      estimatedReadingMinutes: json['estimatedReadingMinutes'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'index': index,
      'href': href,
      'wordCount': wordCount,
      'estimatedReadingMinutes': estimatedReadingMinutes,
    };
  }

  EpubChapterMeta copyWith({
    String? id,
    String? title,
    int? index,
    String? href,
    int? wordCount,
    int? estimatedReadingMinutes,
  }) {
    return EpubChapterMeta(
      id: id ?? this.id,
      title: title ?? this.title,
      index: index ?? this.index,
      href: href ?? this.href,
      wordCount: wordCount ?? this.wordCount,
      estimatedReadingMinutes:
          estimatedReadingMinutes ?? this.estimatedReadingMinutes,
    );
  }

  @override
  List<Object?> get props => [id, title, index, href];
}

/// Table of contents entry
@HiveType(typeId: 2)
class TocEntry extends Equatable {
  @HiveField(0)
  final String title;

  @HiveField(1)
  final String href;

  @HiveField(2)
  final int level;

  @HiveField(3)
  final List<TocEntry> children;

  @HiveField(4)
  final String? anchor;

  @HiveField(5)
  final int? playOrder;

  const TocEntry({
    required this.title,
    required this.href,
    this.level = 0,
    this.children = const [],
    this.anchor,
    this.playOrder,
  });

  factory TocEntry.fromJson(Map<String, dynamic> json) {
    return TocEntry(
      title: json['title'] as String? ?? '',
      href: json['href'] as String? ?? '',
      level: json['level'] as int? ?? 0,
      children:
          (json['children'] as List<dynamic>?)
              ?.map((e) => TocEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      anchor: json['anchor'] as String?,
      playOrder: json['playOrder'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'href': href,
      'level': level,
      'children': children.map((e) => e.toJson()).toList(),
      'anchor': anchor,
      'playOrder': playOrder,
    };
  }

  /// Flatten TOC to list
  List<TocEntry> flatten() {
    final result = <TocEntry>[this];
    for (final child in children) {
      result.addAll(child.flatten());
    }
    return result;
  }

  @override
  List<Object?> get props => [title, href, level, children.length];
}

/// Book sorting options
enum BookSortOption {
  title('Title'),
  author('Author'),
  dateAdded('Date Added'),
  lastRead('Last Read'),
  progress('Progress');

  final String displayName;
  const BookSortOption(this.displayName);
}

/// Book filter options
enum BookFilterOption {
  all('All Books'),
  downloaded('Downloaded'),
  favorites('Favorites'),
  reading('Currently Reading'),
  finished('Finished'),
  unread('Unread');

  final String displayName;
  const BookFilterOption(this.displayName);
}

/// Extension for filtering books
extension EpubBookListExtension on List<EpubBook> {
  /// Filter books
  List<EpubBook> filter(BookFilterOption option) {
    switch (option) {
      case BookFilterOption.all:
        return this;
      case BookFilterOption.downloaded:
        return where((b) => b.isDownloaded).toList();
      case BookFilterOption.favorites:
        return where((b) => b.isFavorite).toList();
      case BookFilterOption.reading:
        return where((b) => b.hasStartedReading && !b.isFinished).toList();
      case BookFilterOption.finished:
        return where((b) => b.isFinished).toList();
      case BookFilterOption.unread:
        return where((b) => !b.hasStartedReading).toList();
    }
  }

  /// Sort books
  List<EpubBook> sortBy(BookSortOption option, {bool ascending = true}) {
    final sorted = List<EpubBook>.from(this);
    sorted.sort((a, b) {
      int result;
      switch (option) {
        case BookSortOption.title:
          result = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case BookSortOption.author:
          result = (a.author ?? '').toLowerCase().compareTo(
            (b.author ?? '').toLowerCase(),
          );
          break;
        case BookSortOption.dateAdded:
          result = a.addedAt.compareTo(b.addedAt);
          break;
        case BookSortOption.lastRead:
          result = (a.lastOpenedAt ?? DateTime(1970)).compareTo(
            b.lastOpenedAt ?? DateTime(1970),
          );
          break;
        case BookSortOption.progress:
          result = a.readingProgress.compareTo(b.readingProgress);
          break;
      }
      return ascending ? result : -result;
    });
    return sorted;
  }

  /// Search books
  List<EpubBook> search(String query) {
    if (query.isEmpty) return this;
    final lowerQuery = query.toLowerCase();
    return where((book) {
      return book.title.toLowerCase().contains(lowerQuery) ||
          (book.author?.toLowerCase().contains(lowerQuery) ?? false) ||
          book.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList();
  }
}

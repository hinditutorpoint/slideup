import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'reading_progress.g.dart';

/// Reading progress tracker for EPUB books
@HiveType(typeId: 11)
class ReadingProgress extends Equatable {
  /// Unique progress identifier
  @HiveField(0)
  final String id;

  /// Book ID this progress belongs to
  @HiveField(1)
  final String bookId;

  /// Current chapter index
  @HiveField(2)
  final int chapterIndex;

  /// Current chapter ID
  @HiveField(3)
  final String? chapterId;

  /// Scroll position within chapter (0.0 to 1.0)
  @HiveField(4)
  final double chapterProgress;

  /// Overall book progress (0.0 to 1.0)
  @HiveField(5)
  final double overallProgress;

  /// Current page number (if paginated)
  @HiveField(6)
  final int? currentPage;

  /// Total pages in book (if paginated)
  @HiveField(7)
  final int? totalPages;

  /// Character offset in current chapter
  @HiveField(8)
  final int? characterOffset;

  /// Word offset in current chapter
  @HiveField(9)
  final int? wordOffset;

  /// Bookmarks in this book
  @HiveField(10)
  final List<Bookmark> bookmarks;

  /// Highlights in this book
  @HiveField(11)
  final List<Highlight> highlights;

  /// Notes/annotations in this book
  @HiveField(12)
  final List<Note> notes;

  /// Reading sessions history
  @HiveField(13)
  final List<ReadingSession> sessions;

  /// Last reading position CFI (Canonical Fragment Identifier)
  @HiveField(14)
  final String? lastCFI;

  /// Total reading time in seconds
  @HiveField(15)
  final int totalReadingTimeSeconds;

  /// Average reading speed (words per minute)
  @HiveField(16)
  final double averageReadingSpeed;

  /// Estimated time remaining in minutes
  @HiveField(17)
  final int? estimatedTimeRemaining;

  /// When reading was started
  @HiveField(18)
  final DateTime? startedAt;

  /// When reading was last updated
  @HiveField(19)
  final DateTime lastUpdatedAt;

  /// When book was finished
  @HiveField(20)
  final DateTime? finishedAt;

  /// Is book marked as finished
  @HiveField(21)
  final bool isFinished;

  /// Reading streak (consecutive days)
  @HiveField(22)
  final int readingStreak;

  /// Last reading date
  @HiveField(23)
  final DateTime? lastReadDate;

  /// Custom progress metadata
  @HiveField(24)
  final Map<String, dynamic>? metadata;

  /// Text translations (phrase/sentence level)
  @HiveField(25)
  final List<TextTranslation> textTranslations;

  /// Chapter translations (full chapter level)
  @HiveField(26)
  final List<ChapterTranslation> chapterTranslations;

  /// Translation settings/preferences
  @HiveField(27)
  final TranslationSettings? translationSettings;

  const ReadingProgress({
    required this.id,
    required this.bookId,
    this.chapterIndex = 0,
    this.chapterId,
    this.chapterProgress = 0.0,
    this.overallProgress = 0.0,
    this.currentPage,
    this.totalPages,
    this.characterOffset,
    this.wordOffset,
    this.bookmarks = const [],
    this.highlights = const [],
    this.notes = const [],
    this.sessions = const [],
    this.lastCFI,
    this.totalReadingTimeSeconds = 0,
    this.averageReadingSpeed = 0.0,
    this.estimatedTimeRemaining,
    this.startedAt,
    required this.lastUpdatedAt,
    this.finishedAt,
    this.isFinished = false,
    this.readingStreak = 0,
    this.lastReadDate,
    this.metadata,
    this.textTranslations = const [],
    this.chapterTranslations = const [],
    this.translationSettings,
  });

  // ===========================================================================
  // COMPUTED PROPERTIES
  // ===========================================================================

  /// Get progress percentage
  int get progressPercentage => (overallProgress * 100).round();

  /// Get chapter progress percentage
  int get chapterProgressPercentage => (chapterProgress * 100).round();

  /// Get formatted total reading time
  String get formattedReadingTime {
    final duration = Duration(seconds: totalReadingTimeSeconds);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }

  /// Get formatted time remaining
  String get formattedTimeRemaining {
    if (estimatedTimeRemaining == null) return 'Unknown';
    if (estimatedTimeRemaining! < 60) {
      return '${estimatedTimeRemaining}m';
    }
    final hours = estimatedTimeRemaining! ~/ 60;
    final mins = estimatedTimeRemaining! % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  /// Get total bookmarks count
  int get bookmarksCount => bookmarks.length;

  /// Get total highlights count
  int get highlightsCount => highlights.length;

  /// Get total notes count
  int get notesCount => notes.length;

  /// Get total sessions count
  int get sessionsCount => sessions.length;

  /// Get active bookmarks (not deleted)
  List<Bookmark> get activeBookmarks =>
      bookmarks.where((b) => !b.isDeleted).toList();

  /// Get active highlights
  List<Highlight> get activeHighlights =>
      highlights.where((h) => !h.isDeleted).toList();

  /// Get active notes
  List<Note> get activeNotes => notes.where((n) => !n.isDeleted).toList();

  /// Check if has any bookmarks
  bool get hasBookmarks => activeBookmarks.isNotEmpty;

  /// Check if has any highlights
  bool get hasHighlights => activeHighlights.isNotEmpty;

  /// Check if has any notes
  bool get hasNotes => activeNotes.isNotEmpty;

  /// Check if reading has started
  bool get hasStarted => startedAt != null || overallProgress > 0;

  /// Get days since started
  int get daysSinceStarted {
    if (startedAt == null) return 0;
    return DateTime.now().difference(startedAt!).inDays;
  }

  /// Get last session
  ReadingSession? get lastSession {
    if (sessions.isEmpty) return null;
    return sessions.last;
  }

  /// Get today's reading time
  int get todayReadingTimeSeconds {
    final today = DateTime.now();
    return sessions
        .where(
          (s) =>
              s.startTime.year == today.year &&
              s.startTime.month == today.month &&
              s.startTime.day == today.day,
        )
        .fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  /// Get this week's reading time
  int get weekReadingTimeSeconds {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return sessions
        .where((s) => s.startTime.isAfter(weekAgo))
        .fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  /// Get this month's reading time
  int get monthReadingTimeSeconds {
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));
    return sessions
        .where((s) => s.startTime.isAfter(monthAgo))
        .fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  // ===========================================================================
  // TRANSLATION COMPUTED PROPERTIES
  // ===========================================================================

  /// Check if has any translations
  bool get hasTranslations =>
      textTranslations.isNotEmpty || chapterTranslations.isNotEmpty;

  /// Get total text translations count
  int get textTranslationsCount => activeTextTranslations.length;

  /// Get total chapter translations count
  int get chapterTranslationsCount => activeChapterTranslations.length;

  /// Get active text translations (not deleted)
  List<TextTranslation> get activeTextTranslations =>
      textTranslations.where((t) => !t.isDeleted).toList();

  /// Get active chapter translations
  List<ChapterTranslation> get activeChapterTranslations =>
      chapterTranslations.where((t) => !t.isDeleted).toList();

  /// Get all unique translated languages
  Set<String> get translatedLanguages {
    final languages = <String>{};
    for (final t in activeTextTranslations) {
      languages.add(t.targetLanguage);
    }
    for (final t in activeChapterTranslations) {
      languages.add(t.targetLanguage);
    }
    return languages;
  }

  /// Get translations for a specific language
  List<TextTranslation> getTextTranslationsForLanguage(String languageCode) {
    return activeTextTranslations
        .where((t) => t.targetLanguage == languageCode)
        .toList();
  }

  /// Get chapter translations for a specific language
  List<ChapterTranslation> getChapterTranslationsForLanguage(
    String languageCode,
  ) {
    return activeChapterTranslations
        .where((t) => t.targetLanguage == languageCode)
        .toList();
  }

  /// Get translation for specific text in specific language
  TextTranslation? findTextTranslation({
    required String originalText,
    required String targetLanguage,
    int? chapterIndex,
  }) {
    try {
      return activeTextTranslations.firstWhere(
        (t) =>
            t.originalText == originalText &&
            t.targetLanguage == targetLanguage &&
            (chapterIndex == null || t.chapterIndex == chapterIndex),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get chapter translation
  ChapterTranslation? findChapterTranslation({
    required int chapterIndex,
    required String targetLanguage,
  }) {
    try {
      return activeChapterTranslations.firstWhere(
        (t) =>
            t.chapterIndex == chapterIndex &&
            t.targetLanguage == targetLanguage,
      );
    } catch (_) {
      return null;
    }
  }

  /// Check if text is already translated
  bool isTextTranslated({
    required String originalText,
    required String targetLanguage,
    int? chapterIndex,
  }) {
    return findTextTranslation(
          originalText: originalText,
          targetLanguage: targetLanguage,
          chapterIndex: chapterIndex,
        ) !=
        null;
  }

  /// Check if chapter is already translated
  bool isChapterTranslated({
    required int chapterIndex,
    required String targetLanguage,
  }) {
    return findChapterTranslation(
          chapterIndex: chapterIndex,
          targetLanguage: targetLanguage,
        ) !=
        null;
  }

  // ===========================================================================
  // FACTORY CONSTRUCTORS
  // ===========================================================================

  /// Create new reading progress
  factory ReadingProgress.create({
    required String bookId,
    TranslationSettings? translationSettings,
  }) {
    return ReadingProgress(
      id: _generateId(),
      bookId: bookId,
      lastUpdatedAt: DateTime.now(),
      translationSettings: translationSettings,
    );
  }

  /// Create from JSON
  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    try {
      return ReadingProgress(
        id: json['id'] as String? ?? _generateId(),
        bookId: json['bookId'] as String? ?? '',
        chapterIndex: json['chapterIndex'] as int? ?? 0,
        chapterId: json['chapterId'] as String?,
        chapterProgress: (json['chapterProgress'] as num?)?.toDouble() ?? 0.0,
        overallProgress: (json['overallProgress'] as num?)?.toDouble() ?? 0.0,
        currentPage: json['currentPage'] as int?,
        totalPages: json['totalPages'] as int?,
        characterOffset: json['characterOffset'] as int?,
        wordOffset: json['wordOffset'] as int?,
        bookmarks:
            (json['bookmarks'] as List<dynamic>?)
                ?.map(
                  (e) => Bookmark.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList() ??
            [],
        highlights:
            (json['highlights'] as List<dynamic>?)
                ?.map(
                  (e) =>
                      Highlight.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList() ??
            [],
        notes:
            (json['notes'] as List<dynamic>?)
                ?.map((e) => Note.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        sessions:
            (json['sessions'] as List<dynamic>?)
                ?.map(
                  (e) => ReadingSession.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList() ??
            [],
        lastCFI: json['lastCFI'] as String?,
        totalReadingTimeSeconds: json['totalReadingTimeSeconds'] as int? ?? 0,
        averageReadingSpeed:
            (json['averageReadingSpeed'] as num?)?.toDouble() ?? 0.0,
        estimatedTimeRemaining: json['estimatedTimeRemaining'] as int?,
        startedAt: json['startedAt'] != null
            ? DateTime.tryParse(json['startedAt'] as String)
            : null,
        lastUpdatedAt: json['lastUpdatedAt'] != null
            ? DateTime.parse(json['lastUpdatedAt'] as String)
            : DateTime.now(),
        finishedAt: json['finishedAt'] != null
            ? DateTime.tryParse(json['finishedAt'] as String)
            : null,
        isFinished: json['isFinished'] as bool? ?? false,
        readingStreak: json['readingStreak'] as int? ?? 0,
        lastReadDate: json['lastReadDate'] != null
            ? DateTime.tryParse(json['lastReadDate'] as String)
            : null,
        metadata: json['metadata'] != null
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : null,
        textTranslations:
            (json['textTranslations'] as List<dynamic>?)
                ?.map(
                  (e) => TextTranslation.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList() ??
            [],
        chapterTranslations:
            (json['chapterTranslations'] as List<dynamic>?)
                ?.map(
                  (e) => ChapterTranslation.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList() ??
            [],
        translationSettings: json['translationSettings'] != null
            ? TranslationSettings.fromJson(
                Map<String, dynamic>.from(json['translationSettings'] as Map),
              )
            : null,
      );
    } catch (e) {
      return ReadingProgress.create(bookId: json['bookId'] as String? ?? '');
    }
  }

  // ===========================================================================
  // SERIALIZATION
  // ===========================================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'chapterId': chapterId,
      'chapterProgress': chapterProgress,
      'overallProgress': overallProgress,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'characterOffset': characterOffset,
      'wordOffset': wordOffset,
      'bookmarks': bookmarks.map((e) => e.toJson()).toList(),
      'highlights': highlights.map((e) => e.toJson()).toList(),
      'notes': notes.map((e) => e.toJson()).toList(),
      'sessions': sessions.map((e) => e.toJson()).toList(),
      'lastCFI': lastCFI,
      'totalReadingTimeSeconds': totalReadingTimeSeconds,
      'averageReadingSpeed': averageReadingSpeed,
      'estimatedTimeRemaining': estimatedTimeRemaining,
      'startedAt': startedAt?.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'isFinished': isFinished,
      'readingStreak': readingStreak,
      'lastReadDate': lastReadDate?.toIso8601String(),
      'metadata': metadata,
      'textTranslations': textTranslations.map((e) => e.toJson()).toList(),
      'chapterTranslations': chapterTranslations
          .map((e) => e.toJson())
          .toList(),
      'translationSettings': translationSettings?.toJson(),
    };
  }

  // ===========================================================================
  // COPY WITH
  // ===========================================================================

  ReadingProgress copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    String? chapterId,
    double? chapterProgress,
    double? overallProgress,
    int? currentPage,
    int? totalPages,
    int? characterOffset,
    int? wordOffset,
    List<Bookmark>? bookmarks,
    List<Highlight>? highlights,
    List<Note>? notes,
    List<ReadingSession>? sessions,
    String? lastCFI,
    int? totalReadingTimeSeconds,
    double? averageReadingSpeed,
    int? estimatedTimeRemaining,
    DateTime? startedAt,
    DateTime? lastUpdatedAt,
    DateTime? finishedAt,
    bool? isFinished,
    int? readingStreak,
    DateTime? lastReadDate,
    Map<String, dynamic>? metadata,
    List<TextTranslation>? textTranslations,
    List<ChapterTranslation>? chapterTranslations,
    TranslationSettings? translationSettings,
  }) {
    return ReadingProgress(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterId: chapterId ?? this.chapterId,
      chapterProgress: chapterProgress ?? this.chapterProgress,
      overallProgress: overallProgress ?? this.overallProgress,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      characterOffset: characterOffset ?? this.characterOffset,
      wordOffset: wordOffset ?? this.wordOffset,
      bookmarks: bookmarks ?? this.bookmarks,
      highlights: highlights ?? this.highlights,
      notes: notes ?? this.notes,
      sessions: sessions ?? this.sessions,
      lastCFI: lastCFI ?? this.lastCFI,
      totalReadingTimeSeconds:
          totalReadingTimeSeconds ?? this.totalReadingTimeSeconds,
      averageReadingSpeed: averageReadingSpeed ?? this.averageReadingSpeed,
      estimatedTimeRemaining:
          estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      startedAt: startedAt ?? this.startedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      isFinished: isFinished ?? this.isFinished,
      readingStreak: readingStreak ?? this.readingStreak,
      lastReadDate: lastReadDate ?? this.lastReadDate,
      metadata: metadata ?? this.metadata,
      textTranslations: textTranslations ?? this.textTranslations,
      chapterTranslations: chapterTranslations ?? this.chapterTranslations,
      translationSettings: translationSettings ?? this.translationSettings,
    );
  }

  // ===========================================================================
  // UPDATE METHODS
  // ===========================================================================

  /// Update position
  ReadingProgress updatePosition({
    required int chapterIndex,
    String? chapterId,
    double? chapterProgress,
    double? overallProgress,
    int? characterOffset,
    int? wordOffset,
    String? cfi,
  }) {
    return copyWith(
      chapterIndex: chapterIndex,
      chapterId: chapterId,
      chapterProgress: chapterProgress,
      overallProgress: overallProgress,
      characterOffset: characterOffset,
      wordOffset: wordOffset,
      lastCFI: cfi,
      lastUpdatedAt: DateTime.now(),
      startedAt: startedAt ?? DateTime.now(),
      lastReadDate: DateTime.now(),
    );
  }

  /// Add bookmark
  ReadingProgress addBookmark(Bookmark bookmark) {
    final updatedBookmarks = [...bookmarks, bookmark];
    return copyWith(bookmarks: updatedBookmarks, lastUpdatedAt: DateTime.now());
  }

  /// Remove bookmark
  ReadingProgress removeBookmark(String bookmarkId) {
    final updatedBookmarks = bookmarks
        .map((b) => b.id == bookmarkId ? b.delete() : b)
        .toList();
    return copyWith(bookmarks: updatedBookmarks, lastUpdatedAt: DateTime.now());
  }

  /// Update bookmark
  ReadingProgress updateBookmark(Bookmark bookmark) {
    final updatedBookmarks = bookmarks
        .map((b) => b.id == bookmark.id ? bookmark : b)
        .toList();
    return copyWith(bookmarks: updatedBookmarks, lastUpdatedAt: DateTime.now());
  }

  /// Add highlight
  ReadingProgress addHighlight(Highlight highlight) {
    final updatedHighlights = [...highlights, highlight];
    return copyWith(
      highlights: updatedHighlights,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Remove highlight
  ReadingProgress removeHighlight(String highlightId) {
    final updatedHighlights = highlights
        .map((h) => h.id == highlightId ? h.delete() : h)
        .toList();
    return copyWith(
      highlights: updatedHighlights,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Update highlight
  ReadingProgress updateHighlight(Highlight highlight) {
    final updatedHighlights = highlights
        .map((h) => h.id == highlight.id ? highlight : h)
        .toList();
    return copyWith(
      highlights: updatedHighlights,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Add note
  ReadingProgress addNote(Note note) {
    final updatedNotes = [...notes, note];
    return copyWith(notes: updatedNotes, lastUpdatedAt: DateTime.now());
  }

  /// Remove note
  ReadingProgress removeNote(String noteId) {
    final updatedNotes = notes
        .map((n) => n.id == noteId ? n.delete() : n)
        .toList();
    return copyWith(notes: updatedNotes, lastUpdatedAt: DateTime.now());
  }

  /// Update note
  ReadingProgress updateNote(Note note) {
    final updatedNotes = notes.map((n) => n.id == note.id ? note : n).toList();
    return copyWith(notes: updatedNotes, lastUpdatedAt: DateTime.now());
  }

  /// Add reading session
  ReadingProgress addSession(ReadingSession session) {
    final updatedSessions = [...sessions, session];
    final totalTime = totalReadingTimeSeconds + session.durationSeconds;

    // Update streak
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    int newStreak = readingStreak;

    if (lastReadDate == null) {
      newStreak = 1;
    } else if (_isSameDay(lastReadDate!, today)) {
      // Same day, keep streak
    } else if (_isSameDay(lastReadDate!, yesterday)) {
      // Yesterday, increment streak
      newStreak++;
    } else {
      // Streak broken, reset
      newStreak = 1;
    }

    return copyWith(
      sessions: updatedSessions,
      totalReadingTimeSeconds: totalTime,
      lastReadDate: today,
      readingStreak: newStreak,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Mark as finished
  ReadingProgress markFinished() {
    return copyWith(
      isFinished: true,
      finishedAt: DateTime.now(),
      overallProgress: 1.0,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Reset progress
  ReadingProgress reset() {
    return ReadingProgress(
      id: id,
      bookId: bookId,
      bookmarks: bookmarks, // Keep bookmarks
      highlights: highlights, // Keep highlights
      notes: notes, // Keep notes
      sessions: sessions, // Keep history
      textTranslations: textTranslations, // Keep translations
      chapterTranslations: chapterTranslations, // Keep translations
      translationSettings: translationSettings,
      totalReadingTimeSeconds: totalReadingTimeSeconds,
      lastUpdatedAt: DateTime.now(),
    );
  }

  // ===========================================================================
  // TRANSLATION METHODS
  // ===========================================================================

  /// Add text translation
  ReadingProgress addTextTranslation(TextTranslation translation) {
    // Check if translation already exists
    final existingIndex = textTranslations.indexWhere(
      (t) =>
          t.originalText == translation.originalText &&
          t.targetLanguage == translation.targetLanguage &&
          t.chapterIndex == translation.chapterIndex &&
          !t.isDeleted,
    );

    List<TextTranslation> updatedTranslations;
    if (existingIndex != -1) {
      // Update existing translation
      updatedTranslations = List.from(textTranslations);
      updatedTranslations[existingIndex] = translation;
    } else {
      // Add new translation
      updatedTranslations = [...textTranslations, translation];
    }

    return copyWith(
      textTranslations: updatedTranslations,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Add or update text translation (convenience method)
  ReadingProgress saveTextTranslation({
    required String originalText,
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
    int? chapterIndex,
    String? chapterId,
    int? startOffset,
    int? endOffset,
    String? context,
    TranslationProvider? provider,
  }) {
    final translation = TextTranslation.create(
      originalText: originalText,
      translatedText: translatedText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      chapterIndex: chapterIndex,
      chapterId: chapterId,
      startOffset: startOffset,
      endOffset: endOffset,
      context: context,
      provider: provider,
    );
    return addTextTranslation(translation);
  }

  /// Remove text translation
  ReadingProgress removeTextTranslation(String translationId) {
    final updatedTranslations = textTranslations
        .map((t) => t.id == translationId ? t.delete() : t)
        .toList();
    return copyWith(
      textTranslations: updatedTranslations,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Update text translation
  ReadingProgress updateTextTranslation(TextTranslation translation) {
    final updatedTranslations = textTranslations
        .map((t) => t.id == translation.id ? translation : t)
        .toList();
    return copyWith(
      textTranslations: updatedTranslations,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Add chapter translation
  ReadingProgress addChapterTranslation(ChapterTranslation translation) {
    // Check if translation already exists for this chapter and language
    final existingIndex = chapterTranslations.indexWhere(
      (t) =>
          t.chapterIndex == translation.chapterIndex &&
          t.targetLanguage == translation.targetLanguage &&
          !t.isDeleted,
    );

    List<ChapterTranslation> updatedTranslations;
    if (existingIndex != -1) {
      // Update existing translation
      updatedTranslations = List.from(chapterTranslations);
      updatedTranslations[existingIndex] = translation;
    } else {
      // Add new translation
      updatedTranslations = [...chapterTranslations, translation];
    }

    return copyWith(
      chapterTranslations: updatedTranslations,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Add or update chapter translation (convenience method)
  ReadingProgress saveChapterTranslation({
    required int chapterIndex,
    required String chapterId,
    required String originalTitle,
    required String translatedTitle,
    required String originalContent,
    required String translatedContent,
    required String sourceLanguage,
    required String targetLanguage,
    TranslationProvider? provider,
  }) {
    final translation = ChapterTranslation.create(
      chapterIndex: chapterIndex,
      chapterId: chapterId,
      originalTitle: originalTitle,
      translatedTitle: translatedTitle,
      originalContent: originalContent,
      translatedContent: translatedContent,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      provider: provider,
    );
    return addChapterTranslation(translation);
  }

  /// Remove chapter translation
  ReadingProgress removeChapterTranslation(String translationId) {
    final updatedTranslations = chapterTranslations
        .map((t) => t.id == translationId ? t.delete() : t)
        .toList();
    return copyWith(
      chapterTranslations: updatedTranslations,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Update chapter translation
  ReadingProgress updateChapterTranslation(ChapterTranslation translation) {
    final updatedTranslations = chapterTranslations
        .map((t) => t.id == translation.id ? translation : t)
        .toList();
    return copyWith(
      chapterTranslations: updatedTranslations,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Clear all translations for a specific language
  ReadingProgress clearTranslationsForLanguage(String languageCode) {
    final updatedTextTranslations = textTranslations
        .map((t) => t.targetLanguage == languageCode ? t.delete() : t)
        .toList();
    final updatedChapterTranslations = chapterTranslations
        .map((t) => t.targetLanguage == languageCode ? t.delete() : t)
        .toList();

    return copyWith(
      textTranslations: updatedTextTranslations,
      chapterTranslations: updatedChapterTranslations,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Clear all translations
  ReadingProgress clearAllTranslations() {
    return copyWith(
      textTranslations: textTranslations.map((t) => t.delete()).toList(),
      chapterTranslations: chapterTranslations.map((t) => t.delete()).toList(),
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Purge deleted translations (permanently remove)
  ReadingProgress purgeDeletedTranslations() {
    return copyWith(
      textTranslations: textTranslations.where((t) => !t.isDeleted).toList(),
      chapterTranslations: chapterTranslations
          .where((t) => !t.isDeleted)
          .toList(),
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Update translation settings
  ReadingProgress updateTranslationSettings(TranslationSettings settings) {
    return copyWith(
      translationSettings: settings,
      lastUpdatedAt: DateTime.now(),
    );
  }

  /// Get translation statistics
  TranslationStats getTranslationStats() {
    return TranslationStats(
      totalTextTranslations: activeTextTranslations.length,
      totalChapterTranslations: activeChapterTranslations.length,
      languagesTranslated: translatedLanguages.toList(),
      translationsByLanguage: _groupTranslationsByLanguage(),
      chaptersFullyTranslated: _getFullyTranslatedChapters(),
    );
  }

  Map<String, int> _groupTranslationsByLanguage() {
    final result = <String, int>{};
    for (final t in activeTextTranslations) {
      result[t.targetLanguage] = (result[t.targetLanguage] ?? 0) + 1;
    }
    for (final t in activeChapterTranslations) {
      result[t.targetLanguage] = (result[t.targetLanguage] ?? 0) + 1;
    }
    return result;
  }

  Map<String, List<int>> _getFullyTranslatedChapters() {
    final result = <String, List<int>>{};
    for (final t in activeChapterTranslations) {
      result[t.targetLanguage] ??= [];
      result[t.targetLanguage]!.add(t.chapterIndex);
    }
    return result;
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  static String _generateId() {
    return 'progress_${DateTime.now().millisecondsSinceEpoch}';
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  List<Object?> get props => [
    id,
    bookId,
    chapterIndex,
    overallProgress,
    lastUpdatedAt,
    bookmarks.length,
    highlights.length,
    notes.length,
    textTranslations.length,
    chapterTranslations.length,
  ];

  @override
  String toString() =>
      'ReadingProgress(bookId: $bookId, chapter: $chapterIndex, progress: $progressPercentage%)';
}

// =============================================================================
// TEXT TRANSLATION
// =============================================================================

/// Translation for text/phrase/sentence level
@HiveType(typeId: 18)
class TextTranslation extends Equatable {
  @HiveField(0)
  final String id;

  /// Original text that was translated
  @HiveField(1)
  final String originalText;

  /// Translated text
  @HiveField(2)
  final String translatedText;

  /// Source language code (e.g., 'en', 'es', 'zh')
  @HiveField(3)
  final String sourceLanguage;

  /// Target language code
  @HiveField(4)
  final String targetLanguage;

  /// Chapter index where this translation was made
  @HiveField(5)
  final int? chapterIndex;

  /// Chapter ID
  @HiveField(6)
  final String? chapterId;

  /// Start character offset in chapter content
  @HiveField(7)
  final int? startOffset;

  /// End character offset in chapter content
  @HiveField(8)
  final int? endOffset;

  /// Context around the text (for better matching)
  @HiveField(9)
  final String? context;

  /// Translation provider used
  @HiveField(10)
  final TranslationProvider? provider;

  /// Confidence score (0.0 to 1.0)
  @HiveField(11)
  final double? confidence;

  /// Alternative translations
  @HiveField(12)
  final List<String>? alternatives;

  /// Pronunciation/phonetic (for languages like Chinese, Japanese)
  @HiveField(13)
  final String? pronunciation;

  /// Part of speech (noun, verb, etc.)
  @HiveField(14)
  final String? partOfSpeech;

  /// User notes about this translation
  @HiveField(15)
  final String? note;

  /// When translation was created
  @HiveField(16)
  final DateTime createdAt;

  /// When translation was last updated
  @HiveField(17)
  final DateTime? updatedAt;

  /// Is translation deleted (soft delete)
  @HiveField(18)
  final bool isDeleted;

  /// Is user-edited (vs auto-translated)
  @HiveField(19)
  final bool isUserEdited;

  /// Times this translation was viewed/used
  @HiveField(20)
  final int usageCount;

  /// Last time translation was accessed
  @HiveField(21)
  final DateTime? lastAccessedAt;

  /// Additional metadata
  @HiveField(22)
  final Map<String, dynamic>? metadata;

  const TextTranslation({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.chapterIndex,
    this.chapterId,
    this.startOffset,
    this.endOffset,
    this.context,
    this.provider,
    this.confidence,
    this.alternatives,
    this.pronunciation,
    this.partOfSpeech,
    this.note,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.isUserEdited = false,
    this.usageCount = 0,
    this.lastAccessedAt,
    this.metadata,
  });

  /// Create a new text translation
  factory TextTranslation.create({
    required String originalText,
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
    int? chapterIndex,
    String? chapterId,
    int? startOffset,
    int? endOffset,
    String? context,
    TranslationProvider? provider,
    double? confidence,
    List<String>? alternatives,
    String? pronunciation,
    String? partOfSpeech,
    String? note,
  }) {
    return TextTranslation(
      id: 'text_trans_${DateTime.now().millisecondsSinceEpoch}_${originalText.hashCode.abs()}',
      originalText: originalText,
      translatedText: translatedText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      chapterIndex: chapterIndex,
      chapterId: chapterId,
      startOffset: startOffset,
      endOffset: endOffset,
      context: context,
      provider: provider,
      confidence: confidence,
      alternatives: alternatives,
      pronunciation: pronunciation,
      partOfSpeech: partOfSpeech,
      note: note,
      createdAt: DateTime.now(),
    );
  }

  factory TextTranslation.fromJson(Map<String, dynamic> json) {
    try {
      return TextTranslation(
        id: json['id'] as String? ?? '',
        originalText: json['originalText'] as String? ?? '',
        translatedText: json['translatedText'] as String? ?? '',
        sourceLanguage: json['sourceLanguage'] as String? ?? 'unknown',
        targetLanguage: json['targetLanguage'] as String? ?? 'unknown',
        chapterIndex: json['chapterIndex'] as int?,
        chapterId: json['chapterId'] as String?,
        startOffset: json['startOffset'] as int?,
        endOffset: json['endOffset'] as int?,
        context: json['context'] as String?,
        provider: json['provider'] != null
            ? TranslationProvider.values.firstWhere(
                (e) => e.name == json['provider'],
                orElse: () => TranslationProvider.unknown,
              )
            : null,
        confidence: (json['confidence'] as num?)?.toDouble(),
        alternatives: (json['alternatives'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        pronunciation: json['pronunciation'] as String?,
        partOfSpeech: json['partOfSpeech'] as String?,
        note: json['note'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        isDeleted: json['isDeleted'] as bool? ?? false,
        isUserEdited: json['isUserEdited'] as bool? ?? false,
        usageCount: json['usageCount'] as int? ?? 0,
        lastAccessedAt: json['lastAccessedAt'] != null
            ? DateTime.tryParse(json['lastAccessedAt'] as String)
            : null,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      return TextTranslation(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        originalText: '',
        translatedText: '',
        sourceLanguage: 'unknown',
        targetLanguage: 'unknown',
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalText': originalText,
      'translatedText': translatedText,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'chapterIndex': chapterIndex,
      'chapterId': chapterId,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'context': context,
      'provider': provider?.name,
      'confidence': confidence,
      'alternatives': alternatives,
      'pronunciation': pronunciation,
      'partOfSpeech': partOfSpeech,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'isUserEdited': isUserEdited,
      'usageCount': usageCount,
      'lastAccessedAt': lastAccessedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  TextTranslation copyWith({
    String? id,
    String? originalText,
    String? translatedText,
    String? sourceLanguage,
    String? targetLanguage,
    int? chapterIndex,
    String? chapterId,
    int? startOffset,
    int? endOffset,
    String? context,
    TranslationProvider? provider,
    double? confidence,
    List<String>? alternatives,
    String? pronunciation,
    String? partOfSpeech,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isUserEdited,
    int? usageCount,
    DateTime? lastAccessedAt,
    Map<String, dynamic>? metadata,
  }) {
    return TextTranslation(
      id: id ?? this.id,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterId: chapterId ?? this.chapterId,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      context: context ?? this.context,
      provider: provider ?? this.provider,
      confidence: confidence ?? this.confidence,
      alternatives: alternatives ?? this.alternatives,
      pronunciation: pronunciation ?? this.pronunciation,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isUserEdited: isUserEdited ?? this.isUserEdited,
      usageCount: usageCount ?? this.usageCount,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Mark as accessed (increment usage count)
  TextTranslation markAccessed() {
    return copyWith(usageCount: usageCount + 1, lastAccessedAt: DateTime.now());
  }

  /// Update translation text
  TextTranslation updateTranslation(String newTranslation) {
    return copyWith(
      translatedText: newTranslation,
      updatedAt: DateTime.now(),
      isUserEdited: true,
    );
  }

  /// Add note
  TextTranslation addNote(String newNote) {
    return copyWith(note: newNote, updatedAt: DateTime.now());
  }

  /// Delete (soft delete)
  TextTranslation delete() {
    return copyWith(isDeleted: true, updatedAt: DateTime.now());
  }

  /// Get language pair string
  String get languagePair => '$sourceLanguage → $targetLanguage';

  /// Get short preview of original text
  String get originalPreview {
    if (originalText.length <= 50) return originalText;
    return '${originalText.substring(0, 50)}...';
  }

  @override
  List<Object?> get props => [
    id,
    originalText,
    translatedText,
    sourceLanguage,
    targetLanguage,
    chapterIndex,
    isDeleted,
  ];

  @override
  String toString() =>
      'TextTranslation(id: $id, $languagePair, "$originalPreview")';
}

// =============================================================================
// CHAPTER TRANSLATION
// =============================================================================

/// Translation for full chapter content
@HiveType(typeId: 19)
class ChapterTranslation extends Equatable {
  @HiveField(0)
  final String id;

  /// Chapter index
  @HiveField(1)
  final int chapterIndex;

  /// Chapter ID
  @HiveField(2)
  final String chapterId;

  /// Original chapter title
  @HiveField(3)
  final String originalTitle;

  /// Translated chapter title
  @HiveField(4)
  final String translatedTitle;

  /// Original HTML content
  @HiveField(5)
  final String originalContent;

  /// Translated HTML content
  @HiveField(6)
  final String translatedContent;

  /// Source language code
  @HiveField(7)
  final String sourceLanguage;

  /// Target language code
  @HiveField(8)
  final String targetLanguage;

  /// Translation provider used
  @HiveField(9)
  final TranslationProvider? provider;

  /// Word count of original
  @HiveField(10)
  final int originalWordCount;

  /// Word count of translated
  @HiveField(11)
  final int translatedWordCount;

  /// Translation quality score (0.0 to 1.0)
  @HiveField(12)
  final double? qualityScore;

  /// Is translation complete (vs partial)
  @HiveField(13)
  final bool isComplete;

  /// Percentage of chapter translated
  @HiveField(14)
  final double completionPercentage;

  /// When translation was created
  @HiveField(15)
  final DateTime createdAt;

  /// When translation was last updated
  @HiveField(16)
  final DateTime? updatedAt;

  /// Is translation deleted (soft delete)
  @HiveField(17)
  final bool isDeleted;

  /// Is user-edited
  @HiveField(18)
  final bool isUserEdited;

  /// Translation notes
  @HiveField(19)
  final String? notes;

  /// Additional metadata
  @HiveField(20)
  final Map<String, dynamic>? metadata;

  const ChapterTranslation({
    required this.id,
    required this.chapterIndex,
    required this.chapterId,
    required this.originalTitle,
    required this.translatedTitle,
    required this.originalContent,
    required this.translatedContent,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.provider,
    this.originalWordCount = 0,
    this.translatedWordCount = 0,
    this.qualityScore,
    this.isComplete = true,
    this.completionPercentage = 100.0,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.isUserEdited = false,
    this.notes,
    this.metadata,
  });

  /// Create new chapter translation
  factory ChapterTranslation.create({
    required int chapterIndex,
    required String chapterId,
    required String originalTitle,
    required String translatedTitle,
    required String originalContent,
    required String translatedContent,
    required String sourceLanguage,
    required String targetLanguage,
    TranslationProvider? provider,
    double? qualityScore,
    bool isComplete = true,
    double completionPercentage = 100.0,
    String? notes,
  }) {
    return ChapterTranslation(
      id: 'chapter_trans_${DateTime.now().millisecondsSinceEpoch}_$chapterIndex',
      chapterIndex: chapterIndex,
      chapterId: chapterId,
      originalTitle: originalTitle,
      translatedTitle: translatedTitle,
      originalContent: originalContent,
      translatedContent: translatedContent,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      provider: provider,
      originalWordCount: _countWords(originalContent),
      translatedWordCount: _countWords(translatedContent),
      qualityScore: qualityScore,
      isComplete: isComplete,
      completionPercentage: completionPercentage,
      createdAt: DateTime.now(),
      notes: notes,
    );
  }

  factory ChapterTranslation.fromJson(Map<String, dynamic> json) {
    try {
      return ChapterTranslation(
        id: json['id'] as String? ?? '',
        chapterIndex: json['chapterIndex'] as int? ?? 0,
        chapterId: json['chapterId'] as String? ?? '',
        originalTitle: json['originalTitle'] as String? ?? '',
        translatedTitle: json['translatedTitle'] as String? ?? '',
        originalContent: json['originalContent'] as String? ?? '',
        translatedContent: json['translatedContent'] as String? ?? '',
        sourceLanguage: json['sourceLanguage'] as String? ?? 'unknown',
        targetLanguage: json['targetLanguage'] as String? ?? 'unknown',
        provider: json['provider'] != null
            ? TranslationProvider.values.firstWhere(
                (e) => e.name == json['provider'],
                orElse: () => TranslationProvider.unknown,
              )
            : null,
        originalWordCount: json['originalWordCount'] as int? ?? 0,
        translatedWordCount: json['translatedWordCount'] as int? ?? 0,
        qualityScore: (json['qualityScore'] as num?)?.toDouble(),
        isComplete: json['isComplete'] as bool? ?? true,
        completionPercentage:
            (json['completionPercentage'] as num?)?.toDouble() ?? 100.0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        isDeleted: json['isDeleted'] as bool? ?? false,
        isUserEdited: json['isUserEdited'] as bool? ?? false,
        notes: json['notes'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      return ChapterTranslation(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        chapterIndex: 0,
        chapterId: '',
        originalTitle: '',
        translatedTitle: '',
        originalContent: '',
        translatedContent: '',
        sourceLanguage: 'unknown',
        targetLanguage: 'unknown',
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapterIndex': chapterIndex,
      'chapterId': chapterId,
      'originalTitle': originalTitle,
      'translatedTitle': translatedTitle,
      'originalContent': originalContent,
      'translatedContent': translatedContent,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'provider': provider?.name,
      'originalWordCount': originalWordCount,
      'translatedWordCount': translatedWordCount,
      'qualityScore': qualityScore,
      'isComplete': isComplete,
      'completionPercentage': completionPercentage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'isUserEdited': isUserEdited,
      'notes': notes,
      'metadata': metadata,
    };
  }

  ChapterTranslation copyWith({
    String? id,
    int? chapterIndex,
    String? chapterId,
    String? originalTitle,
    String? translatedTitle,
    String? originalContent,
    String? translatedContent,
    String? sourceLanguage,
    String? targetLanguage,
    TranslationProvider? provider,
    int? originalWordCount,
    int? translatedWordCount,
    double? qualityScore,
    bool? isComplete,
    double? completionPercentage,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? isUserEdited,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return ChapterTranslation(
      id: id ?? this.id,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterId: chapterId ?? this.chapterId,
      originalTitle: originalTitle ?? this.originalTitle,
      translatedTitle: translatedTitle ?? this.translatedTitle,
      originalContent: originalContent ?? this.originalContent,
      translatedContent: translatedContent ?? this.translatedContent,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      provider: provider ?? this.provider,
      originalWordCount: originalWordCount ?? this.originalWordCount,
      translatedWordCount: translatedWordCount ?? this.translatedWordCount,
      qualityScore: qualityScore ?? this.qualityScore,
      isComplete: isComplete ?? this.isComplete,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isUserEdited: isUserEdited ?? this.isUserEdited,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Update translated content
  ChapterTranslation updateContent(String newContent) {
    return copyWith(
      translatedContent: newContent,
      translatedWordCount: _countWords(newContent),
      updatedAt: DateTime.now(),
      isUserEdited: true,
    );
  }

  /// Update translated title
  ChapterTranslation updateTitle(String newTitle) {
    return copyWith(
      translatedTitle: newTitle,
      updatedAt: DateTime.now(),
      isUserEdited: true,
    );
  }

  /// Delete (soft delete)
  ChapterTranslation delete() {
    return copyWith(isDeleted: true, updatedAt: DateTime.now());
  }

  /// Get language pair string
  String get languagePair => '$sourceLanguage → $targetLanguage';

  /// Get size in bytes (approximate)
  int get sizeBytes => (originalContent.length + translatedContent.length) * 2;

  /// Get size in MB
  double get sizeMB => sizeBytes / (1024 * 1024);

  static int _countWords(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 0;
    return cleaned.split(' ').length;
  }

  @override
  List<Object?> get props => [
    id,
    chapterIndex,
    sourceLanguage,
    targetLanguage,
    isDeleted,
  ];

  @override
  String toString() =>
      'ChapterTranslation(chapter: $chapterIndex, $languagePair)';
}

// =============================================================================
// TRANSLATION SETTINGS
// =============================================================================

/// User preferences for translation
@HiveType(typeId: 20)
class TranslationSettings extends Equatable {
  /// Preferred target language
  @HiveField(0)
  final String preferredLanguage;

  /// Preferred translation provider
  @HiveField(1)
  final TranslationProvider preferredProvider;

  /// Auto-translate on text selection
  @HiveField(2)
  final bool autoTranslateOnSelect;

  /// Show pronunciation for languages that support it
  @HiveField(3)
  final bool showPronunciation;

  /// Show alternative translations
  @HiveField(4)
  final bool showAlternatives;

  /// Cache translations for offline use
  @HiveField(5)
  final bool cacheTranslations;

  /// Maximum cached translations per book
  @HiveField(6)
  final int maxCachedTranslations;

  /// Auto-detect source language
  @HiveField(7)
  final bool autoDetectSource;

  /// Default source language (if not auto-detect)
  @HiveField(8)
  final String? defaultSourceLanguage;

  /// Show inline translations
  @HiveField(9)
  final bool showInlineTranslations;

  /// Translation display mode
  @HiveField(10)
  final TranslationDisplayMode displayMode;

  /// Recently used languages
  @HiveField(11)
  final List<String> recentLanguages;

  /// Additional settings
  @HiveField(12)
  final Map<String, dynamic>? additionalSettings;

  const TranslationSettings({
    this.preferredLanguage = 'en',
    this.preferredProvider = TranslationProvider.google,
    this.autoTranslateOnSelect = false,
    this.showPronunciation = true,
    this.showAlternatives = true,
    this.cacheTranslations = true,
    this.maxCachedTranslations = 1000,
    this.autoDetectSource = true,
    this.defaultSourceLanguage,
    this.showInlineTranslations = false,
    this.displayMode = TranslationDisplayMode.popup,
    this.recentLanguages = const [],
    this.additionalSettings,
  });

  factory TranslationSettings.fromJson(Map<String, dynamic> json) {
    return TranslationSettings(
      preferredLanguage: json['preferredLanguage'] as String? ?? 'en',
      preferredProvider: TranslationProvider.values.firstWhere(
        (e) => e.name == json['preferredProvider'],
        orElse: () => TranslationProvider.google,
      ),
      autoTranslateOnSelect: json['autoTranslateOnSelect'] as bool? ?? false,
      showPronunciation: json['showPronunciation'] as bool? ?? true,
      showAlternatives: json['showAlternatives'] as bool? ?? true,
      cacheTranslations: json['cacheTranslations'] as bool? ?? true,
      maxCachedTranslations: json['maxCachedTranslations'] as int? ?? 1000,
      autoDetectSource: json['autoDetectSource'] as bool? ?? true,
      defaultSourceLanguage: json['defaultSourceLanguage'] as String?,
      showInlineTranslations: json['showInlineTranslations'] as bool? ?? false,
      displayMode: TranslationDisplayMode.values.firstWhere(
        (e) => e.name == json['displayMode'],
        orElse: () => TranslationDisplayMode.popup,
      ),
      recentLanguages:
          (json['recentLanguages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      additionalSettings: json['additionalSettings'] != null
          ? Map<String, dynamic>.from(json['additionalSettings'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferredLanguage': preferredLanguage,
      'preferredProvider': preferredProvider.name,
      'autoTranslateOnSelect': autoTranslateOnSelect,
      'showPronunciation': showPronunciation,
      'showAlternatives': showAlternatives,
      'cacheTranslations': cacheTranslations,
      'maxCachedTranslations': maxCachedTranslations,
      'autoDetectSource': autoDetectSource,
      'defaultSourceLanguage': defaultSourceLanguage,
      'showInlineTranslations': showInlineTranslations,
      'displayMode': displayMode.name,
      'recentLanguages': recentLanguages,
      'additionalSettings': additionalSettings,
    };
  }

  TranslationSettings copyWith({
    String? preferredLanguage,
    TranslationProvider? preferredProvider,
    bool? autoTranslateOnSelect,
    bool? showPronunciation,
    bool? showAlternatives,
    bool? cacheTranslations,
    int? maxCachedTranslations,
    bool? autoDetectSource,
    String? defaultSourceLanguage,
    bool? showInlineTranslations,
    TranslationDisplayMode? displayMode,
    List<String>? recentLanguages,
    Map<String, dynamic>? additionalSettings,
  }) {
    return TranslationSettings(
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      preferredProvider: preferredProvider ?? this.preferredProvider,
      autoTranslateOnSelect:
          autoTranslateOnSelect ?? this.autoTranslateOnSelect,
      showPronunciation: showPronunciation ?? this.showPronunciation,
      showAlternatives: showAlternatives ?? this.showAlternatives,
      cacheTranslations: cacheTranslations ?? this.cacheTranslations,
      maxCachedTranslations:
          maxCachedTranslations ?? this.maxCachedTranslations,
      autoDetectSource: autoDetectSource ?? this.autoDetectSource,
      defaultSourceLanguage:
          defaultSourceLanguage ?? this.defaultSourceLanguage,
      showInlineTranslations:
          showInlineTranslations ?? this.showInlineTranslations,
      displayMode: displayMode ?? this.displayMode,
      recentLanguages: recentLanguages ?? this.recentLanguages,
      additionalSettings: additionalSettings ?? this.additionalSettings,
    );
  }

  /// Add language to recent list
  TranslationSettings addRecentLanguage(String languageCode) {
    if (recentLanguages.contains(languageCode)) {
      // Move to front
      final updated = [
        languageCode,
        ...recentLanguages.where((l) => l != languageCode),
      ];
      return copyWith(recentLanguages: updated.take(10).toList());
    }
    return copyWith(
      recentLanguages: [languageCode, ...recentLanguages].take(10).toList(),
    );
  }

  @override
  List<Object?> get props => [
    preferredLanguage,
    preferredProvider,
    autoTranslateOnSelect,
    cacheTranslations,
    displayMode,
  ];
}

// =============================================================================
// TRANSLATION STATISTICS
// =============================================================================

/// Statistics about translations for a book
class TranslationStats {
  final int totalTextTranslations;
  final int totalChapterTranslations;
  final List<String> languagesTranslated;
  final Map<String, int> translationsByLanguage;
  final Map<String, List<int>> chaptersFullyTranslated;

  const TranslationStats({
    required this.totalTextTranslations,
    required this.totalChapterTranslations,
    required this.languagesTranslated,
    required this.translationsByLanguage,
    required this.chaptersFullyTranslated,
  });

  int get totalTranslations => totalTextTranslations + totalChapterTranslations;

  bool get hasTranslations => totalTranslations > 0;

  Map<String, dynamic> toJson() {
    return {
      'totalTextTranslations': totalTextTranslations,
      'totalChapterTranslations': totalChapterTranslations,
      'languagesTranslated': languagesTranslated,
      'translationsByLanguage': translationsByLanguage,
      'chaptersFullyTranslated': chaptersFullyTranslated,
    };
  }
}

// =============================================================================
// ENUMS
// =============================================================================

/// Translation provider enum
@HiveType(typeId: 21)
enum TranslationProvider {
  @HiveField(0)
  google,

  @HiveField(1)
  microsoft,

  @HiveField(2)
  deepl,

  @HiveField(3)
  amazon,

  @HiveField(4)
  yandex,

  @HiveField(5)
  baidu,

  @HiveField(6)
  libre,

  @HiveField(7)
  offline,

  @HiveField(8)
  manual,

  @HiveField(9)
  unknown,
}

/// Translation display mode
@HiveType(typeId: 22)
enum TranslationDisplayMode {
  @HiveField(0)
  popup,

  @HiveField(1)
  inline,

  @HiveField(2)
  bottomSheet,

  @HiveField(3)
  sideBySide,

  @HiveField(4)
  overlay,
}

/// Extension for TranslationProvider
extension TranslationProviderExtension on TranslationProvider {
  String get displayName {
    switch (this) {
      case TranslationProvider.google:
        return 'Google Translate';
      case TranslationProvider.microsoft:
        return 'Microsoft Translator';
      case TranslationProvider.deepl:
        return 'DeepL';
      case TranslationProvider.amazon:
        return 'Amazon Translate';
      case TranslationProvider.yandex:
        return 'Yandex Translate';
      case TranslationProvider.baidu:
        return 'Baidu Translate';
      case TranslationProvider.libre:
        return 'LibreTranslate';
      case TranslationProvider.offline:
        return 'Offline Translation';
      case TranslationProvider.manual:
        return 'Manual Translation';
      case TranslationProvider.unknown:
        return 'Unknown';
    }
  }

  bool get supportsAutoDetect {
    switch (this) {
      case TranslationProvider.google:
      case TranslationProvider.microsoft:
      case TranslationProvider.deepl:
      case TranslationProvider.amazon:
      case TranslationProvider.yandex:
        return true;
      default:
        return false;
    }
  }

  bool get isOnline {
    return this != TranslationProvider.offline &&
        this != TranslationProvider.manual;
  }
}

// =============================================================================
// LANGUAGE HELPER
// =============================================================================

/// Common language codes and names
class LanguageHelper {
  static const Map<String, String> commonLanguages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'zh': 'Chinese (Simplified)',
    'zh-TW': 'Chinese (Traditional)',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'bn': 'Bengali',
    'pa': 'Punjabi',
    'vi': 'Vietnamese',
    'th': 'Thai',
    'id': 'Indonesian',
    'ms': 'Malay',
    'tr': 'Turkish',
    'pl': 'Polish',
    'nl': 'Dutch',
    'sv': 'Swedish',
    'no': 'Norwegian',
    'da': 'Danish',
    'fi': 'Finnish',
    'el': 'Greek',
    'he': 'Hebrew',
    'uk': 'Ukrainian',
    'cs': 'Czech',
    'ro': 'Romanian',
    'hu': 'Hungarian',
    'ta': 'Tamil',
    'te': 'Telugu',
    'mr': 'Marathi',
    'gu': 'Gujarati',
    'kn': 'Kannada',
    'ml': 'Malayalam',
  };

  static String getLanguageName(String code) {
    return commonLanguages[code] ?? code.toUpperCase();
  }

  static String? getLanguageCode(String name) {
    try {
      return commonLanguages.entries
          .firstWhere((e) => e.value.toLowerCase() == name.toLowerCase())
          .key;
    } catch (_) {
      return null;
    }
  }

  static List<MapEntry<String, String>> searchLanguages(String query) {
    if (query.isEmpty) {
      return commonLanguages.entries.toList();
    }
    final lowerQuery = query.toLowerCase();
    return commonLanguages.entries
        .where(
          (e) =>
              e.key.toLowerCase().contains(lowerQuery) ||
              e.value.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }
}

// =============================================================================
// BOOKMARK (Updated from original)
// =============================================================================

@HiveType(typeId: 12)
class Bookmark extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int chapterIndex;

  @HiveField(2)
  final String? chapterId;

  @HiveField(3)
  final String? chapterTitle;

  @HiveField(4)
  final double chapterProgress;

  @HiveField(5)
  final int? characterOffset;

  @HiveField(6)
  final String? cfi;

  @HiveField(7)
  final String? previewText;

  @HiveField(8)
  final String? note;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final DateTime? updatedAt;

  @HiveField(11)
  final bool isDeleted;

  @HiveField(12)
  final Map<String, dynamic>? metadata;

  const Bookmark({
    required this.id,
    required this.chapterIndex,
    this.chapterId,
    this.chapterTitle,
    this.chapterProgress = 0.0,
    this.characterOffset,
    this.cfi,
    this.previewText,
    this.note,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.metadata,
  });

  factory Bookmark.create({
    required int chapterIndex,
    String? chapterId,
    String? chapterTitle,
    double? chapterProgress,
    int? characterOffset,
    String? cfi,
    String? previewText,
    String? note,
  }) {
    return Bookmark(
      id: 'bookmark_${DateTime.now().millisecondsSinceEpoch}',
      chapterIndex: chapterIndex,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      chapterProgress: chapterProgress ?? 0.0,
      characterOffset: characterOffset,
      cfi: cfi,
      previewText: previewText,
      note: note,
      createdAt: DateTime.now(),
    );
  }

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String? ?? '',
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      chapterId: json['chapterId'] as String?,
      chapterTitle: json['chapterTitle'] as String?,
      chapterProgress: (json['chapterProgress'] as num?)?.toDouble() ?? 0.0,
      characterOffset: json['characterOffset'] as int?,
      cfi: json['cfi'] as String?,
      previewText: json['previewText'] as String?,
      note: json['note'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapterIndex': chapterIndex,
      'chapterId': chapterId,
      'chapterTitle': chapterTitle,
      'chapterProgress': chapterProgress,
      'characterOffset': characterOffset,
      'cfi': cfi,
      'previewText': previewText,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'metadata': metadata,
    };
  }

  Bookmark copyWith({
    String? id,
    int? chapterIndex,
    String? chapterId,
    String? chapterTitle,
    double? chapterProgress,
    int? characterOffset,
    String? cfi,
    String? previewText,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    Map<String, dynamic>? metadata,
  }) {
    return Bookmark(
      id: id ?? this.id,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterProgress: chapterProgress ?? this.chapterProgress,
      characterOffset: characterOffset ?? this.characterOffset,
      cfi: cfi ?? this.cfi,
      previewText: previewText ?? this.previewText,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata ?? this.metadata,
    );
  }

  Bookmark updateNote(String newNote) {
    return copyWith(note: newNote, updatedAt: DateTime.now());
  }

  Bookmark delete() {
    return copyWith(isDeleted: true, updatedAt: DateTime.now());
  }

  @override
  List<Object?> get props => [id, chapterIndex, cfi, isDeleted];
}

// =============================================================================
// HIGHLIGHT
// =============================================================================

@HiveType(typeId: 13)
class Highlight extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int chapterIndex;

  @HiveField(2)
  final String? chapterId;

  @HiveField(3)
  final String selectedText;

  @HiveField(4)
  final String? contextBefore;

  @HiveField(5)
  final String? contextAfter;

  @HiveField(6)
  final int startOffset;

  @HiveField(7)
  final int endOffset;

  @HiveField(8)
  final String? startCFI;

  @HiveField(9)
  final String? endCFI;

  @HiveField(10)
  final HighlightColor color;

  @HiveField(11)
  final String? note;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  final DateTime? updatedAt;

  @HiveField(14)
  final bool isDeleted;

  @HiveField(15)
  final Map<String, dynamic>? metadata;

  const Highlight({
    required this.id,
    required this.chapterIndex,
    this.chapterId,
    required this.selectedText,
    this.contextBefore,
    this.contextAfter,
    required this.startOffset,
    required this.endOffset,
    this.startCFI,
    this.endCFI,
    this.color = HighlightColor.yellow,
    this.note,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.metadata,
  });

  factory Highlight.create({
    required int chapterIndex,
    String? chapterId,
    required String selectedText,
    String? contextBefore,
    String? contextAfter,
    required int startOffset,
    required int endOffset,
    String? startCFI,
    String? endCFI,
    HighlightColor color = HighlightColor.yellow,
    String? note,
  }) {
    return Highlight(
      id: 'highlight_${DateTime.now().millisecondsSinceEpoch}',
      chapterIndex: chapterIndex,
      chapterId: chapterId,
      selectedText: selectedText,
      contextBefore: contextBefore,
      contextAfter: contextAfter,
      startOffset: startOffset,
      endOffset: endOffset,
      startCFI: startCFI,
      endCFI: endCFI,
      color: color,
      note: note,
      createdAt: DateTime.now(),
    );
  }

  factory Highlight.fromJson(Map<String, dynamic> json) {
    return Highlight(
      id: json['id'] as String? ?? '',
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      chapterId: json['chapterId'] as String?,
      selectedText: json['selectedText'] as String? ?? '',
      contextBefore: json['contextBefore'] as String?,
      contextAfter: json['contextAfter'] as String?,
      startOffset: json['startOffset'] as int? ?? 0,
      endOffset: json['endOffset'] as int? ?? 0,
      startCFI: json['startCFI'] as String?,
      endCFI: json['endCFI'] as String?,
      color: HighlightColor.values.firstWhere(
        (e) => e.name == json['color'],
        orElse: () => HighlightColor.yellow,
      ),
      note: json['note'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapterIndex': chapterIndex,
      'chapterId': chapterId,
      'selectedText': selectedText,
      'contextBefore': contextBefore,
      'contextAfter': contextAfter,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'startCFI': startCFI,
      'endCFI': endCFI,
      'color': color.name,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'metadata': metadata,
    };
  }

  Highlight copyWith({
    String? id,
    int? chapterIndex,
    String? chapterId,
    String? selectedText,
    String? contextBefore,
    String? contextAfter,
    int? startOffset,
    int? endOffset,
    String? startCFI,
    String? endCFI,
    HighlightColor? color,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    Map<String, dynamic>? metadata,
  }) {
    return Highlight(
      id: id ?? this.id,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterId: chapterId ?? this.chapterId,
      selectedText: selectedText ?? this.selectedText,
      contextBefore: contextBefore ?? this.contextBefore,
      contextAfter: contextAfter ?? this.contextAfter,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      startCFI: startCFI ?? this.startCFI,
      endCFI: endCFI ?? this.endCFI,
      color: color ?? this.color,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata ?? this.metadata,
    );
  }

  Highlight updateColor(HighlightColor newColor) {
    return copyWith(color: newColor, updatedAt: DateTime.now());
  }

  Highlight updateNote(String newNote) {
    return copyWith(note: newNote, updatedAt: DateTime.now());
  }

  Highlight delete() {
    return copyWith(isDeleted: true, updatedAt: DateTime.now());
  }

  @override
  List<Object?> get props => [
    id,
    chapterIndex,
    startOffset,
    endOffset,
    color,
    isDeleted,
  ];
}

// =============================================================================
// NOTE/ANNOTATION
// =============================================================================

@HiveType(typeId: 14)
class Note extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int chapterIndex;

  @HiveField(2)
  final String? chapterId;

  @HiveField(3)
  final String content;

  @HiveField(4)
  final String? title;

  @HiveField(5)
  final int? characterOffset;

  @HiveField(6)
  final String? cfi;

  @HiveField(7)
  final String? quotedText;

  @HiveField(8)
  final NoteType type;

  @HiveField(9)
  final List<String> tags;

  @HiveField(10)
  final DateTime createdAt;

  @HiveField(11)
  final DateTime? updatedAt;

  @HiveField(12)
  final bool isDeleted;

  @HiveField(13)
  final Map<String, dynamic>? metadata;

  const Note({
    required this.id,
    required this.chapterIndex,
    this.chapterId,
    required this.content,
    this.title,
    this.characterOffset,
    this.cfi,
    this.quotedText,
    this.type = NoteType.note,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.metadata,
  });

  factory Note.create({
    required int chapterIndex,
    String? chapterId,
    required String content,
    String? title,
    int? characterOffset,
    String? cfi,
    String? quotedText,
    NoteType type = NoteType.note,
    List<String>? tags,
  }) {
    return Note(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      chapterIndex: chapterIndex,
      chapterId: chapterId,
      content: content,
      title: title,
      characterOffset: characterOffset,
      cfi: cfi,
      quotedText: quotedText,
      type: type,
      tags: tags ?? [],
      createdAt: DateTime.now(),
    );
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String? ?? '',
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      chapterId: json['chapterId'] as String?,
      content: json['content'] as String? ?? '',
      title: json['title'] as String?,
      characterOffset: json['characterOffset'] as int?,
      cfi: json['cfi'] as String?,
      quotedText: json['quotedText'] as String?,
      type: NoteType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NoteType.note,
      ),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapterIndex': chapterIndex,
      'chapterId': chapterId,
      'content': content,
      'title': title,
      'characterOffset': characterOffset,
      'cfi': cfi,
      'quotedText': quotedText,
      'type': type.name,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'metadata': metadata,
    };
  }

  Note copyWith({
    String? id,
    int? chapterIndex,
    String? chapterId,
    String? content,
    String? title,
    int? characterOffset,
    String? cfi,
    String? quotedText,
    NoteType? type,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    Map<String, dynamic>? metadata,
  }) {
    return Note(
      id: id ?? this.id,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterId: chapterId ?? this.chapterId,
      content: content ?? this.content,
      title: title ?? this.title,
      characterOffset: characterOffset ?? this.characterOffset,
      cfi: cfi ?? this.cfi,
      quotedText: quotedText ?? this.quotedText,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata ?? this.metadata,
    );
  }

  Note updateContent(String newContent) {
    return copyWith(content: newContent, updatedAt: DateTime.now());
  }

  Note addTag(String tag) {
    if (tags.contains(tag)) return this;
    return copyWith(tags: [...tags, tag], updatedAt: DateTime.now());
  }

  Note removeTag(String tag) {
    return copyWith(
      tags: tags.where((t) => t != tag).toList(),
      updatedAt: DateTime.now(),
    );
  }

  Note delete() {
    return copyWith(isDeleted: true, updatedAt: DateTime.now());
  }

  @override
  List<Object?> get props => [id, chapterIndex, content, type, isDeleted];
}

// =============================================================================
// READING SESSION
// =============================================================================

@HiveType(typeId: 15)
class ReadingSession extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime startTime;

  @HiveField(2)
  final DateTime endTime;

  @HiveField(3)
  final int durationSeconds;

  @HiveField(4)
  final int startChapterIndex;

  @HiveField(5)
  final int endChapterIndex;

  @HiveField(6)
  final double progressGained;

  @HiveField(7)
  final int wordsRead;

  @HiveField(8)
  final double averageSpeed;

  @HiveField(9)
  final Map<String, dynamic>? metadata;

  const ReadingSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.startChapterIndex,
    required this.endChapterIndex,
    this.progressGained = 0.0,
    this.wordsRead = 0,
    this.averageSpeed = 0.0,
    this.metadata,
  });

  factory ReadingSession.create({
    required DateTime startTime,
    required DateTime endTime,
    required int startChapterIndex,
    required int endChapterIndex,
    double? progressGained,
    int? wordsRead,
  }) {
    final duration = endTime.difference(startTime).inSeconds;
    final speed = wordsRead != null && duration > 0
        ? (wordsRead / (duration / 60.0))
        : 0.0;

    return ReadingSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      startTime: startTime,
      endTime: endTime,
      durationSeconds: duration,
      startChapterIndex: startChapterIndex,
      endChapterIndex: endChapterIndex,
      progressGained: progressGained ?? 0.0,
      wordsRead: wordsRead ?? 0,
      averageSpeed: speed,
    );
  }

  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    return ReadingSession(
      id: json['id'] as String? ?? '',
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : DateTime.now(),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      startChapterIndex: json['startChapterIndex'] as int? ?? 0,
      endChapterIndex: json['endChapterIndex'] as int? ?? 0,
      progressGained: (json['progressGained'] as num?)?.toDouble() ?? 0.0,
      wordsRead: json['wordsRead'] as int? ?? 0,
      averageSpeed: (json['averageSpeed'] as num?)?.toDouble() ?? 0.0,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationSeconds': durationSeconds,
      'startChapterIndex': startChapterIndex,
      'endChapterIndex': endChapterIndex,
      'progressGained': progressGained,
      'wordsRead': wordsRead,
      'averageSpeed': averageSpeed,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [id, startTime, endTime, durationSeconds];
}

// =============================================================================
// REMAINING ENUMS
// =============================================================================

@HiveType(typeId: 16)
enum HighlightColor {
  @HiveField(0)
  yellow(Color(0xFFFFEB3B)),

  @HiveField(1)
  green(Color(0xFF4CAF50)),

  @HiveField(2)
  blue(Color(0xFF2196F3)),

  @HiveField(3)
  pink(Color(0xFFE91E63)),

  @HiveField(4)
  orange(Color(0xFFFF9800)),

  @HiveField(5)
  purple(Color(0xFF9C27B0)),

  @HiveField(6)
  red(Color(0xFFF44336));

  final Color color;
  const HighlightColor(this.color);
}

@HiveType(typeId: 17)
enum NoteType {
  @HiveField(0)
  note,

  @HiveField(1)
  annotation,

  @HiveField(2)
  question,

  @HiveField(3)
  thought,

  @HiveField(4)
  summary,
}

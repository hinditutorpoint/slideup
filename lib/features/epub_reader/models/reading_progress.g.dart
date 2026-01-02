// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_progress.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReadingProgressAdapter extends TypeAdapter<ReadingProgress> {
  @override
  final int typeId = 11;

  @override
  ReadingProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingProgress(
      id: fields[0] as String,
      bookId: fields[1] as String,
      chapterIndex: fields[2] == null ? 0 : fields[2] as int,
      chapterId: fields[3] as String?,
      chapterProgress: fields[4] == null ? 0.0 : fields[4] as double,
      overallProgress: fields[5] == null ? 0.0 : fields[5] as double,
      currentPage: fields[6] as int?,
      totalPages: fields[7] as int?,
      characterOffset: fields[8] as int?,
      wordOffset: fields[9] as int?,
      bookmarks: fields[10] == null
          ? const []
          : (fields[10] as List).cast<Bookmark>(),
      highlights: fields[11] == null
          ? const []
          : (fields[11] as List).cast<Highlight>(),
      notes: fields[12] == null ? const [] : (fields[12] as List).cast<Note>(),
      sessions: fields[13] == null
          ? const []
          : (fields[13] as List).cast<ReadingSession>(),
      lastCFI: fields[14] as String?,
      totalReadingTimeSeconds: fields[15] == null ? 0 : fields[15] as int,
      averageReadingSpeed: fields[16] == null ? 0.0 : fields[16] as double,
      estimatedTimeRemaining: fields[17] as int?,
      startedAt: fields[18] as DateTime?,
      lastUpdatedAt: fields[19] as DateTime,
      finishedAt: fields[20] as DateTime?,
      isFinished: fields[21] == null ? false : fields[21] as bool,
      readingStreak: fields[22] == null ? 0 : fields[22] as int,
      lastReadDate: fields[23] as DateTime?,
      metadata: (fields[24] as Map?)?.cast<String, dynamic>(),
      textTranslations: fields[25] == null
          ? const []
          : (fields[25] as List).cast<TextTranslation>(),
      chapterTranslations: fields[26] == null
          ? const []
          : (fields[26] as List).cast<ChapterTranslation>(),
      translationSettings: fields[27] as TranslationSettings?,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingProgress obj) {
    writer
      ..writeByte(28)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.chapterIndex)
      ..writeByte(3)
      ..write(obj.chapterId)
      ..writeByte(4)
      ..write(obj.chapterProgress)
      ..writeByte(5)
      ..write(obj.overallProgress)
      ..writeByte(6)
      ..write(obj.currentPage)
      ..writeByte(7)
      ..write(obj.totalPages)
      ..writeByte(8)
      ..write(obj.characterOffset)
      ..writeByte(9)
      ..write(obj.wordOffset)
      ..writeByte(10)
      ..write(obj.bookmarks)
      ..writeByte(11)
      ..write(obj.highlights)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
      ..write(obj.sessions)
      ..writeByte(14)
      ..write(obj.lastCFI)
      ..writeByte(15)
      ..write(obj.totalReadingTimeSeconds)
      ..writeByte(16)
      ..write(obj.averageReadingSpeed)
      ..writeByte(17)
      ..write(obj.estimatedTimeRemaining)
      ..writeByte(18)
      ..write(obj.startedAt)
      ..writeByte(19)
      ..write(obj.lastUpdatedAt)
      ..writeByte(20)
      ..write(obj.finishedAt)
      ..writeByte(21)
      ..write(obj.isFinished)
      ..writeByte(22)
      ..write(obj.readingStreak)
      ..writeByte(23)
      ..write(obj.lastReadDate)
      ..writeByte(24)
      ..write(obj.metadata)
      ..writeByte(25)
      ..write(obj.textTranslations)
      ..writeByte(26)
      ..write(obj.chapterTranslations)
      ..writeByte(27)
      ..write(obj.translationSettings);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BookmarkAdapter extends TypeAdapter<Bookmark> {
  @override
  final int typeId = 12;

  @override
  Bookmark read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bookmark(
      id: fields[0] as String,
      chapterIndex: fields[1] as int,
      chapterId: fields[2] as String?,
      chapterTitle: fields[3] as String?,
      chapterProgress: fields[4] == null ? 0.0 : fields[4] as double,
      characterOffset: fields[5] as int?,
      cfi: fields[6] as String?,
      previewText: fields[7] as String?,
      note: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime?,
      isDeleted: fields[11] == null ? false : fields[11] as bool,
      metadata: (fields[12] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Bookmark obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.chapterIndex)
      ..writeByte(2)
      ..write(obj.chapterId)
      ..writeByte(3)
      ..write(obj.chapterTitle)
      ..writeByte(4)
      ..write(obj.chapterProgress)
      ..writeByte(5)
      ..write(obj.characterOffset)
      ..writeByte(6)
      ..write(obj.cfi)
      ..writeByte(7)
      ..write(obj.previewText)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.isDeleted)
      ..writeByte(12)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HighlightAdapter extends TypeAdapter<Highlight> {
  @override
  final int typeId = 13;

  @override
  Highlight read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Highlight(
      id: fields[0] as String,
      chapterIndex: fields[1] as int,
      chapterId: fields[2] as String?,
      selectedText: fields[3] as String,
      contextBefore: fields[4] as String?,
      contextAfter: fields[5] as String?,
      startOffset: fields[6] as int,
      endOffset: fields[7] as int,
      startCFI: fields[8] as String?,
      endCFI: fields[9] as String?,
      color: fields[10] as HighlightColor,
      note: fields[11] as String?,
      createdAt: fields[12] as DateTime,
      updatedAt: fields[13] as DateTime?,
      isDeleted: fields[14] == null ? false : fields[14] as bool,
      metadata: (fields[15] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Highlight obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.chapterIndex)
      ..writeByte(2)
      ..write(obj.chapterId)
      ..writeByte(3)
      ..write(obj.selectedText)
      ..writeByte(4)
      ..write(obj.contextBefore)
      ..writeByte(5)
      ..write(obj.contextAfter)
      ..writeByte(6)
      ..write(obj.startOffset)
      ..writeByte(7)
      ..write(obj.endOffset)
      ..writeByte(8)
      ..write(obj.startCFI)
      ..writeByte(9)
      ..write(obj.endCFI)
      ..writeByte(10)
      ..write(obj.color)
      ..writeByte(11)
      ..write(obj.note)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(14)
      ..write(obj.isDeleted)
      ..writeByte(15)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 14;

  @override
  Note read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Note(
      id: fields[0] as String,
      chapterIndex: fields[1] as int,
      chapterId: fields[2] as String?,
      content: fields[3] as String,
      title: fields[4] as String?,
      characterOffset: fields[5] as int?,
      cfi: fields[6] as String?,
      quotedText: fields[7] as String?,
      type: fields[8] as NoteType,
      tags: fields[9] == null ? const [] : (fields[9] as List).cast<String>(),
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime?,
      isDeleted: fields[12] == null ? false : fields[12] as bool,
      metadata: (fields[13] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.chapterIndex)
      ..writeByte(2)
      ..write(obj.chapterId)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.characterOffset)
      ..writeByte(6)
      ..write(obj.cfi)
      ..writeByte(7)
      ..write(obj.quotedText)
      ..writeByte(8)
      ..write(obj.type)
      ..writeByte(9)
      ..write(obj.tags)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.isDeleted)
      ..writeByte(13)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReadingSessionAdapter extends TypeAdapter<ReadingSession> {
  @override
  final int typeId = 15;

  @override
  ReadingSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingSession(
      id: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime,
      durationSeconds: fields[3] as int,
      startChapterIndex: fields[4] as int,
      endChapterIndex: fields[5] as int,
      progressGained: fields[6] == null ? 0.0 : fields[6] as double,
      wordsRead: fields[7] == null ? 0 : fields[7] as int,
      averageSpeed: fields[8] == null ? 0.0 : fields[8] as double,
      metadata: (fields[9] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, ReadingSession obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.durationSeconds)
      ..writeByte(4)
      ..write(obj.startChapterIndex)
      ..writeByte(5)
      ..write(obj.endChapterIndex)
      ..writeByte(6)
      ..write(obj.progressGained)
      ..writeByte(7)
      ..write(obj.wordsRead)
      ..writeByte(8)
      ..write(obj.averageSpeed)
      ..writeByte(9)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HighlightColorAdapter extends TypeAdapter<HighlightColor> {
  @override
  final int typeId = 16;

  @override
  HighlightColor read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return HighlightColor.yellow;
      case 1:
        return HighlightColor.green;
      case 2:
        return HighlightColor.blue;
      case 3:
        return HighlightColor.pink;
      case 4:
        return HighlightColor.orange;
      case 5:
        return HighlightColor.purple;
      case 6:
        return HighlightColor.red;
      default:
        return HighlightColor.yellow;
    }
  }

  @override
  void write(BinaryWriter writer, HighlightColor obj) {
    switch (obj) {
      case HighlightColor.yellow:
        writer.writeByte(0);
        break;
      case HighlightColor.green:
        writer.writeByte(1);
        break;
      case HighlightColor.blue:
        writer.writeByte(2);
        break;
      case HighlightColor.pink:
        writer.writeByte(3);
        break;
      case HighlightColor.orange:
        writer.writeByte(4);
        break;
      case HighlightColor.purple:
        writer.writeByte(5);
        break;
      case HighlightColor.red:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightColorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NoteTypeAdapter extends TypeAdapter<NoteType> {
  @override
  final int typeId = 17;

  @override
  NoteType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NoteType.note;
      case 1:
        return NoteType.annotation;
      case 2:
        return NoteType.question;
      case 3:
        return NoteType.thought;
      case 4:
        return NoteType.summary;
      default:
        return NoteType.note;
    }
  }

  @override
  void write(BinaryWriter writer, NoteType obj) {
    switch (obj) {
      case NoteType.note:
        writer.writeByte(0);
        break;
      case NoteType.annotation:
        writer.writeByte(1);
        break;
      case NoteType.question:
        writer.writeByte(2);
        break;
      case NoteType.thought:
        writer.writeByte(3);
        break;
      case NoteType.summary:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TextTranslationAdapter extends TypeAdapter<TextTranslation> {
  @override
  final int typeId = 18;

  @override
  TextTranslation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TextTranslation(
      id: fields[0] as String,
      originalText: fields[1] as String,
      translatedText: fields[2] as String,
      sourceLanguage: fields[3] as String,
      targetLanguage: fields[4] as String,
      chapterIndex: fields[5] as int?,
      chapterId: fields[6] as String?,
      startOffset: fields[7] as int?,
      endOffset: fields[8] as int?,
      context: fields[9] as String?,
      provider: fields[10] as TranslationProvider?,
      confidence: fields[11] as double?,
      alternatives: (fields[12] as List?)?.cast<String>(),
      pronunciation: fields[13] as String?,
      partOfSpeech: fields[14] as String?,
      note: fields[15] as String?,
      createdAt: fields[16] as DateTime,
      updatedAt: fields[17] as DateTime?,
      isDeleted: fields[18] == null ? false : fields[18] as bool,
      isUserEdited: fields[19] == null ? false : fields[19] as bool,
      usageCount: fields[20] == null ? 0 : fields[20] as int,
      lastAccessedAt: fields[21] as DateTime?,
      metadata: (fields[22] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, TextTranslation obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.originalText)
      ..writeByte(2)
      ..write(obj.translatedText)
      ..writeByte(3)
      ..write(obj.sourceLanguage)
      ..writeByte(4)
      ..write(obj.targetLanguage)
      ..writeByte(5)
      ..write(obj.chapterIndex)
      ..writeByte(6)
      ..write(obj.chapterId)
      ..writeByte(7)
      ..write(obj.startOffset)
      ..writeByte(8)
      ..write(obj.endOffset)
      ..writeByte(9)
      ..write(obj.context)
      ..writeByte(10)
      ..write(obj.provider)
      ..writeByte(11)
      ..write(obj.confidence)
      ..writeByte(12)
      ..write(obj.alternatives)
      ..writeByte(13)
      ..write(obj.pronunciation)
      ..writeByte(14)
      ..write(obj.partOfSpeech)
      ..writeByte(15)
      ..write(obj.note)
      ..writeByte(16)
      ..write(obj.createdAt)
      ..writeByte(17)
      ..write(obj.updatedAt)
      ..writeByte(18)
      ..write(obj.isDeleted)
      ..writeByte(19)
      ..write(obj.isUserEdited)
      ..writeByte(20)
      ..write(obj.usageCount)
      ..writeByte(21)
      ..write(obj.lastAccessedAt)
      ..writeByte(22)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextTranslationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChapterTranslationAdapter extends TypeAdapter<ChapterTranslation> {
  @override
  final int typeId = 19;

  @override
  ChapterTranslation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChapterTranslation(
      id: fields[0] as String,
      chapterIndex: fields[1] as int,
      chapterId: fields[2] as String,
      originalTitle: fields[3] as String,
      translatedTitle: fields[4] as String,
      originalContent: fields[5] as String,
      translatedContent: fields[6] as String,
      sourceLanguage: fields[7] as String,
      targetLanguage: fields[8] as String,
      provider: fields[9] as TranslationProvider?,
      originalWordCount: fields[10] == null ? 0 : fields[10] as int,
      translatedWordCount: fields[11] == null ? 0 : fields[11] as int,
      qualityScore: fields[12] as double?,
      isComplete: fields[13] == null ? true : fields[13] as bool,
      completionPercentage: fields[14] == null ? 100.0 : fields[14] as double,
      createdAt: fields[15] as DateTime,
      updatedAt: fields[16] as DateTime?,
      isDeleted: fields[17] == null ? false : fields[17] as bool,
      isUserEdited: fields[18] == null ? false : fields[18] as bool,
      notes: fields[19] as String?,
      metadata: (fields[20] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, ChapterTranslation obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.chapterIndex)
      ..writeByte(2)
      ..write(obj.chapterId)
      ..writeByte(3)
      ..write(obj.originalTitle)
      ..writeByte(4)
      ..write(obj.translatedTitle)
      ..writeByte(5)
      ..write(obj.originalContent)
      ..writeByte(6)
      ..write(obj.translatedContent)
      ..writeByte(7)
      ..write(obj.sourceLanguage)
      ..writeByte(8)
      ..write(obj.targetLanguage)
      ..writeByte(9)
      ..write(obj.provider)
      ..writeByte(10)
      ..write(obj.originalWordCount)
      ..writeByte(11)
      ..write(obj.translatedWordCount)
      ..writeByte(12)
      ..write(obj.qualityScore)
      ..writeByte(13)
      ..write(obj.isComplete)
      ..writeByte(14)
      ..write(obj.completionPercentage)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.updatedAt)
      ..writeByte(17)
      ..write(obj.isDeleted)
      ..writeByte(18)
      ..write(obj.isUserEdited)
      ..writeByte(19)
      ..write(obj.notes)
      ..writeByte(20)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterTranslationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TranslationSettingsAdapter extends TypeAdapter<TranslationSettings> {
  @override
  final int typeId = 20;

  @override
  TranslationSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TranslationSettings(
      preferredLanguage: fields[0] == null ? 'en' : fields[0] as String,
      preferredProvider: fields[1] == null
          ? TranslationProvider.google
          : fields[1] as TranslationProvider,
      autoTranslateOnSelect: fields[2] == null ? false : fields[2] as bool,
      showPronunciation: fields[3] == null ? true : fields[3] as bool,
      showAlternatives: fields[4] == null ? true : fields[4] as bool,
      cacheTranslations: fields[5] == null ? true : fields[5] as bool,
      maxCachedTranslations: fields[6] == null ? 1000 : fields[6] as int,
      autoDetectSource: fields[7] == null ? true : fields[7] as bool,
      defaultSourceLanguage: fields[8] as String?,
      showInlineTranslations: fields[9] == null ? false : fields[9] as bool,
      displayMode: fields[10] == null
          ? TranslationDisplayMode.popup
          : fields[10] as TranslationDisplayMode,
      recentLanguages: fields[11] == null
          ? const []
          : (fields[11] as List).cast<String>(),
      additionalSettings: (fields[12] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, TranslationSettings obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.preferredLanguage)
      ..writeByte(1)
      ..write(obj.preferredProvider)
      ..writeByte(2)
      ..write(obj.autoTranslateOnSelect)
      ..writeByte(3)
      ..write(obj.showPronunciation)
      ..writeByte(4)
      ..write(obj.showAlternatives)
      ..writeByte(5)
      ..write(obj.cacheTranslations)
      ..writeByte(6)
      ..write(obj.maxCachedTranslations)
      ..writeByte(7)
      ..write(obj.autoDetectSource)
      ..writeByte(8)
      ..write(obj.defaultSourceLanguage)
      ..writeByte(9)
      ..write(obj.showInlineTranslations)
      ..writeByte(10)
      ..write(obj.displayMode)
      ..writeByte(11)
      ..write(obj.recentLanguages)
      ..writeByte(12)
      ..write(obj.additionalSettings);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TranslationProviderAdapter extends TypeAdapter<TranslationProvider> {
  @override
  final int typeId = 21;

  @override
  TranslationProvider read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TranslationProvider.google;
      case 1:
        return TranslationProvider.microsoft;
      case 2:
        return TranslationProvider.deepl;
      case 3:
        return TranslationProvider.amazon;
      case 4:
        return TranslationProvider.yandex;
      case 5:
        return TranslationProvider.baidu;
      case 6:
        return TranslationProvider.libre;
      case 7:
        return TranslationProvider.offline;
      case 8:
        return TranslationProvider.manual;
      case 9:
        return TranslationProvider.unknown;
      default:
        return TranslationProvider.google;
    }
  }

  @override
  void write(BinaryWriter writer, TranslationProvider obj) {
    switch (obj) {
      case TranslationProvider.google:
        writer.writeByte(0);
        break;
      case TranslationProvider.microsoft:
        writer.writeByte(1);
        break;
      case TranslationProvider.deepl:
        writer.writeByte(2);
        break;
      case TranslationProvider.amazon:
        writer.writeByte(3);
        break;
      case TranslationProvider.yandex:
        writer.writeByte(4);
        break;
      case TranslationProvider.baidu:
        writer.writeByte(5);
        break;
      case TranslationProvider.libre:
        writer.writeByte(6);
        break;
      case TranslationProvider.offline:
        writer.writeByte(7);
        break;
      case TranslationProvider.manual:
        writer.writeByte(8);
        break;
      case TranslationProvider.unknown:
        writer.writeByte(9);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationProviderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TranslationDisplayModeAdapter
    extends TypeAdapter<TranslationDisplayMode> {
  @override
  final int typeId = 22;

  @override
  TranslationDisplayMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TranslationDisplayMode.popup;
      case 1:
        return TranslationDisplayMode.inline;
      case 2:
        return TranslationDisplayMode.bottomSheet;
      case 3:
        return TranslationDisplayMode.sideBySide;
      case 4:
        return TranslationDisplayMode.overlay;
      default:
        return TranslationDisplayMode.popup;
    }
  }

  @override
  void write(BinaryWriter writer, TranslationDisplayMode obj) {
    switch (obj) {
      case TranslationDisplayMode.popup:
        writer.writeByte(0);
        break;
      case TranslationDisplayMode.inline:
        writer.writeByte(1);
        break;
      case TranslationDisplayMode.bottomSheet:
        writer.writeByte(2);
        break;
      case TranslationDisplayMode.sideBySide:
        writer.writeByte(3);
        break;
      case TranslationDisplayMode.overlay:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationDisplayModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

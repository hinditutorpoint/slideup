// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epub_book.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EpubBookAdapter extends TypeAdapter<EpubBook> {
  @override
  final int typeId = 0;

  @override
  EpubBook read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EpubBook(
      id: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String?,
      publisher: fields[3] as String?,
      publicationDate: fields[4] as DateTime?,
      description: fields[5] as String?,
      language: fields[6] as String?,
      isbn: fields[7] as String?,
      coverPath: fields[8] as String?,
      coverUrl: fields[9] as String?,
      filePath: fields[10] as String?,
      sourceUrl: fields[11] as String?,
      fileSize: fields[12] as int?,
      chapterCount: fields[13] == null ? 0 : fields[13] as int,
      chapters: fields[14] == null
          ? const []
          : (fields[14] as List).cast<EpubChapterMeta>(),
      subjects: fields[15] == null
          ? const []
          : (fields[15] as List).cast<String>(),
      rights: fields[16] as String?,
      epubVersion: fields[17] as String?,
      addedAt: fields[18] as DateTime,
      lastOpenedAt: fields[19] as DateTime?,
      isDownloaded: fields[20] == null ? false : fields[20] as bool,
      isFavorite: fields[21] == null ? false : fields[21] as bool,
      tags: fields[22] == null ? const [] : (fields[22] as List).cast<String>(),
      readingProgress: fields[23] == null ? 0.0 : fields[23] as double,
      currentChapterIndex: fields[24] == null ? 0 : fields[24] as int,
      metadata: (fields[25] as Map?)?.cast<String, String>(),
      tableOfContents: (fields[26] as List?)?.cast<TocEntry>(),
      spine: (fields[27] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, EpubBook obj) {
    writer
      ..writeByte(28)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.publisher)
      ..writeByte(4)
      ..write(obj.publicationDate)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.language)
      ..writeByte(7)
      ..write(obj.isbn)
      ..writeByte(8)
      ..write(obj.coverPath)
      ..writeByte(9)
      ..write(obj.coverUrl)
      ..writeByte(10)
      ..write(obj.filePath)
      ..writeByte(11)
      ..write(obj.sourceUrl)
      ..writeByte(12)
      ..write(obj.fileSize)
      ..writeByte(13)
      ..write(obj.chapterCount)
      ..writeByte(14)
      ..write(obj.chapters)
      ..writeByte(15)
      ..write(obj.subjects)
      ..writeByte(16)
      ..write(obj.rights)
      ..writeByte(17)
      ..write(obj.epubVersion)
      ..writeByte(18)
      ..write(obj.addedAt)
      ..writeByte(19)
      ..write(obj.lastOpenedAt)
      ..writeByte(20)
      ..write(obj.isDownloaded)
      ..writeByte(21)
      ..write(obj.isFavorite)
      ..writeByte(22)
      ..write(obj.tags)
      ..writeByte(23)
      ..write(obj.readingProgress)
      ..writeByte(24)
      ..write(obj.currentChapterIndex)
      ..writeByte(25)
      ..write(obj.metadata)
      ..writeByte(26)
      ..write(obj.tableOfContents)
      ..writeByte(27)
      ..write(obj.spine);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpubBookAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EpubChapterMetaAdapter extends TypeAdapter<EpubChapterMeta> {
  @override
  final int typeId = 1;

  @override
  EpubChapterMeta read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EpubChapterMeta(
      id: fields[0] as String,
      title: fields[1] as String,
      index: fields[2] as int,
      href: fields[3] as String?,
      wordCount: fields[4] as int?,
      estimatedReadingMinutes: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, EpubChapterMeta obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.index)
      ..writeByte(3)
      ..write(obj.href)
      ..writeByte(4)
      ..write(obj.wordCount)
      ..writeByte(5)
      ..write(obj.estimatedReadingMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpubChapterMetaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TocEntryAdapter extends TypeAdapter<TocEntry> {
  @override
  final int typeId = 2;

  @override
  TocEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TocEntry(
      title: fields[0] as String,
      href: fields[1] as String,
      level: fields[2] == null ? 0 : fields[2] as int,
      children: fields[3] == null
          ? const []
          : (fields[3] as List).cast<TocEntry>(),
      anchor: fields[4] as String?,
      playOrder: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TocEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.href)
      ..writeByte(2)
      ..write(obj.level)
      ..writeByte(3)
      ..write(obj.children)
      ..writeByte(4)
      ..write(obj.anchor)
      ..writeByte(5)
      ..write(obj.playOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TocEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

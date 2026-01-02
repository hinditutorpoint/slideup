// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epub_chapter.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EpubChapterAdapter extends TypeAdapter<EpubChapter> {
  @override
  final int typeId = 3;

  @override
  EpubChapter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EpubChapter(
      id: fields[0] as String,
      title: fields[1] as String,
      index: fields[2] as int,
      htmlContent: fields[3] as String?,
      textContent: fields[4] as String?,
      href: fields[5] as String,
      mediaType: fields[6] as String?,
      wordCount: fields[7] == null ? 0 : fields[7] as int,
      characterCount: fields[8] == null ? 0 : fields[8] as int,
      estimatedReadingMinutes: fields[9] == null ? 0 : fields[9] as int,
      images: fields[10] == null
          ? const []
          : (fields[10] as List).cast<ChapterImage>(),
      links: fields[11] == null
          ? const []
          : (fields[11] as List).cast<ChapterLink>(),
      styleSheets: fields[12] == null
          ? const []
          : (fields[12] as List).cast<String>(),
      anchors: fields[13] == null
          ? const []
          : (fields[13] as List).cast<ChapterAnchor>(),
      isLoaded: fields[14] == null ? false : fields[14] as bool,
      bookId: fields[15] as String,
      basePath: fields[16] as String?,
      level: fields[17] == null ? 0 : fields[17] as int,
      playOrder: fields[18] as int?,
      properties: (fields[19] as Map?)?.cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, EpubChapter obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.index)
      ..writeByte(3)
      ..write(obj.htmlContent)
      ..writeByte(4)
      ..write(obj.textContent)
      ..writeByte(5)
      ..write(obj.href)
      ..writeByte(6)
      ..write(obj.mediaType)
      ..writeByte(7)
      ..write(obj.wordCount)
      ..writeByte(8)
      ..write(obj.characterCount)
      ..writeByte(9)
      ..write(obj.estimatedReadingMinutes)
      ..writeByte(10)
      ..write(obj.images)
      ..writeByte(11)
      ..write(obj.links)
      ..writeByte(12)
      ..write(obj.styleSheets)
      ..writeByte(13)
      ..write(obj.anchors)
      ..writeByte(14)
      ..write(obj.isLoaded)
      ..writeByte(15)
      ..write(obj.bookId)
      ..writeByte(16)
      ..write(obj.basePath)
      ..writeByte(17)
      ..write(obj.level)
      ..writeByte(18)
      ..write(obj.playOrder)
      ..writeByte(19)
      ..write(obj.properties);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpubChapterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChapterImageAdapter extends TypeAdapter<ChapterImage> {
  @override
  final int typeId = 4;

  @override
  ChapterImage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChapterImage(
      id: fields[0] as String,
      src: fields[1] as String,
      alt: fields[2] as String?,
      title: fields[3] as String?,
      width: fields[4] as int?,
      height: fields[5] as int?,
      mimeType: fields[6] as String?,
      localPath: fields[7] as String?,
      isCover: fields[8] == null ? false : fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ChapterImage obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.src)
      ..writeByte(2)
      ..write(obj.alt)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.width)
      ..writeByte(5)
      ..write(obj.height)
      ..writeByte(6)
      ..write(obj.mimeType)
      ..writeByte(7)
      ..write(obj.localPath)
      ..writeByte(8)
      ..write(obj.isCover);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterImageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChapterLinkAdapter extends TypeAdapter<ChapterLink> {
  @override
  final int typeId = 5;

  @override
  ChapterLink read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChapterLink(
      href: fields[0] as String,
      text: fields[1] as String?,
      type: fields[2] as LinkType,
      targetChapterId: fields[3] as String?,
      anchor: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChapterLink obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.href)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.targetChapterId)
      ..writeByte(4)
      ..write(obj.anchor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterLinkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LinkTypeAdapter extends TypeAdapter<LinkType> {
  @override
  final int typeId = 6;

  @override
  LinkType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return LinkType.internal;
      case 1:
        return LinkType.external;
      case 2:
        return LinkType.footnote;
      case 3:
        return LinkType.endnote;
      case 4:
        return LinkType.image;
      case 5:
        return LinkType.unknown;
      default:
        return LinkType.internal;
    }
  }

  @override
  void write(BinaryWriter writer, LinkType obj) {
    switch (obj) {
      case LinkType.internal:
        writer.writeByte(0);
        break;
      case LinkType.external:
        writer.writeByte(1);
        break;
      case LinkType.footnote:
        writer.writeByte(2);
        break;
      case LinkType.endnote:
        writer.writeByte(3);
        break;
      case LinkType.image:
        writer.writeByte(4);
        break;
      case LinkType.unknown:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChapterAnchorAdapter extends TypeAdapter<ChapterAnchor> {
  @override
  final int typeId = 7;

  @override
  ChapterAnchor read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChapterAnchor(
      id: fields[0] as String,
      title: fields[1] as String?,
      position: fields[2] as int?,
      type: fields[3] as AnchorType,
    );
  }

  @override
  void write(BinaryWriter writer, ChapterAnchor obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.position)
      ..writeByte(3)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterAnchorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AnchorTypeAdapter extends TypeAdapter<AnchorType> {
  @override
  final int typeId = 8;

  @override
  AnchorType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AnchorType.generic;
      case 1:
        return AnchorType.heading;
      case 2:
        return AnchorType.footnote;
      case 3:
        return AnchorType.bookmark;
      case 4:
        return AnchorType.highlight;
      default:
        return AnchorType.generic;
    }
  }

  @override
  void write(BinaryWriter writer, AnchorType obj) {
    switch (obj) {
      case AnchorType.generic:
        writer.writeByte(0);
        break;
      case AnchorType.heading:
        writer.writeByte(1);
        break;
      case AnchorType.footnote:
        writer.writeByte(2);
        break;
      case AnchorType.bookmark:
        writer.writeByte(3);
        break;
      case AnchorType.highlight:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnchorTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

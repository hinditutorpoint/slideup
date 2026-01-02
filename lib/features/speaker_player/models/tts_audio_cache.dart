import 'package:hive_flutter/hive_flutter.dart';

/// Cached TTS audio entry
class TtsAudioCache extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String textHash;

  @HiveField(2)
  final String text;

  @HiveField(3)
  final String modelId;

  @HiveField(4)
  final String filePath;

  @HiveField(5)
  final int durationMs;

  @HiveField(6)
  final double speed;

  @HiveField(7)
  final int speakerId;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final DateTime lastUsedAt;

  @HiveField(10)
  final int fileSize;

  @HiveField(11)
  final String? bookId;

  @HiveField(12)
  final int? pageNumber;

  TtsAudioCache({
    required this.id,
    required this.textHash,
    required this.text,
    required this.modelId,
    required this.filePath,
    required this.durationMs,
    this.speed = 1.0,
    this.speakerId = 0,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    this.fileSize = 0,
    this.bookId,
    this.pageNumber,
  }) : createdAt = createdAt ?? DateTime.now(),
       lastUsedAt = lastUsedAt ?? DateTime.now();

  Duration get duration => Duration(milliseconds: durationMs);

  String get textPreview =>
      text.length > 100 ? '${text.substring(0, 100)}...' : text;

  TtsAudioCache copyWith({
    String? id,
    String? textHash,
    String? text,
    String? modelId,
    String? filePath,
    int? durationMs,
    double? speed,
    int? speakerId,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int? fileSize,
    String? bookId,
    int? pageNumber,
  }) {
    return TtsAudioCache(
      id: id ?? this.id,
      textHash: textHash ?? this.textHash,
      text: text ?? this.text,
      modelId: modelId ?? this.modelId,
      filePath: filePath ?? this.filePath,
      durationMs: durationMs ?? this.durationMs,
      speed: speed ?? this.speed,
      speakerId: speakerId ?? this.speakerId,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      fileSize: fileSize ?? this.fileSize,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
    );
  }
}

// Hive Adapter
class TtsAudioCacheAdapter extends TypeAdapter<TtsAudioCache> {
  @override
  final int typeId = 26; // Unique ID

  @override
  TtsAudioCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TtsAudioCache(
      id: fields[0] as String,
      textHash: fields[1] as String,
      text: fields[2] as String,
      modelId: fields[3] as String,
      filePath: fields[4] as String,
      durationMs: fields[5] as int,
      speed: fields[6] as double? ?? 1.0,
      speakerId: fields[7] as int? ?? 0,
      createdAt: fields[8] as DateTime?,
      lastUsedAt: fields[9] as DateTime?,
      fileSize: fields[10] as int? ?? 0,
      bookId: fields[11] as String?,
      pageNumber: fields[12] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TtsAudioCache obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.textHash)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.modelId)
      ..writeByte(4)
      ..write(obj.filePath)
      ..writeByte(5)
      ..write(obj.durationMs)
      ..writeByte(6)
      ..write(obj.speed)
      ..writeByte(7)
      ..write(obj.speakerId)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.lastUsedAt)
      ..writeByte(10)
      ..write(obj.fileSize)
      ..writeByte(11)
      ..write(obj.bookId)
      ..writeByte(12)
      ..write(obj.pageNumber);
  }
}

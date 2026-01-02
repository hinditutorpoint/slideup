// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadStatusAdapter extends TypeAdapter<DownloadStatus> {
  @override
  final int typeId = 10;

  @override
  DownloadStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DownloadStatus.idle;
      case 1:
        return DownloadStatus.queued;
      case 2:
        return DownloadStatus.downloading;
      case 3:
        return DownloadStatus.paused;
      case 4:
        return DownloadStatus.completed;
      case 5:
        return DownloadStatus.failed;
      case 6:
        return DownloadStatus.cancelled;
      default:
        return DownloadStatus.idle;
    }
  }

  @override
  void write(BinaryWriter writer, DownloadStatus obj) {
    switch (obj) {
      case DownloadStatus.idle:
        writer.writeByte(0);
        break;
      case DownloadStatus.queued:
        writer.writeByte(1);
        break;
      case DownloadStatus.downloading:
        writer.writeByte(2);
        break;
      case DownloadStatus.paused:
        writer.writeByte(3);
        break;
      case DownloadStatus.completed:
        writer.writeByte(4);
        break;
      case DownloadStatus.failed:
        writer.writeByte(5);
        break;
      case DownloadStatus.cancelled:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadTaskAdapter extends TypeAdapter<DownloadTask> {
  @override
  final int typeId = 9;

  @override
  DownloadTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadTask(
      id: fields[0] as String,
      bookId: fields[1] as String,
      url: fields[2] as String,
      localPath: fields[3] as String?,
      fileName: fields[4] as String,
      status: fields[5] as DownloadStatus,
      downloadedBytes: fields[6] == null ? 0 : fields[6] as int,
      totalBytes: fields[7] == null ? 0 : fields[7] as int,
      progress: fields[8] == null ? 0.0 : fields[8] as double,
      speedBytesPerSecond: fields[9] == null ? 0 : fields[9] as int,
      createdAt: fields[10] as DateTime,
      startedAt: fields[11] as DateTime?,
      completedAt: fields[12] as DateTime?,
      pausedAt: fields[13] as DateTime?,
      errorMessage: fields[14] as String?,
      errorCode: fields[15] as String?,
      retryCount: fields[16] == null ? 0 : fields[16] as int,
      maxRetries: fields[17] == null ? 3 : fields[17] as int,
      priority: fields[18] == null ? 0 : fields[18] as int,
      headers: (fields[19] as Map?)?.cast<String, String>(),
      resumeData: fields[20] as String?,
      supportsResume: fields[21] == null ? true : fields[21] as bool,
      etag: fields[22] as String?,
      lastModified: fields[23] as DateTime?,
      notificationId: fields[24] as int?,
      isBackground: fields[25] == null ? false : fields[25] as bool,
      metadata: (fields[26] as Map?)?.cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DownloadTask obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.localPath)
      ..writeByte(4)
      ..write(obj.fileName)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.downloadedBytes)
      ..writeByte(7)
      ..write(obj.totalBytes)
      ..writeByte(8)
      ..write(obj.progress)
      ..writeByte(9)
      ..write(obj.speedBytesPerSecond)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.startedAt)
      ..writeByte(12)
      ..write(obj.completedAt)
      ..writeByte(13)
      ..write(obj.pausedAt)
      ..writeByte(14)
      ..write(obj.errorMessage)
      ..writeByte(15)
      ..write(obj.errorCode)
      ..writeByte(16)
      ..write(obj.retryCount)
      ..writeByte(17)
      ..write(obj.maxRetries)
      ..writeByte(18)
      ..write(obj.priority)
      ..writeByte(19)
      ..write(obj.headers)
      ..writeByte(20)
      ..write(obj.resumeData)
      ..writeByte(21)
      ..write(obj.supportsResume)
      ..writeByte(22)
      ..write(obj.etag)
      ..writeByte(23)
      ..write(obj.lastModified)
      ..writeByte(24)
      ..write(obj.notificationId)
      ..writeByte(25)
      ..write(obj.isBackground)
      ..writeByte(26)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

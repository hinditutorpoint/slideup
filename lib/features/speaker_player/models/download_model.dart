import 'package:hive_flutter/hive_flutter.dart';

enum ModelDownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
  extracting,
}

enum SherpaModelType {
  tts,
  stt,
  vad,
  speakerIdentification,
  languageIdentification,
}

// ============================================================================
// MODEL CLASS
// ============================================================================

class DownloadedModel extends HiveObject {
  final String id;
  final String name;
  String url;
  String localPath;
  ModelDownloadStatus status;
  double progress;
  int totalBytes;
  int downloadedBytes;
  final SherpaModelType modelType;
  final String language;
  final String? description;
  DateTime? downloadedAt;
  DateTime? lastUsedAt;
  String? errorMessage;
  final int version;
  final String? checksum;
  final Map<String, String>? modelFiles;

  bool isActive;
  final bool isLocal;
  final String? sourcePath;

  DownloadedModel({
    required this.id,
    required this.name,
    this.url = '',
    this.localPath = '',
    this.status = ModelDownloadStatus.pending,
    this.progress = 0.0,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    required this.modelType,
    required this.language,
    this.description,
    this.downloadedAt,
    this.lastUsedAt,
    this.errorMessage,
    this.version = 1,
    this.checksum,
    this.modelFiles,
    this.isActive = false, // NEW
    this.isLocal = false,
    this.sourcePath,
  });

  // Computed properties
  bool get isDownloaded => status == ModelDownloadStatus.completed;
  bool get isDownloading => status == ModelDownloadStatus.downloading;
  bool get isPaused => status == ModelDownloadStatus.paused;
  bool get isFailed => status == ModelDownloadStatus.failed;
  bool get isExtracting => status == ModelDownloadStatus.extracting;
  bool get canResume => isPaused || isFailed;
  bool get canPause => isDownloading;
  bool get canCancel => isDownloading || isPaused;

  String get progressText => '${(progress * 100).toStringAsFixed(1)}%';

  String get sizeText {
    if (totalBytes == 0) return 'Unknown size';
    return '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  DownloadedModel copyWith({
    String? id,
    String? name,
    String? url,
    String? localPath,
    ModelDownloadStatus? status,
    double? progress,
    int? totalBytes,
    int? downloadedBytes,
    SherpaModelType? modelType,
    String? language,
    String? description,
    DateTime? downloadedAt,
    DateTime? lastUsedAt,
    String? errorMessage,
    int? version,
    String? checksum,
    Map<String, String>? modelFiles,
    bool? isActive,
    bool? isLocal,
    String? sourcePath,
  }) {
    return DownloadedModel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      modelType: modelType ?? this.modelType,
      language: language ?? this.language,
      description: description ?? this.description,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      version: version ?? this.version,
      checksum: checksum ?? this.checksum,
      modelFiles: modelFiles ?? this.modelFiles,
      isActive: isActive ?? this.isActive,
      isLocal: isLocal ?? this.isLocal,
      sourcePath: sourcePath ?? this.sourcePath,
    );
  }

  factory DownloadedModel.fromLocalImport({
    required String name,
    required SherpaModelType modelType,
    required String language,
    required String localPath,
    required int sizeBytes,
    String? description,
    String? sourcePath,
    Map<String, String>? modelFiles,
  }) {
    return DownloadedModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode.abs()}',
      name: name,
      url: '', // No URL for local imports
      localPath: localPath,
      status: ModelDownloadStatus.completed,
      progress: 1.0,
      totalBytes: sizeBytes,
      downloadedBytes: sizeBytes,
      modelType: modelType,
      language: language,
      description: description,
      downloadedAt: DateTime.now(),
      isLocal: true,
      sourcePath: sourcePath,
      modelFiles: modelFiles,
    );
  }

  @override
  String toString() =>
      'DownloadedModel(id: $id, name: $name, status: $status, isActive: $isActive)';
}

// ============================================================================
// HIVE ADAPTERS
// ============================================================================

class ModelDownloadStatusAdapter extends TypeAdapter<ModelDownloadStatus> {
  @override
  final int typeId = 23;

  @override
  ModelDownloadStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ModelDownloadStatus.pending;
      case 1:
        return ModelDownloadStatus.downloading;
      case 2:
        return ModelDownloadStatus.paused;
      case 3:
        return ModelDownloadStatus.completed;
      case 4:
        return ModelDownloadStatus.failed;
      case 5:
        return ModelDownloadStatus.cancelled;
      case 6:
        return ModelDownloadStatus.extracting;
      default:
        return ModelDownloadStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, ModelDownloadStatus obj) {
    switch (obj) {
      case ModelDownloadStatus.pending:
        writer.writeByte(0);
        break;
      case ModelDownloadStatus.downloading:
        writer.writeByte(1);
        break;
      case ModelDownloadStatus.paused:
        writer.writeByte(2);
        break;
      case ModelDownloadStatus.completed:
        writer.writeByte(3);
        break;
      case ModelDownloadStatus.failed:
        writer.writeByte(4);
        break;
      case ModelDownloadStatus.cancelled:
        writer.writeByte(5);
        break;
      case ModelDownloadStatus.extracting:
        writer.writeByte(6);
        break;
    }
  }
}

class SherpaModelTypeAdapter extends TypeAdapter<SherpaModelType> {
  @override
  final int typeId = 24;

  @override
  SherpaModelType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SherpaModelType.tts;
      case 1:
        return SherpaModelType.stt;
      case 2:
        return SherpaModelType.vad;
      case 3:
        return SherpaModelType.speakerIdentification;
      case 4:
        return SherpaModelType.languageIdentification;
      default:
        return SherpaModelType.tts;
    }
  }

  @override
  void write(BinaryWriter writer, SherpaModelType obj) {
    switch (obj) {
      case SherpaModelType.tts:
        writer.writeByte(0);
        break;
      case SherpaModelType.stt:
        writer.writeByte(1);
        break;
      case SherpaModelType.vad:
        writer.writeByte(2);
        break;
      case SherpaModelType.speakerIdentification:
        writer.writeByte(3);
        break;
      case SherpaModelType.languageIdentification:
        writer.writeByte(4);
        break;
    }
  }
}

class DownloadedModelAdapter extends TypeAdapter<DownloadedModel> {
  @override
  final int typeId = 25;

  @override
  DownloadedModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadedModel(
      id: fields[0] as String,
      name: fields[1] as String,
      url: fields[2] as String,
      localPath: fields[3] as String? ?? '',
      status: fields[4] as ModelDownloadStatus? ?? ModelDownloadStatus.pending,
      progress: fields[5] as double? ?? 0.0,
      totalBytes: fields[6] as int? ?? 0,
      downloadedBytes: fields[7] as int? ?? 0,
      modelType: fields[8] as SherpaModelType,
      language: fields[9] as String,
      description: fields[10] as String?,
      downloadedAt: fields[11] as DateTime?,
      lastUsedAt: fields[12] as DateTime?,
      errorMessage: fields[13] as String?,
      version: fields[14] as int? ?? 1,
      checksum: fields[15] as String?,
      modelFiles: (fields[16] as Map?)?.cast<String, String>(),
      isActive: fields[17] as bool? ?? false, // NEW
      isLocal: fields[18] as bool? ?? false,
      sourcePath: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadedModel obj) {
    writer
      ..writeByte(20) // Updated field count: 18 -> 20
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.localPath)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.progress)
      ..writeByte(6)
      ..write(obj.totalBytes)
      ..writeByte(7)
      ..write(obj.downloadedBytes)
      ..writeByte(8)
      ..write(obj.modelType)
      ..writeByte(9)
      ..write(obj.language)
      ..writeByte(10)
      ..write(obj.description)
      ..writeByte(11)
      ..write(obj.downloadedAt)
      ..writeByte(12)
      ..write(obj.lastUsedAt)
      ..writeByte(13)
      ..write(obj.errorMessage)
      ..writeByte(14)
      ..write(obj.version)
      ..writeByte(15)
      ..write(obj.checksum)
      ..writeByte(16)
      ..write(obj.modelFiles)
      ..writeByte(17)
      ..write(obj.isActive)
      ..writeByte(18) // NEW
      ..write(obj.isLocal)
      ..writeByte(19) // NEW
      ..write(obj.sourcePath);
  }
}

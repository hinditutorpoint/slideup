import 'package:equatable/equatable.dart';

enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class DownloadTask extends Equatable {
  final String id;
  final String identifier;
  final String title;
  final String url;
  final String fileName;
  final String? filePath;
  final String? thumbnailUrl;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String mediaType;

  const DownloadTask({
    required this.id,
    required this.identifier,
    required this.title,
    required this.url,
    required this.fileName,
    this.filePath,
    this.thumbnailUrl,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.pending,
    this.error,
    required this.createdAt,
    this.completedAt,
    required this.mediaType,
  });

  double get progress {
    if (totalBytes == 0) return 0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).toInt();

  bool get isActive =>
      status == DownloadStatus.downloading || status == DownloadStatus.pending;

  bool get canResume =>
      status == DownloadStatus.paused || status == DownloadStatus.failed;

  bool get canPause => status == DownloadStatus.downloading;

  bool get canCancel => isActive || status == DownloadStatus.paused;

  String get formattedSize {
    if (totalBytes <= 0) return 'Unknown';
    return _formatBytes(totalBytes);
  }

  String get formattedDownloaded {
    return _formatBytes(downloadedBytes);
  }

  String get formattedProgress {
    return '$formattedDownloaded / $formattedSize';
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var suffixIndex = 0;
    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }

  DownloadTask copyWith({
    String? id,
    String? identifier,
    String? title,
    String? url,
    String? fileName,
    String? filePath,
    String? thumbnailUrl,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    String? error,
    DateTime? createdAt,
    DateTime? completedAt,
    String? mediaType,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      identifier: identifier ?? this.identifier,
      title: title ?? this.title,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      mediaType: mediaType ?? this.mediaType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'identifier': identifier,
      'title': title,
      'url': url,
      'file_name': fileName,
      'file_path': filePath,
      'thumbnail_url': thumbnailUrl,
      'total_bytes': totalBytes,
      'downloaded_bytes': downloadedBytes,
      'status': status.index,
      'error': error,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'media_type': mediaType,
    };
  }

  factory DownloadTask.fromMap(Map<String, dynamic> map) {
    return DownloadTask(
      id: map['id'] ?? '',
      identifier: map['identifier'] ?? '',
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      fileName: map['file_name'] ?? '',
      filePath: map['file_path'],
      thumbnailUrl: map['thumbnail_url'],
      totalBytes: map['total_bytes'] ?? 0,
      downloadedBytes: map['downloaded_bytes'] ?? 0,
      status: DownloadStatus.values[map['status'] ?? 0],
      error: map['error'],
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'])
          : null,
      mediaType: map['media_type'] ?? '',
    );
  }

  @override
  List<Object?> get props => [
    id,
    identifier,
    title,
    url,
    fileName,
    filePath,
    thumbnailUrl,
    totalBytes,
    downloadedBytes,
    status,
    error,
    createdAt,
    completedAt,
    mediaType,
  ];
}

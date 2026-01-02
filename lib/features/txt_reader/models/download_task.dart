import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Download Status Enum
enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Download Task Model
class DownloadTask {
  final String id;
  final String url;
  final String fileName;
  String title;
  String? localPath;
  DownloadStatus status;
  double progress;
  int downloadedBytes;
  int totalBytes;
  String? error;
  DateTime createdAt;
  DateTime? completedAt;
  CancelToken? cancelToken;
  bool isPaused;

  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this.title,
    this.localPath,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.error,
    DateTime? createdAt,
    this.completedAt,
    this.cancelToken,
    this.isPaused = false,
  }) : createdAt = createdAt ?? DateTime.now();

  DownloadTask copyWith({
    String? id,
    String? url,
    String? fileName,
    String? localPath,
    String? title,
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? error,
    DateTime? createdAt,
    DateTime? completedAt,
    CancelToken? cancelToken,
    bool? isPaused,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
      title: title ?? this.title,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      cancelToken: cancelToken ?? this.cancelToken,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  String get fileExtension {
    try {
      final ext = fileName.split('.').last.toLowerCase();
      return ext.isNotEmpty ? ext : 'txt';
    } catch (_) {
      return 'txt';
    }
  }

  IconData get fileIcon {
    switch (fileExtension) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'epub':
        return Icons.auto_stories_rounded;
      case 'txt':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get fileColor {
    switch (fileExtension) {
      case 'pdf':
        return Colors.red;
      case 'epub':
        return Colors.purple;
      case 'txt':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

/// Reading Stats Model
class ReadingStats {
  final int totalBooks;
  final int booksRead;
  final int pagesRead;
  final int currentStreak;
  final Map<String, double> progressByBook;

  const ReadingStats({
    this.totalBooks = 0,
    this.booksRead = 0,
    this.pagesRead = 0,
    this.currentStreak = 0,
    this.progressByBook = const {},
  });
}

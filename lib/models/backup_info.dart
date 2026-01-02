import 'dart:io';

class BackupInfo {
  final String fileName;
  final String filePath;
  final DateTime createdAt;
  final int sizeInBytes;
  final BackupType type;
  final List<String>? includedDatabases;

  BackupInfo({
    required this.fileName,
    required this.filePath,
    required this.createdAt,
    required this.sizeInBytes,
    this.type = BackupType.single,
    this.includedDatabases,
  });

  String get formattedSize {
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  bool get isZipBackup => fileName.endsWith('.zip');

  static Future<BackupInfo> fromFile(File file, {BackupType? type}) async {
    final stat = await file.stat();
    return BackupInfo(
      fileName: file.path.split('/').last,
      filePath: file.path,
      createdAt: stat.modified,
      sizeInBytes: stat.size,
      type:
          type ??
          (file.path.endsWith('.zip')
              ? BackupType.combined
              : BackupType.single),
    );
  }
}

enum BackupType {
  single, // Single database backup
  combined, // Multiple databases in zip
}

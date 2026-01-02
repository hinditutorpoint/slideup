import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/backup_info.dart';

enum BackupResult {
  success,
  permissionDenied,
  databaseNotFound,
  fileNotFound,
  invalidBackup,
  error,
}

class BackupResponse {
  final BackupResult result;
  final String? message;
  final String? filePath;

  BackupResponse({required this.result, this.message, this.filePath});

  bool get isSuccess => result == BackupResult.success;
}

class DatabaseBackupService {
  static DatabaseBackupService? _instance;

  // Your database name
  final String databaseName;

  // Backup folder name
  final String backupFolderName;

  DatabaseBackupService._({
    required this.databaseName,
    this.backupFolderName = 'database_backups',
  });

  factory DatabaseBackupService({
    required String databaseName,
    String backupFolderName = 'database_backups',
  }) {
    _instance ??= DatabaseBackupService._(
      databaseName: databaseName,
      backupFolderName: backupFolderName,
    );
    return _instance!;
  }

  /// Get the database file path
  Future<String> get _databasePath async {
    final dbPath = await getDatabasesPath();
    return path.join(dbPath, databaseName);
  }

  /// Get the backup directory
  Future<Directory> get _backupDirectory async {
    Directory baseDir;

    if (Platform.isAndroid) {
      // Use external storage on Android for user access
      baseDir =
          (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final backupDir = Directory(path.join(baseDir.path, backupFolderName));

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    return backupDir;
  }

  /// Check and request storage permissions
  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we don't need storage permission for app-specific directories
      if (await Permission.storage.isGranted) {
        return true;
      }

      // For older Android versions
      final status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      }

      // Try manage external storage for Android 11+
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      final manageStatus = await Permission.manageExternalStorage.request();
      return manageStatus.isGranted;
    }

    return true; // iOS doesn't need explicit storage permission for app documents
  }

  /// Generate backup file name with timestamp
  String _generateBackupFileName() {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dbNameWithoutExtension = path.basenameWithoutExtension(databaseName);
    return '${dbNameWithoutExtension}_backup_$timestamp.db';
  }

  /// Create a backup of the database
  Future<BackupResponse> createBackup({String? customFileName}) async {
    try {
      // Check permissions
      if (!await _checkPermissions()) {
        return BackupResponse(
          result: BackupResult.permissionDenied,
          message: 'Storage permission denied',
        );
      }

      // Get database path
      final dbPath = await _databasePath;
      final dbFile = File(dbPath);

      // Check if database exists
      if (!await dbFile.exists()) {
        return BackupResponse(
          result: BackupResult.databaseNotFound,
          message: 'Database file not found',
        );
      }

      // Close database connection before backup
      await _closeDatabase();

      // Get backup directory
      final backupDir = await _backupDirectory;

      // Generate backup file name
      final backupFileName = customFileName ?? _generateBackupFileName();
      final backupPath = path.join(backupDir.path, backupFileName);

      // Copy database to backup location
      await dbFile.copy(backupPath);

      // Verify backup was created
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        return BackupResponse(
          result: BackupResult.error,
          message: 'Failed to create backup file',
        );
      }

      return BackupResponse(
        result: BackupResult.success,
        message: 'Backup created successfully',
        filePath: backupPath,
      );
    } catch (e) {
      debugPrint('Backup error: $e');
      return BackupResponse(
        result: BackupResult.error,
        message: 'Error creating backup: ${e.toString()}',
      );
    }
  }

  /// Restore database from a backup file path
  Future<BackupResponse> restoreFromPath(String backupFilePath) async {
    try {
      // Check permissions
      if (!await _checkPermissions()) {
        return BackupResponse(
          result: BackupResult.permissionDenied,
          message: 'Storage permission denied',
        );
      }

      final backupFile = File(backupFilePath);

      // Check if backup file exists
      if (!await backupFile.exists()) {
        return BackupResponse(
          result: BackupResult.fileNotFound,
          message: 'Backup file not found',
        );
      }

      // Validate backup file (basic check)
      if (!await _isValidSQLiteFile(backupFile)) {
        return BackupResponse(
          result: BackupResult.invalidBackup,
          message: 'Invalid SQLite database file',
        );
      }

      // Close database connection before restore
      await _closeDatabase();

      // Get database path
      final dbPath = await _databasePath;
      final dbFile = File(dbPath);

      // Create backup of current database before restoring (safety measure)
      if (await dbFile.exists()) {
        final tempBackupPath = '$dbPath.temp_backup';
        await dbFile.copy(tempBackupPath);
      }

      // Delete current database
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // Copy backup to database location
      await backupFile.copy(dbPath);

      // Verify restoration
      final restoredFile = File(dbPath);
      if (!await restoredFile.exists()) {
        return BackupResponse(
          result: BackupResult.error,
          message: 'Failed to restore database',
        );
      }

      // Delete temp backup
      final tempBackupFile = File('$dbPath.temp_backup');
      if (await tempBackupFile.exists()) {
        await tempBackupFile.delete();
      }

      return BackupResponse(
        result: BackupResult.success,
        message: 'Database restored successfully',
      );
    } catch (e) {
      debugPrint('Restore error: $e');
      return BackupResponse(
        result: BackupResult.error,
        message: 'Error restoring database: ${e.toString()}',
      );
    }
  }

  /// Restore from file picker
  Future<BackupResponse> restoreFromFilePicker() async {
    try {
      // Pick a file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return BackupResponse(
          result: BackupResult.error,
          message: 'No file selected',
        );
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        return BackupResponse(
          result: BackupResult.error,
          message: 'Invalid file path',
        );
      }

      return await restoreFromPath(filePath);
    } catch (e) {
      debugPrint('File picker error: $e');
      return BackupResponse(
        result: BackupResult.error,
        message: 'Error picking file: ${e.toString()}',
      );
    }
  }

  /// Get list of available backups
  Future<List<BackupInfo>> getBackupsList() async {
    try {
      final backupDir = await _backupDirectory;

      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.db'))
          .cast<File>()
          .toList();

      final backups = await Future.wait(
        files.map((file) => BackupInfo.fromFile(file)),
      );

      // Sort by date, newest first
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return backups;
    } catch (e) {
      debugPrint('Error getting backups list: $e');
      return [];
    }
  }

  /// Delete a specific backup
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }

  /// Delete all backups
  Future<bool> deleteAllBackups() async {
    try {
      final backupDir = await _backupDirectory;
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
        await backupDir.create();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting all backups: $e');
      return false;
    }
  }

  /// Get backup directory path
  Future<String> getBackupDirectoryPath() async {
    final dir = await _backupDirectory;
    return dir.path;
  }

  /// Validate SQLite file
  Future<bool> _isValidSQLiteFile(File file) async {
    try {
      final bytes = await file.openRead(0, 16).first;
      // SQLite files start with "SQLite format 3"
      final header = String.fromCharCodes(bytes.take(15));
      return header == 'SQLite format 3';
    } catch (e) {
      return false;
    }
  }

  /// Close database connection
  Future<void> _closeDatabase() async {
    try {
      final dbPath = await _databasePath;
      final db = await openDatabase(dbPath);
      await db.close();
    } catch (e) {
      debugPrint('Error closing database: $e');
    }
  }

  /// Export backup to custom location
  Future<BackupResponse> exportBackupToCustomLocation() async {
    try {
      // First create a backup
      final backupResponse = await createBackup();

      if (!backupResponse.isSuccess || backupResponse.filePath == null) {
        return backupResponse;
      }

      // Let user pick a directory (only available on some platforms)
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        return BackupResponse(
          result: BackupResult.error,
          message: 'No directory selected',
        );
      }

      final backupFile = File(backupResponse.filePath!);
      final fileName = path.basename(backupResponse.filePath!);
      final newPath = path.join(selectedDirectory, fileName);

      await backupFile.copy(newPath);

      return BackupResponse(
        result: BackupResult.success,
        message: 'Backup exported successfully',
        filePath: newPath,
      );
    } catch (e) {
      debugPrint('Export error: $e');
      return BackupResponse(
        result: BackupResult.error,
        message: 'Error exporting backup: ${e.toString()}',
      );
    }
  }

  /// Auto backup with retention policy
  Future<BackupResponse> createAutoBackup({int maxBackups = 5}) async {
    try {
      // Create new backup
      final response = await createBackup();

      if (!response.isSuccess) {
        return response;
      }

      // Apply retention policy
      final backups = await getBackupsList();
      if (backups.length > maxBackups) {
        // Delete oldest backups
        final backupsToDelete = backups.skip(maxBackups);
        for (final backup in backupsToDelete) {
          await deleteBackup(backup.filePath);
        }
      }

      return response;
    } catch (e) {
      return BackupResponse(
        result: BackupResult.error,
        message: 'Error creating auto backup: ${e.toString()}',
      );
    }
  }
}

import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/backup_info.dart';
import '../models/database_config.dart';

enum BackupResult {
  success,
  partialSuccess,
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
  final Map<String, bool>? databaseResults;

  BackupResponse({
    required this.result,
    this.message,
    this.filePath,
    this.databaseResults,
  });

  bool get isSuccess => result == BackupResult.success;
  bool get isPartialSuccess => result == BackupResult.partialSuccess;
}

class MultiDatabaseBackupService {
  static MultiDatabaseBackupService? _instance;

  final List<DatabaseConfig> databases;
  final String backupFolderName;

  MultiDatabaseBackupService._({
    required this.databases,
    this.backupFolderName = 'database_backups',
  });

  factory MultiDatabaseBackupService({
    required List<DatabaseConfig> databases,
    String backupFolderName = 'database_backups',
  }) {
    _instance ??= MultiDatabaseBackupService._(
      databases: databases,
      backupFolderName: backupFolderName,
    );
    return _instance!;
  }

  // Reset instance (useful for testing or reconfiguration)
  static void resetInstance() {
    _instance = null;
  }

  /// Get database file path
  Future<String> _getDatabasePath(String fileName) async {
    final dbPath = await getDatabasesPath();
    return path.join(dbPath, fileName);
  }

  /// Get the backup directory
  Future<Directory> get _backupDirectory async {
    Directory baseDir;

    if (Platform.isAndroid) {
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
      if (await Permission.storage.isGranted) {
        return true;
      }

      final status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      }

      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      final manageStatus = await Permission.manageExternalStorage.request();
      return manageStatus.isGranted;
    }

    return true;
  }

  /// Generate backup file name with timestamp
  String _generateBackupFileName(String dbName, {bool isZip = false}) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final extension = isZip ? 'zip' : 'db';
    return '${dbName}_backup_$timestamp.$extension';
  }

  /// Close a specific database
  Future<void> _closeDatabase(String filePath) async {
    try {
      final db = await openDatabase(filePath);
      await db.close();
    } catch (e) {
      debugPrint('Error closing database: $e');
    }
  }

  /// Validate SQLite file
  Future<bool> _isValidSQLiteFile(File file) async {
    try {
      final bytes = await file.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes.take(15));
      return header == 'SQLite format 3';
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // SINGLE DATABASE OPERATIONS
  // ============================================

  /// Backup a single database
  Future<BackupResponse> backupSingleDatabase(DatabaseConfig dbConfig) async {
    try {
      if (!await _checkPermissions()) {
        return BackupResponse(
          result: BackupResult.permissionDenied,
          message: 'Storage permission denied',
        );
      }

      final dbPath = await _getDatabasePath(dbConfig.fileName);
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return BackupResponse(
          result: BackupResult.databaseNotFound,
          message: '${dbConfig.displayName} database not found',
        );
      }

      await _closeDatabase(dbPath);

      final backupDir = await _backupDirectory;
      final backupFileName = _generateBackupFileName(dbConfig.name);
      final backupPath = path.join(backupDir.path, backupFileName);

      await dbFile.copy(backupPath);

      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        return BackupResponse(
          result: BackupResult.error,
          message: 'Failed to create backup file',
        );
      }

      return BackupResponse(
        result: BackupResult.success,
        message: '${dbConfig.displayName} backed up successfully',
        filePath: backupPath,
      );
    } catch (e) {
      debugPrint('Backup error: $e');
      return BackupResponse(
        result: BackupResult.error,
        message: 'Error backing up ${dbConfig.displayName}: ${e.toString()}',
      );
    }
  }

  /// Restore a single database
  Future<BackupResponse> restoreSingleDatabase(
    DatabaseConfig dbConfig,
    String backupFilePath,
  ) async {
    try {
      if (!await _checkPermissions()) {
        return BackupResponse(
          result: BackupResult.permissionDenied,
          message: 'Storage permission denied',
        );
      }

      final backupFile = File(backupFilePath);

      if (!await backupFile.exists()) {
        return BackupResponse(
          result: BackupResult.fileNotFound,
          message: 'Backup file not found',
        );
      }

      if (!await _isValidSQLiteFile(backupFile)) {
        return BackupResponse(
          result: BackupResult.invalidBackup,
          message: 'Invalid SQLite database file',
        );
      }

      final dbPath = await _getDatabasePath(dbConfig.fileName);
      await _closeDatabase(dbPath);

      final dbFile = File(dbPath);

      // Create temp backup
      if (await dbFile.exists()) {
        await dbFile.copy('$dbPath.temp_backup');
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
        // Restore from temp backup
        final tempBackup = File('$dbPath.temp_backup');
        if (await tempBackup.exists()) {
          await tempBackup.copy(dbPath);
        }
        return BackupResponse(
          result: BackupResult.error,
          message: 'Failed to restore ${dbConfig.displayName}',
        );
      }

      // Delete temp backup
      final tempBackupFile = File('$dbPath.temp_backup');
      if (await tempBackupFile.exists()) {
        await tempBackupFile.delete();
      }

      return BackupResponse(
        result: BackupResult.success,
        message: '${dbConfig.displayName} restored successfully',
      );
    } catch (e) {
      debugPrint('Restore error: $e');
      return BackupResponse(
        result: BackupResult.error,
        message: 'Error restoring ${dbConfig.displayName}: ${e.toString()}',
      );
    }
  }

  // ============================================
  // MULTIPLE DATABASE OPERATIONS
  // ============================================

  /// Backup all databases individually
  Future<BackupResponse> backupAllDatabasesIndividually() async {
    try {
      if (!await _checkPermissions()) {
        return BackupResponse(
          result: BackupResult.permissionDenied,
          message: 'Storage permission denied',
        );
      }

      final Map<String, bool> results = {};
      final List<String> backupPaths = [];

      for (final dbConfig in databases) {
        final response = await backupSingleDatabase(dbConfig);
        results[dbConfig.name] = response.isSuccess;
        if (response.filePath != null) {
          backupPaths.add(response.filePath!);
        }
      }

      final allSuccess = results.values.every((success) => success);
      final anySuccess = results.values.any((success) => success);

      return BackupResponse(
        result: allSuccess
            ? BackupResult.success
            : (anySuccess ? BackupResult.partialSuccess : BackupResult.error),
        message: allSuccess
            ? 'All databases backed up successfully'
            : 'Some databases failed to backup',
        databaseResults: results,
      );
    } catch (e) {
      return BackupResponse(
        result: BackupResult.error,
        message: 'Error backing up databases: ${e.toString()}',
      );
    }
  }

  /// Backup all databases into a single ZIP file
  Future<BackupResponse> backupAllDatabasesAsZip({
    String? customFileName,
  }) async {
    try {
      if (!await _checkPermissions()) {
        return BackupResponse(
          result: BackupResult.permissionDenied,
          message: 'Storage permission denied',
        );
      }

      final archive = Archive();
      final Map<String, bool> results = {};

      for (final dbConfig in databases) {
        final dbPath = await _getDatabasePath(dbConfig.fileName);
        final dbFile = File(dbPath);

        if (await dbFile.exists()) {
          await _closeDatabase(dbPath);

          final bytes = await dbFile.readAsBytes();
          archive.addFile(ArchiveFile(dbConfig.fileName, bytes.length, bytes));
          results[dbConfig.name] = true;
        } else {
          results[dbConfig.name] = false;
          if (dbConfig.isRequired) {
            debugPrint('Required database not found: ${dbConfig.fileName}');
          }
        }
      }

      if (archive.isEmpty) {
        return BackupResponse(
          result: BackupResult.databaseNotFound,
          message: 'No databases found to backup',
          databaseResults: results,
        );
      }

      // Create ZIP file
      final backupDir = await _backupDirectory;
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final zipFileName = customFileName ?? 'full_backup_$timestamp.zip';
      final zipPath = path.join(backupDir.path, zipFileName);

      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      if (zipData.isEmpty) {
        return BackupResponse(
          result: BackupResult.error,
          message: 'Failed to create ZIP archive',
        );
      }

      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);

      final allSuccess = results.values.every((success) => success);

      return BackupResponse(
        result: allSuccess ? BackupResult.success : BackupResult.partialSuccess,
        message: allSuccess
            ? 'All databases backed up to ZIP'
            : 'Backup created (some databases missing)',
        filePath: zipPath,
        databaseResults: results,
      );
    } catch (e) {
      debugPrint('ZIP backup error: $e');
      return BackupResponse(
        result: BackupResult.error,
        message: 'Error creating ZIP backup: ${e.toString()}',
      );
    }
  }

  /// Restore all databases from ZIP file
  Future<BackupResponse> restoreAllDatabasesFromZip(String zipFilePath) async {
    try {
      if (!await _checkPermissions()) {
        return BackupResponse(
          result: BackupResult.permissionDenied,
          message: 'Storage permission denied',
        );
      }

      final zipFile = File(zipFilePath);

      if (!await zipFile.exists()) {
        return BackupResponse(
          result: BackupResult.fileNotFound,
          message: 'ZIP file not found',
        );
      }

      // Read and decode ZIP file
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      if (archive.isEmpty) {
        return BackupResponse(
          result: BackupResult.invalidBackup,
          message: 'ZIP file is empty or invalid',
        );
      }

      final Map<String, bool> results = {};

      // Create temp directory for extraction
      final tempDir = await getTemporaryDirectory();
      final extractPath = path.join(tempDir.path, 'db_restore_temp');
      final extractDir = Directory(extractPath);

      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create();

      // Extract files
      for (final file in archive) {
        if (file.isFile) {
          final extractedFile = File(path.join(extractPath, file.name));
          await extractedFile.writeAsBytes(file.content as List<int>);
        }
      }

      // Restore each database
      for (final dbConfig in databases) {
        final extractedDbPath = path.join(extractPath, dbConfig.fileName);
        final extractedDbFile = File(extractedDbPath);

        if (await extractedDbFile.exists()) {
          // Validate SQLite file
          if (await _isValidSQLiteFile(extractedDbFile)) {
            final dbPath = await _getDatabasePath(dbConfig.fileName);
            await _closeDatabase(dbPath);

            final dbFile = File(dbPath);

            // Create temp backup
            if (await dbFile.exists()) {
              await dbFile.copy('$dbPath.temp_backup');
              await dbFile.delete();
            }

            // Copy restored file
            await extractedDbFile.copy(dbPath);
            results[dbConfig.name] = true;

            // Delete temp backup
            final tempBackup = File('$dbPath.temp_backup');
            if (await tempBackup.exists()) {
              await tempBackup.delete();
            }
          } else {
            results[dbConfig.name] = false;
          }
        } else {
          results[dbConfig.name] = false;
        }
      }

      // Cleanup temp directory
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }

      final allSuccess = results.values.every((success) => success);
      final anySuccess = results.values.any((success) => success);

      return BackupResponse(
        result: allSuccess
            ? BackupResult.success
            : (anySuccess ? BackupResult.partialSuccess : BackupResult.error),
        message: allSuccess
            ? 'All databases restored successfully'
            : 'Some databases failed to restore',
        databaseResults: results,
      );
    } catch (e) {
      debugPrint('ZIP restore error: $e');
      return BackupResponse(
        result: BackupResult.error,
        message: 'Error restoring from ZIP: ${e.toString()}',
      );
    }
  }

  /// Backup selected databases as ZIP
  Future<BackupResponse> backupSelectedDatabasesAsZip(
    List<DatabaseConfig> selectedDatabases,
  ) async {
    try {
      if (!await _checkPermissions()) {
        return BackupResponse(
          result: BackupResult.permissionDenied,
          message: 'Storage permission denied',
        );
      }

      if (selectedDatabases.isEmpty) {
        return BackupResponse(
          result: BackupResult.error,
          message: 'No databases selected',
        );
      }

      final archive = Archive();
      final Map<String, bool> results = {};

      for (final dbConfig in selectedDatabases) {
        final dbPath = await _getDatabasePath(dbConfig.fileName);
        final dbFile = File(dbPath);

        if (await dbFile.exists()) {
          await _closeDatabase(dbPath);

          final bytes = await dbFile.readAsBytes();
          archive.addFile(ArchiveFile(dbConfig.fileName, bytes.length, bytes));
          results[dbConfig.name] = true;
        } else {
          results[dbConfig.name] = false;
        }
      }

      if (archive.isEmpty) {
        return BackupResponse(
          result: BackupResult.databaseNotFound,
          message: 'No selected databases found',
          databaseResults: results,
        );
      }

      final backupDir = await _backupDirectory;
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final dbNames = selectedDatabases.map((db) => db.name).join('_');
      final zipFileName = '${dbNames}_backup_$timestamp.zip';
      final zipPath = path.join(backupDir.path, zipFileName);

      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      if (zipData.isEmpty) {
        return BackupResponse(
          result: BackupResult.error,
          message: 'Failed to create ZIP archive',
        );
      }

      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);

      return BackupResponse(
        result: BackupResult.success,
        message: 'Selected databases backed up successfully',
        filePath: zipPath,
        databaseResults: results,
      );
    } catch (e) {
      return BackupResponse(
        result: BackupResult.error,
        message: 'Error creating backup: ${e.toString()}',
      );
    }
  }

  // ============================================
  // FILE PICKER OPERATIONS
  // ============================================

  /// Restore from file picker (auto-detect single DB or ZIP)
  Future<BackupResponse> restoreFromFilePicker({
    DatabaseConfig? targetDatabase,
  }) async {
    try {
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

      // Check if it's a ZIP file
      if (filePath.toLowerCase().endsWith('.zip')) {
        return await restoreAllDatabasesFromZip(filePath);
      } else if (targetDatabase != null) {
        return await restoreSingleDatabase(targetDatabase, filePath);
      } else {
        // Try to match database by filename
        final fileName = path.basename(filePath);
        for (final dbConfig in databases) {
          if (fileName.contains(dbConfig.name)) {
            return await restoreSingleDatabase(dbConfig, filePath);
          }
        }

        return BackupResponse(
          result: BackupResult.error,
          message:
              'Could not determine target database. Please select a specific database to restore.',
        );
      }
    } catch (e) {
      return BackupResponse(
        result: BackupResult.error,
        message: 'Error picking file: ${e.toString()}',
      );
    }
  }

  // ============================================
  // BACKUP MANAGEMENT
  // ============================================

  /// Get all backups list
  Future<List<BackupInfo>> getBackupsList() async {
    try {
      final backupDir = await _backupDirectory;

      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir
          .list()
          .where(
            (entity) =>
                entity is File &&
                (entity.path.endsWith('.db') || entity.path.endsWith('.zip')),
          )
          .cast<File>()
          .toList();

      final backups = await Future.wait(
        files.map((file) => BackupInfo.fromFile(file)),
      );

      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return backups;
    } catch (e) {
      debugPrint('Error getting backups list: $e');
      return [];
    }
  }

  /// Get backups for a specific database
  Future<List<BackupInfo>> getBackupsForDatabase(
    DatabaseConfig dbConfig,
  ) async {
    final allBackups = await getBackupsList();
    return allBackups
        .where(
          (backup) =>
              backup.fileName.contains(dbConfig.name) && !backup.isZipBackup,
        )
        .toList();
  }

  /// Get ZIP backups only
  Future<List<BackupInfo>> getZipBackups() async {
    final allBackups = await getBackupsList();
    return allBackups.where((backup) => backup.isZipBackup).toList();
  }

  /// Delete a backup
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

  /// Auto backup with retention
  Future<BackupResponse> createAutoBackup({
    int maxBackups = 5,
    bool useZip = true,
  }) async {
    try {
      final response = useZip
          ? await backupAllDatabasesAsZip()
          : await backupAllDatabasesIndividually();

      if (!response.isSuccess && !response.isPartialSuccess) {
        return response;
      }

      // Apply retention policy
      final backups = useZip ? await getZipBackups() : await getBackupsList();

      if (backups.length > maxBackups) {
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

  /// Get contents of a ZIP backup
  Future<List<String>> getZipContents(String zipFilePath) async {
    try {
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        return [];
      }

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      return archive
          .where((file) => file.isFile)
          .map((file) => file.name)
          .toList();
    } catch (e) {
      debugPrint('Error reading ZIP contents: $e');
      return [];
    }
  }
}

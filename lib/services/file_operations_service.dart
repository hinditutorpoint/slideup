import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'permission_service.dart';
import 'saf_service.dart';

enum FileOperation { copy, cut, move }

class FileOperationResult {
  final bool success;
  final String? error;
  final int processedCount;
  final int totalCount;
  final bool needsStorageAccess;

  const FileOperationResult({
    required this.success,
    this.error,
    this.processedCount = 0,
    this.totalCount = 0,
    this.needsStorageAccess = false,
  });

  FileOperationResult copyWith({
    bool? success,
    String? error,
    int? processedCount,
    int? totalCount,
    bool? needsStorageAccess,
  }) {
    return FileOperationResult(
      success: success ?? this.success,
      error: error ?? this.error,
      processedCount: processedCount ?? this.processedCount,
      totalCount: totalCount ?? this.totalCount,
      needsStorageAccess: needsStorageAccess ?? this.needsStorageAccess,
    );
  }

  // Helper getters for convenience
  bool get hasError => error != null && error!.isNotEmpty;
  bool get isComplete => processedCount >= totalCount;
  double get progressPercentage =>
      totalCount > 0 ? processedCount / totalCount : 0.0;
}

class FileOperationsService {
  static final FileOperationsService instance = FileOperationsService._();
  FileOperationsService._() {
    _loadSafVolumes();
  }

  /// Restores persisted SAF tree grants so [_needsSaf] routes removable
  /// volume writes through SAF even before any picker ran this session.
  Future<void> _loadSafVolumes() async {
    try {
      _safVolumes.addAll(await SafService.instance.getStoredTrees());
    } catch (_) {}
  }

  List<FileSystemEntity> _clipboard = [];
  FileOperation? _currentOperation;

  /// Volume IDs (e.g. `XXXX-XXXX`) that have SAF tree access granted.
  /// Paths under these volumes must route writes/deletes through SAF.
  final Set<String> _safVolumes = {};

  // Progress callback for long operations
  Function(int current, int total, String currentFile)? onProgress;

  // Getters
  List<FileSystemEntity> get clipboard => List.unmodifiable(_clipboard);
  FileOperation? get currentOperation => _currentOperation;
  bool get hasClipboard => _clipboard.isNotEmpty;

  Future<bool> _checkWritePermissionForOperation(String opPath) async {
    // A persisted SAF tree grant means the volume is writable through SAF
    // even though raw-path writes stay blocked — skip both the write test
    // and the picker prompt.
    if (PermissionService.instance.isRemovableStorage(opPath)) {
      if (await SafService.instance.hasTree(opPath)) {
        final segments = opPath.split('/');
        if (segments.length >= 3) _safVolumes.add(segments[2]);
        debugPrint('✅ Reusing persisted SAF tree for: $opPath');
        return true;
      }
    }

    final hasPermission =
        await PermissionService.instance.isPathWritable(opPath);
    if (hasPermission) return true;

    if (PermissionService.instance.isRemovableStorage(opPath)) {
      debugPrint('🔄 Removable storage blocked — requesting SAF tree access…');
      final treeUri = await SafService.instance.pickTree();
      if (treeUri != null) {
        final stored = await SafService.instance.storeTree(treeUri);
        if (stored != null) {
          debugPrint('✅ SAF tree granted for volume: $stored');
          _safVolumes.add(stored);
          return true;
        }
      }
      debugPrint('❌ SAF tree access not granted for: $opPath');
    }

    debugPrint('❌ No write permission for path: $opPath');
    return false;
  }

  /// Returns `true` if [opPath] is on a removable volume with SAF access.
  bool _needsSaf(String opPath) {
    if (!PermissionService.instance.isRemovableStorage(opPath)) return false;
    final segments = opPath.split('/');
    if (segments.length >= 3 && segments[0] == '' && segments[1] == 'storage') {
      return _safVolumes.contains(segments[2]);
    }
    return false;
  }

  /// SAF-based file write: reads source bytes, writes through SAF channel.
  Future<bool> _safCopyFile(File source, String destPath) async {
    try {
      final bytes = await source.readAsBytes();
      final result = await SafService.instance.writeFile(destPath, bytes);
      return result == 'ok';
    } catch (e) {
      debugPrint('❌ SAF copy failed: $e');
      return false;
    }
  }

  /// SAF-based file delete.
  Future<bool> _safDeleteFile(String filePath) async {
    final result = await SafService.instance.deleteFile(filePath);
    return result == 'ok';
  }

  /// SAF-based move: copy then delete source.
  Future<bool> _safMoveFile(File source, String destPath) async {
    if (!await _safCopyFile(source, destPath)) return false;
    return await _safDeleteFile(source.path);
  }

  /// Enhanced create folder with permission check
  Future<FileOperationResult> createFolderWithPermissionCheck(
    String parentPath,
    String folderName,
  ) async {
    try {
      // Check write permission first
      if (!await _checkWritePermissionForOperation(parentPath)) {
        return FileOperationResult(
          success: false,
          error:
              'No write permission for this location. Try a different folder or grant storage permissions.',
          totalCount: 1,
        );
      }

      return await createFolder(parentPath, folderName);
    } catch (e) {
      return FileOperationResult(
        success: false,
        error: 'Permission error: $e',
        totalCount: 1,
      );
    }
  }

  /// Enhanced paste files with permission check
  Future<FileOperationResult> pasteFilesWithPermissionCheck(
    String destinationPath,
  ) async {
    try {
      // Check write permission first
      if (!await _checkWritePermissionForOperation(destinationPath)) {
        return FileOperationResult(
          success: false,
          error:
              'No write permission for destination. Try a different location or grant permissions.',
          totalCount: _clipboard.length,
        );
      }

      return await pasteFiles(destinationPath);
    } catch (e) {
      return FileOperationResult(
        success: false,
        error: 'Permission error: $e',
        totalCount: _clipboard.length,
      );
    }
  }

  /// Enhanced move files with permission check
  Future<FileOperationResult> moveFilesWithPermissionCheck(
    List<FileSystemEntity> files,
    String destinationPath,
  ) async {
    try {
      // Check write permission for destination
      if (!await _checkWritePermissionForOperation(destinationPath)) {
        return FileOperationResult(
          success: false,
          error: 'No write permission for destination.',
          totalCount: files.length,
        );
      }

      // Check write permission for source files (for deletion)
      for (final file in files) {
        final sourceDir = file.parent.path;
        if (!await _checkWritePermissionForOperation(sourceDir)) {
          return FileOperationResult(
            success: false,
            error: 'No write permission to move files from source location.',
            totalCount: files.length,
          );
        }
      }

      return await moveFiles(files, destinationPath);
    } catch (e) {
      return FileOperationResult(
        success: false,
        error: 'Permission error: $e',
        totalCount: files.length,
      );
    }
  }

  /// Enhanced delete files with permission check
  ///
  /// Files on writable paths are deleted directly. Files on removable volumes
  /// (USB OTG / SD card) that block raw-path writes are deleted through the
  /// Storage Access Framework; if the user hasn't granted tree access yet,
  /// [FileOperationResult.needsStorageAccess] is set so the UI can prompt.
  Future<FileOperationResult> deleteFilesWithPermissionCheck(
    List<FileSystemEntity> files,
  ) async {
    if (files.isEmpty) {
      return const FileOperationResult(
        success: false,
        error: 'No files selected',
      );
    }

    try {
      final rawDeletable = <FileSystemEntity>[];
      bool needsTree = false;
      int safDeleted = 0;

      for (final file in files) {
        final filePath = file.path;

        // Removable volumes block raw unlink even when the write-permission
        // check passes, so always route them through SAF first. The native
        // side reads its persisted tree grants directly, so this works
        // regardless of the in-memory [_safVolumes] cache.
        if (PermissionService.instance.isRemovableStorage(filePath)) {
          final safResult = await SafService.instance.deleteFile(filePath);
          switch (safResult) {
            case 'ok':
              safDeleted++;
              debugPrint('🗑️ Deleted via SAF: $filePath');
              continue;
            case 'needs_tree':
              needsTree = true;
              debugPrint('🔑 SAF tree access needed for: $filePath');
              continue;
            default:
              return FileOperationResult(
                success: false,
                error: 'Could not delete ${path.basename(filePath)} from '
                    'removable storage.',
                processedCount: safDeleted,
                totalCount: files.length,
              );
          }
        }

        if (await _checkWritePermissionForOperation(file.parent.path)) {
          rawDeletable.add(file);
          continue;
        }

        return FileOperationResult(
          success: false,
          error: 'No write permission to delete files from this location.',
          totalCount: files.length,
        );
      }

      final rawResult = rawDeletable.isEmpty
          ? const FileOperationResult(
              success: true,
              processedCount: 0,
              totalCount: 0,
            )
          : await deleteFiles(rawDeletable);

      final processed = rawResult.processedCount + safDeleted;
      final success = rawResult.error == null &&
          processed == files.length &&
          !needsTree;

      return FileOperationResult(
        success: success,
        error: rawResult.error,
        processedCount: processed,
        totalCount: files.length,
        needsStorageAccess: needsTree,
      );
    } catch (e) {
      return FileOperationResult(
        success: false,
        error: 'Permission error: $e',
        totalCount: files.length,
      );
    }
  }

  /// Copy files to clipboard
  Future<bool> copyFiles(List<FileSystemEntity> files) async {
    try {
      if (files.isEmpty) return false;

      _clipboard = List.from(files);
      _currentOperation = FileOperation.copy;
      debugPrint('📋 Copied ${files.length} items to clipboard');
      return true;
    } catch (e) {
      debugPrint('❌ Error copying files to clipboard: $e');
      return false;
    }
  }

  /// Cut files to clipboard
  Future<bool> cutFiles(List<FileSystemEntity> files) async {
    try {
      if (files.isEmpty) return false;

      _clipboard = List.from(files);
      _currentOperation = FileOperation.cut;
      debugPrint('✂️ Cut ${files.length} items to clipboard');
      return true;
    } catch (e) {
      debugPrint('❌ Error cutting files to clipboard: $e');
      return false;
    }
  }

  /// Paste files from clipboard to destination
  Future<FileOperationResult> pasteFiles(String destinationPath) async {
    // Check preconditions
    if (_clipboard.isEmpty) {
      return const FileOperationResult(
        success: false,
        error: 'No files in clipboard',
      );
    }

    if (_currentOperation == null) {
      return const FileOperationResult(
        success: false,
        error: 'No operation in clipboard',
      );
    }

    try {
      final destinationDir = Directory(destinationPath);
      final dirExists = await destinationDir.exists();

      if (!dirExists) {
        return const FileOperationResult(
          success: false,
          error: 'Destination directory does not exist',
        );
      }

      int processedCount = 0;
      final totalCount = _clipboard.length;
      final errors = <String>[];

      for (final file in _clipboard) {
        try {
          final fileName = path.basename(file.path);
          final newPath = path.join(destinationPath, fileName);

          final progressCallback = onProgress;
          if (progressCallback != null) {
            progressCallback(processedCount, totalCount, fileName);
          }

          final useSaf = _needsSaf(newPath);

          if (_currentOperation == FileOperation.copy) {
            if (useSaf && file is File) {
              final ok = await _safCopyFile(file, newPath);
              if (!ok) throw Exception('SAF write failed');
            } else {
              await _copyFileOrDirectory(file, newPath);
            }
          } else if (_currentOperation == FileOperation.cut) {
            if (useSaf && file is File) {
              final ok = await _safMoveFile(file, newPath);
              if (!ok) throw Exception('SAF move failed');
            } else {
              await _moveFileOrDirectory(file, newPath);
            }
          }

          processedCount++;
        } catch (e) {
          errors.add('${path.basename(file.path)}: $e');
          debugPrint('❌ Error processing ${file.path}: $e');
        }
      }

      // Clear clipboard after successful operation (both copy and cut)
      final hasNoErrors = errors.isEmpty;
      if (hasNoErrors) {
        clearClipboard();
      }

      final success = errors.isEmpty;
      final errorMessage = errors.isNotEmpty ? errors.join('\n') : null;

      debugPrint(
        '📁 Paste operation completed: $processedCount/$totalCount files',
      );

      return FileOperationResult(
        success: success,
        error: errorMessage,
        processedCount: processedCount,
        totalCount: totalCount,
      );
    } catch (e) {
      debugPrint('❌ Paste operation failed: $e');
      return FileOperationResult(
        success: false,
        error: 'Paste operation failed: $e',
        totalCount: _clipboard.length,
      );
    }
  }

  /// Move files to destination
  Future<FileOperationResult> moveFiles(
    List<FileSystemEntity> files,
    String destinationPath,
  ) async {
    if (files.isEmpty) {
      return const FileOperationResult(
        success: false,
        error: 'No files selected',
      );
    }

    try {
      final destinationDir = Directory(destinationPath);
      final dirExists = await destinationDir.exists();

      if (!dirExists) {
        return const FileOperationResult(
          success: false,
          error: 'Destination directory does not exist',
        );
      }

      int processedCount = 0;
      final totalCount = files.length;
      final errors = <String>[];

      for (final file in files) {
        try {
          final fileName = path.basename(file.path);
          final newPath = path.join(destinationPath, fileName);

          final progressCallback = onProgress;
          if (progressCallback != null) {
            progressCallback(processedCount, totalCount, fileName);
          }

          if (_needsSaf(newPath) && file is File) {
            final ok = await _safMoveFile(file, newPath);
            if (!ok) throw Exception('SAF move failed');
          } else {
            await _moveFileOrDirectory(file, newPath);
          }
          processedCount++;
        } catch (e) {
          errors.add('${path.basename(file.path)}: $e');
          debugPrint('❌ Error moving ${file.path}: $e');
        }
      }

      final success = errors.isEmpty;
      final errorMessage = errors.isNotEmpty ? errors.join('\n') : null;

      debugPrint(
        '📁 Move operation completed: $processedCount/$totalCount files',
      );

      return FileOperationResult(
        success: success,
        error: errorMessage,
        processedCount: processedCount,
        totalCount: totalCount,
      );
    } catch (e) {
      debugPrint('❌ Move operation failed: $e');
      return FileOperationResult(
        success: false,
        error: 'Move operation failed: $e',
        totalCount: files.length,
      );
    }
  }

  /// Delete files
  Future<FileOperationResult> deleteFiles(List<FileSystemEntity> files) async {
    if (files.isEmpty) {
      return const FileOperationResult(
        success: false,
        error: 'No files selected',
      );
    }

    try {
      int processedCount = 0;
      final totalCount = files.length;
      final errors = <String>[];

      for (final file in files) {
        try {
          final fileName = path.basename(file.path);
          final progressCallback = onProgress;
          if (progressCallback != null) {
            progressCallback(processedCount, totalCount, fileName);
          }

          final isDirectory = file is Directory;
          if (isDirectory) {
            await file.delete(recursive: true);
          } else {
            await file.delete();
          }

          processedCount++;
          debugPrint('🗑️ Deleted: ${file.path}');
        } catch (e) {
          final raw = e.toString();
          final isPermissionIssue =
              raw.contains('Permission denied') ||
              raw.contains('errno = 13') ||
              e is PathAccessException;
          final friendly = isPermissionIssue
              ? 'No permission to delete. Check storage permission or '
                  'read-only media.'
              : '$e';
          errors.add('${path.basename(file.path)}: $friendly');
          debugPrint('❌ Error deleting ${file.path}: $e');
        }
      }

      final success = errors.isEmpty;
      final errorMessage = errors.isNotEmpty ? errors.join('\n') : null;

      debugPrint(
        '🗑️ Delete operation completed: $processedCount/$totalCount files',
      );

      return FileOperationResult(
        success: success,
        error: errorMessage,
        processedCount: processedCount,
        totalCount: totalCount,
      );
    } catch (e) {
      debugPrint('❌ Delete operation failed: $e');
      return FileOperationResult(
        success: false,
        error: 'Delete operation failed: $e',
        totalCount: files.length,
      );
    }
  }

  /// Rename file or directory
  Future<FileOperationResult> renameFile(
    FileSystemEntity file,
    String newName,
  ) async {
    try {
      if (newName.trim().isEmpty) {
        return const FileOperationResult(
          success: false,
          error: 'Name cannot be empty',
        );
      }

      final parentPath = file.parent.path;
      final newPath = path.join(parentPath, newName);

      // Check if new name already exists
      final fileExists = await FileSystemEntity.isFile(newPath);
      final dirExists = await FileSystemEntity.isDirectory(newPath);

      if (fileExists || dirExists) {
        return const FileOperationResult(
          success: false,
          error: 'A file or folder with this name already exists',
        );
      }

      if (_needsSaf(newPath) && file is File) {
        // SAF rename: read → write to new path → delete old
        final bytes = await file.readAsBytes();
        final writeResult = await SafService.instance.writeFile(newPath, bytes);
        if (writeResult != 'ok') throw Exception('SAF rename write failed: $writeResult');
        await _safDeleteFile(file.path);
      } else {
        await file.rename(newPath);
      }
      debugPrint('✏️ Renamed: ${file.path} → $newPath');

      return const FileOperationResult(
        success: true,
        processedCount: 1,
        totalCount: 1,
      );
    } catch (e) {
      debugPrint('❌ Error renaming file: $e');
      return FileOperationResult(
        success: false,
        error: 'Failed to rename: $e',
        totalCount: 1,
      );
    }
  }

  /// Create new folder
  Future<FileOperationResult> createFolder(
    String parentPath,
    String folderName,
  ) async {
    try {
      if (folderName.trim().isEmpty) {
        return const FileOperationResult(
          success: false,
          error: 'Folder name cannot be empty',
        );
      }

      final newPath = path.join(parentPath, folderName);

      // Check if folder already exists
      final exists = await Directory(newPath).exists();
      if (exists) {
        return const FileOperationResult(
          success: false,
          error: 'A folder with this name already exists',
        );
      }

      final directory = Directory(newPath);

      if (_needsSaf(newPath)) {
        // SAF can't mkdir directly — write an empty placeholder to create the folder.
        final result = await SafService.instance.writeFile(
          path.join(newPath, '.nomedia'),
          Uint8List(0),
        );
        if (result != 'ok' && result != 'needs_tree') {
          throw Exception('SAF folder create failed: $result');
        }
      } else {
        await directory.create(recursive: true);
      }
      debugPrint('📁 Created folder: $newPath');

      return const FileOperationResult(
        success: true,
        processedCount: 1,
        totalCount: 1,
      );
    } catch (e) {
      debugPrint('❌ Error creating folder: $e');
      return FileOperationResult(
        success: false,
        error: 'Failed to create folder: $e',
        totalCount: 1,
      );
    }
  }

  /// Create new file
  Future<FileOperationResult> createFile(
    String parentPath,
    String fileName, {
    String content = '',
  }) async {
    try {
      if (fileName.trim().isEmpty) {
        return const FileOperationResult(
          success: false,
          error: 'File name cannot be empty',
        );
      }

      final newPath = path.join(parentPath, fileName);

      // Check if file already exists
      final exists = await File(newPath).exists();
      if (exists) {
        return const FileOperationResult(
          success: false,
          error: 'A file with this name already exists',
        );
      }

      if (_needsSaf(newPath)) {
        final result = await SafService.instance.writeFile(
          newPath,
          Uint8List.fromList(content.codeUnits),
        );
        if (result != 'ok') throw Exception('SAF write failed: $result');
      } else {
        final file = File(newPath);
        await file.writeAsString(content);
      }
      debugPrint('📄 Created file: $newPath');

      return const FileOperationResult(
        success: true,
        processedCount: 1,
        totalCount: 1,
      );
    } catch (e) {
      debugPrint('❌ Error creating file: $e');
      return FileOperationResult(
        success: false,
        error: 'Failed to create file: $e',
        totalCount: 1,
      );
    }
  }

  /// Duplicate files
  Future<FileOperationResult> duplicateFiles(
    List<FileSystemEntity> files,
  ) async {
    if (files.isEmpty) {
      return const FileOperationResult(
        success: false,
        error: 'No files selected',
      );
    }

    try {
      int processedCount = 0;
      final totalCount = files.length;
      final errors = <String>[];

      for (final file in files) {
        try {
          final fileName = path.basename(file.path);
          final parentPath = file.parent.path;
          final nameWithoutExtension = path.basenameWithoutExtension(file.path);
          final extension = path.extension(file.path);

          // Find a unique name
          String newName = fileName;
          int counter = 1;

          bool nameExists = true;
          while (nameExists) {
            final testPath = path.join(parentPath, newName);
            final fileExists = await FileSystemEntity.isFile(testPath);
            final dirExists = await FileSystemEntity.isDirectory(testPath);

            nameExists = fileExists || dirExists;

            if (nameExists) {
              if (extension.isNotEmpty) {
                newName = '${nameWithoutExtension}_copy_$counter$extension';
              } else {
                newName = '${fileName}_copy_$counter';
              }
              counter++;
            }
          }

          final newPath = path.join(parentPath, newName);
          final progressCallback = onProgress;
          if (progressCallback != null) {
            progressCallback(processedCount, totalCount, fileName);
          }

          await _copyFileOrDirectory(file, newPath);
          processedCount++;
          debugPrint('📋 Duplicated: ${file.path} → $newPath');
        } catch (e) {
          errors.add('${path.basename(file.path)}: $e');
          debugPrint('❌ Error duplicating ${file.path}: $e');
        }
      }

      final success = errors.isEmpty;
      final errorMessage = errors.isNotEmpty ? errors.join('\n') : null;

      debugPrint(
        '📋 Duplicate operation completed: $processedCount/$totalCount files',
      );

      return FileOperationResult(
        success: success,
        error: errorMessage,
        processedCount: processedCount,
        totalCount: totalCount,
      );
    } catch (e) {
      debugPrint('❌ Duplicate operation failed: $e');
      return FileOperationResult(
        success: false,
        error: 'Duplicate operation failed: $e',
        totalCount: files.length,
      );
    }
  }

  /// Share files using the system share dialog
  Future<FileOperationResult> shareFiles(List<FileSystemEntity> files) async {
    if (files.isEmpty) {
      return const FileOperationResult(
        success: false,
        error: 'No files selected for sharing',
      );
    }

    try {
      final shareFiles = <XFile>[];
      final shareText = <String>[];

      for (final file in files) {
        final isFile = file is File;
        if (isFile) {
          shareFiles.add(XFile(file.path));
        } else {
          shareText.add('Folder: ${path.basename(file.path)}');
        }
      }

      final hasFiles = shareFiles.isNotEmpty;
      final hasText = shareText.isNotEmpty;

      if (hasFiles) {
        final textToShare = hasText ? shareText.join('\n') : null;
        await SharePlus.instance.share(
          ShareParams(
            text: textToShare,
            subject: files.length == 1
                ? path.basename(files.first.path)
                : '${files.length} files',
            files: shareFiles,
          ),
        );
      } else if (hasText) {
        await SharePlus.instance.share(
          ShareParams(
            text: shareText.join('\n'),
            subject: files.length == 1
                ? path.basename(files.first.path)
                : '${files.length} items',
          ),
        );
      }

      debugPrint('📤 Shared ${files.length} items');

      return FileOperationResult(
        success: true,
        processedCount: files.length,
        totalCount: files.length,
      );
    } catch (e) {
      debugPrint('❌ Error sharing files: $e');
      return FileOperationResult(
        success: false,
        error: 'Failed to share files: $e',
        totalCount: files.length,
      );
    }
  }

  /// Get file/directory properties
  Future<Map<String, dynamic>?> getProperties(FileSystemEntity entity) async {
    try {
      final stat = await entity.stat();
      final name = path.basename(entity.path);
      final isFile = entity is File;
      final isDirectory = entity is Directory;

      final properties = <String, dynamic>{
        'name': name,
        'path': entity.path,
        'size': isFile
            ? stat.size
            : await _getDirectorySize(entity as Directory),
        'modified': stat.modified,
        'accessed': stat.accessed,
        'changed': stat.changed,
        'mode': stat.mode,
        'type': isFile ? 'File' : 'Directory',
      };

      if (isFile) {
        properties['extension'] = path.extension(entity.path);
        properties['mimeType'] = _getMimeType(entity.path);
      } else if (isDirectory) {
        properties['itemCount'] = await _getDirectoryItemCount(entity);
      }

      return properties;
    } catch (e) {
      debugPrint('❌ Error getting properties: $e');
      return null;
    }
  }

  /// Clear clipboard
  void clearClipboard() {
    _clipboard.clear();
    _currentOperation = null;
    debugPrint('🧹 Clipboard cleared');
  }

  /// Internal method to copy file or directory
  Future<void> _copyFileOrDirectory(
    FileSystemEntity source,
    String destinationPath,
  ) async {
    final isFile = source is File;
    if (isFile) {
      await _copyFile(source, destinationPath);
    } else {
      await _copyDirectory(source as Directory, destinationPath);
    }
  }

  /// Internal method to copy a file
  Future<void> _copyFile(File source, String destinationPath) async {
    final destinationFile = File(destinationPath);

    // Ensure parent directory exists
    await destinationFile.parent.create(recursive: true);

    // Handle large files with chunked copying
    final sourceSize = await source.length();
    final isLargeFile = sourceSize > 100 * 1024 * 1024; // 100MB

    if (isLargeFile) {
      await _copyFileChunked(source, destinationFile);
    } else {
      await source.copy(destinationPath);
    }
  }

  /// Copy large files in chunks
  Future<void> _copyFileChunked(File source, File destination) async {
    //const chunkSize = 1024 * 1024; // 1MB chunks
    final sourceStream = source.openRead();
    final destinationSink = destination.openWrite();

    try {
      await sourceStream.listen((List<int> chunk) {
        destinationSink.add(chunk);
      }).asFuture();
    } finally {
      await destinationSink.close();
    }
  }

  /// Internal method to copy a directory recursively
  Future<void> _copyDirectory(Directory source, String destinationPath) async {
    final destinationDir = Directory(destinationPath);
    await destinationDir.create(recursive: true);

    await for (final entity in source.list(recursive: false)) {
      final fileName = path.basename(entity.path);
      final newPath = path.join(destinationPath, fileName);
      await _copyFileOrDirectory(entity, newPath);
    }
  }

  /// Internal method to move file or directory
  Future<void> _moveFileOrDirectory(
    FileSystemEntity source,
    String destinationPath,
  ) async {
    try {
      // Try direct rename first (fastest method)
      await source.rename(destinationPath);
    } catch (e) {
      // If rename fails (different filesystems), copy and delete
      await _copyFileOrDirectory(source, destinationPath);
      final isDirectory = source is Directory;
      if (isDirectory) {
        await source.delete(recursive: true);
      } else {
        await source.delete();
      }
    }
  }

  /// Get directory size recursively
  Future<int> _getDirectorySize(Directory directory) async {
    int totalSize = 0;
    try {
      await for (final entity in directory.list(recursive: true)) {
        final isFile = entity is File;
        if (isFile) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
          } catch (e) {
            // Skip files that can't be accessed
            debugPrint('Skipping file size for ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating directory size: $e');
    }
    return totalSize;
  }

  /// Get directory item count
  Future<int> _getDirectoryItemCount(Directory directory) async {
    int count = 0;
    try {
      await for (final _ in directory.list(recursive: false)) {
        count++;
      }
    } catch (e) {
      debugPrint('Error counting directory items: $e');
    }
    return count;
  }

  /// Get MIME type from file extension
  String? _getMimeType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    const mimeTypes = {
      '.txt': 'text/plain',
      '.html': 'text/html',
      '.htm': 'text/html',
      '.css': 'text/css',
      '.js': 'text/javascript',
      '.json': 'application/json',
      '.xml': 'application/xml',
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.zip': 'application/zip',
      '.rar': 'application/x-rar-compressed',
      '.7z': 'application/x-7z-compressed',
      '.tar': 'application/x-tar',
      '.gz': 'application/gzip',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.bmp': 'image/bmp',
      '.webp': 'image/webp',
      '.svg': 'image/svg+xml',
      '.ico': 'image/x-icon',
      '.mp3': 'audio/mpeg',
      '.wav': 'audio/wav',
      '.flac': 'audio/flac',
      '.aac': 'audio/aac',
      '.ogg': 'audio/ogg',
      '.m4a': 'audio/mp4',
      '.mp4': 'video/mp4',
      '.mkv': 'video/x-matroska',
      '.avi': 'video/x-msvideo',
      '.mov': 'video/quicktime',
      '.wmv': 'video/x-ms-wmv',
      '.flv': 'video/x-flv',
      '.webm': 'video/webm',
      '.m4v': 'video/mp4',
      '.3gp': 'video/3gpp',
      '.ts': 'video/mp2t',
      '.mpg': 'video/mpeg',
      '.mpeg': 'video/mpeg',
      // Add more as needed
    };

    return mimeTypes[extension];
  }

  /// Cancel ongoing operation (if supported)
  void cancelOperation() {
    // This is a placeholder for cancellation logic
    // In a real implementation, you'd use CancelToken or similar
    debugPrint('🛑 Operation cancelled');
  }

  /// Get clipboard info string for UI display
  String getClipboardInfo() {
    final hasClipboard = this.hasClipboard;
    final hasOperation = _currentOperation != null;

    if (!hasClipboard || !hasOperation) {
      return 'Clipboard empty';
    }

    final operationText = _currentOperation == FileOperation.copy
        ? 'Copied'
        : 'Cut';
    final itemCount = _clipboard.length;
    final itemText = itemCount == 1 ? 'item' : 'items';

    return '$operationText $itemCount $itemText';
  }
}

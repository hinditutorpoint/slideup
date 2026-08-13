import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_constants.dart' as app_constants;
import '../models/download_task.dart';
import '../utils/reader_utils.dart';
import 'txt_reader_screen.dart';
import '../../documents/screens/unified_reader_screen.dart';

/// Text Downloads Screen - Main Downloads Manager for TXT files
class TextDownloadsScreen extends StatefulWidget {
  final String? url;
  final String? localPath;
  final String? title;

  /// Which file type this library manages.
  final PdfFileFilter filter;

  /// AppBar title shown for this library.
  final String libraryTitle;

  /// Extensions allowed when picking local files.
  final List<String> pickExtensions;

  /// Title shown in the "Add Download" bottom sheet.
  final String addSheetTitle;

  /// URL hint shown in the "Add Download" bottom sheet.
  final String addSheetUrlHint;

  /// Subtitle shown when the downloaded library is empty.
  final String emptyDownloadedSubtitle;

  const TextDownloadsScreen({
    super.key,
    this.url,
    this.localPath,
    this.title,
    this.filter = PdfFileFilter.txt,
    this.libraryTitle = 'Text Library',
    this.pickExtensions = const ['txt'],
    this.addSheetTitle = 'Add Text File',
    this.addSheetUrlHint = 'https://example.com/document.txt',
    this.emptyDownloadedSubtitle =
        'Your downloaded text files will appear here',
  });

  @override
  State<TextDownloadsScreen> createState() => _TextDownloadsScreenState();
}

class _TextDownloadsScreenState extends State<TextDownloadsScreen>
    with TickerProviderStateMixin {
  // ========== Controllers ==========
  late TabController _tabController;
  final ScrollController _downloadingScrollController = ScrollController();
  final ScrollController _downloadedScrollController = ScrollController();
  final ScrollController _analyticsScrollController = ScrollController();

  // ========== State ==========
  // ignore: prefer_final_fields
  List<DownloadTask> _downloadingTasks = [];
  List<DownloadTask> _completedTasks = [];
  final Map<String, String> _epubBookTitles = {};
  ReadingStats _readingStats = const ReadingStats();
  bool _isLoading = true;
  String? _error;

  // ========== Services ==========
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      headers: {'User-Agent': 'Mozilla/5.0 (compatible; ArchiveApp/1.0)'},
    ),
  );

  // IMPORTANT: Use DownloadLibraryManager for PERMANENT storage
  final DownloadLibraryManager _libraryManager = DownloadLibraryManager();
  final ReaderStorageManager _storageManager = ReaderStorageManager();

  // Cache manager is only for temporary data
  final DocumentCacheManager _cacheManager = DocumentCacheManager();

  // ========== Screen Info ==========
  // ignore: unused_field
  Size _screenSize = Size.zero;
  EdgeInsets _safeArea = EdgeInsets.zero;

  @override
  void initState() {
    super.initState();
    _safeInit();
  }

  Future<void> _safeInit() async {
    try {
      _tabController = TabController(length: 3, vsync: this);
      _tabController.addListener(_onTabChanged);

      await _initializeData();

      // Handle incoming params
      if (widget.url != null) {
        await _handleIncomingUrl(widget.url!, widget.title);
      } else if (widget.localPath != null) {
        await _handleLocalFile(widget.localPath!, widget.title);
      }
    } catch (e, stack) {
      _logError('Init error', e, stack);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to initialize';
        });
      }
    }
  }

  void _onTabChanged() {
    try {
      if (mounted) setState(() {});
      // Refresh library + stats when leaving the Active tab, so files
      // downloaded/read via other managers show up.
      if (_tabController.index != 0) {
        _loadDownloadedFiles();
        _loadReadingStats();
      }
    } catch (_) {}
  }

  Future<void> _initializeData() async {
    try {
      await _libraryManager.initialize();
      await _storageManager.initialize();

      await _loadDownloadedFiles();
      await _loadReadingStats();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      _logError('Initialize data error', e, stack);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load data';
        });
      }
    }
  }

  /// Load PERMANENTLY downloaded files from DownloadLibraryManager
  Future<void> _loadDownloadedFiles() async {
    try {
      // Re-sync with disk in case files were added by another manager
      // instance (e.g. the documents DownloadLibraryManager).
      await _libraryManager.reload();

      // Filter for the configured file type only
      final downloads = await _libraryManager.listDownloads(
        filter: widget.filter,
      );

      final tasks = <DownloadTask>[];

      for (final item in downloads) {
        try {
          final file = await _libraryManager.getFileForItem(item);
          final exists = await file.exists();

          tasks.add(
            DownloadTask(
              id: item.id,
              url: item.sourceUrl ?? '',
              fileName: item.fileName,
              title: item.title,
              localPath: exists ? file.path : null,
              status: exists ? DownloadStatus.completed : DownloadStatus.failed,
              progress: 1.0,
              totalBytes: item.sizeBytes ?? 0,
              downloadedBytes: item.sizeBytes ?? 0,
              createdAt: item.addedAt,
              completedAt: item.lastOpened ?? item.addedAt,
            ),
          );
        } catch (e) {
          _logError('Load item error', e, null);
        }
      }

      if (mounted) {
        setState(() {
          _completedTasks = tasks;
        });
      }
    } catch (e, stack) {
      _logError('Load downloads error', e, stack);
    }
  }

  Future<void> _loadReadingStats() async {
    try {
      final positions = await _storageManager.getAllReadingPositions();
      _epubBookTitles.clear();

      final filtered = <String, ReadingPosition>{};

      if (widget.filter == PdfFileFilter.epub) {
        try {
          await _loadEpubPositions(filtered);
        } catch (e) {
          _logError('Load epub stats error', e, null);
        }
      }

      for (final entry in positions.entries) {
        if (_positionBelongsToFilter(entry.key)) {
          filtered.putIfAbsent(entry.key, () => entry.value);
        }
      }

      int booksRead = 0;
      int pagesRead = 0;
      final progressByBook = <String, double>{};

      for (final entry in filtered.entries) {
        final progress = entry.value.progress.clamp(0.0, 1.0);
        progressByBook[entry.key] = progress;
        if (progress >= 0.9) booksRead++;
        pagesRead += entry.value.page;
      }

      if (mounted) {
        setState(() {
          _readingStats = ReadingStats(
            totalBooks: _completedTasks.length,
            booksRead: booksRead,
            pagesRead: pagesRead,
            currentStreak: _calculateStreak(filtered),
            progressByBook: progressByBook,
          );
        });
      }
    } catch (e, stack) {
      _logError('Load stats error', e, stack);
    }
  }

  /// Merge EPUB reading progress (stored in the 'reading_progress' Hive box)
  /// into the stats for the EPUB library tab.
  Future<void> _loadEpubPositions(
    Map<String, ReadingPosition> filtered,
  ) async {
    final progressBox = await Hive.openBox<dynamic>(
      app_constants.AppConstants.hiveProgressBox,
    );
    final booksBox = await Hive.openBox<dynamic>(
      app_constants.AppConstants.hiveBooksBox,
    );

    for (final key in progressBox.keys) {
      final raw = progressBox.get(key);
      if (raw == null) continue;
      try {
        final map = Map<String, dynamic>.from(raw as Map);
        final bookId = map['bookId'] as String? ?? key.toString();
        final progress = (map['overallProgress'] as num?)?.toDouble() ?? 0.0;
        final page = map['currentPage'] as int? ?? 0;

        final rawLastRead = map['lastReadDate'];
        final lastRead = rawLastRead is String
            ? (DateTime.tryParse(rawLastRead) ?? DateTime.now())
            : DateTime.now();

        String title = '';
        try {
          final book = booksBox.get(bookId);
          final dynamicBookTitle = book?.title;
          if (dynamicBookTitle is String) title = dynamicBookTitle;
        } catch (_) {}

        _epubBookTitles[bookId] = title.isNotEmpty ? title : bookId;

        if (progress <= 0 && page <= 0) continue;

        filtered[key.toString()] = ReadingPosition(
          identifier: key.toString(),
          page: page,
          progress: progress,
          lastRead: lastRead,
          metadata: {'title': title},
        );
      } catch (_) {}
    }
  }

  /// Whether the position (keyed by [identifier]) belongs to THIS tab's type.
  bool _positionBelongsToFilter(String identifier) {
    if (widget.filter == PdfFileFilter.all) return true;

    final matchesLibrary = _completedTasks.any(
      (t) =>
          t.id == identifier ||
          t.url == identifier ||
          t.localPath == identifier,
    );
    if (matchesLibrary) return true;

    return _identifierHasType(identifier, widget.filter);
  }

  bool _identifierHasType(String id, PdfFileFilter filter) {
    final lower = id.toLowerCase();
    String? ext;
    try {
      final cleaned = lower.split('#').first.split('?').first;
      final segment = cleaned.split('/').last;
      final dot = segment.lastIndexOf('.');
      if (dot != -1 && dot < segment.length - 1) {
        ext = segment.substring(dot + 1);
      }
    } catch (_) {}

    switch (filter) {
      case PdfFileFilter.pdf:
        return ext == 'pdf';
      case PdfFileFilter.epub:
        return ext == 'epub';
      case PdfFileFilter.txt:
        return ext == 'txt';
      case PdfFileFilter.all:
      case PdfFileFilter.other:
        return true;
    }
  }

  int _calculateStreak(Map<String, ReadingPosition> positions) {
    try {
      if (positions.isEmpty) return 0;

      final dates =
          positions.values
              .map(
                (p) =>
                    DateTime(p.lastRead.year, p.lastRead.month, p.lastRead.day),
              )
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a));

      if (dates.isEmpty) return 0;

      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

      if (dates.first.difference(today).inDays > 1) return 0;

      int streak = 1;
      for (int i = 0; i < dates.length - 1; i++) {
        if (dates[i].difference(dates[i + 1]).inDays == 1) {
          streak++;
        } else {
          break;
        }
      }

      return streak;
    } catch (_) {
      return 0;
    }
  }

  // ========== Handle Incoming URL/File ==========

  Future<void> _handleIncomingUrl(String url, String? title) async {
    try {
      // Check if already PERMANENTLY downloaded
      final isDownloaded = await _libraryManager.isDownloaded(url);

      if (isDownloaded) {
        final item = await _libraryManager.getItemByUrl(url);
        if (item != null) {
          final file = await _libraryManager.getFileForItem(item);
          if (await file.exists()) {
            // Mark as opened
            await _libraryManager.markOpened(item.id);

            // Open reader directly
            _openReader(file.path, item.title, url);
            return;
          }
        }
      }

      // Not downloaded - start download
      final docTitle = title ?? _extractTitleFromUrl(url);
      _startDownload(url, docTitle);
    } catch (e, stack) {
      _logError('Handle URL error', e, stack);
      _showSnackBar('Failed to process URL');
    }
  }

  Future<void> _handleLocalFile(String path, String? title) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        _openReader(path, title ?? _extractTitleFromPath(path), null);
      } else {
        _showSnackBar('File not found');
      }
    } catch (e, stack) {
      _logError('Handle local file error', e, stack);
      _showSnackBar('Failed to open file');
    }
  }

  String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'document';
      return fileName
          .replaceAll(RegExp(r'\.[^.]+$'), '')
          .replaceAll(RegExp(r'[_-]'), ' ')
          .trim();
    } catch (_) {
      return 'Document';
    }
  }

  String _extractTitleFromPath(String path) {
    try {
      final fileName = path.split('/').last;
      return fileName
          .replaceAll(RegExp(r'\.[^.]+$'), '')
          .replaceAll(RegExp(r'[_-]'), ' ')
          .trim();
    } catch (_) {
      return 'Document';
    }
  }

  // ========== Download Management ==========

  Future<void> _startDownload(String url, String title) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = _generateFileName(url, title);
      final cancelToken = CancelToken();

      final task = DownloadTask(
        id: id,
        url: url,
        fileName: fileName,
        title: title,
        status: DownloadStatus.downloading,
        cancelToken: cancelToken,
      );

      setState(() {
        _downloadingTasks.insert(0, task);
      });

      // Switch to downloading tab
      _tabController.animateTo(0);

      await _executeDownload(task);
    } catch (e, stack) {
      _logError('Start download error', e, stack);
      _showSnackBar('Failed to start download');
    }
  }

  String _generateFileName(String url, String title) {
    try {
      final uri = Uri.parse(url);
      String ext = switch (widget.filter) {
        PdfFileFilter.pdf => 'pdf',
        PdfFileFilter.epub => 'epub',
        _ => 'txt',
      };

      final path = uri.path.toLowerCase();
      if (path.endsWith('.pdf')) {
        ext = 'pdf';
      } else if (path.endsWith('.epub')) {
        ext = 'epub';
      } else if (path.endsWith('.txt')) {
        ext = 'txt';
      }

      final safeName = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
      final truncatedName = safeName.length > 50
          ? safeName.substring(0, 50)
          : safeName;

      return '${truncatedName}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    } catch (_) {
      return 'document_${DateTime.now().millisecondsSinceEpoch}.txt';
    }
  }

  Future<void> _executeDownload(DownloadTask task) async {
    try {
      // Get PERMANENT downloads directory
      final dir = await _libraryManager.downloadsDirectory;
      final filePath = '${dir.path}/${task.fileName}';

      await _dio.download(
        task.url,
        filePath,
        cancelToken: task.cancelToken,
        onReceiveProgress: (received, total) {
          if (!mounted) return;

          final index = _downloadingTasks.indexWhere((t) => t.id == task.id);
          if (index == -1) return;

          setState(() {
            _downloadingTasks[index] = _downloadingTasks[index].copyWith(
              downloadedBytes: received,
              totalBytes: total > 0 ? total : received,
              progress: total > 0 ? received / total : 0,
              status: DownloadStatus.downloading,
            );
          });
        },
      );

      // Download completed - save to PERMANENT library
      if (mounted) {
        final index = _downloadingTasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          final file = File(filePath);
          final fileSize = await file.length();

          // Save to PERMANENT download library
          final savedItem = await _libraryManager.saveFromExistingFile(
            sourceFile: file,
            title: task.title,
            sourceUrl: task.url,
          );

          final completedTask = task.copyWith(
            id: savedItem.id,
            status: DownloadStatus.completed,
            progress: 1.0,
            localPath: filePath,
            totalBytes: fileSize,
            downloadedBytes: fileSize,
            completedAt: DateTime.now(),
          );

          setState(() {
            _downloadingTasks.removeAt(index);
            _completedTasks.insert(0, completedTask);
          });

          _showSnackBar('Download completed: ${task.title}');

          // Reload stats
          await _loadReadingStats();
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        _updateTaskStatus(task.id, DownloadStatus.cancelled);
      } else {
        _updateTaskStatus(task.id, DownloadStatus.failed, error: e.message);
        _showSnackBar('Download failed: ${e.message}');
      }
    } catch (e, stack) {
      _logError('Execute download error', e, stack);
      _updateTaskStatus(task.id, DownloadStatus.failed, error: e.toString());
    }
  }

  void _updateTaskStatus(
    String taskId,
    DownloadStatus status, {
    String? error,
  }) {
    try {
      if (!mounted) return;

      final index = _downloadingTasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        setState(() {
          _downloadingTasks[index] = _downloadingTasks[index].copyWith(
            status: status,
            error: error,
          );
        });
      }
    } catch (e, stack) {
      _logError('Update task status error', e, stack);
    }
  }

  void _pauseDownload(DownloadTask task) {
    try {
      task.cancelToken?.cancel('Paused by user');

      final index = _downloadingTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        setState(() {
          _downloadingTasks[index] = _downloadingTasks[index].copyWith(
            status: DownloadStatus.paused,
            isPaused: true,
          );
        });
      }
    } catch (e, stack) {
      _logError('Pause download error', e, stack);
    }
  }

  void _resumeDownload(DownloadTask task) {
    try {
      final index = _downloadingTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        final updatedTask = _downloadingTasks[index].copyWith(
          status: DownloadStatus.downloading,
          isPaused: false,
          cancelToken: CancelToken(),
        );

        setState(() {
          _downloadingTasks[index] = updatedTask;
        });

        _executeDownload(updatedTask);
      }
    } catch (e, stack) {
      _logError('Resume download error', e, stack);
    }
  }

  void _cancelDownload(DownloadTask task) {
    try {
      task.cancelToken?.cancel('Cancelled by user');

      setState(() {
        _downloadingTasks.removeWhere((t) => t.id == task.id);
      });

      // Delete partial file
      _deletePartialFile(task);
    } catch (e, stack) {
      _logError('Cancel download error', e, stack);
    }
  }

  Future<void> _deletePartialFile(DownloadTask task) async {
    try {
      final dir = await _libraryManager.downloadsDirectory;
      final file = File('${dir.path}/${task.fileName}');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  void _retryDownload(DownloadTask task) {
    try {
      final index = _downloadingTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        final updatedTask = task.copyWith(
          status: DownloadStatus.downloading,
          progress: 0,
          downloadedBytes: 0,
          error: null,
          cancelToken: CancelToken(),
        );

        setState(() {
          _downloadingTasks[index] = updatedTask;
        });

        _executeDownload(updatedTask);
      }
    } catch (e, stack) {
      _logError('Retry download error', e, stack);
    }
  }

  // ========== File Operations ==========

  void _openReader(String path, String title, String? url) {
    try {
      final Widget reader = widget.filter == PdfFileFilter.txt
          ? TxtReaderScreen(
              txtUrl: url ?? 'file://$path',
              title: title,
              identifier: url ?? path,
            )
          : UnifiedReaderScreen(
              documentUrl: path,
              title: title,
              identifier: url ?? path,
              source: 'local',
            );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => reader),
      ).then((_) {
        // Reload library + stats when returning from reader
        _loadDownloadedFiles();
        _loadReadingStats();
      });
    } catch (e, stack) {
      _logError('Open reader error', e, stack);
      _showSnackBar('Failed to open file');
    }
  }

  Future<void> _shareFile(DownloadTask task) async {
    try {
      if (task.localPath != null && await File(task.localPath!).exists()) {
        await SharePlus.instance.share(
          ShareParams(
            title: task.title,
            files: [XFile(task.localPath!)],
            subject: task.title,
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(
            title: task.title,
            subject: task.title,
            text: 'Check out: ${task.title}\n${task.url}',
          ),
        );
      }
    } catch (e, stack) {
      _logError('Share error', e, stack);
      _showSnackBar('Failed to share');
    }
  }

  Future<void> _renameFile(DownloadTask task) async {
    try {
      final controller = TextEditingController(text: task.title);

      final newName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'New name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Rename'),
            ),
          ],
        ),
      );

      if (newName != null && newName.isNotEmpty && newName != task.title) {
        await _libraryManager.rename(task.id, newName);
        await _loadDownloadedFiles();
        _showSnackBar('Renamed successfully');
      }
    } catch (e, stack) {
      _logError('Rename error', e, stack);
      _showSnackBar('Failed to rename');
    }
  }

  Future<void> _deleteFile(DownloadTask task) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete File'),
          content: Text(
            'Are you sure you want to delete "${task.title}"?\n\nThis cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // Delete from PERMANENT library
        await _libraryManager.delete(task.id);

        // Also clear reading position
        await _storageManager.deleteReadingPosition(
          task.url.isNotEmpty ? task.url : task.localPath ?? task.id,
        );

        setState(() {
          _completedTasks.removeWhere((t) => t.id == task.id);
        });

        await _loadReadingStats();
        _showSnackBar('Deleted successfully');
      }
    } catch (e, stack) {
      _logError('Delete error', e, stack);
      _showSnackBar('Failed to delete');
    }
  }

  // ========== Add New Download Dialog ==========

  void _showAddDownloadDialog() {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _AddDownloadSheet(
          sheetTitle: widget.addSheetTitle,
          urlHint: widget.addSheetUrlHint,
          onUrlSubmit: (url, title) {
            Navigator.pop(context);
            _startDownload(url, title);
          },
          onPickFile: () async {
            Navigator.pop(context);
            await _pickLocalFile();
          },
        ),
      );
    } catch (e, stack) {
      _logError('Show add dialog error', e, stack);
    }
  }

  Future<void> _pickLocalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: widget.pickExtensions,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          // Import file to permanent storage
          final sourceFile = File(file.path!);
          final title = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

          final savedItem = await _libraryManager.saveFromExistingFile(
            sourceFile: sourceFile,
            title: title,
          );

          await _loadDownloadedFiles();

          // Open the file
          final downloadedFile = await _libraryManager.getFileForItem(
            savedItem,
          );
          _openReader(downloadedFile.path, savedItem.title, null);
        }
      }
    } catch (e, stack) {
      _logError('Pick file error', e, stack);
      _showSnackBar('Failed to import file');
    }
  }

  // ========== Helpers ==========

  void _logError(String message, dynamic error, StackTrace? stack) {
    debugPrint('⚠️ TextDownloadsScreen: $message - $error');
    if (stack != null) {
      debugPrint('Stack: ${stack.toString().split('\n').take(3).join('\n')}');
    }
  }

  void _showSnackBar(String message) {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final mediaQuery = MediaQuery.of(context);
      _screenSize = mediaQuery.size;
      _safeArea = mediaQuery.padding;
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _downloadingScrollController.dispose();
    _downloadedScrollController.dispose();
    _analyticsScrollController.dispose();
    _dio.close();
    super.dispose();
  }

  // ========== Build ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildCenteredLoader(message: 'Loading library...')
          : _error != null
          ? _buildErrorView()
          : _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.libraryTitle),
      centerTitle: false,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () async {
            setState(() => _isLoading = true);
            await _loadDownloadedFiles();
            await _loadReadingStats();
            setState(() => _isLoading = false);
          },
          tooltip: 'Refresh',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.downloading_rounded, size: 18),
                const SizedBox(width: 6),
                const Text('Active'),
                if (_downloadingTasks.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildBadge(_downloadingTasks.length),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_rounded, size: 18),
                const SizedBox(width: 6),
                const Text('Library'),
                if (_completedTasks.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildBadge(_completedTasks.length),
                ],
              ],
            ),
          ),
          const Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.analytics_rounded, size: 18),
                SizedBox(width: 6),
                Text('Stats'),
              ],
            ),
          ),
        ],
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCenteredLoader({String? message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingAnimationWidget.progressiveDots(
            color: Theme.of(context).colorScheme.primary,
            size: 50,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: Theme.of(context).hintColor)),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _error ?? 'Something went wrong',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDownloadingTab(),
        _buildDownloadedTab(),
        _buildAnalyticsTab(),
      ],
    );
  }

  Widget? _buildFAB() {
    // Show FAB on downloading and downloaded tabs
    if (_tabController.index == 2) return null;

    return FloatingActionButton.extended(
      onPressed: _showAddDownloadDialog,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add'),
    );
  }

  // ========== Downloading Tab ==========

  Widget _buildDownloadingTab() {
    if (_downloadingTasks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.cloud_download_rounded,
        title: 'No Active Downloads',
        subtitle: 'Tap the + button to add a new download',
      );
    }

    return ListView.builder(
      controller: _downloadingScrollController,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 100 + _safeArea.bottom),
      itemCount: _downloadingTasks.length,
      itemBuilder: (context, index) {
        try {
          return _DownloadingTaskCard(
            task: _downloadingTasks[index],
            onPause: () => _pauseDownload(_downloadingTasks[index]),
            onResume: () => _resumeDownload(_downloadingTasks[index]),
            onCancel: () => _cancelDownload(_downloadingTasks[index]),
            onRetry: () => _retryDownload(_downloadingTasks[index]),
          );
        } catch (_) {
          return const SizedBox.shrink();
        }
      },
    );
  }

  // ========== Downloaded Tab ==========

  Widget _buildDownloadedTab() {
    if (_completedTasks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_open_rounded,
        title: 'No Downloaded Files',
        subtitle: widget.emptyDownloadedSubtitle,
      );
    }

    return ListView.builder(
      controller: _downloadedScrollController,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 100 + _safeArea.bottom),
      itemCount: _completedTasks.length,
      itemBuilder: (context, index) {
        try {
          final task = _completedTasks[index];
          return _DownloadedFileCard(
            task: task,
            progress:
                _readingStats.progressByBook[task.url] ??
                _readingStats.progressByBook[task.localPath ?? ''] ??
                0.0,
            onTap: () {
              if (task.localPath != null) {
                _openReader(task.localPath!, task.title, task.url);
              } else {
                _showSnackBar('File not found. Re-download required.');
              }
            },
            onShare: () => _shareFile(task),
            onRename: () => _renameFile(task),
            onDelete: () => _deleteFile(task),
          );
        } catch (_) {
          return const SizedBox.shrink();
        }
      },
    );
  }

  // ========== Analytics Tab ==========

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      controller: _analyticsScrollController,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + _safeArea.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 24),
          _buildSectionTitle('Reading Progress'),
          const SizedBox(height: 12),
          _buildReadingProgressList(),
          const SizedBox(height: 24),
          _buildResetStatsButton(),
          const SizedBox(height: 24),
          _buildSectionTitle('Storage'),
          const SizedBox(height: 12),
          _buildStorageCard(),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _StatCard(
              icon: Icons.library_books_rounded,
              label: 'Total Books',
              value: '${_readingStats.totalBooks}',
              color: Colors.blue,
            ),
            _StatCard(
              icon: Icons.check_circle_rounded,
              label: 'Completed',
              value: '${_readingStats.booksRead}',
              color: Colors.green,
            ),
            _StatCard(
              icon: Icons.menu_book_rounded,
              label: 'Pages Read',
              value: '${_readingStats.pagesRead}',
              color: Colors.purple,
            ),
            _StatCard(
              icon: Icons.local_fire_department_rounded,
              label: 'Day Streak',
              value: '${_readingStats.currentStreak}',
              color: Colors.orange,
            ),
          ],
        );
      },
    );
  }

  Widget _buildResetStatsButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _resetReadingStats,
        icon: const Icon(Icons.restart_alt_rounded),
        label: const Text('Reset Reading Stats'),
      ),
    );
  }

  Future<void> _resetReadingStats() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Reading Stats'),
        content: const Text(
          'This will clear all reading progress, pages read and day streak.\n'
          'Your downloaded files will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storageManager.clearReadingProgress();
      await _loadReadingStats();
      if (mounted) setState(() {});
      _showSnackBar('Reading stats reset');
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildReadingProgressList() {
    if (_readingStats.progressByBook.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No reading progress yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start reading to track your progress',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: _readingStats.progressByBook.entries.take(5).map((entry) {
          final bookTitle = _getBookTitle(entry.key);
          return _ProgressItem(title: bookTitle, progress: entry.value);
        }).toList(),
      ),
    );
  }

  String _getBookTitle(String identifier) {
    try {
      final task = _completedTasks.firstWhere(
        (t) =>
            t.id == identifier ||
            t.url == identifier ||
            t.localPath == identifier,
        orElse: () => DownloadTask(
          id: '',
          url: '',
          fileName: '',
          title: '',
        ),
      );
      if (task.title.trim().isNotEmpty) return task.title;
      final epubTitle = _epubBookTitles[identifier];
      if (epubTitle != null && epubTitle.trim().isNotEmpty) return epubTitle;
      return _extractTitleFromUrl(identifier);
    } catch (_) {
      return 'Unknown';
    }
  }

  Widget _buildStorageCard() {
    return FutureBuilder<int>(
      future: _libraryManager.totalSize,
      builder: (context, snapshot) {
        final size = snapshot.data ?? 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storage_rounded, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Storage Used',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        DocumentUtils.formatFileSize(size),
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _clearCache,
                  child: const Text('Clear Cache'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _clearCache() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Cache'),
          content: const Text(
            'This will clear cached translations, temporary files and '
            'reset all reading progress/stats.\n\n'
            'Your downloaded books will NOT be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _cacheManager.clearCache();
        await _storageManager.clearTranslationsCache();
        await _storageManager.clearReadingProgress();
        await _loadReadingStats();
        if (mounted) setState(() {});
        _showSnackBar('Cache cleared and reading stats reset');
      }
    } catch (e, stack) {
      _logError('Clear cache error', e, stack);
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ========== Downloading Task Card ==========

class _DownloadingTaskCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  const _DownloadingTaskCard({
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: task.fileColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(task.fileIcon, color: task.fileColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          color: _getStatusColor(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress
            if (task.status == DownloadStatus.downloading ||
                task.status == DownloadStatus.paused) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(task.progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${DocumentUtils.formatFileSize(task.downloadedBytes)} / ${DocumentUtils.formatFileSize(task.totalBytes)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Error message
            if (task.status == DownloadStatus.failed && task.error != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.error!,
                        style: TextStyle(color: Colors.red[400], fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.status == DownloadStatus.downloading)
                  TextButton.icon(
                    onPressed: onPause,
                    icon: const Icon(Icons.pause_rounded, size: 18),
                    label: const Text('Pause'),
                  ),
                if (task.status == DownloadStatus.paused)
                  TextButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Resume'),
                  ),
                if (task.status == DownloadStatus.failed)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onCancel,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.red[400],
                  ),
                  label: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.red[400]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (task.status) {
      case DownloadStatus.pending:
        return 'Waiting...';
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
      default:
        return '';
    }
  }

  Color _getStatusColor(BuildContext context) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.failed:
        return Colors.red;
      default:
        return Theme.of(context).hintColor;
    }
  }
}

// ========== Downloaded File Card (with Progress) ==========

class _DownloadedFileCard extends StatelessWidget {
  final DownloadTask task;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _DownloadedFileCard({
    required this.task,
    required this.progress,
    required this.onTap,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  // File icon with progress indicator
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: task.fileColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          task.fileIcon,
                          color: task.fileColor,
                          size: 26,
                        ),
                      ),
                      if (progress > 0 && progress < 1)
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 3,
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation(task.fileColor),
                          ),
                        ),
                      if (progress >= 0.9)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              task.fileExtension.toUpperCase(),
                              style: TextStyle(
                                color: task.fileColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DocumentUtils.formatFileSize(task.totalBytes),
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 12,
                              ),
                            ),
                            if (progress > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${(progress * 100).toInt()}% read',
                                style: TextStyle(
                                  color: Colors.green[600],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Theme.of(context).hintColor,
                    ),
                    onSelected: (action) {
                      switch (action) {
                        case 'read':
                          onTap();
                          break;
                        case 'share':
                          onShare();
                          break;
                        case 'rename':
                          onRename();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'read',
                        child: Row(
                          children: [
                            Icon(Icons.auto_stories_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Read'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Share'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_rounded,
                              size: 20,
                              color: Colors.red[400],
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Delete',
                              style: TextStyle(color: Colors.red[400]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Progress bar
              if (progress > 0 && progress < 1) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(Colors.green[400]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ========== Stat Card ==========

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== Progress Item ==========

class _ProgressItem extends StatelessWidget {
  final String title;
  final double progress;

  const _ProgressItem({required this.title, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

// ========== Add Download Sheet ==========

class _AddDownloadSheet extends StatefulWidget {
  final Function(String url, String title) onUrlSubmit;
  final VoidCallback onPickFile;
  final String sheetTitle;
  final String urlHint;

  const _AddDownloadSheet({
    required this.onUrlSubmit,
    required this.onPickFile,
    this.sheetTitle = 'Add Text File',
    this.urlHint = 'https://example.com/document.txt',
  });

  @override
  State<_AddDownloadSheet> createState() => _AddDownloadSheetState();
}

class _AddDownloadSheetState extends State<_AddDownloadSheet> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_validate);
  }

  void _validate() {
    try {
      final url = _urlController.text.trim();
      final isValid = Uri.tryParse(url)?.hasAbsolutePath ?? false;
      if (_isValid != isValid) {
        setState(() => _isValid = isValid);
      }

      // Auto-fill title from URL
      if (isValid && _titleController.text.isEmpty) {
        final uri = Uri.parse(url);
        final fileName = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : '';
        _titleController.text = fileName
            .replaceAll(RegExp(r'\.[^.]+$'), '')
            .replaceAll(RegExp(r'[_-]'), ' ')
            .trim();
      }
    } catch (_) {}
  }

  void _submit() {
    try {
      if (!_isValid) return;

      final url = _urlController.text.trim();
      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : 'Document';
      widget.onUrlSubmit(url, title);
    } catch (_) {}
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        _urlController.text = data!.text!;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              widget.sheetTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // URL Input
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: widget.urlHint,
                prefixIcon: const Icon(Icons.link_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded),
                  onPressed: _pasteFromClipboard,
                  tooltip: 'Paste',
                ),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Title Input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                hintText: 'Document title',
                prefixIcon: Icon(Icons.title_rounded),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),

            // Download Button
            FilledButton.icon(
              onPressed: _isValid ? _submit : null,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),

            const SizedBox(height: 16),

            // Pick File Button
            OutlinedButton.icon(
              onPressed: widget.onPickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Select Local File'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

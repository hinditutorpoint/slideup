import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_constants.dart';
import 'models/epub_book.dart';
import 'providers/epub_provider.dart';
import 'widgets/active_downloads_tab.dart';
import 'widgets/library_tab.dart';

/// Downloaded EPUB Catalogue with Two Tabs
class DownloadedEpubCatalogue extends ConsumerStatefulWidget {
  final String? url;
  final String? localFilePath;
  final String? bookTitle;
  final String? bookAuthor;
  final String? coverUrl;

  const DownloadedEpubCatalogue({
    super.key,
    this.url,
    this.localFilePath,
    this.bookTitle,
    this.bookAuthor,
    this.coverUrl,
  });

  @override
  ConsumerState<DownloadedEpubCatalogue> createState() =>
      _DownloadedEpubCatalogueState();
}

class _DownloadedEpubCatalogueState
    extends ConsumerState<DownloadedEpubCatalogue>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  bool _isInitializing = true;
  bool _isWakelockEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
      _listenToDownloads();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _setNormalSystemUI();
    _disableWakelock();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setNormalSystemUI();
          _checkWakelock();
        }
      });
    }
  }

  void _setNormalSystemUI() {
    try {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    } catch (_) {}
  }

  Future<void> _enableWakelock() async {
    if (!_isWakelockEnabled) {
      try {
        await WakelockPlus.enable();
        _isWakelockEnabled = true;
      } catch (_) {}
    }
  }

  Future<void> _disableWakelock() async {
    if (_isWakelockEnabled) {
      try {
        await WakelockPlus.disable();
        _isWakelockEnabled = false;
      } catch (_) {}
    }
  }

  void _checkWakelock() {
    final downloadState = ref.read(downloadProvider);
    final hasActive = downloadState.tasks.any(
      (t) => t.status == DownloadStatus.downloading,
    );
    if (hasActive) {
      _enableWakelock();
    } else {
      _disableWakelock();
    }
  }

  void _listenToDownloads() {
    ref.listenManual(downloadProvider, (previous, next) {
      _checkWakelock();

      // Auto-switch to library when download completes
      final prevCompleted =
          previous?.tasks
              .where((t) => t.status == DownloadStatus.completed)
              .length ??
          0;
      final nextCompleted = next.tasks
          .where((t) => t.status == DownloadStatus.completed)
          .length;

      if (nextCompleted > prevCompleted) {
        // New download completed, refresh library
        ref.read(libraryProvider.notifier).loadLibrary();
      }
    });
  }

  Future<void> _initialize() async {
    try {
      setState(() => _isInitializing = true);
      await ref.read(libraryProvider.notifier).loadLibrary();

      // Handle URL if provided
      if (widget.url != null && widget.url!.isNotEmpty) {
        _handleUrl(widget.url!);
      }

      // Handle local file if provided
      if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
        _handleLocalFile(widget.localFilePath!);
      }

      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  void _handleUrl(String url) {
    // Check if already downloading
    final downloadState = ref.read(downloadProvider);
    final existing = downloadState.tasks.any((t) => t.url == url);

    if (existing) {
      _tabController.animateTo(0); // Switch to downloads tab
      return;
    }

    // Check if already in library
    final libraryState = ref.read(libraryProvider);
    final book = libraryState.books.cast<EpubBook?>().firstWhere(
      (b) => b?.sourceUrl == url,
      orElse: () => null,
    );

    if (book != null && book.isDownloaded) {
      _tabController.animateTo(1); // Switch to library tab
      return;
    }

    // Start download
    _startDownload(url, widget.bookTitle ?? _extractTitle(url));
  }

  Future<void> _handleLocalFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    final result = await ref
        .read(libraryProvider.notifier)
        .addBookFromFile(filePath);
    if (result.isSuccess) {
      _tabController.animateTo(1); // Switch to library
    }
  }

  void _startDownload(String url, String title) {
    final bookId = 'book_${DateTime.now().millisecondsSinceEpoch}';
    ref
        .read(downloadProvider.notifier)
        .startDownload(url: url, bookId: bookId, fileName: '$title.epub');
    _tabController.animateTo(0); // Switch to downloads tab
    _enableWakelock();
  }

  String _extractTitle(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        String name = uri.pathSegments.last;
        if (name.toLowerCase().endsWith('.epub')) {
          name = name.substring(0, name.length - 5);
        }
        return name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
      }
    } catch (_) {}
    return 'Unknown Book';
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = ref.watch(activeDownloadsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Books'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.downloading, size: 18),
                  const SizedBox(width: 6),
                  const Text('Downloads'),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.library_books, size: 18),
                  SizedBox(width: 6),
                  Text('Library'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_file',
                child: Row(
                  children: [
                    Icon(Icons.file_open, size: 20),
                    SizedBox(width: 12),
                    Text('Add from File'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add_url',
                child: Row(
                  children: [
                    Icon(Icons.link, size: 20),
                    SizedBox(width: 12),
                    Text('Add from URL'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_downloads',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20),
                    SizedBox(width: 12),
                    Text('Clear Downloads'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                ActiveDownloadsTab(
                  onDownloadComplete: () {
                    ref.read(libraryProvider.notifier).loadLibrary();
                  },
                ),
                LibraryTab(onAddBook: () => _showAddOptions()),
              ],
            ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'add_file':
        _addFromFile();
        break;
      case 'add_url':
        _showAddUrlDialog();
        break;
      case 'clear_downloads':
        ref.read(downloadProvider.notifier).clearAll();
        break;
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  radius: 20,
                  child: Icon(Icons.file_open, size: 20),
                ),
                title: const Text('Add from File'),
                subtitle: const Text('Select EPUB from device'),
                onTap: () {
                  Navigator.pop(context);
                  _addFromFile();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  radius: 20,
                  child: Icon(Icons.link, size: 20),
                ),
                title: const Text('Add from URL'),
                subtitle: const Text('Download from web link'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddUrlDialog();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            final result = await ref
                .read(libraryProvider.notifier)
                .addBookFromFile(filePath);

            if (result.isSuccess) {
              _tabController.animateTo(1); // Switch to library tab
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Book added successfully: ${result.requireData.title}',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to add book: ${result.error}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddUrlDialog() {
    final urlController = TextEditingController();
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add from URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'EPUB URL',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                prefixIcon: Icon(Icons.title),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final url = urlController.text.trim();
              final title = titleController.text.trim();
              if (url.isNotEmpty) {
                _startDownload(
                  url,
                  title.isNotEmpty ? title : _extractTitle(url),
                );
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}

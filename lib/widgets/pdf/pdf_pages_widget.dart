import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../providers/pdf_provider.dart';

class PdfPagesWidget extends ConsumerStatefulWidget {
  final String? filePath;
  final String? fileName;
  final Function(int)? onPageSelected;
  final int? currentPage;

  const PdfPagesWidget({
    super.key,
    this.filePath,
    this.fileName,
    this.onPageSelected,
    this.currentPage,
  });

  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  @override
  ConsumerState<PdfPagesWidget> createState() => _PdfPagesWidgetState();
}

class _PdfPagesWidgetState extends ConsumerState<PdfPagesWidget> {
  // State variables
  bool _isLoading = false;
  String? _error;
  bool _isGridView = true;
  bool _showingFolders = true;
  String? _currentFolderPath;

  // Data lists
  List<ExtractedFolder> _folders = [];
  List<ExtractedPageInfo> _extractedPages = [];

  // Scroll controller
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(PdfPagesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filePath != oldWidget.filePath) {
      _initialize();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== INITIALIZATION ====================

  Future<void> _initialize() async {
    if (widget.hasFile) {
      _showingFolders = false;
      await _loadCurrentFilePages();
    } else {
      _showingFolders = true;
      await _loadFolders();
    }
  }

  // ==================== DATA LOADING ====================

  Future<void> _loadFolders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final folders = await ref
          .read(pdfStateProvider.notifier)
          .getExtractedFolders(ExtractedType.pages);

      if (mounted) {
        setState(() {
          _folders = folders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load folders: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCurrentFilePages() async {
    if (!widget.hasFile) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pdfState = ref.read(pdfStateProvider);
      final extractDir = await ref
          .read(pdfStateProvider.notifier)
          .getExtractionDirectory(ExtractedType.pages);

      // Get existing extracted pages
      final existingPages = await ref
          .read(pdfStateProvider.notifier)
          .getExtractedPagesFromFolder(extractDir);

      // Create list for all pages (extracted or not)
      List<ExtractedPageInfo> allPages = [];
      final totalPages = pdfState.pageCount > 0 ? pdfState.pageCount : 0;

      for (int i = 1; i <= totalPages; i++) {
        // Find existing extracted page or create placeholder
        ExtractedPageInfo? existingPage;
        for (final page in existingPages) {
          if (page.pageNumber == i) {
            existingPage = page;
            break;
          }
        }

        if (existingPage != null) {
          allPages.add(existingPage);
        } else {
          // Create placeholder for non-extracted page
          allPages.add(
            ExtractedPageInfo(
              pageNumber: i,
              filePath: '$extractDir/page_$i.png',
              extractedAt: DateTime.now(),
              fileSize: 0,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _extractedPages = allPages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load pages: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFolderPages(String folderPath) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pages = await ref
          .read(pdfStateProvider.notifier)
          .getExtractedPagesFromFolder(folderPath);

      if (mounted) {
        setState(() {
          _extractedPages = pages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load pages: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ==================== EXTRACTION ====================

  Future<void> _extractAllPages() async {
    if (!widget.hasFile) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pages = await ref
          .read(pdfStateProvider.notifier)
          .extractAllPages(
            onProgress: (current, total) {
              // Progress callback if needed
            },
          );

      if (mounted) {
        setState(() {
          _extractedPages = pages;
          _isLoading = false;
        });
        _showSuccessMessage('Extracted ${pages.length} pages');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to extract pages: $e';
          _isLoading = false;
        });
        _showErrorMessage('Failed to extract pages');
      }
    }
  }

  Future<void> _extractSinglePage(int pageNumber) async {
    if (!widget.hasFile) return;

    try {
      final page = await ref
          .read(pdfStateProvider.notifier)
          .extractSinglePage(pageNumber);

      // Update the page in list
      final index = _extractedPages.indexWhere(
        (p) => p.pageNumber == pageNumber,
      );
      if (index != -1 && mounted) {
        setState(() {
          _extractedPages[index] = page;
        });
        _showSuccessMessage('Page $pageNumber extracted');
      }
    } catch (e) {
      _showErrorMessage('Failed to extract page $pageNumber');
    }
  }

  // ==================== HELPER METHODS ====================

  bool _isPageExtracted(int pageNumber) {
    for (final page in _extractedPages) {
      if (page.pageNumber == pageNumber) {
        return page.fileSize > 0 && File(page.filePath).existsSync();
      }
    }
    return false;
  }

  ExtractedPageInfo? _getPageInfo(int pageNumber) {
    for (final page in _extractedPages) {
      if (page.pageNumber == pageNumber) {
        return page;
      }
    }
    return null;
  }

  int get _extractedCount {
    int count = 0;
    for (final page in _extractedPages) {
      if (page.fileSize > 0 && File(page.filePath).existsSync()) {
        count++;
      }
    }
    return count;
  }

  void _navigateBack() {
    setState(() {
      _currentFolderPath = null;
      _showingFolders = true;
      _extractedPages.clear();
    });
    _loadFolders();
  }

  // ==================== FOLDER ACTIONS ====================

  Future<void> _openFolder(ExtractedFolder folder) async {
    setState(() {
      _currentFolderPath = folder.path;
      _showingFolders = false;
    });
    await _loadFolderPages(folder.path);
  }

  Future<void> _shareFolder(ExtractedFolder folder) async {
    try {
      final dir = Directory(folder.path);
      final files = <XFile>[];

      await for (final entity in dir.list()) {
        if (entity is File) {
          final ext = entity.path.toLowerCase();
          if (ext.endsWith('.png') || ext.endsWith('.jpg')) {
            files.add(XFile(entity.path));
          }
        }
      }

      if (files.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            title: 'Share Pages from ${folder.name}',
            files: files,
            subject: 'Pages from ${folder.name}',
          ),
        );
      } else {
        _showErrorMessage('No files to share');
      }
    } catch (e) {
      _showErrorMessage('Failed to share: $e');
    }
  }

  Future<void> _deleteFolder(ExtractedFolder folder) async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete Folder?',
      message:
          'Delete "${folder.name}" and all ${folder.itemCount} pages? This cannot be undone.',
    );

    if (confirmed == true) {
      try {
        await ref
            .read(pdfStateProvider.notifier)
            .deleteExtractedFolder(folder.path);
        await _loadFolders();
        _showSuccessMessage('Folder deleted');
      } catch (e) {
        _showErrorMessage('Failed to delete folder');
      }
    }
  }

  // ==================== PAGE ACTIONS ====================

  Future<void> _sharePage(ExtractedPageInfo page) async {
    if (!File(page.filePath).existsSync()) {
      _showErrorMessage('Page not extracted yet');
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Share Page ${page.pageNumber}',
          files: [XFile(page.filePath)],
          subject: 'Page ${page.pageNumber}',
        ),
      );
    } catch (e) {
      _showErrorMessage('Failed to share page');
    }
  }

  Future<void> _deletePage(ExtractedPageInfo page, int index) async {
    if (!File(page.filePath).existsSync()) {
      _showErrorMessage('Page not extracted');
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Delete Page?',
      message: 'Delete page ${page.pageNumber}? This cannot be undone.',
    );

    if (confirmed == true) {
      try {
        await ref
            .read(pdfStateProvider.notifier)
            .deleteExtractedItem(page.filePath);

        if (widget.hasFile) {
          // Replace with placeholder
          setState(() {
            _extractedPages[index] = ExtractedPageInfo(
              pageNumber: page.pageNumber,
              filePath: page.filePath,
              extractedAt: DateTime.now(),
              fileSize: 0,
            );
          });
        } else {
          // Remove from list
          setState(() {
            _extractedPages.removeAt(index);
          });
        }

        _showSuccessMessage('Page deleted');
      } catch (e) {
        _showErrorMessage('Failed to delete page');
      }
    }
  }

  void _showPageProperties(ExtractedPageInfo page) {
    final pdfState = ref.read(pdfStateProvider);
    final isExtracted = page.fileSize > 0 && File(page.filePath).existsSync();
    final isBookmarked = pdfState.bookmarks.contains(page.pageNumber);
    final highlightCount = pdfState.highlights[page.pageNumber]?.length ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Page ${page.pageNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropertyRow('Page Number', '${page.pageNumber}'),
            _buildPropertyRow(
              'Status',
              isExtracted ? 'Extracted' : 'Not Extracted',
            ),
            if (isExtracted) ...[
              _buildPropertyRow('File Size', _formatFileSize(page.fileSize)),
              _buildPropertyRow(
                'Extracted At',
                _formatDateTime(page.extractedAt),
              ),
            ],
            _buildPropertyRow('Bookmarked', isBookmarked ? 'Yes' : 'No'),
            _buildPropertyRow('Highlights', '$highlightCount'),
            if (isExtracted) _buildPropertyRow('Path', page.filePath),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ==================== UI HELPERS ====================

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return 'Unknown';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ==================== BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    final pdfState = ref.watch(pdfStateProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Column(
      children: [
        _buildHeader(pdfState, isCompact),
        if (_isLoading) _buildLoadingIndicator(pdfState),
        if (_error != null) _buildErrorWidget(),
        Expanded(
          child: _showingFolders && !widget.hasFile
              ? _buildFoldersList(isCompact)
              : _buildPagesList(pdfState, isCompact),
        ),
      ],
    );
  }

  Widget _buildHeader(PdfState pdfState, bool isCompact) {
    final totalPages = pdfState.pageCount;
    final extracted = _extractedCount;
    final canExtract = widget.hasFile && !_isLoading;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getHeaderTitle(pdfState),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isCompact ? 14 : 16,
                      ),
                    ),
                    if (_currentFolderPath != null && !widget.hasFile)
                      GestureDetector(
                        onTap: _navigateBack,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back,
                                size: 14,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Back to folders',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!_showingFolders || widget.hasFile) ...[
                _buildViewModeToggle(isCompact),
                const SizedBox(width: 8),
              ],
              if (canExtract)
                ElevatedButton.icon(
                  onPressed: _extractAllPages,
                  icon: Icon(Icons.download, size: isCompact ? 16 : 18),
                  label: Text(
                    'Extract All',
                    style: TextStyle(fontSize: isCompact ? 12 : 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 12 : 16,
                      vertical: isCompact ? 8 : 10,
                    ),
                  ),
                ),
            ],
          ),
          if (widget.hasFile && totalPages > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildProgressBar(extracted, totalPages),
            ),
        ],
      ),
    );
  }

  String _getHeaderTitle(PdfState pdfState) {
    if (_showingFolders && !widget.hasFile) {
      return '${_folders.length} Folder${_folders.length != 1 ? 's' : ''}';
    } else if (widget.hasFile) {
      return '${pdfState.pageCount} Pages';
    } else {
      return '${_extractedPages.length} Page${_extractedPages.length != 1 ? 's' : ''}';
    }
  }

  Widget _buildViewModeToggle(bool isCompact) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewModeButton(
            isGrid: true,
            icon: Icons.grid_view,
            isCompact: isCompact,
          ),
          _buildViewModeButton(
            isGrid: false,
            icon: Icons.list,
            isCompact: isCompact,
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton({
    required bool isGrid,
    required IconData icon,
    required bool isCompact,
  }) {
    final isSelected = _isGridView == isGrid;

    return InkWell(
      onTap: () => setState(() => _isGridView = isGrid),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 6 : 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: isCompact ? 18 : 20,
          color: isSelected
              ? Theme.of(context).primaryColor
              : Theme.of(context).iconTheme.color,
        ),
      ),
    );
  }

  Widget _buildProgressBar(int extracted, int total) {
    final progress = total > 0 ? extracted / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$extracted of $total extracted',
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade700,
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator(PdfState pdfState) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (pdfState.loadingProgress > 0)
            LinearProgressIndicator(value: pdfState.loadingProgress)
          else
            const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            pdfState.loadingMessage ?? 'Loading...',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  // ==================== FOLDERS LIST ====================

  Widget _buildFoldersList(bool isCompact) {
    if (_folders.isEmpty && !_isLoading) {
      return _buildEmptyState(
        icon: Icons.folder_open,
        title: 'No Extracted Pages',
        subtitle: 'Open a PDF to extract pages',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        return _buildFolderCard(_folders[index], isCompact);
      },
    );
  }

  Widget _buildFolderCard(ExtractedFolder folder, bool isCompact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: isCompact ? 44 : 48,
          height: isCompact ? 44 : 48,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.folder,
            color: Theme.of(context).primaryColor,
            size: isCompact ? 22 : 24,
          ),
        ),
        title: Text(
          folder.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: isCompact ? 14 : 16),
        ),
        subtitle: Text(
          '${folder.itemCount} page${folder.itemCount != 1 ? 's' : ''} • ${_formatDateTime(folder.createdAt)}',
          style: TextStyle(fontSize: isCompact ? 11 : 12),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: isCompact ? 18 : 20),
          onSelected: (value) => _handleFolderAction(value, folder),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.folder_open, size: 18),
                  SizedBox(width: 12),
                  Text('Open'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 18),
                  SizedBox(width: 12),
                  Text('Share All'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _openFolder(folder),
      ),
    );
  }

  void _handleFolderAction(String action, ExtractedFolder folder) {
    switch (action) {
      case 'open':
        _openFolder(folder);
        break;
      case 'share':
        _shareFolder(folder);
        break;
      case 'delete':
        _deleteFolder(folder);
        break;
    }
  }

  // ==================== PAGES LIST ====================

  Widget _buildPagesList(PdfState pdfState, bool isCompact) {
    if (_extractedPages.isEmpty && !_isLoading) {
      return _buildEmptyState(
        icon: Icons.insert_drive_file,
        title: 'No Pages',
        subtitle: widget.hasFile
            ? 'Tap "Extract All" to extract pages'
            : 'Select a folder to view pages',
      );
    }

    if (_isGridView) {
      return _buildPagesGrid(pdfState, isCompact);
    } else {
      return _buildPagesListView(pdfState, isCompact);
    }
  }

  Widget _buildPagesGrid(PdfState pdfState, bool isCompact) {
    final crossAxisCount = isCompact ? 2 : 3;

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _extractedPages.length,
      itemBuilder: (context, index) {
        return _buildPageGridItem(
          _extractedPages[index],
          index,
          pdfState,
          isCompact,
        );
      },
    );
  }

  Widget _buildPageGridItem(
    ExtractedPageInfo page,
    int index,
    PdfState pdfState,
    bool isCompact,
  ) {
    final pageNum = page.pageNumber;
    final isCurrentPage = pageNum == widget.currentPage;
    final isExtracted = page.fileSize > 0 && File(page.filePath).existsSync();
    final isBookmarked = pdfState.bookmarks.contains(pageNum);
    final hasHighlights = pdfState.highlights.containsKey(pageNum);

    return GestureDetector(
      onTap: () => widget.onPageSelected?.call(pageNum),
      onLongPress: () => _showPageOptionsSheet(page, index, pdfState),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: Border.all(
            color: isCurrentPage
                ? Theme.of(context).primaryColor
                : Colors.grey.shade700,
            width: isCurrentPage ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isCurrentPage
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Page thumbnail or placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: isExtracted
                  ? Image.file(
                      File(page.filePath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          _buildPagePlaceholder(pageNum),
                    )
                  : _buildPagePlaceholder(pageNum),
            ),

            // Not extracted overlay
            if (!isExtracted)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Not Extracted',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Page number overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrentPage
                      ? Theme.of(context).primaryColor
                      : Colors.black54,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(7),
                  ),
                ),
                child: Text(
                  'Page $pageNum',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Bookmark & Highlight indicators
            if (isBookmarked || hasHighlights)
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBookmarked)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.bookmark,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    if (isBookmarked && hasHighlights) const SizedBox(width: 4),
                    if (hasHighlights)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.highlight,
                          color: Colors.black,
                          size: 12,
                        ),
                      ),
                  ],
                ),
              ),

            // Extract button for single page
            if (!isExtracted && widget.hasFile)
              Positioned(
                top: 4,
                left: 4,
                child: GestureDetector(
                  onTap: () => _extractSinglePage(pageNum),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.download,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagesListView(PdfState pdfState, bool isCompact) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _extractedPages.length,
      itemBuilder: (context, index) {
        return _buildPageListItem(
          _extractedPages[index],
          index,
          pdfState,
          isCompact,
        );
      },
    );
  }

  Widget _buildPageListItem(
    ExtractedPageInfo page,
    int index,
    PdfState pdfState,
    bool isCompact,
  ) {
    final pageNum = page.pageNumber;
    final isCurrentPage = pageNum == widget.currentPage;
    final isExtracted = page.fileSize > 0 && File(page.filePath).existsSync();
    final isBookmarked = pdfState.bookmarks.contains(pageNum);
    final hasHighlights = pdfState.highlights.containsKey(pageNum);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCurrentPage
          ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
          : null,
      child: ListTile(
        leading: Container(
          width: isCompact ? 45 : 50,
          height: isCompact ? 60 : 65,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isCurrentPage
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade700,
              width: isCurrentPage ? 2 : 1,
            ),
          ),
          child: isExtracted
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.file(
                    File(page.filePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        '$pageNum',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    '$pageNum',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCurrentPage
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                  ),
                ),
        ),
        title: Row(
          children: [
            Text(
              'Page $pageNum',
              style: TextStyle(
                fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                fontSize: isCompact ? 14 : 16,
              ),
            ),
            if (isBookmarked) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.bookmark,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
            ],
            if (hasHighlights) ...[
              const SizedBox(width: 4),
              const Icon(Icons.highlight, size: 16, color: Colors.yellow),
            ],
          ],
        ),
        subtitle: Text(
          _getPageSubtitle(page, isExtracted, pdfState),
          style: TextStyle(
            fontSize: isCompact ? 11 : 12,
            color: isExtracted ? null : Colors.orange,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isExtracted && widget.hasFile)
              IconButton(
                icon: const Icon(Icons.download, size: 20),
                tooltip: 'Extract',
                onPressed: () => _extractSinglePage(pageNum),
              ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: isCompact ? 18 : 20),
              onSelected: (value) => _handlePageAction(value, page, index),
              itemBuilder: (context) => _buildPageMenuItems(page, isExtracted),
            ),
          ],
        ),
        onTap: () => widget.onPageSelected?.call(pageNum),
        onLongPress: () => _showPageOptionsSheet(page, index, pdfState),
      ),
    );
  }

  String _getPageSubtitle(
    ExtractedPageInfo page,
    bool isExtracted,
    PdfState pdfState,
  ) {
    if (!isExtracted) {
      return 'Not extracted';
    }

    final parts = <String>[];
    parts.add(_formatFileSize(page.fileSize));

    final highlightCount = pdfState.highlights[page.pageNumber]?.length ?? 0;
    if (highlightCount > 0) {
      parts.add('$highlightCount highlight${highlightCount > 1 ? 's' : ''}');
    }

    return parts.join(' • ');
  }

  List<PopupMenuEntry<String>> _buildPageMenuItems(
    ExtractedPageInfo page,
    bool isExtracted,
  ) {
    return [
      if (widget.onPageSelected != null)
        const PopupMenuItem(
          value: 'goto',
          child: Row(
            children: [
              Icon(Icons.visibility, size: 18),
              SizedBox(width: 12),
              Text('Go to Page'),
            ],
          ),
        ),
      if (isExtracted) ...[
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, size: 18),
              SizedBox(width: 12),
              Text('Share'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'properties',
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18),
              SizedBox(width: 12),
              Text('Properties'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: Colors.red),
              SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      if (!isExtracted && widget.hasFile)
        const PopupMenuItem(
          value: 'extract',
          child: Row(
            children: [
              Icon(Icons.download, size: 18),
              SizedBox(width: 12),
              Text('Extract'),
            ],
          ),
        ),
    ];
  }

  void _handlePageAction(String action, ExtractedPageInfo page, int index) {
    switch (action) {
      case 'goto':
        widget.onPageSelected?.call(page.pageNumber);
        break;
      case 'share':
        _sharePage(page);
        break;
      case 'properties':
        _showPageProperties(page);
        break;
      case 'delete':
        _deletePage(page, index);
        break;
      case 'extract':
        _extractSinglePage(page.pageNumber);
        break;
    }
  }

  void _showPageOptionsSheet(
    ExtractedPageInfo page,
    int index,
    PdfState pdfState,
  ) {
    final pageNum = page.pageNumber;
    final isExtracted = page.fileSize > 0 && File(page.filePath).existsSync();
    final isBookmarked = pdfState.bookmarks.contains(pageNum);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Page $pageNum',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (widget.onPageSelected != null)
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Go to Page'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onPageSelected!(pageNum);
                },
              ),
            ListTile(
              leading: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              ),
              title: Text(isBookmarked ? 'Remove Bookmark' : 'Add Bookmark'),
              onTap: () {
                ref.read(pdfStateProvider.notifier).toggleBookmark(pageNum);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.highlight),
              title: const Text('Add Highlight'),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(pdfStateProvider.notifier)
                    .addHighlight(
                      pageNumber: pageNum,
                      text: 'Highlight on page $pageNum',
                    );
                _showSuccessMessage('Highlight added');
              },
            ),
            if (!isExtracted && widget.hasFile)
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Extract Page'),
                onTap: () {
                  Navigator.pop(context);
                  _extractSinglePage(pageNum);
                },
              ),
            if (isExtracted) ...[
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _sharePage(page);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Properties'),
                onTap: () {
                  Navigator.pop(context);
                  _showPageProperties(page);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deletePage(page, index);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPagePlaceholder(int pageNum) {
    return Container(
      color: Colors.grey.shade800,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article, size: 28, color: Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(
              '$pageNum',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

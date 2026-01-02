import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import '../../providers/pdf_provider.dart';
import 'package:share_plus/share_plus.dart';

class PdfThumbnailPanel extends ConsumerStatefulWidget {
  final String? filePath;
  final int currentPage;
  final Function(int) onPageSelected;
  final PdfViewerController? pdfController;

  const PdfThumbnailPanel({
    super.key,
    this.filePath,
    required this.currentPage,
    required this.onPageSelected,
    this.pdfController,
  });

  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  @override
  ConsumerState<PdfThumbnailPanel> createState() => _PdfThumbnailPanelState();
}

class _PdfThumbnailPanelState extends ConsumerState<PdfThumbnailPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _isGridView = true;
  bool _isLoading = false;
  List<ExtractedFolder> _folders = [];
  List<ExtractedPageInfo> _extractedPages = [];
  String? _currentFolderPath;
  bool _showingFolders = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(PdfThumbnailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filePath != oldWidget.filePath) {
      _initialize();
    }
    if (widget.currentPage != oldWidget.currentPage) {
      _scrollToCurrentPage();
    }
  }

  Future<void> _initialize() async {
    if (widget.hasFile) {
      _showingFolders = false;
      await _loadExtractedPages();
    } else {
      _showingFolders = true;
      await _loadFolders();
    }
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);
    try {
      final folders = await ref
          .read(pdfStateProvider.notifier)
          .getExtractedFolders(ExtractedType.pages);
      setState(() {
        _folders = folders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading folders: $e');
    }
  }

  Future<void> _loadExtractedPages() async {
    if (!widget.hasFile) return;

    setState(() => _isLoading = true);
    try {
      final extractDir = await ref
          .read(pdfStateProvider.notifier)
          .getExtractionDirectory(ExtractedType.pages);

      final pages = await ref
          .read(pdfStateProvider.notifier)
          .getExtractedPagesFromFolder(extractDir);

      setState(() {
        _extractedPages = pages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading extracted pages: $e');
    }
  }

  Future<void> _loadFolderPages(String folderPath) async {
    setState(() => _isLoading = true);
    try {
      final pages = await ref
          .read(pdfStateProvider.notifier)
          .getExtractedPagesFromFolder(folderPath);

      setState(() {
        _extractedPages = pages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading folder pages: $e');
    }
  }

  void _scrollToCurrentPage() {
    if (!_scrollController.hasClients) return;

    final pdfState = ref.read(pdfStateProvider);
    if (pdfState.pageCount == 0) return;

    final itemHeight = _isGridView ? 160.0 : 80.0;
    final itemsPerRow = _isGridView ? 2 : 1;
    final rowIndex = (widget.currentPage - 1) ~/ itemsPerRow;
    final targetOffset = rowIndex * itemHeight;

    _scrollController.animateTo(
      targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _isPageExtracted(int pageNumber) {
    return _extractedPages.any(
      (p) => p.pageNumber == pageNumber && File(p.filePath).existsSync(),
    );
  }

  ExtractedPageInfo? _getExtractedPage(int pageNumber) {
    try {
      return _extractedPages.firstWhere((p) => p.pageNumber == pageNumber);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pdfState = ref.watch(pdfStateProvider);
    final pageCount = pdfState.pageCount > 0 ? pdfState.pageCount : 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Column(
      children: [
        _buildHeader(pdfState, isCompact),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        Expanded(
          child: _showingFolders && !widget.hasFile
              ? _buildFoldersList(isCompact)
              : _buildPagesList(pageCount, pdfState, isCompact),
        ),
      ],
    );
  }

  Widget _buildHeader(PdfState pdfState, bool isCompact) {
    final extractedCount = _extractedPages.length;
    final totalPages = pdfState.pageCount;

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
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showingFolders && !widget.hasFile
                          ? '${_folders.length} Folder${_folders.length != 1 ? 's' : ''}'
                          : widget.hasFile
                          ? '$totalPages Pages'
                          : '${_extractedPages.length} Pages',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isCompact ? 14 : 16,
                      ),
                    ),
                    if (_currentFolderPath != null && !widget.hasFile)
                      GestureDetector(
                        onTap: _navigateBack,
                        child: Row(
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
                  ],
                ),
              ),
              if (!_showingFolders || widget.hasFile)
                _buildViewModeToggle(isCompact),
            ],
          ),
          if (widget.hasFile && totalPages > 0) ...[
            const SizedBox(height: 8),
            _buildProgressBar(extractedCount, totalPages),
          ],
        ],
      ),
    );
  }

  void _navigateBack() {
    setState(() {
      _currentFolderPath = null;
      _showingFolders = true;
      _extractedPages.clear();
    });
    _loadFolders();
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
          _buildViewModeButton(true, Icons.grid_view, isCompact),
          _buildViewModeButton(false, Icons.list, isCompact),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(bool isGrid, IconData icon, bool isCompact) {
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

  Widget _buildFoldersList(bool isCompact) {
    if (_folders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_open,
        title: 'No Extracted Pages',
        subtitle: 'Open a PDF to extract pages',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        return _buildFolderCard(folder, isCompact);
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
          '${folder.itemCount} page${folder.itemCount != 1 ? 's' : ''}',
          style: TextStyle(fontSize: isCompact ? 11 : 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openFolder(folder),
      ),
    );
  }

  Future<void> _openFolder(ExtractedFolder folder) async {
    setState(() {
      _currentFolderPath = folder.path;
      _showingFolders = false;
    });
    await _loadFolderPages(folder.path);
  }

  Widget _buildPagesList(int pageCount, PdfState pdfState, bool isCompact) {
    if (pageCount == 0 && _extractedPages.isEmpty) {
      return _buildEmptyState(
        icon: Icons.insert_drive_file,
        title: 'No Pages',
        subtitle: widget.hasFile
            ? 'Loading pages...'
            : 'Select a folder to view pages',
      );
    }

    final displayCount = widget.hasFile ? pageCount : _extractedPages.length;

    if (_isGridView) {
      return _buildGridView(displayCount, pdfState, isCompact);
    } else {
      return _buildListView(displayCount, pdfState, isCompact);
    }
  }

  Widget _buildGridView(int pageCount, PdfState pdfState, bool isCompact) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isCompact ? 2 : 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: pageCount,
      itemBuilder: (context, index) {
        final pageNum = widget.hasFile
            ? index + 1
            : _extractedPages[index].pageNumber;
        return _buildPageThumbnail(pageNum, pdfState, isCompact);
      },
    );
  }

  Widget _buildListView(int pageCount, PdfState pdfState, bool isCompact) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: pageCount,
      itemBuilder: (context, index) {
        final pageNum = widget.hasFile
            ? index + 1
            : _extractedPages[index].pageNumber;
        return _buildPageListItem(pageNum, pdfState, isCompact);
      },
    );
  }

  Widget _buildPageThumbnail(int pageNum, PdfState pdfState, bool isCompact) {
    final isCurrentPage = pageNum == widget.currentPage;
    final isBookmarked = pdfState.bookmarks.contains(pageNum);
    final hasHighlights = pdfState.highlights.containsKey(pageNum);
    final isExtracted = _isPageExtracted(pageNum);
    final extractedPage = _getExtractedPage(pageNum);

    return GestureDetector(
      onTap: () => widget.onPageSelected(pageNum),
      onLongPress: () => _showPageOptions(pageNum, pdfState),
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
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: isExtracted && extractedPage != null
                  ? Image.file(
                      File(extractedPage.filePath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(pageNum),
                    )
                  : _buildPlaceholder(pageNum),
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

            // Indicators
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

            // Not extracted indicator
            if (!isExtracted && widget.hasFile)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.download,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageListItem(int pageNum, PdfState pdfState, bool isCompact) {
    final isCurrentPage = pageNum == widget.currentPage;
    final isBookmarked = pdfState.bookmarks.contains(pageNum);
    final hasHighlights = pdfState.highlights.containsKey(pageNum);
    final isExtracted = _isPageExtracted(pageNum);
    final extractedPage = _getExtractedPage(pageNum);

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
          child: isExtracted && extractedPage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.file(
                    File(extractedPage.filePath),
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
        title: Text(
          'Page $pageNum',
          style: TextStyle(
            fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
            fontSize: isCompact ? 14 : 16,
          ),
        ),
        subtitle: Row(
          children: [
            if (isBookmarked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark,
                    size: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Bookmarked',
                    style: TextStyle(fontSize: isCompact ? 10 : 11),
                  ),
                ],
              ),
            if (isBookmarked && hasHighlights)
              Text(' • ', style: TextStyle(fontSize: isCompact ? 10 : 11)),
            if (hasHighlights)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.highlight, size: 14, color: Colors.yellow),
                  const SizedBox(width: 4),
                  Text(
                    '${pdfState.highlights[pageNum]!.length} highlights',
                    style: TextStyle(fontSize: isCompact ? 10 : 11),
                  ),
                ],
              ),
            if (!isBookmarked && !hasHighlights)
              Text(
                isExtracted ? 'Extracted' : 'Not extracted',
                style: TextStyle(
                  fontSize: isCompact ? 10 : 11,
                  color: isExtracted ? Colors.green : Colors.orange,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.more_vert, size: isCompact ? 18 : 20),
          onPressed: () => _showPageOptions(pageNum, pdfState),
        ),
        onTap: () => widget.onPageSelected(pageNum),
        onLongPress: () => _showPageOptions(pageNum, pdfState),
      ),
    );
  }

  Widget _buildPlaceholder(int pageNum) {
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

  void _showPageOptions(int pageNum, PdfState pdfState) {
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

            // lib/widgets/pdf/pdf_thumbnail_panel.dart (continued)
            Text(
              'Page $pageNum',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Go to Page'),
              onTap: () {
                Navigator.pop(context);
                widget.onPageSelected(pageNum);
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
                _showSuccess('Highlight added');
              },
            ),
            if (widget.hasFile) ...[
              ListTile(
                leading: const Icon(Icons.text_snippet),
                title: const Text('Extract Text'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ref
                        .read(pdfStateProvider.notifier)
                        .extractSinglePageText(pageNum);
                    _showSuccess('Text extracted from page $pageNum');
                  } catch (e) {
                    _showError('Failed to extract text: $e');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Extract Page as Image'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ref
                        .read(pdfStateProvider.notifier)
                        .extractSinglePage(pageNum);
                    await _loadExtractedPages();
                    _showSuccess('Page $pageNum extracted');
                  } catch (e) {
                    _showError('Failed to extract page: $e');
                  }
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Page'),
              onTap: () {
                Navigator.pop(context);
                _sharePage(pageNum);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Properties'),
              onTap: () {
                Navigator.pop(context);
                _showPageProperties(pageNum, pdfState);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sharePage(int pageNum) async {
    final extractedPage = _getExtractedPage(pageNum);
    if (extractedPage != null && File(extractedPage.filePath).existsSync()) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            subject: 'Page $pageNum',
            files: [XFile(extractedPage.filePath)],
          ),
        );
      } catch (e) {
        _showError('Failed to share: $e');
      }
    } else {
      _showError('Page not extracted yet. Extract the page first.');
    }
  }

  void _showPageProperties(int pageNum, PdfState pdfState) {
    final extractedPage = _getExtractedPage(pageNum);
    final isBookmarked = pdfState.bookmarks.contains(pageNum);
    final highlightCount = pdfState.highlights[pageNum]?.length ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Page $pageNum Properties'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropertyRow('Page Number', '$pageNum'),
            _buildPropertyRow('Total Pages', '${pdfState.pageCount}'),
            _buildPropertyRow('Bookmarked', isBookmarked ? 'Yes' : 'No'),
            _buildPropertyRow('Highlights', '$highlightCount'),
            _buildPropertyRow(
              'Extracted',
              extractedPage != null ? 'Yes' : 'No',
            ),
            if (extractedPage != null) ...[
              _buildPropertyRow(
                'File Size',
                _formatFileSize(extractedPage.fileSize),
              ),
              _buildPropertyRow(
                'Extracted At',
                _formatDateTime(extractedPage.extractedAt),
              ),
            ],
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

  void _showError(String message) {
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

  void _showSuccess(String message) {
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

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return 'Unknown';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

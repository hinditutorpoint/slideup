import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/reader_utils.dart';
import '../screens/enhanced_pdf_reader.dart';

class DownloadedPdfsScreen extends StatefulWidget {
  const DownloadedPdfsScreen({super.key});

  @override
  State<DownloadedPdfsScreen> createState() => _DownloadedPdfsScreenState();
}

class _DownloadedPdfsScreenState extends State<DownloadedPdfsScreen> {
  final DownloadLibraryManager _library = DownloadLibraryManager();
  final DioPdfDownloader _downloader = DioPdfDownloader();

  List<DownloadedPdfItem> _items = [];
  List<DownloadedPdfItem> _filteredItems = [];
  bool _loading = true;

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  SortOrder _sortOrder = SortOrder.dateDesc;
  PdfFileFilter _filter = PdfFileFilter.all;
  bool _isSearching = false;

  // Selection Mode
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  // Download State
  CancelToken? _downloadCancel;

  // ignore: unused_field
  bool _isDownloading = false;

  // Stats
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _downloadCancel?.cancel('dispose');
    _downloader.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);

    try {
      await _library.initialize();
      final items = await _library.listDownloads(
        sortOrder: _sortOrder,
        filter: _filter,
      );
      final totalSize = await _library.totalSize;

      if (!mounted) return;
      setState(() {
        _items = items;
        _totalSize = totalSize;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      _showSnackBar('Failed to load downloads');
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        _filteredItems = _items.where((item) {
          return item.title.toLowerCase().contains(query) ||
              item.fileName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }

      if (_selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredItems.length) {
        _selectedIds.clear();
        _selectionMode = false;
      } else {
        _selectedIds.addAll(_filteredItems.map((e) => e.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final confirm = await _showConfirmDialog(
      title: 'Delete $count items?',
      message: 'This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirm != true) return;

    await _library.deleteMultiple(_selectedIds.toList());
    _toggleSelectionMode();
    _reload();
    _showSnackBar('$count items deleted');
  }

  Future<void> _open(DownloadedPdfItem item) async {
    if (_selectionMode) {
      _toggleSelection(item.id);
      return;
    }

    final file = await _library.getFileForItem(item);
    if (!await file.exists()) {
      _showSnackBar('File not found');
      _reload();
      return;
    }

    await _library.markOpened(item.id);
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancedPdfReader.file(
          file: file,
          title: item.title,
          identifier: item.id,
        ),
      ),
    );

    _reload();
  }

  Future<void> _share(DownloadedPdfItem item) async {
    final file = await _library.getFileForItem(item);
    if (!await file.exists()) {
      _showSnackBar('File not found');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: item.title),
    );
  }

  Future<void> _delete(DownloadedPdfItem item) async {
    final confirm = await _showConfirmDialog(
      title: 'Delete "${item.title}"?',
      message: 'This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirm != true) return;
    await _library.delete(item.id);
    _reload();
    _showSnackBar('Deleted successfully');
  }

  Future<void> _rename(DownloadedPdfItem item) async {
    final controller = TextEditingController(text: item.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle.trim().isEmpty) return;
    await _library.rename(item.id, newTitle.trim(), renameFileOnDisk: true);
    _reload();
    _showSnackBar('Renamed successfully');
  }

  Future<void> _downloadByUrl() async {
    final urlController = TextEditingController();
    final titleController = TextEditingController();

    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Download PDF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'PDF URL',
                hintText: 'https://example.com/document.pdf',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                border: OutlineInputBorder(),
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
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, {
              'url': urlController.text,
              'title': titleController.text,
            }),
            icon: const Icon(Icons.download),
            label: const Text('Download'),
          ),
        ],
      ),
    );

    if (data == null) return;

    final url = data['url']?.trim() ?? '';
    final title = data['title']?.trim().isNotEmpty == true
        ? data['title']!.trim()
        : DocumentUtils.extractTitleFromUrl(url);

    if (url.isEmpty) {
      _showSnackBar('Please enter a URL');
      return;
    }

    if (!url.startsWith('http')) {
      _showSnackBar('Invalid URL');
      return;
    }

    await _startDownload(url, title);
  }

  Future<void> _startDownload(String url, String title) async {
    _downloadCancel?.cancel('new');
    _downloadCancel = CancelToken();

    final progress = ValueNotifier<double?>(0);

    setState(() => _isDownloading = true);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadProgressDialog(
        title: title,
        progress: progress,
        onCancel: () {
          _downloadCancel?.cancel('user cancel');
          Navigator.pop(context);
        },
      ),
    );

    try {
      await _library.downloadAndSave(
        url: url,
        title: title,
        downloader: _downloader,
        cancelToken: _downloadCancel!,
        onProgress: (p) => progress.value = p,
      );

      if (mounted) Navigator.pop(context);
      _reload();
      _showSnackBar('Download complete: $title');
    } on DioException catch (e) {
      if (mounted) Navigator.pop(context);
      if (e.type != DioExceptionType.cancel && mounted) {
        _showSnackBar('Download failed: ${_getErrorMessage(e)}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Download failed');
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  String _getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout';
      case DioExceptionType.connectionError:
        return 'No internet connection';
      default:
        return 'Unknown error';
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => _SortOptionsSheet(
        currentSort: _sortOrder,
        onSortChanged: (sort) {
          Navigator.pop(context);
          setState(() => _sortOrder = sort);
          _reload();
        },
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => _FilterOptionsSheet(
        currentFilter: _filter,
        onFilterChanged: (filter) {
          Navigator.pop(context);
          setState(() => _filter = filter);
          _reload();
        },
      ),
    );
  }

  Future<void> _clearAll() async {
    final confirm = await _showConfirmDialog(
      title: 'Clear all downloads?',
      message:
          'This will delete ${_items.length} files (${DocumentUtils.formatFileSize(_totalSize)})',
      confirmText: 'Clear All',
      isDestructive: true,
    );

    if (confirm != true) return;
    await _library.clearAll();
    _reload();
    _showSnackBar('All downloads cleared');
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDestructive
                ? ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  )
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _downloadByUrl,
              icon: const Icon(Icons.add),
              label: const Text('Download'),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_selectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _toggleSelectionMode,
        ),
        title: Text('${_selectedIds.length} selected'),
        actions: [
          IconButton(
            icon: Icon(
              _selectedIds.length == _filteredItems.length
                  ? Icons.deselect
                  : Icons.select_all,
            ),
            onPressed: _selectAll,
            tooltip: 'Select all',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
            tooltip: 'Delete selected',
          ),
        ],
      );
    }

    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _toggleSearch,
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search downloads...',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _searchController.clear(),
            ),
        ],
      );
    }

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Downloads'),
          if (!_loading && _items.isNotEmpty)
            Text(
              '${_items.length} files • ${DocumentUtils.formatFileSize(_totalSize)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _toggleSearch,
          tooltip: 'Search',
        ),
        IconButton(
          icon: const Icon(Icons.sort),
          onPressed: _showSortOptions,
          tooltip: 'Sort',
        ),
        IconButton(
          icon: Badge(
            isLabelVisible: _filter != PdfFileFilter.all,
            child: const Icon(Icons.filter_list),
          ),
          onPressed: _showFilterOptions,
          tooltip: 'Filter',
        ),
        PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'select':
                _toggleSelectionMode();
                break;
              case 'clear':
                _clearAll();
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'select',
              child: ListTile(
                leading: Icon(Icons.checklist),
                title: Text('Select items'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (_items.isNotEmpty)
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep, color: Colors.red),
                  title: Text('Clear all', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    if (_filteredItems.isEmpty) {
      return _buildNoResultsState();
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _filteredItems.length,
        itemBuilder: (_, index) {
          final item = _filteredItems[index];
          final isSelected = _selectedIds.contains(item.id);

          return _DownloadedPdfTile(
            item: item,
            isSelected: isSelected,
            selectionMode: _selectionMode,
            onTap: () => _open(item),
            onLongPress: () {
              if (!_selectionMode) {
                _toggleSelectionMode();
              }
              _toggleSelection(item.id);
            },
            onShare: () => _share(item),
            onRename: () => _rename(item),
            onDelete: () => _delete(item),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_for_offline_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No downloads yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Downloaded PDFs will appear here for offline reading',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _downloadByUrl,
              icon: const Icon(Icons.add),
              label: const Text('Download PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term or filter',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _filter = PdfFileFilter.all);
                _reload();
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== Downloaded PDF Tile ==========

class _DownloadedPdfTile extends StatelessWidget {
  final DownloadedPdfItem item;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _DownloadedPdfTile({
    required this.item,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isSelected ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection checkbox or file icon
              if (selectionMode)
                Checkbox(value: isSelected, onChanged: (_) => onTap())
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getFileColor(item.extension).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getFileIcon(item.extension),
                    color: _getFileColor(item.extension),
                    size: 24,
                  ),
                ),

              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.sd_storage,
                          size: 14,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.sizeBytes != null
                              ? DocumentUtils.formatFileSize(item.sizeBytes!)
                              : 'Unknown size',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(item.lastOpened ?? item.addedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              if (!selectionMode)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    switch (action) {
                      case 'open':
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
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'open',
                      child: ListTile(
                        leading: Icon(Icons.open_in_new),
                        title: Text('Open'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                        leading: Icon(Icons.share),
                        title: Text('Share'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Rename'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'epub':
        return Icons.book;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'epub':
        return Colors.blue;
      case 'txt':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// ========== Sort Options Sheet ==========

class _SortOptionsSheet extends StatelessWidget {
  final SortOrder currentSort;
  final ValueChanged<SortOrder> onSortChanged;

  const _SortOptionsSheet({
    required this.currentSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Sort by',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          _SortOption(
            title: 'Date (newest first)',
            isSelected: currentSort == SortOrder.dateDesc,
            onTap: () => onSortChanged(SortOrder.dateDesc),
          ),
          _SortOption(
            title: 'Date (oldest first)',
            isSelected: currentSort == SortOrder.dateAsc,
            onTap: () => onSortChanged(SortOrder.dateAsc),
          ),
          _SortOption(
            title: 'Name (A-Z)',
            isSelected: currentSort == SortOrder.nameAsc,
            onTap: () => onSortChanged(SortOrder.nameAsc),
          ),
          _SortOption(
            title: 'Name (Z-A)',
            isSelected: currentSort == SortOrder.nameDesc,
            onTap: () => onSortChanged(SortOrder.nameDesc),
          ),
          _SortOption(
            title: 'Size (largest first)',
            isSelected: currentSort == SortOrder.sizeDesc,
            onTap: () => onSortChanged(SortOrder.sizeDesc),
          ),
          _SortOption(
            title: 'Size (smallest first)',
            isSelected: currentSort == SortOrder.sizeAsc,
            onTap: () => onSortChanged(SortOrder.sizeAsc),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).primaryColor)
          : null,
      onTap: onTap,
    );
  }
}

// ========== Filter Options Sheet ==========

class _FilterOptionsSheet extends StatelessWidget {
  final PdfFileFilter currentFilter;
  final ValueChanged<PdfFileFilter> onFilterChanged;

  const _FilterOptionsSheet({
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Filter by type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          _FilterOption(
            title: 'All files',
            icon: Icons.folder,
            isSelected: currentFilter == PdfFileFilter.all,
            onTap: () => onFilterChanged(PdfFileFilter.all),
          ),
          _FilterOption(
            title: 'PDF only',
            icon: Icons.picture_as_pdf,
            iconColor: Colors.red,
            isSelected: currentFilter == PdfFileFilter.pdf,
            onTap: () => onFilterChanged(PdfFileFilter.pdf),
          ),
          _FilterOption(
            title: 'EPUB only',
            icon: Icons.book,
            iconColor: Colors.blue,
            isSelected: currentFilter == PdfFileFilter.epub,
            onTap: () => onFilterChanged(PdfFileFilter.epub),
          ),
          _FilterOption(
            title: 'Text files',
            icon: Icons.text_snippet,
            iconColor: Colors.green,
            isSelected: currentFilter == PdfFileFilter.txt,
            onTap: () => onFilterChanged(PdfFileFilter.txt),
          ),
          _FilterOption(
            title: 'Other',
            icon: Icons.insert_drive_file,
            isSelected: currentFilter == PdfFileFilter.other,
            onTap: () => onFilterChanged(PdfFileFilter.other),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterOption({
    required this.title,
    required this.icon,
    this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).primaryColor)
          : null,
      onTap: onTap,
    );
  }
}

// ========== Download Progress Dialog ==========

class _DownloadProgressDialog extends StatelessWidget {
  final String title;
  final ValueNotifier<double?> progress;
  final VoidCallback onCancel;

  const _DownloadProgressDialog({
    required this.title,
    required this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Downloading'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, p, __) {
              final progressValue = p ?? 0;
              final progressText = p == null
                  ? 'Connecting...'
                  : '${(progressValue * 100).toStringAsFixed(0)}%';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: p,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progressText,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      actions: [TextButton(onPressed: onCancel, child: const Text('Cancel'))],
    );
  }
}

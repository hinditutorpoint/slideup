import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../providers/pdf_provider.dart';

enum ViewMode { grid, list }

abstract class BaseExtractedListWidget<T> extends ConsumerStatefulWidget {
  final String? filePath;
  final String? fileName;
  final Function(int)? onPageSelected;
  final int? currentPage;

  const BaseExtractedListWidget({
    super.key,
    this.filePath,
    this.fileName,
    this.onPageSelected,
    this.currentPage,
  });

  bool get hasFile => filePath != null && filePath!.isNotEmpty;
}

abstract class BaseExtractedListWidgetState<
  T,
  W extends BaseExtractedListWidget<T>
>
    extends ConsumerState<W> {
  ViewMode _viewMode = ViewMode.grid;
  bool _isLoading = false;
  String? _error;
  // ignore: prefer_final_fields
  List<T> _items = [];
  List<ExtractedFolder> _folders = [];
  String? _currentFolderPath;
  bool _showingFolders = true;

  ExtractedType get extractedType;
  String get emptyMessage;
  String get emptyFolderMessage;
  IconData get emptyIcon;
  String get itemTypeName;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filePath != oldWidget.filePath) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    if (widget.hasFile) {
      _showingFolders = false;
      await _loadCurrentFileItems();
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
          .getExtractedFolders(extractedType);
      setState(() {
        _folders = folders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentFileItems();

  Future<void> _loadFolderItems(String folderPath);

  Future<void> _extractItems();

  Widget buildItemWidget(T item, int index);

  Widget buildItemListTile(T item, int index);

  //Future<void> _shareItem(T item);

  //Future<void> _deleteItem(T item, int index);

  //void _showItemProperties(T item);

  int getItemPageNumber(T item);

  String getItemFilePath(T item);

  @override
  Widget build(BuildContext context) {
    final pdfState = ref.watch(pdfStateProvider);
    final canExtract = widget.hasFile && !_isLoading;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Column(
      children: [
        _buildHeader(pdfState, canExtract, isCompact),
        if (_isLoading) _buildLoadingIndicator(pdfState),
        if (_error != null) _buildErrorWidget(),
        Expanded(
          child: _showingFolders && !widget.hasFile
              ? _buildFoldersList()
              : _buildItemsList(isCompact),
        ),
      ],
    );
  }

  Widget _buildHeader(PdfState pdfState, bool canExtract, bool isCompact) {
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
                          ? 'Extracted ${itemTypeName}s'
                          : widget.hasFile
                          ? '${pdfState.pageCount} Pages'
                          : _currentFolderPath != null
                          ? '${_items.length} $itemTypeName${_items.length != 1 ? 's' : ''}'
                          : '${_folders.length} Folder${_folders.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isCompact ? 14 : 16,
                      ),
                    ),
                    if (_currentFolderPath != null && !widget.hasFile)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentFolderPath = null;
                            _showingFolders = true;
                            _items.clear();
                          });
                          _loadFolders();
                        },
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
              if (!_showingFolders || widget.hasFile) ...[
                _buildViewModeToggle(isCompact),
                if (canExtract) ...[
                  const SizedBox(width: 8),
                  _buildExtractButton(isCompact),
                ],
              ],
            ],
          ),
          if (widget.hasFile && pdfState.pageCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildProgressIndicator(pdfState),
            ),
        ],
      ),
    );
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
          _buildViewModeButton(ViewMode.grid, Icons.grid_view, isCompact),
          _buildViewModeButton(ViewMode.list, Icons.list, isCompact),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(ViewMode mode, IconData icon, bool isCompact) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
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

  Widget _buildExtractButton(bool isCompact) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _extractItems,
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
    );
  }

  Widget _buildProgressIndicator(PdfState pdfState) {
    final extractedCount = _items
        .where((item) => File(getItemFilePath(item)).existsSync())
        .length;
    final totalPages = pdfState.pageCount;
    final progress = totalPages > 0 ? extractedCount / totalPages : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$extractedCount of $totalPages extracted',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  Widget _buildFoldersList() {
    if (_folders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_open,
        title: 'No Extracted ${itemTypeName}s',
        subtitle: 'Open a PDF to extract $itemTypeName',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        return _buildFolderCard(folder);
      },
    );
  }

  Widget _buildFolderCard(ExtractedFolder folder) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.folder, color: Theme.of(context).primaryColor),
        ),
        title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${folder.itemCount} $itemTypeName${folder.itemCount != 1 ? 's' : ''} • ${_formatDate(folder.createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert, size: 20),
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
          onSelected: (value) async {
            switch (value) {
              case 'open':
                await _openFolder(folder);
                break;
              case 'share':
                await _shareFolder(folder);
                break;
              case 'delete':
                await _deleteFolderConfirm(folder);
                break;
            }
          },
        ),
        onTap: () => _openFolder(folder),
      ),
    );
  }

  Future<void> _openFolder(ExtractedFolder folder) async {
    setState(() {
      _currentFolderPath = folder.path;
      _showingFolders = false;
    });
    await _loadFolderItems(folder.path);
  }

  Future<void> _shareFolder(ExtractedFolder folder) async {
    try {
      final dir = Directory(folder.path);
      final files = <XFile>[];

      await for (final entity in dir.list()) {
        if (entity is File) {
          files.add(XFile(entity.path));
        }
      }

      if (files.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            title: 'Share Extracted Files',
            files: files,
            subject: 'Extracted ${folder.name}',
          ),
        );
      }
    } catch (e) {
      _showError('Failed to share: $e');
    }
  }

  Future<void> _deleteFolderConfirm(ExtractedFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text(
          'This will delete "${folder.name}" and all its contents. This action cannot be undone.',
        ),
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

    if (confirmed == true) {
      await ref
          .read(pdfStateProvider.notifier)
          .deleteExtractedFolder(folder.path);
      await _loadFolders();
      _showSuccess('Folder deleted');
    }
  }

  Widget _buildItemsList(bool isCompact) {
    if (_items.isEmpty && !_isLoading) {
      return _buildEmptyState(
        icon: emptyIcon,
        title: widget.hasFile ? 'No Extracted $itemTypeName' : emptyMessage,
        subtitle: widget.hasFile
            ? 'Tap "Extract All" to extract $itemTypeName from this PDF'
            : emptyFolderMessage,
      );
    }

    if (_viewMode == ViewMode.grid) {
      return _buildGridView(isCompact);
    } else {
      return _buildListView();
    }
  }

  Widget _buildGridView(bool isCompact) {
    final crossAxisCount = isCompact ? 2 : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) => buildItemWidget(_items[index], index),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      itemBuilder: (context, index) => buildItemListTile(_items[index], index),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

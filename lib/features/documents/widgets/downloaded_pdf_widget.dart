import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/utils/responsive_helper.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../utils/reader_utils.dart';
import '../screens/unified_reader_screen.dart';

// ========== Providers ==========

final downloadedPdfsProvider =
    StateNotifierProvider<DownloadedPdfsNotifier, DownloadedPdfsState>((ref) {
      return DownloadedPdfsNotifier();
    });

final downloadedPdfViewModeProvider = StateProvider<PdfViewMode>((ref) {
  return PdfViewMode.list;
});

final downloadedPdfSortProvider = StateProvider<SortOrder>((ref) {
  return SortOrder.dateDesc;
});

final downloadedPdfSearchProvider = StateProvider<String>((ref) {
  return '';
});

final downloadedPdfFilterProvider = StateProvider<PdfFileFilter>((ref) {
  return PdfFileFilter.all;
});

final downloadedPdfSelectionProvider =
    StateNotifierProvider<SelectionNotifier, Set<String>>((ref) {
      return SelectionNotifier();
    });

// ========== State Classes ==========

class DownloadedPdfsState {
  final List<DownloadedPdfItem> items;
  final bool isLoading;
  final String? error;
  final int totalSize;
  final bool isInitialized;

  const DownloadedPdfsState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.totalSize = 0,
    this.isInitialized = false,
  });

  DownloadedPdfsState copyWith({
    List<DownloadedPdfItem>? items,
    bool? isLoading,
    String? error,
    int? totalSize,
    bool? isInitialized,
  }) {
    return DownloadedPdfsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      totalSize: totalSize ?? this.totalSize,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class DownloadedPdfsNotifier extends StateNotifier<DownloadedPdfsState> {
  DownloadedPdfsNotifier() : super(const DownloadedPdfsState());

  final DownloadLibraryManager _libraryManager = DownloadLibraryManager();

  Future<void> loadDownloads({
    SortOrder sortOrder = SortOrder.dateDesc,
    String? searchQuery,
    PdfFileFilter filter = PdfFileFilter.all,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final items = await _libraryManager.listDownloads(
        sortOrder: sortOrder,
        searchQuery: searchQuery,
        filter: filter,
      );

      final totalSize = await _libraryManager.totalSize;

      state = state.copyWith(
        items: items,
        isLoading: false,
        totalSize: totalSize,
        isInitialized: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load downloads: $e',
        isInitialized: true,
      );
    }
  }

  Future<void> refresh({
    SortOrder sortOrder = SortOrder.dateDesc,
    String? searchQuery,
    PdfFileFilter filter = PdfFileFilter.all,
  }) async {
    await loadDownloads(
      sortOrder: sortOrder,
      searchQuery: searchQuery,
      filter: filter,
    );
  }

  Future<bool> deleteItem(String id) async {
    try {
      await _libraryManager.delete(id);
      state = state.copyWith(
        items: state.items.where((item) => item.id != id).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteMultiple(List<String> ids) async {
    try {
      await _libraryManager.deleteMultiple(ids);
      state = state.copyWith(
        items: state.items.where((item) => !ids.contains(item.id)).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> renameItem(String id, String newTitle) async {
    try {
      await _libraryManager.rename(id, newTitle);
      state = state.copyWith(
        items: state.items.map((item) {
          if (item.id == id) {
            return item.copyWith(title: newTitle);
          }
          return item;
        }).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> markOpened(String id) async {
    try {
      await _libraryManager.markOpened(id);
    } catch (_) {}
  }

  Future<File?> getFileForItem(DownloadedPdfItem item) async {
    try {
      return await _libraryManager.getFileForItem(item);
    } catch (e) {
      return null;
    }
  }
}

class SelectionNotifier extends StateNotifier<Set<String>> {
  SelectionNotifier() : super({});

  void toggle(String id) {
    if (state.contains(id)) {
      state = Set.from(state)..remove(id);
    } else {
      state = Set.from(state)..add(id);
    }
  }

  void selectAll(List<String> ids) {
    state = Set.from(ids);
  }

  void clear() {
    state = {};
  }

  bool isSelected(String id) => state.contains(id);
}

// ========== Main Widget ==========

class DownloadedPdfWidget extends ConsumerStatefulWidget {
  final bool showHeader;
  final bool showSearch;
  final EdgeInsets? padding;

  const DownloadedPdfWidget({
    super.key,
    this.showHeader = true,
    this.showSearch = true,
    this.padding,
  });

  @override
  ConsumerState<DownloadedPdfWidget> createState() =>
      _DownloadedPdfWidgetState();
}

class _DownloadedPdfWidgetState extends ConsumerState<DownloadedPdfWidget> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid modifying provider during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDownloads();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeDownloads() {
    if (!mounted) return;
    final state = ref.read(downloadedPdfsProvider);
    if (!state.isInitialized) {
      _loadDownloads();
    }
  }

  void _loadDownloads() {
    if (!mounted) return;
    try {
      final sortOrder = ref.read(downloadedPdfSortProvider);
      final searchQuery = ref.read(downloadedPdfSearchProvider);
      final filter = ref.read(downloadedPdfFilterProvider);

      ref
          .read(downloadedPdfsProvider.notifier)
          .loadDownloads(
            sortOrder: sortOrder,
            searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
            filter: filter,
          );
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(downloadedPdfsProvider);
    final viewMode = ref.watch(downloadedPdfViewModeProvider);
    final selectedIds = ref.watch(downloadedPdfSelectionProvider);

    // Listen to filter/sort/search changes - use addPostFrameCallback
    ref.listen(downloadedPdfSortProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDownloads());
    });
    ref.listen(downloadedPdfFilterProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDownloads());
    });
    ref.listen(downloadedPdfSearchProvider, (_, value) {
      if (value.isEmpty || value.length >= 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadDownloads());
      }
    });

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        slivers: [
          if (widget.showHeader)
            SliverToBoxAdapter(child: _buildHeader(state, viewMode)),
          if (widget.showSearch) SliverToBoxAdapter(child: _buildSearchBar()),
          if (_isSelectionMode && selectedIds.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildSelectionActions(selectedIds, state),
            ),
          _buildSliverContent(state, viewMode, selectedIds),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    try {
      await ref
          .read(downloadedPdfsProvider.notifier)
          .refresh(
            sortOrder: ref.read(downloadedPdfSortProvider),
            searchQuery: ref.read(downloadedPdfSearchProvider),
            filter: ref.read(downloadedPdfFilterProvider),
          );
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

  Widget _buildHeader(DownloadedPdfsState state, PdfViewMode viewMode) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.download_done, color: colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Downloads',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${state.items.length} files • ${DocumentUtils.formatFileSize(state.totalSize)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _buildHeaderActions(viewMode, colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeaderActions(PdfViewMode viewMode, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _isSelectionMode ? Icons.close : Icons.checklist,
            color: _isSelectionMode ? colorScheme.error : null,
          ),
          onPressed: _toggleSelectionMode,
          tooltip: _isSelectionMode ? 'Cancel selection' : 'Select items',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: Icon(
            viewMode == PdfViewMode.grid ? Icons.view_list : Icons.grid_view,
          ),
          onPressed: _toggleViewMode,
          tooltip: 'Toggle view',
          visualDensity: VisualDensity.compact,
        ),
        PopupMenuButton<SortOrder>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort',
          onSelected: _onSortChanged,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: SortOrder.dateDesc,
              child: Text('Newest first'),
            ),
            PopupMenuItem(
              value: SortOrder.dateAsc,
              child: Text('Oldest first'),
            ),
            PopupMenuItem(value: SortOrder.nameAsc, child: Text('Name (A-Z)')),
            PopupMenuItem(value: SortOrder.nameDesc, child: Text('Name (Z-A)')),
            PopupMenuItem(
              value: SortOrder.sizeDesc,
              child: Text('Largest first'),
            ),
            PopupMenuItem(
              value: SortOrder.sizeAsc,
              child: Text('Smallest first'),
            ),
          ],
        ),
        PopupMenuButton<PdfFileFilter>(
          icon: const Icon(Icons.filter_alt_outlined),
          tooltip: 'Filter',
          onSelected: _onFilterChanged,
          itemBuilder: (context) => const [
            PopupMenuItem(value: PdfFileFilter.all, child: Text('All Files')),
            PopupMenuItem(value: PdfFileFilter.pdf, child: Text('PDF Only')),
            PopupMenuItem(value: PdfFileFilter.epub, child: Text('EPUB Only')),
            PopupMenuItem(value: PdfFileFilter.txt, child: Text('TXT Only')),
            PopupMenuItem(value: PdfFileFilter.other, child: Text('Other')),
          ],
        ),
      ],
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        ref.read(downloadedPdfSelectionProvider.notifier).clear();
      }
    });
  }

  void _toggleViewMode() {
    final current = ref.read(downloadedPdfViewModeProvider);
    ref.read(downloadedPdfViewModeProvider.notifier).state =
        current == PdfViewMode.grid ? PdfViewMode.list : PdfViewMode.grid;
  }

  void _onSortChanged(SortOrder order) {
    ref.read(downloadedPdfSortProvider.notifier).state = order;
  }

  void _onFilterChanged(PdfFileFilter filter) {
    ref.read(downloadedPdfFilterProvider.notifier).state = filter;
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search downloads...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
          isDense: true,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(downloadedPdfSearchProvider.notifier).state = '';
  }

  void _onSearchChanged(String value) {
    ref.read(downloadedPdfSearchProvider.notifier).state = value;
  }

  Widget _buildSelectionActions(
    Set<String> selectedIds,
    DownloadedPdfsState state,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          Text(
            '${selectedIds.length} selected',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _selectAll(state.items),
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('All'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: selectedIds.isNotEmpty
                ? () => _deleteMultiple(selectedIds.toList())
                : null,
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: colorScheme.error,
            ),
            label: Text('Delete', style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _selectAll(List<DownloadedPdfItem> items) {
    ref
        .read(downloadedPdfSelectionProvider.notifier)
        .selectAll(items.map((e) => e.id).toList());
  }

  Widget _buildSliverContent(
    DownloadedPdfsState state,
    PdfViewMode viewMode,
    Set<String> selectedIds,
  ) {
    // Not initialized yet - show loading
    if (!state.isInitialized && !state.isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.isLoading && state.items.isEmpty) {
      return const SliverFillRemaining(
        child: LoadingWidget(message: 'Loading downloads...'),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return SliverFillRemaining(
        child: AppErrorWidget(message: state.error!, onRetry: _loadDownloads),
      );
    }

    if (state.items.isEmpty) {
      final filter = ref.read(downloadedPdfFilterProvider);
      final searchQuery = ref.read(downloadedPdfSearchProvider);

      return SliverFillRemaining(
        child: EmptyStateWidget(
          title: 'No Downloads',
          subtitle: searchQuery.isNotEmpty
              ? 'No results for "$searchQuery"'
              : filter != PdfFileFilter.all
              ? 'No ${filter.name} files downloaded'
              : 'Downloaded files will appear here',
          icon: Icons.download_outlined,
        ),
      );
    }

    if (viewMode == PdfViewMode.grid) {
      return _buildSliverGrid(state.items, selectedIds);
    } else {
      return _buildSliverList(state.items, selectedIds);
    }
  }

  Widget _buildSliverGrid(
    List<DownloadedPdfItem> items,
    Set<String> selectedIds,
  ) {
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(context);
    final padding =
        widget.padding ?? ResponsiveHelper.getScreenPadding(context);

    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildGridItem(items[index], selectedIds),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildGridItem(DownloadedPdfItem item, Set<String> selectedIds) {
    try {
      return _DownloadedPdfGridItem(
        item: item,
        isSelected: selectedIds.contains(item.id),
        isSelectionMode: _isSelectionMode,
        onTap: () => _handleItemTap(item),
        onLongPress: () => _handleItemLongPress(item),
        onRead: () => _openItem(item),
        onDelete: () => _deleteItem(item),
        onMoveToDownloads: () => _moveToDownloads(item),
        onRename: () => _renameItem(item),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildSliverList(
    List<DownloadedPdfItem> items,
    Set<String> selectedIds,
  ) {
    return SliverPadding(
      padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildListItem(items[index], selectedIds),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildListItem(DownloadedPdfItem item, Set<String> selectedIds) {
    try {
      return _DownloadedPdfListItem(
        item: item,
        isSelected: selectedIds.contains(item.id),
        isSelectionMode: _isSelectionMode,
        onTap: () => _handleItemTap(item),
        onLongPress: () => _handleItemLongPress(item),
        onRead: () => _openItem(item),
        onDelete: () => _deleteItem(item),
        onMoveToDownloads: () => _moveToDownloads(item),
        onRename: () => _renameItem(item),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  // ========== Item Handlers ==========

  void _handleItemTap(DownloadedPdfItem item) {
    if (_isSelectionMode) {
      ref.read(downloadedPdfSelectionProvider.notifier).toggle(item.id);
    } else {
      _openItem(item);
    }
  }

  void _handleItemLongPress(DownloadedPdfItem item) {
    if (!_isSelectionMode) {
      setState(() => _isSelectionMode = true);
    }
    ref.read(downloadedPdfSelectionProvider.notifier).toggle(item.id);
  }

  // ========== Actions ==========

  Future<void> _openItem(DownloadedPdfItem item) async {
    try {
      if (!item.isPdf && !item.isEpub && !item.isTxt) {
        _showSnackBar('Only PDF, Epub and TXT files can be opened');
        return;
      }

      final file = await ref
          .read(downloadedPdfsProvider.notifier)
          .getFileForItem(item);
      if (file == null || !await file.exists()) {
        _showSnackBar('File not found');
        return;
      }

      await ref.read(downloadedPdfsProvider.notifier).markOpened(item.id);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UnifiedReaderScreen(
            documentUrl: file.path,
            title: item.title,
            identifier: item.id,
            thumbnailUrl: item.thumbnailUrl,
            source: 'local',
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Error opening file: $e');
    }
  }

  Future<void> _deleteItem(DownloadedPdfItem item) async {
    try {
      final confirmed = await _showConfirmDialog(
        title: 'Delete Download',
        message: 'Are you sure you want to delete "${item.title}"?',
        confirmText: 'Delete',
        isDestructive: true,
      );

      if (confirmed != true) return;

      final success = await ref
          .read(downloadedPdfsProvider.notifier)
          .deleteItem(item.id);
      _showSnackBar(
        success ? 'Deleted: ${item.title}' : 'Failed to delete file',
      );
    } catch (e) {
      _showSnackBar('Error deleting file: $e');
    }
  }

  Future<void> _deleteMultiple(List<String> ids) async {
    try {
      final confirmed = await _showConfirmDialog(
        title: 'Delete ${ids.length} Downloads',
        message: 'Are you sure you want to delete ${ids.length} files?',
        confirmText: 'Delete All',
        isDestructive: true,
      );

      if (confirmed != true) return;

      final success = await ref
          .read(downloadedPdfsProvider.notifier)
          .deleteMultiple(ids);
      if (success) {
        _showSnackBar('Deleted ${ids.length} files');
        ref.read(downloadedPdfSelectionProvider.notifier).clear();
        setState(() => _isSelectionMode = false);
      } else {
        _showSnackBar('Failed to delete some files');
      }
    } catch (e) {
      _showSnackBar('Error deleting files: $e');
    }
  }

  Future<void> _moveToDownloads(DownloadedPdfItem item) async {
    try {
      final file = await ref
          .read(downloadedPdfsProvider.notifier)
          .getFileForItem(item);
      if (file == null || !await file.exists()) {
        _showSnackBar('File not found');
        return;
      }

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await AppDirectoryProvider.preferredBaseDir();
        }
      } else {
        downloadsDir = await AppDirectoryProvider.preferredBaseDir();
      }

      final destPath = '${downloadsDir.path}/${item.fileName}';
      final destFile = File(destPath);

      if (await destFile.exists()) {
        final overwrite = await _showConfirmDialog(
          title: 'File Exists',
          message:
              'A file with this name already exists in Downloads. Overwrite?',
          confirmText: 'Overwrite',
          isDestructive: true,
        );

        if (overwrite != true) return;
        await destFile.delete();
      }

      await file.copy(destPath);
      _showSnackBar('Copied to Downloads: ${item.fileName}');
    } catch (e) {
      _showSnackBar('Error moving file: $e');
    }
  }

  Future<void> _renameItem(DownloadedPdfItem item) async {
    try {
      final controller = TextEditingController(text: item.title);

      final newTitle = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'New name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.pop(ctx, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Rename'),
            ),
          ],
        ),
      );

      controller.dispose();

      if (newTitle == null || newTitle.trim().isEmpty) return;
      if (newTitle.trim() == item.title) return;

      final success = await ref
          .read(downloadedPdfsProvider.notifier)
          .renameItem(item.id, newTitle.trim());

      _showSnackBar(success ? 'Renamed successfully' : 'Failed to rename');
    } catch (e) {
      _showSnackBar('Error renaming: $e');
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
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
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ========== Grid Item Widget ==========

class _DownloadedPdfGridItem extends StatelessWidget {
  final DownloadedPdfItem item;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRead;
  final VoidCallback onDelete;
  final VoidCallback onMoveToDownloads;
  final VoidCallback onRename;

  const _DownloadedPdfGridItem({
    required this.item,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onRead,
    required this.onDelete,
    required this.onMoveToDownloads,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(colorScheme),
                  if (isSelectionMode)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildCheckbox(colorScheme),
                    ),
                  if (!isSelectionMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _buildMenu(context, colorScheme),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildChip(colorScheme),
                      const Spacer(),
                      Text(
                        DocumentUtils.formatFileSize(item.sizeBytes ?? 0),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: item.thumbnailUrl != null
          ? Image.network(
              item.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildIcon(colorScheme),
            )
          : _buildIcon(colorScheme),
    );
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    final (icon, color) = _getIconData(colorScheme);
    return Center(
      child: Icon(icon, size: 48, color: color.withValues(alpha: 0.7)),
    );
  }

  (IconData, Color) _getIconData(ColorScheme colorScheme) {
    if (item.isPdf) return (Icons.picture_as_pdf, Colors.red);
    if (item.isEpub) return (Icons.menu_book, Colors.green);
    if (item.isTxt) return (Icons.description, Colors.blue);
    return (Icons.insert_drive_file, colorScheme.primary);
  }

  Widget _buildCheckbox(ColorScheme colorScheme) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary
            : colorScheme.surface.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outline,
          width: 2,
        ),
      ),
      child: isSelected
          ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
          : null,
    );
  }

  Widget _buildChip(ColorScheme colorScheme) {
    final (_, color) = _getIconData(colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        item.extension.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(16),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onSelected: (value) {
          switch (value) {
            case 'read':
              onRead();
            case 'rename':
              onRename();
            case 'move':
              onMoveToDownloads();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (context) => [
          _menuItem('read', Icons.menu_book, 'Read'),
          _menuItem('rename', Icons.edit, 'Rename'),
          _menuItem('move', Icons.drive_file_move, 'Move to Downloads'),
          _menuItem(
            'delete',
            Icons.delete,
            'Delete',
            isDestructive: true,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool isDestructive = false,
    ColorScheme? colorScheme,
  }) {
    final color = isDestructive ? colorScheme?.error : null;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: color != null ? TextStyle(color: color) : null),
        ],
      ),
    );
  }
}

// ========== List Item Widget ==========

class _DownloadedPdfListItem extends StatelessWidget {
  final DownloadedPdfItem item;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRead;
  final VoidCallback onDelete;
  final VoidCallback onMoveToDownloads;
  final VoidCallback onRename;

  const _DownloadedPdfListItem({
    required this.item,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onRead,
    required this.onDelete,
    required this.onMoveToDownloads,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: colorScheme.primary, width: 2)
              : BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (isSelectionMode)
                  _buildCheckbox(colorScheme)
                else
                  _buildThumbnail(colorScheme),
                const SizedBox(width: 12),
                Expanded(child: _buildContent(textTheme, colorScheme)),
                if (!isSelectionMode) ...[
                  IconButton(
                    icon: const Icon(Icons.menu_book),
                    onPressed: onRead,
                    tooltip: 'Read',
                    visualDensity: VisualDensity.compact,
                  ),
                  _buildMenu(context, colorScheme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(ColorScheme colorScheme) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primary : colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outline,
          width: 2,
        ),
      ),
      child: isSelected
          ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
          : null,
    );
  }

  Widget _buildThumbnail(ColorScheme colorScheme) {
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: item.thumbnailUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildIcon(colorScheme),
              ),
            )
          : _buildIcon(colorScheme),
    );
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    final (icon, color) = _getIconData(colorScheme);
    return Center(
      child: Icon(icon, size: 28, color: color.withValues(alpha: 0.7)),
    );
  }

  (IconData, Color) _getIconData(ColorScheme colorScheme) {
    if (item.isPdf) return (Icons.picture_as_pdf, Colors.red);
    if (item.isEpub) return (Icons.menu_book, Colors.green);
    if (item.isTxt) return (Icons.description, Colors.blue);
    return (Icons.insert_drive_file, colorScheme.primary);
  }

  Widget _buildContent(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildChip(colorScheme),
            const SizedBox(width: 8),
            Text(
              DocumentUtils.formatFileSize(item.sizeBytes ?? 0),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (item.lastOpened != null) ...[
              const SizedBox(width: 8),
              Text(
                DocumentUtils.formatReadingTime(
                  DateTime.now().difference(item.lastOpened!),
                ),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildChip(ColorScheme colorScheme) {
    final (_, color) = _getIconData(colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        item.extension.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, ColorScheme colorScheme) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        switch (value) {
          case 'rename':
            onRename();
          case 'move':
            onMoveToDownloads();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (context) => [
        _menuItem('rename', Icons.edit, 'Rename'),
        _menuItem('move', Icons.drive_file_move, 'Move to Downloads'),
        _menuItem(
          'delete',
          Icons.delete,
          'Delete',
          isDestructive: true,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool isDestructive = false,
    ColorScheme? colorScheme,
  }) {
    final color = isDestructive ? colorScheme?.error : null;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: color != null ? TextStyle(color: color) : null),
        ],
      ),
    );
  }
}

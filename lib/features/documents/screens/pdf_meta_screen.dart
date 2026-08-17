import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../providers/download_providers.dart';
import '../../video_search/models/thumbnail_file.dart';
import '../../video_search/widgets/thumbnail_grid_item.dart';
import '../../video_search/widgets/thumbnail_list_item.dart';
import '../models/archive_item.dart';
import '../models/pdf_file.dart';
import '../models/pdf_metadata.dart';
import '../providers/pdf_metadata_provider.dart';
import '../widgets/pdf_file_grid_item.dart';
import '../widgets/pdf_file_list_item.dart';
import '../widgets/downloaded_pdf_widget.dart';
import '../utils/reader_utils.dart' as doc_utils;
import 'unified_reader_screen.dart';
import '../../private_browser/private_browser_screen.dart';
import '../../../../core/constants/languages.dart';
import '../widgets/filter_bottom_sheet.dart' show LanguagePickerSheet;

// ========== REUSE EXISTING WIDGETS ==========
import '../widgets/reading_history_widget.dart' show ReadingHistoryWidget;

class PdfMetaScreen extends ConsumerStatefulWidget {
  final ArchiveItem item;

  const PdfMetaScreen({super.key, required this.item});

  @override
  ConsumerState<PdfMetaScreen> createState() => _PdfMetaScreenState();
}

class _PdfMetaScreenState extends ConsumerState<PdfMetaScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // CHANGED: 2 tabs -> 4 tabs
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _identifier => widget.item.identifier;

  @override
  Widget build(BuildContext context) {
    try {
      final state = ref.watch(pdfMetadataNotifierProvider(_identifier));
      final viewMode = ref.watch(pdfMetaViewModeProvider);

      return Scaffold(body: _buildBody(state, viewMode));
    } catch (e) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: AppErrorWidget(
          message: 'Something went wrong: $e',
          onRetry: () => setState(() {}),
        ),
      );
    }
  }

  Widget _buildBody(PdfMetadataState state, PdfViewMode viewMode) {
    final colorScheme = Theme.of(context).colorScheme;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          _buildAppBar(state, viewMode),
          _buildTabBarHeader(colorScheme, state),
        ];
      },
      body: _buildTabContent(state, viewMode),
    );
  }

  Widget _buildAppBar(PdfMetadataState state, PdfViewMode viewMode) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      floating: false,
      flexibleSpace: FlexibleSpaceBar(background: _buildHeader(state)),
      actions: [
        IconButton(
          icon: Icon(
            viewMode == PdfViewMode.grid ? Icons.view_list : Icons.grid_view,
          ),
          onPressed: () {
            ref.read(pdfMetaViewModeProvider.notifier).toggle();
          },
          tooltip: viewMode == PdfViewMode.grid
              ? 'Switch to List view'
              : 'Switch to Grid view',
        ),
        Consumer(
          builder: (context, ref, _) {
            final selectedLang = ref.watch(pdfFileLanguageFilterProvider);
            final isFiltered = selectedLang.code.isNotEmpty;
            return IconButton(
              icon: Badge(
                isLabelVisible: isFiltered,
                smallSize: 8,
                child: Icon(
                  isFiltered ? Icons.language : Icons.language_outlined,
                  color: isFiltered ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
              tooltip: isFiltered
                  ? 'Language: ${selectedLang.name}'
                  : 'Filter by Language',
              onPressed: _showLanguagePicker,
            );
          },
        ),
        PopupMenuButton<PdfFileFilter>(
          icon: const Icon(Icons.filter_alt_outlined),
          tooltip: 'Format Filter',
          onSelected: (filter) {
            ref.read(pdfFileFilterProvider.notifier).state = filter;
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: PdfFileFilter.all, child: Text('All Files')),
            PopupMenuItem(value: PdfFileFilter.pdf, child: Text('PDF Only')),
            PopupMenuItem(value: PdfFileFilter.epub, child: Text('EPUB Only')),
            PopupMenuItem(value: PdfFileFilter.other, child: Text('Other')),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.open_in_browser),
          onPressed: () => _openUrl(widget.item.detailsUrl),
          tooltip: 'Open in browser',
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _shareItem,
          tooltip: 'Share',
        ),
      ],
    );
  }

  Widget _buildHeader(PdfMetadataState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final meta = state.metadata;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.8),
            colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: widget.item.thumbnailUrl,
                  width: 70,
                  height: 95,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 70,
                    height: 95,
                    color: colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 70,
                    height: 95,
                    color: colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.picture_as_pdf, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      meta?.title ?? widget.item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_getCreator(meta) != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _getCreator(meta)!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _InfoChip(
                          icon: Icons.visibility,
                          label: widget.item.formattedDownloads,
                        ),
                        _InfoChip(
                          icon: Icons.sd_storage,
                          label:
                              meta?.formattedItemSize ??
                              widget.item.formattedSize,
                        ),
                        if (state.filesCount > 0)
                          _InfoChip(
                            icon: Icons.folder,
                            label: '${state.filesCount}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _getCreator(PdfMetadata? meta) {
    return meta?.creator ?? widget.item.creator;
  }

  // CHANGED: Added Downloads and History tabs
  Widget _buildTabBarHeader(ColorScheme colorScheme, PdfMetadataState state) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        tabBar: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_drive_file, size: 16),
                  SizedBox(width: 6),
                  Text('Files'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image, size: 16),
                  SizedBox(width: 6),
                  Text('Images'),
                ],
              ),
            ),
            // NEW: Downloads tab
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_done, size: 16),
                  SizedBox(width: 6),
                  Text('Downloads'),
                ],
              ),
            ),
            // NEW: History tab
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 16),
                  SizedBox(width: 6),
                  Text('History'),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.surface,
      ),
    );
  }

  // CHANGED: Added Downloads and History tab content
  Widget _buildTabContent(PdfMetadataState state, PdfViewMode viewMode) {
    if (state.isLoading) {
      return TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          LoadingWidget(message: 'Loading files...'),
          LoadingWidget(message: 'Loading images...'),
          LoadingWidget(message: 'Loading downloads...'),
          LoadingWidget(message: 'Loading history...'),
        ],
      );
    }

    if (state.error != null) {
      return TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          AppErrorWidget(message: state.error!, onRetry: _refresh),
          AppErrorWidget(message: state.error!, onRetry: _refresh),
          // Downloads and History still work even if metadata fails
          DownloadedPdfWidget(showHeader: false), // need create
          const ReadingHistoryWidget(showHeader: false),
        ],
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildFilesTab(state, viewMode),
        _buildImagesTab(state, viewMode),
        // NEW: Reuse existing widgets
        DownloadedPdfWidget(showHeader: false), // need create(),
        const ReadingHistoryWidget(showHeader: false),
      ],
    );
  }

  void _showLanguagePicker() {
    final currentLang = ref.read(pdfFileLanguageFilterProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LanguagePickerSheet(
        selectedLanguage: currentLang,
        onSelected: (language) {
          ref.read(pdfFileLanguageFilterProvider.notifier).state = language;
          Navigator.pop(context);
        },
      ),
    );
  }

  void _resetAllFilters() {
    ref.read(pdfFileFilterProvider.notifier).state = PdfFileFilter.all;
    ref.read(pdfFileLanguageFilterProvider.notifier).state = AppLanguages.all;
  }

  Widget _buildFilesTab(PdfMetadataState state, PdfViewMode viewMode) {
    final formatFilter = ref.watch(pdfFileFilterProvider);
    final languageFilter = ref.watch(pdfFileLanguageFilterProvider);
    final files = state.getFilteredFiles(
      formatFilter: formatFilter,
      languageFilter: languageFilter,
    );

    final hasActiveFilter =
        formatFilter != PdfFileFilter.all || languageFilter.code.isNotEmpty;

    return Column(
      children: [
        _buildQuickFilterBar(formatFilter, languageFilter, state),
        if (hasActiveFilter)
          _buildFilterBanner(formatFilter, languageFilter, files.length),
        Expanded(
          child: files.isEmpty
              ? _buildEmptyFilteredState(formatFilter, languageFilter)
              : (viewMode == PdfViewMode.grid
                  ? _buildFilesGrid(files, state)
                  : _buildFilesList(files, state)),
        ),
      ],
    );
  }

  Widget _buildQuickFilterBar(
    PdfFileFilter formatFilter,
    Language languageFilter,
    PdfMetadataState state,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final detectedLangs = state.getDetectedLanguages();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Language picker chip
          ActionChip(
            avatar: Icon(
              Icons.language,
              size: 16,
              color: languageFilter.code.isNotEmpty
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            label: Text(
              languageFilter.code.isNotEmpty
                  ? languageFilter.name
                  : 'Language',
            ),
            backgroundColor: languageFilter.code.isNotEmpty
                ? colorScheme.primaryContainer
                : null,
            side: BorderSide(
              color: languageFilter.code.isNotEmpty
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
            onPressed: _showLanguagePicker,
          ),
          if (languageFilter.code.isNotEmpty) ...[
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                ref.read(pdfFileLanguageFilterProvider.notifier).state =
                    AppLanguages.all;
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.cancel,
                  size: 18,
                  color: colorScheme.outline,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          const SizedBox(
            height: 20,
            child: VerticalDivider(thickness: 1, width: 1),
          ),
          const SizedBox(width: 8),
          // Format filter chips
          ...PdfFileFilter.values.map((f) {
            final isSelected = formatFilter == f;
            String label;
            switch (f) {
              case PdfFileFilter.all:
                label = 'All Types';
                break;
              case PdfFileFilter.pdf:
                label = 'PDF';
                break;
              case PdfFileFilter.epub:
                label = 'EPUB';
                break;
              case PdfFileFilter.other:
                label = 'Other';
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  ref.read(pdfFileFilterProvider.notifier).state =
                      selected ? f : PdfFileFilter.all;
                },
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
          // Detected item languages quick chips (if any other languages detected)
          if (detectedLangs.length > 1) ...[
            const SizedBox(
              height: 20,
              child: VerticalDivider(thickness: 1, width: 1),
            ),
            const SizedBox(width: 8),
            ...detectedLangs.map((lang) {
              final isSelected = languageFilter.code == lang.code;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(lang.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    ref.read(pdfFileLanguageFilterProvider.notifier).state =
                        selected ? lang : AppLanguages.all;
                  },
                  visualDensity: VisualDensity.compact,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterBanner(
    PdfFileFilter formatFilter,
    Language languageFilter,
    int count,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final filterParts = <String>[];
    if (formatFilter != PdfFileFilter.all) {
      filterParts.add(formatFilter.name.toUpperCase());
    }
    if (languageFilter.code.isNotEmpty) {
      filterParts.add(languageFilter.name);
    }
    final filterText = filterParts.join(' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: colorScheme.primaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.filter_alt,
            size: 16,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$filterText ($count files)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onPrimaryContainer,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _resetAllFilters,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
            ),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilteredState(
    PdfFileFilter formatFilter,
    Language languageFilter,
  ) {
    String subtitle = 'No document files available';
    if (languageFilter.code.isNotEmpty && formatFilter != PdfFileFilter.all) {
      subtitle =
          'No ${formatFilter.name.toUpperCase()} files found in ${languageFilter.name}';
    } else if (languageFilter.code.isNotEmpty) {
      subtitle = 'No files found in ${languageFilter.name}';
    } else if (formatFilter != PdfFileFilter.all) {
      subtitle = 'No ${formatFilter.name.toUpperCase()} files found';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyStateWidget(
              title: 'No Matching Files',
              subtitle: subtitle,
              icon: Icons.filter_alt_off_outlined,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _resetAllFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesGrid(List<PdfFile> files, PdfMetadataState state) {
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(context);
    final padding = ResponsiveHelper.getScreenPadding(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          return PdfFileGridItem(
            file: file,
            identifier: _identifier,
            thumbnailUrl: _findThumbnailForFile(file, state.allThumbnails),
            isLiked: state.isFileLiked(file.name),
            onOpen: () => _openFile(file),
            onDownload: () => _downloadFile(file),
            onShare: () => _shareFile(file),
            onLike: () => _toggleFileLike(file.name),
          );
        },
      ),
    );
  }

  Widget _buildFilesList(List<PdfFile> files, PdfMetadataState state) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          return PdfFileListItem(
            file: file,
            identifier: _identifier,
            thumbnailUrl: _findThumbnailForFile(file, state.allThumbnails),
            isLiked: state.isFileLiked(file.name),
            onOpen: () => _openFile(file),
            onDownload: () => _downloadFile(file),
            onShare: () => _shareFile(file),
            onLike: () => _toggleFileLike(file.name),
          );
        },
      ),
    );
  }

  Widget _buildImagesTab(PdfMetadataState state, PdfViewMode viewMode) {
    final thumbnails = state.allThumbnails;

    if (thumbnails.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Images',
        subtitle: 'No images available for this item',
        icon: Icons.image_not_supported_outlined,
      );
    }

    return viewMode == PdfViewMode.grid
        ? _buildImagesGrid(thumbnails, state)
        : _buildImagesList(thumbnails, state);
  }

  Widget _buildImagesGrid(
    List<ThumbnailFile> thumbnails,
    PdfMetadataState state,
  ) {
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(context);
    final padding = ResponsiveHelper.getScreenPadding(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: thumbnails.length,
        itemBuilder: (context, index) {
          final thumb = thumbnails[index];
          return ThumbnailGridItem(
            thumbnail: thumb,
            identifier: _identifier,
            isFavorite: state.isThumbnailLiked(thumb.name),
            onTap: () => _viewImage(thumb),
            onDownload: () => _downloadImage(thumb),
            onShare: () => _shareImage(thumb),
            onFavorite: () => _toggleFavorite(thumb),
          );
        },
      ),
    );
  }

  Widget _buildImagesList(
    List<ThumbnailFile> thumbnails,
    PdfMetadataState state,
  ) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: thumbnails.length,
        itemBuilder: (context, index) {
          final thumb = thumbnails[index];
          return ThumbnailListItem(
            thumbnail: thumb,
            identifier: _identifier,
            isFavorite: state.isThumbnailLiked(thumb.name),
            onTap: () => _viewImage(thumb),
            onDownload: () => _downloadImage(thumb),
            onShare: () => _shareImage(thumb),
            onFavorite: () => _toggleFavorite(thumb),
          );
        },
      ),
    );
  }

  // ========== Helpers ==========

  String? _findThumbnailForFile(PdfFile file, List<ThumbnailFile> thumbnails) {
    if (thumbnails.isEmpty) {
      return widget.item.thumbnailUrl;
    }

    final baseName = file.name.contains('.')
        ? file.name.substring(0, file.name.lastIndexOf('.')).toLowerCase()
        : file.name.toLowerCase();

    for (final thumb in thumbnails) {
      final thumbName = thumb.name.toLowerCase();
      if (thumbName.contains(baseName)) {
        return thumb.getUrl(_identifier);
      }
    }

    return thumbnails.isNotEmpty
        ? thumbnails.first.getUrl(_identifier)
        : widget.item.thumbnailUrl;
  }

  // ========== Actions ==========

  Future<void> _refresh() async {
    try {
      await ref
          .read(pdfMetadataNotifierProvider(_identifier).notifier)
          .refresh();
    } catch (e) {
      _showSnackBar('Failed to refresh');
    }
  }

  void _toggleFileLike(String fileName) {
    try {
      ref
          .read(pdfMetadataNotifierProvider(_identifier).notifier)
          .toggleFileLike(fileName);
    } catch (e) {
      _showSnackBar('Failed to toggle like');
    }
  }

  // FIXED: Corrected the logic bug
  Future<void> _openFile(PdfFile item) async {
    try {
      final ext = item.extension.toLowerCase().replaceAll('.', '');
      if (ext != 'pdf' && ext != 'epub' && ext != 'txt') {
        _showSnackBar('Only PDF, EPUB, and TXT files are supported');
        return;
      }

      final url = item.getUrl(_identifier);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UnifiedReaderScreen(
            documentUrl: url,
            title: item.displayName,
            identifier: _identifier,
            thumbnailUrl: widget.item.thumbnailUrl,
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Error opening file');
    }
  }

  Future<void> _downloadFile(PdfFile file) async {
    try {
      final url = file.getUrl(_identifier);
      await doc_utils.DownloadLibraryManager().downloadAndSave(
        url: url,
        title: '${widget.item.title} - ${file.displayName}',
        downloader: doc_utils.DioPdfDownloader(),
        cancelToken: CancelToken(),
        thumbnailUrl: widget.item.thumbnailUrl,
      );
      _showSnackBar('Downloaded to library: ${file.displayName}');
    } catch (e) {
      _showSnackBar('Failed to start download');
    }
  }

  Future<void> _shareFile(PdfFile file) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Share: ${file.displayName}',
          text:
              '${widget.item.title}\n\n'
              '${file.displayName}\n\n'
              '${file.getUrl(_identifier)}',
          subject: widget.item.title,
        ),
      );
    } catch (e) {
      _showSnackBar('Error sharing');
    }
  }

  Future<void> _viewImage(ThumbnailFile thumb) async {
    final imageUrl = thumb.getUrl(_identifier);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 64, color: Colors.white54),
                      SizedBox(height: 12),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.download, color: Colors.white, size: 28),
                onPressed: () {
                  Navigator.pop(ctx);
                  _downloadImage(thumb);
                },
              ),
            ),
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Text(
                thumb.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadImage(ThumbnailFile thumb) async {
    try {
      await ref
          .read(downloadsProvider.notifier)
          .startDownload(
            identifier: '${_identifier}_${thumb.name.hashCode}',
            title: thumb.displayName,
            url: thumb.getUrl(_identifier),
            mediaType: 'image',
            thumbnailUrl: thumb.getUrl(_identifier),
          );
      _showSnackBar('Download started');
    } catch (e) {
      _showSnackBar('Failed to start download');
    }
  }

  Future<void> _shareImage(ThumbnailFile thumb) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Share Archive Url',
          uri: Uri.parse(thumb.getUrl(_identifier)),
        ),
      );
    } catch (e) {
      _showSnackBar('Error sharing');
    }
  }

  Future<void> _toggleFavorite(ThumbnailFile thumb) async {
    try {
      final wasLiked = ref
          .read(pdfMetadataNotifierProvider(_identifier))
          .isThumbnailLiked(thumb.name);
      ref
          .read(pdfMetadataNotifierProvider(_identifier).notifier)
          .toggleThumbnailLike(thumb.name);
      _showSnackBar(
        wasLiked ? 'Removed from favorites' : 'Added to favorites',
      );
    } catch (e) {
      _showSnackBar('Failed to update favorite status');
    }
  }

  Future<void> _openUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrivateBrowserScreen(initialUrl: url),
        ),
      );
    } catch (e) {
      _showSnackBar('Failed to open link');
    }
  }

  Future<void> _shareItem() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Archive Detail Url',
          subject: widget.item.title,
          text: '${widget.item.title}\n\n${widget.item.detailsUrl}',
        ),
      );
    } catch (e) {
      _showSnackBar('Error sharing');
    }
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

// ========== Tab Bar Delegate (unchanged) ==========

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  const _TabBarDelegate({required this.tabBar, required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor;
  }
}

// ========== Info Chip (unchanged) ==========

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: colorScheme.outline),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

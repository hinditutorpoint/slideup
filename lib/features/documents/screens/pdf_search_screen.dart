import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../../core/utils/responsive_helper.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../providers/download_providers.dart';
import '../../../screens/downloads_screen.dart';
import '../models/archive_item.dart';
import '../providers/pdf_providers.dart';
import '../widgets/active_filter_chips.dart';
import '../widgets/filter_button.dart';
import '../widgets/pdf_grid_item.dart';
import '../widgets/pdf_list_item.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/view_toggle_button.dart';
import 'pdf_meta_screen.dart';

class PdfSearchScreen extends ConsumerStatefulWidget {
  const PdfSearchScreen({super.key});

  @override
  ConsumerState<PdfSearchScreen> createState() => _PdfSearchScreenState();
}

class _PdfSearchScreenState extends ConsumerState<PdfSearchScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    try {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(pdfSearchProvider.notifier).loadMore();
      }
    } catch (e) {
      debugPrint('Scroll error: $e');
    }
  }

  Future<void> _openPdf(ArchiveItem item) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfMetaScreen(item: item)),
      );
    } catch (e) {
      _showSnackBar('Error opening PDF: $e');
    }
  }

  Future<void> _sharePdf(ArchiveItem item) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${item.title}\n\nView on Archive.org: ${item.detailsUrl}',
          subject: item.title,
        ),
      );
    } catch (e) {
      _showSnackBar('Error sharing: $e');
    }
  }

  void _likePdf(ArchiveItem item) {
    try {
      final wasLiked = item.isLiked;
      ref.read(pdfSearchProvider.notifier).toggleLike(item);
      _showSnackBar(
        wasLiked ? 'Removed from favorites' : 'Added to favorites',
      );
    } catch (e) {
      debugPrint('Like error: $e');
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
  Widget build(BuildContext context) {
    final searchState = ref.watch(pdfSearchProvider);
    final viewMode = ref.watch(viewModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Search'),
        actions: [
          const FilterButton(),
          const ViewToggleButton(),
          IconButton(
            icon: const Icon(Icons.favorite),
            tooltip: 'Liked PDFs',
            onPressed: () => _showLikedPdfs(context),
          ),
          _buildDownloadBadge(),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const PdfSearchBar(),
            const ActiveFilterChips(),
            _buildResultsCount(searchState),
            Expanded(child: _buildContent(searchState, viewMode)),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadBadge() {
    return Consumer(
      builder: (context, ref, child) {
        try {
          final downloadsState = ref.watch(downloadsProvider);
          final activeCount = downloadsState.activeDownloads.length;

          return Badge(
            isLabelVisible: activeCount > 0,
            label: Text('$activeCount'),
            child: IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Downloads',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                );
              },
            ),
          );
        } catch (_) {
          return IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              );
            },
          );
        }
      },
    );
  }

  Widget _buildResultsCount(PdfSearchState state) {
    if (state.items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '${_formatNumber(state.totalResults)} results found',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          if (state.filter.hasActiveFilters) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Filtered',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildContent(PdfSearchState state, ViewMode viewMode) {
    if (state.isLoading && state.items.isEmpty) {
      return const LoadingWidget(message: 'Searching...');
    }

    if (state.error != null && state.items.isEmpty) {
      return AppErrorWidget(
        message: state.error!,
        onRetry: () => ref.read(pdfSearchProvider.notifier).refresh(),
      );
    }

    if (state.query.isEmpty) {
      return const SearchEmptyStateWidget();
    }

    if (state.items.isEmpty) {
      return NoResultsWidget(query: state.query);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(pdfSearchProvider.notifier).refresh(),
      child: viewMode == ViewMode.grid
          ? _buildGridView(state)
          : _buildListView(state),
    );
  }

  Widget _buildGridView(PdfSearchState state) {
    try {
      final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(context);
      final aspectRatio = ResponsiveHelper.getGridChildAspectRatio(context);
      final padding = ResponsiveHelper.getScreenPadding(context);

      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: padding,
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: aspectRatio,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                try {
                  if (index >= state.items.length) return null;
                  final item = state.items[index];
                  return PdfGridItem(
                    item: item,
                    onTap: () => _openPdf(item),
                    onLike: () => _likePdf(item),
                    onShare: () => _sharePdf(item),
                  );
                } catch (_) {
                  return const SizedBox.shrink();
                }
              }, childCount: state.items.length),
            ),
          ),
          // Loading indicator - CENTERED
          if (state.hasMore)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildCenteredLoader(),
            )
          else if (state.isLoadingMore)
            SliverToBoxAdapter(child: _buildCenteredLoader()),
        ],
      );
    } catch (e) {
      debugPrint('Grid view error: $e');
      return const Center(child: Text('Error loading content'));
    }
  }

  Widget _buildListView(PdfSearchState state) {
    try {
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                try {
                  if (index >= state.items.length) return null;
                  final item = state.items[index];
                  return PdfListItem(
                    item: item,
                    onTap: () => _openPdf(item),
                    onLike: () => _likePdf(item),
                    onShare: () => _sharePdf(item),
                  );
                } catch (_) {
                  return const SizedBox.shrink();
                }
              }, childCount: state.items.length),
            ),
          ),
          // Loading indicator - CENTERED
          if (state.hasMore || state.isLoadingMore)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildCenteredLoader(),
            ),
        ],
      );
    } catch (e) {
      debugPrint('List view error: $e');
      return const Center(child: Text('Error loading content'));
    }
  }

  /// Centered loading animation widget
  Widget _buildCenteredLoader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: LoadingAnimationWidget.progressiveDots(
          color: Theme.of(context).colorScheme.primary,
          size: 50,
        ),
      ),
    );
  }

  void _showLikedPdfs(BuildContext context) {
    try {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => const LikedPdfsSheet(),
      );
    } catch (e) {
      debugPrint('Show liked error: $e');
    }
  }
}

class LikedPdfsSheet extends ConsumerWidget {
  const LikedPdfsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedPdfs = ref.watch(likedPdfsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite_rounded, color: Colors.red),
                    const SizedBox(width: 12),
                    Text(
                      'Liked PDFs',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Expanded(
                child: likedPdfs.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const EmptyStateWidget(
                        title: 'No liked PDFs yet',
                        subtitle: 'PDFs you like will appear here',
                        icon: Icons.favorite_border,
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        try {
                          final item = items[index];
                          return _LikedPdfTile(
                            item: item,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PdfMetaScreen(item: item),
                                ),
                              );
                            },
                          );
                        } catch (_) {
                          return const SizedBox.shrink();
                        }
                      },
                    );
                  },
                  loading: () => Center(
                    child: LoadingAnimationWidget.progressiveDots(
                      color: Theme.of(context).colorScheme.primary,
                      size: 50,
                    ),
                  ),
                  error: (error, _) => AppErrorWidget(
                    message: 'Failed to load liked PDFs',
                    onRetry: () => ref.refresh(likedPdfsProvider),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LikedPdfTile extends StatelessWidget {
  final ArchiveItem item;
  final VoidCallback onTap;

  const _LikedPdfTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          item.thumbnailUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded),
          ),
        ),
      ),
      title: Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: item.creator != null
          ? Text(
              item.creator!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

// Empty state widgets
class SearchEmptyStateWidget extends StatelessWidget {
  const SearchEmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
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
                  Icons.search_rounded,
                  size: 56,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Search for PDFs',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter a search term to find PDFs from the Internet Archive',
                style: TextStyle(color: Theme.of(context).hintColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoResultsWidget extends StatelessWidget {
  final String query;

  const NoResultsWidget({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 56,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No results found',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'No PDFs found for "$query"',
                style: TextStyle(color: Theme.of(context).hintColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Try different keywords or check your spelling',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

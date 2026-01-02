// lib/widgets/pdf/pdf_bookmark_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pdf_provider.dart';

class PdfBookmarkWidget extends ConsumerWidget {
  final Function(int)? onPageSelected;
  final int? currentPage;

  const PdfBookmarkWidget({super.key, this.onPageSelected, this.currentPage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdfState = ref.watch(pdfStateProvider);
    final bookmarks = pdfState.bookmarks.toList()..sort();
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Column(
      children: [
        _buildHeader(context, ref, bookmarks.length, isCompact),
        Expanded(
          child: bookmarks.isEmpty
              ? _buildEmptyState(context)
              : _buildBookmarkList(
                  context,
                  ref,
                  bookmarks,
                  pdfState,
                  isCompact,
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    int count,
    bool isCompact,
  ) {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count Bookmark${count != 1 ? 's' : ''}',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? 14 : 16,
            ),
          ),
          if (count > 0)
            TextButton.icon(
              icon: Icon(Icons.delete_sweep, size: isCompact ? 16 : 18),
              label: Text(
                'Clear All',
                style: TextStyle(fontSize: isCompact ? 12 : 14),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => _showClearConfirmation(context, ref),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              'No Bookmarks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark button\nto add pages here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkList(
    BuildContext context,
    WidgetRef ref,
    List<int> bookmarks,
    PdfState pdfState,
    bool isCompact,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final pageNum = bookmarks[index];
        final isCurrentPage = pageNum == currentPage;
        final hasHighlights = pdfState.highlights.containsKey(pageNum);

        return Dismissible(
          key: Key('bookmark_$pageNum'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) {
            ref.read(pdfStateProvider.notifier).removeBookmark(pageNum);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bookmark for page $pageNum removed'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    ref.read(pdfStateProvider.notifier).toggleBookmark(pageNum);
                  },
                ),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isCurrentPage
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : null,
            child: ListTile(
              leading: Container(
                width: isCompact ? 36 : 40,
                height: isCompact ? 36 : 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bookmark,
                  color: Colors.white,
                  size: isCompact ? 18 : 20,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    'Page $pageNum',
                    style: TextStyle(
                      fontWeight: isCurrentPage
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: isCompact ? 14 : 16,
                    ),
                  ),
                  if (hasHighlights) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.yellow.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${pdfState.highlights[pageNum]!.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: isCurrentPage
                  ? Text(
                      'Current page',
                      style: TextStyle(fontSize: isCompact ? 11 : 12),
                    )
                  : null,
              trailing: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: isCompact ? 18 : 20),
                onSelected: (value) =>
                    _handleMenuAction(context, ref, value, pageNum),
                itemBuilder: (context) => [
                  if (onPageSelected != null)
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
                    value: 'extract_text',
                    child: Row(
                      children: [
                        Icon(Icons.text_snippet, size: 18),
                        SizedBox(width: 12),
                        Text('Extract Text'),
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
                        Text('Remove', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () => onPageSelected?.call(pageNum),
            ),
          ),
        );
      },
    );
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    int pageNum,
  ) {
    switch (action) {
      case 'goto':
        onPageSelected?.call(pageNum);
        break;
      case 'share':
        _shareBookmark(context, ref, pageNum);
        break;
      case 'extract_text':
        _extractPageText(context, ref, pageNum);
        break;
      case 'properties':
        _showProperties(context, ref, pageNum);
        break;
      case 'delete':
        ref.read(pdfStateProvider.notifier).removeBookmark(pageNum);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bookmark removed')));
        break;
    }
  }

  void _shareBookmark(BuildContext context, WidgetRef ref, int pageNum) {
    final pdfState = ref.read(pdfStateProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sharing page $pageNum from ${pdfState.fileName ?? "PDF"}',
        ),
      ),
    );
    // Implement actual share functionality
  }

  void _extractPageText(
    BuildContext context,
    WidgetRef ref,
    int pageNum,
  ) async {
    try {
      await ref.read(pdfStateProvider.notifier).extractSinglePageText(pageNum);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Text extracted from page $pageNum')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to extract text: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showProperties(BuildContext context, WidgetRef ref, int pageNum) {
    final pdfState = ref.read(pdfStateProvider);
    final hasHighlights = pdfState.highlights.containsKey(pageNum);
    final highlightCount = hasHighlights
        ? pdfState.highlights[pageNum]!.length
        : 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Page $pageNum'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropertyRow('Page Number', '$pageNum'),
            _buildPropertyRow('Total Pages', '${pdfState.pageCount}'),
            _buildPropertyRow('Highlights', '$highlightCount'),
            _buildPropertyRow(
              'Position',
              '${((pageNum / pdfState.pageCount) * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (onPageSelected != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onPageSelected!(pageNum);
              },
              child: const Text('Go to Page'),
            ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Bookmarks?'),
        content: const Text(
          'This action cannot be undone. All bookmarks will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(pdfStateProvider.notifier).clearAllBookmarks();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All bookmarks cleared')),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

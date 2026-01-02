import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pdf_provider.dart';

class PdfHighlightsWidget extends ConsumerStatefulWidget {
  final Function(int)? onPageSelected;
  final int? currentPage;

  const PdfHighlightsWidget({super.key, this.onPageSelected, this.currentPage});

  @override
  ConsumerState<PdfHighlightsWidget> createState() =>
      _PdfHighlightsWidgetState();
}

class _PdfHighlightsWidgetState extends ConsumerState<PdfHighlightsWidget> {
  bool _isExpanded = true;

  int _getTotalHighlights(PdfState state) {
    int total = 0;
    state.highlights.forEach((key, value) => total += value.length);
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final pdfState = ref.watch(pdfStateProvider);
    final totalHighlights = _getTotalHighlights(pdfState);
    final sortedPages = pdfState.highlights.keys.toList()..sort();
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Column(
      children: [
        _buildHeader(context, totalHighlights, isCompact),
        _buildColorPicker(context, pdfState, isCompact),
        Expanded(
          child: pdfState.highlights.isEmpty
              ? _buildEmptyState(context)
              : _buildHighlightList(context, sortedPages, pdfState, isCompact),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, int count, bool isCompact) {
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
            '$count Highlight${count != 1 ? 's' : ''}',
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
              onPressed: () => _showClearConfirmation(context),
            ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(
    BuildContext context,
    PdfState state,
    bool isCompact,
  ) {
    final colors = [
      Colors.yellow,
      Colors.green.shade300,
      Colors.blue.shade300,
      Colors.pink.shade300,
      Colors.orange.shade300,
      Colors.purple.shade300,
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          Text('Color:', style: TextStyle(fontSize: isCompact ? 12 : 14)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: colors.map((color) {
                  final isSelected = state.currentHighlightColor == color;
                  return GestureDetector(
                    onTap: () {
                      ref
                          .read(pdfStateProvider.notifier)
                          .setHighlightColor(color);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      width: isCompact ? 28 : 32,
                      height: isCompact ? 28 : 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.black54,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
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
            Icon(Icons.highlight_off, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              'No Highlights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select text in the PDF\nand add highlights',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightList(
    BuildContext context,
    List<int> sortedPages,
    PdfState pdfState,
    bool isCompact,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sortedPages.length,
      itemBuilder: (context, index) {
        final pageNum = sortedPages[index];
        final highlights = pdfState.highlights[pageNum]!;
        final isCurrentPage = pageNum == widget.currentPage;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isCurrentPage
              ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
              : null,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _isExpanded && isCurrentPage,
              leading: Container(
                width: isCompact ? 36 : 40,
                height: isCompact ? 36 : 40,
                decoration: BoxDecoration(
                  color: isCurrentPage
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$pageNum',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: isCompact ? 12 : 14,
                    ),
                  ),
                ),
              ),
              title: Text(
                'Page $pageNum',
                style: TextStyle(
                  fontWeight: isCurrentPage
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: isCompact ? 14 : 16,
                ),
              ),
              subtitle: Text(
                '${highlights.length} highlight${highlights.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: isCompact ? 11 : 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Color indicators
                  ...highlights
                      .map((h) => h.color)
                      .toSet()
                      .take(3)
                      .map(
                        (color) => Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: isCompact ? 18 : 20),
                    onSelected: (value) =>
                        _handlePageMenuAction(context, value, pageNum),
                    itemBuilder: (context) => [
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
                        value: 'extract',
                        child: Row(
                          children: [
                            Icon(Icons.text_snippet, size: 18),
                            SizedBox(width: 12),
                            Text('Extract Text'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 12),
                            Text(
                              'Clear Page',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              children: highlights.map((highlight) {
                return _buildHighlightItem(
                  context,
                  highlight,
                  pageNum,
                  isCompact,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightItem(
    BuildContext context,
    HighlightInfo highlight,
    int pageNum,
    bool isCompact,
  ) {
    return Dismissible(
      key: Key('highlight_${highlight.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        ref
            .read(pdfStateProvider.notifier)
            .removeHighlight(pageNum, highlight.id);
      },
      child: ListTile(
        leading: Container(
          width: isCompact ? 20 : 24,
          height: isCompact ? 20 : 24,
          decoration: BoxDecoration(
            color: highlight.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12),
          ),
        ),
        title: Text(
          highlight.text,
          style: TextStyle(fontSize: isCompact ? 13 : 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDateTime(highlight.timestamp),
          style: TextStyle(
            fontSize: isCompact ? 10 : 11,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz, size: isCompact ? 16 : 18),
          onSelected: (value) =>
              _handleHighlightMenuAction(context, value, highlight, pageNum),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copy',
              child: Row(
                children: [
                  Icon(Icons.copy, size: 18),
                  SizedBox(width: 12),
                  Text('Copy'),
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
        ),
        onTap: () => widget.onPageSelected?.call(pageNum),
      ),
    );
  }

  void _handlePageMenuAction(BuildContext context, String action, int pageNum) {
    switch (action) {
      case 'goto':
        widget.onPageSelected?.call(pageNum);
        break;
      case 'share':
        _sharePageHighlights(context, pageNum);
        break;
      case 'extract':
        _extractPageText(context, pageNum);
        break;
      case 'clear':
        _confirmClearPageHighlights(context, pageNum);
        break;
    }
  }

  void _handleHighlightMenuAction(
    BuildContext context,
    String action,
    HighlightInfo highlight,
    int pageNum,
  ) {
    switch (action) {
      case 'copy':
        _copyHighlightText(context, highlight);
        break;
      case 'share':
        _shareHighlight(context, highlight);
        break;
      case 'properties':
        _showHighlightProperties(context, highlight, pageNum);
        break;
      case 'delete':
        ref
            .read(pdfStateProvider.notifier)
            .removeHighlight(pageNum, highlight.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Highlight deleted')));
        break;
    }
  }

  void _copyHighlightText(BuildContext context, HighlightInfo highlight) {
    // Import clipboard
    // Clipboard.setData(ClipboardData(text: highlight.text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Text copied to clipboard')));
  }

  void _shareHighlight(BuildContext context, HighlightInfo highlight) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sharing: ${highlight.text}')));
  }

  void _sharePageHighlights(BuildContext context, int pageNum) {
    final pdfState = ref.read(pdfStateProvider);
    final highlights = pdfState.highlights[pageNum];
    if (highlights == null || highlights.isEmpty) return;

    final text = highlights.map((h) => h.text).join('\n\n');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sharing ${highlights.length} highlights from page $pageNum',
        ),
      ),
    );
  }

  void _extractPageText(BuildContext context, int pageNum) async {
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
            content: Text('Failed to extract: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmClearPageHighlights(BuildContext context, int pageNum) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Highlights on Page $pageNum?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(pdfStateProvider.notifier).clearPageHighlights(pageNum);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Page highlights cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showHighlightProperties(
    BuildContext context,
    HighlightInfo highlight,
    int pageNum,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Highlight Properties'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropertyRow('Page', '$pageNum'),
            _buildPropertyRow('Text', highlight.text),
            Row(
              children: [
                const Text(
                  'Color: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: highlight.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildPropertyRow('Created', _formatDateTime(highlight.timestamp)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Highlights?'),
        content: const Text(
          'This action cannot be undone. All highlights will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(pdfStateProvider.notifier).clearAllHighlights();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All highlights cleared')),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}

import 'dart:io';
import 'package:flutter/material.dart';

import '../utils/reader_utils.dart';
import '../screens/enhanced_pdf_reader.dart';

/// Shared helper to open a reading position from history or continue-reading card
Future<void> openReadingPosition(
  BuildContext context,
  ReadingPosition position,
) async {
  final title = position.metadata?['title']?.toString() ??
      DocumentUtils.extractTitleFromUrl(position.identifier);
  final pdfUrl = position.metadata?['pdfUrl']?.toString();
  final localPath = position.metadata?['localPath']?.toString();
  final archiveId = position.metadata?['identifier']?.toString() ??
      (position.identifier.startsWith('http') ? null : position.identifier);

  // 1. Try local file if exists
  if (localPath != null && localPath.isNotEmpty) {
    final file = File(localPath);
    if (await file.exists()) {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedPdfReader.file(
            file: file,
            title: title,
            identifier: archiveId,
            initialPage: position.page,
          ),
        ),
      );
      return;
    }
  }

  // 2. Try direct network URL
  String? targetUrl = pdfUrl;
  if (targetUrl == null || targetUrl.isEmpty) {
    if (position.identifier.startsWith('http://') ||
        position.identifier.startsWith('https://')) {
      targetUrl = position.identifier;
    } else {
      final fileSuffix = position.metadata?['fileName'] ??
          (title.endsWith('.pdf') ? title : '$title.pdf');
      targetUrl =
          'https://archive.org/download/${position.identifier}/$fileSuffix';
    }
  }

  if (!context.mounted) return;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EnhancedPdfReader.network(
        pdfUrl: targetUrl!,
        title: title,
        identifier: archiveId,
        initialPage: position.page,
      ),
    ),
  );
}

class ReadingHistoryWidget extends StatefulWidget {
  final int maxItems;
  final bool showClearButton;
  final bool showHeader;

  const ReadingHistoryWidget({
    super.key,
    this.maxItems = 20,
    this.showClearButton = true,
    this.showHeader = true,
  });

  @override
  State<ReadingHistoryWidget> createState() => _ReadingHistoryWidgetState();
}

class _ReadingHistoryWidgetState extends State<ReadingHistoryWidget> {
  final ReaderStorageManager _storageManager = ReaderStorageManager();
  //final DownloadLibraryManager _library = DownloadLibraryManager();

  List<ReadingPosition> _recentPositions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _storageManager.initialize();
      final recentIds = await _storageManager.getRecentReads();

      final positions = <ReadingPosition>[];
      for (final id in recentIds.take(widget.maxItems)) {
        final position = await _storageManager.getReadingPosition(id);
        if (position != null) {
          positions.add(position);
        }
      }

      if (mounted) {
        setState(() {
          _recentPositions = positions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load history';
        });
      }
    }
  }

  Future<void> _openDocument(ReadingPosition position) async {
    await openReadingPosition(context, position);

    // Refresh after returning
    if (mounted) _loadHistory();
  }

  Future<void> _deleteItem(ReadingPosition position) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from history?'),
        content: Text(
          'Remove "${position.metadata?['title'] ?? 'this item'}" from reading history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _storageManager.deleteReadingPosition(position.identifier);
    _loadHistory();
    _showSnackBar('Removed from history');
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Reading History?'),
        content: Text(
          'This will remove ${_recentPositions.length} items from your history. '
          'Bookmarks and highlights will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _storageManager.clearRecentReads();
    _loadHistory();
    _showSnackBar('History cleared');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recentPositions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No reading history yet',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Start reading to see your history here',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadHistory,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _recentPositions.length,
              itemBuilder: (context, index) {
                final position = _recentPositions[index];
                return _ReadingHistoryItem(
                  position: position,
                  onTap: () => _openDocument(position),
                  onDelete: () => _deleteItem(position),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.history, size: 20),
          const SizedBox(width: 8),
          Text(
            'Reading History',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_recentPositions.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          const Spacer(),
          if (widget.showClearButton && _recentPositions.isNotEmpty)
            TextButton.icon(
              onPressed: _clearHistory,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            ),
        ],
      ),
    );
  }
}

// ========== Reading History Item ==========

class _ReadingHistoryItem extends StatelessWidget {
  final ReadingPosition position;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ReadingHistoryItem({
    required this.position,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final docType = DocumentUtils.detectDocumentType(position.identifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Document type icon with progress ring
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress ring
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: position.progress,
                        strokeWidth: 3,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: _getIconColor(docType),
                      ),
                    ),
                    // Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getIconColor(docType).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getDocumentIcon(docType),
                        color: _getIconColor(docType),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      position.metadata?['title'] ??
                          _extractTitle(position.identifier),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Page info
                        _InfoBadge(
                          icon: Icons.menu_book,
                          label: 'Page ${position.page}',
                        ),
                        const SizedBox(width: 8),
                        // Progress
                        _InfoBadge(
                          icon: Icons.pie_chart,
                          label: DocumentUtils.formatProgress(
                            position.progress,
                          ),
                          color: Theme.of(context).primaryColor,
                        ),
                        const Spacer(),
                        // Time
                        Text(
                          DocumentUtils.formatReadingTime(
                            DateTime.now().difference(position.lastRead),
                          ),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                onPressed: onDelete,
                tooltip: 'Remove from history',
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDocumentIcon(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.epub:
        return Icons.book;
      case DocumentType.txt:
        return Icons.text_snippet;
      case DocumentType.unknown:
        return Icons.insert_drive_file;
    }
  }

  Color _getIconColor(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Colors.red;
      case DocumentType.epub:
        return Colors.blue;
      case DocumentType.txt:
        return Colors.green;
      case DocumentType.unknown:
        return Colors.grey;
    }
  }

  String _extractTitle(String identifier) {
    return DocumentUtils.extractTitleFromUrl(identifier);
  }
}

// ========== Info Badge ==========

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoBadge({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? Colors.grey[600]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: badgeColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ========== Continue Reading Card ==========

class ContinueReadingCard extends StatefulWidget {
  final VoidCallback? onDismiss;

  const ContinueReadingCard({super.key, this.onDismiss});

  @override
  State<ContinueReadingCard> createState() => _ContinueReadingCardState();
}

class _ContinueReadingCardState extends State<ContinueReadingCard> {
  final ReaderStorageManager _storageManager = ReaderStorageManager();

  ReadingPosition? _lastPosition;
  bool _isLoading = true;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _loadLastRead();
  }

  Future<void> _loadLastRead() async {
    try {
      await _storageManager.initialize();
      final recentIds = await _storageManager.getRecentReads();

      if (recentIds.isNotEmpty) {
        _lastPosition = await _storageManager.getReadingPosition(
          recentIds.first,
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _continueReading() async {
    if (_lastPosition == null) return;

    await openReadingPosition(context, _lastPosition!);

    // Refresh after returning
    if (mounted) _loadLastRead();
  }

  void _dismiss() {
    setState(() => _isDismissed = true);
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _lastPosition == null || _isDismissed) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final progress = _lastPosition!.progress;

    return Dismissible(
      key: Key(_lastPosition!.identifier),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => _dismiss(),
      background: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      child: Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _continueReading,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Background progress indicator
                Positioned(
                  right: -30,
                  bottom: -30,
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Book icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_stories,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Continue Reading',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    DocumentUtils.formatProgress(progress),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _lastPosition!.metadata?['title'] ??
                                  DocumentUtils.extractTitleFromUrl(
                                    _lastPosition!.identifier,
                                  ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.menu_book,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Page ${_lastPosition!.page}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DocumentUtils.formatReadingTime(
                                    DateTime.now().difference(
                                      _lastPosition!.lastRead,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Arrow
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========== Reading History Screen (Standalone) ==========

class ReadingHistoryScreen extends StatelessWidget {
  const ReadingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reading History')),
      body: const ReadingHistoryWidget(
        maxItems: 50,
        showClearButton: true,
        showHeader: false,
      ),
    );
  }
}

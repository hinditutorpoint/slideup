import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as path;

import '../models/epub_book.dart';
import '../providers/epub_provider.dart';
import '../screens/enhanced_epub_reader.dart';

class LibraryTab extends ConsumerStatefulWidget {
  final VoidCallback? onAddBook;

  const LibraryTab({super.key, this.onAddBook});

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab> {
  BookSortOption _sortOption = BookSortOption.dateAdded;
  bool _sortAscending = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    var books = libraryState.books.where((b) => b.isDownloaded).toList();

    // Apply search
    if (_searchQuery.isNotEmpty) {
      books = books.search(_searchQuery);
    }

    // Apply sort
    books = books.sortBy(_sortOption, ascending: _sortAscending);

    return Column(
      children: [
        // Search and Sort Bar
        _buildToolbar(),

        // Search info
        if (_searchQuery.isNotEmpty) _buildSearchInfo(books.length),

        // Book list
        Expanded(
          child: books.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(libraryProvider.notifier).loadLibrary(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      return CompactBookCard(
                        book: books[index],
                        onTap: () => _openReader(books[index]),
                        onRead: () => _openReader(books[index]),
                        onShare: () => _shareBook(books[index]),
                        onMove: () => _moveBook(books[index]),
                        onDelete: () => _confirmDelete(books[index]),
                        onToggleFavorite: () => _toggleFavorite(books[index]),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          // Search
          if (_isSearching)
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search books...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search, size: 22),
              onPressed: () => setState(() => _isSearching = true),
              tooltip: 'Search',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const Spacer(),
          ],

          if (!_isSearching) ...[
            // Sort button
            PopupMenuButton<BookSortOption>(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    _sortOption.displayName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                  ),
                ],
              ),
              tooltip: 'Sort',
              onSelected: (option) {
                setState(() {
                  if (_sortOption == option) {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortOption = option;
                    _sortAscending = option == BookSortOption.title;
                  }
                });
              },
              itemBuilder: (context) => BookSortOption.values.map((option) {
                final isSelected = _sortOption == option;
                return PopupMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      if (isSelected)
                        Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        )
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text(
                        option.displayName,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchInfo(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.grey[100],
      child: Row(
        children: [
          Text(
            '$count result${count != 1 ? 's' : ''} for "$_searchQuery"',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
                _isSearching = false;
              });
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No books found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Library Empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download books to read offline',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onAddBook,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Book'),
            ),
          ],
        ),
      ),
    );
  }

  void _openReader(EpubBook book) {
    if (book.filePath == null) {
      _showError('Book file not found');
      return;
    }
    final file = File(book.filePath!);
    if (!file.existsSync()) {
      _showError('Book file not found');
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EnhancedEpubReader(book: book)));
  }

  Future<void> _shareBook(EpubBook book) async {
    if (book.filePath == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Check out: ${book.title}',
          files: [XFile(book.filePath!)],
        ),
      );
    } catch (e) {
      _showError('Failed to share');
    }
  }

  void _moveBook(EpubBook book) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Copy to Downloads'),
              onTap: () async {
                Navigator.pop(context);
                await _copyToDownloads(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share File'),
              onTap: () {
                Navigator.pop(context);
                _shareBook(book);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToDownloads(EpubBook book) async {
    if (book.filePath == null) return;
    try {
      final source = File(book.filePath!);
      final downloads = '/storage/emulated/0/Download';
      final target = path.join(downloads, path.basename(book.filePath!));
      await source.copy(target);
      _showMessage('Copied to Downloads');
    } catch (e) {
      _showError('Failed to copy');
    }
  }

  void _toggleFavorite(EpubBook book) {
    ref.read(libraryProvider.notifier).toggleFavorite(book.id);
  }

  void _confirmDelete(EpubBook book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book?'),
        content: Text('Delete "${book.title}"?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(libraryProvider.notifier).deleteBook(book.id);
              _showMessage('Deleted');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Compact Book Card for Library
class CompactBookCard extends StatelessWidget {
  final EpubBook book;
  final VoidCallback? onTap;
  final VoidCallback? onRead;
  final VoidCallback? onShare;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleFavorite;

  const CompactBookCard({
    super.key,
    required this.book,
    this.onTap,
    this.onRead,
    this.onShare,
    this.onMove,
    this.onDelete,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: Key(book.id),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => onShare?.call(),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.share,
            label: 'Share',
          ),
          SlidableAction(
            onPressed: (_) => onMove?.call(),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            icon: Icons.folder,
            label: 'Move',
          ),
          SlidableAction(
            onPressed: (_) => onDelete?.call(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Cover
                  _buildCover(),
                  const SizedBox(width: 12),

                  // Details
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                book.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (book.isFavorite)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.favorite,
                                  color: Colors.red,
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Author
                        Text(
                          book.displayAuthor,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Progress
                        _buildProgress(context),
                        const SizedBox(height: 4),

                        // Meta
                        Row(
                          children: [
                            Icon(
                              Icons.storage,
                              size: 11,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 3),
                            Text(
                              book.formattedFileSize,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.list, size: 11, color: Colors.grey[400]),
                            const SizedBox(width: 3),
                            Text(
                              '${book.chapterCount} ch',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  const SizedBox(width: 8),
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    return Container(
      width: 45,
      height: 65,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: book.coverPath != null
            ? Image.file(
                File(book.coverPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _coverPlaceholder(),
              )
            : book.coverUrl != null
            ? CachedNetworkImage(
                imageUrl: book.coverUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _coverPlaceholder(),
                errorWidget: (_, __, ___) => _coverPlaceholder(),
              )
            : _coverPlaceholder(),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book, size: 20, color: Colors.grey[500]),
          Text(
            'EPUB',
            style: TextStyle(
              fontSize: 7,
              color: Colors.grey[500],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(BuildContext context) {
    if (!book.hasStartedReading) {
      return Text(
        'Not started',
        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: book.readingProgress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                book.isFinished ? Colors.green : Theme.of(context).primaryColor,
              ),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${book.readingPercentage}%',
          style: TextStyle(
            fontSize: 10,
            color: book.isFinished ? Colors.green : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Read button
        _actionButton(
          icon: Icons.menu_book,
          color: Theme.of(context).primaryColor,
          onTap: onRead,
          tooltip: 'Read',
        ),
        const SizedBox(height: 4),
        // Favorite button
        _actionButton(
          icon: book.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: book.isFavorite ? Colors.red : Colors.grey,
          onTap: onToggleFavorite,
          tooltip: book.isFavorite ? 'Unfavorite' : 'Favorite',
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

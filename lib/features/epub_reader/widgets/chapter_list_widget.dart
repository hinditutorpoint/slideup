import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/epub_book.dart';
import '../models/reading_progress.dart';
import '../providers/epub_provider.dart';
import '../services/epub_reader_service.dart' show ReadingState;
import 'audiobook_tab.dart';

/// Table of Contents / Chapter list widget
class ChapterListWidget extends ConsumerWidget {
  final EpubBook book;
  final int currentChapterIndex;
  final void Function(TocEntry entry)? onTocEntryTap;
  final void Function(int index)? onChapterTap;
  final bool showProgress;

  const ChapterListWidget({
    super.key,
    required this.book,
    this.currentChapterIndex = 0,
    this.onTocEntryTap,
    this.onChapterTap,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use TOC if available, otherwise use chapters
    if (book.tableOfContents != null && book.tableOfContents!.isNotEmpty) {
      return _buildTocList(context, book.tableOfContents!);
    }

    return _buildChapterList(context);
  }

  Widget _buildTocList(BuildContext context, List<TocEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _TocEntryTile(
          entry: entries[index],
          currentChapterIndex: currentChapterIndex,
          onTap: onTocEntryTap,
          chapterIndexMap: _buildChapterIndexMap(),
        );
      },
    );
  }

  Widget _buildChapterList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: book.chapters.length,
      itemBuilder: (context, index) {
        final chapter = book.chapters[index];
        final isCurrent = index == currentChapterIndex;

        return _ChapterTile(
          chapter: chapter,
          index: index,
          isCurrent: isCurrent,
          showProgress: showProgress,
          onTap: () => onChapterTap?.call(index),
        );
      },
    );
  }

  Map<String, int> _buildChapterIndexMap() {
    final map = <String, int>{};
    for (int i = 0; i < book.chapters.length; i++) {
      final href = book.chapters[i].href;
      if (href != null) {
        map[href] = i;
      }
    }
    return map;
  }
}

class _TocEntryTile extends StatelessWidget {
  final TocEntry entry;
  final int currentChapterIndex;
  final void Function(TocEntry entry)? onTap;
  final Map<String, int> chapterIndexMap;

  const _TocEntryTile({
    required this.entry,
    required this.currentChapterIndex,
    this.onTap,
    required this.chapterIndexMap,
  });

  @override
  Widget build(BuildContext context) {
    // Check if this entry corresponds to current chapter
    final chapterIndex = _findChapterIndex();
    final isCurrent = chapterIndex == currentChapterIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main entry
        ListTile(
          contentPadding: EdgeInsets.only(
            left: 16.0 + (entry.level * 24.0),
            right: 16.0,
          ),
          title: Text(
            entry.title,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? Theme.of(context).primaryColor : null,
              fontSize: entry.level == 0 ? 16 : 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          leading: isCurrent
              ? Icon(
                  Icons.play_arrow,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                )
              : SizedBox(width: entry.level > 0 ? 0 : 20),
          trailing: entry.children.isNotEmpty
              ? Icon(Icons.chevron_right, color: Colors.grey[400], size: 20)
              : null,
          selected: isCurrent,
          selectedTileColor: Theme.of(
            context,
          ).primaryColor.withValues(alpha: 0.1),
          onTap: () => onTap?.call(entry),
        ),

        // Nested children
        if (entry.children.isNotEmpty)
          ...entry.children.map(
            (child) => _TocEntryTile(
              entry: child,
              currentChapterIndex: currentChapterIndex,
              onTap: onTap,
              chapterIndexMap: chapterIndexMap,
            ),
          ),
      ],
    );
  }

  int? _findChapterIndex() {
    // Try exact match
    if (chapterIndexMap.containsKey(entry.href)) {
      return chapterIndexMap[entry.href];
    }

    // Try partial match
    for (final mapEntry in chapterIndexMap.entries) {
      if (mapEntry.key.contains(entry.href) ||
          entry.href.contains(mapEntry.key)) {
        return mapEntry.value;
      }
    }

    return null;
  }
}

class _ChapterTile extends StatelessWidget {
  final EpubChapterMeta chapter;
  final int index;
  final bool isCurrent;
  final bool showProgress;
  final VoidCallback? onTap;

  const _ChapterTile({
    required this.chapter,
    required this.index,
    required this.isCurrent,
    required this.showProgress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isCurrent ? Theme.of(context).primaryColor : Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: isCurrent ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
      title: Text(
        chapter.title,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: isCurrent ? Theme.of(context).primaryColor : null,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: chapter.estimatedReadingMinutes != null
          ? Text(
              '${chapter.estimatedReadingMinutes} min read',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            )
          : null,
      trailing: isCurrent
          ? Icon(Icons.play_arrow, color: Theme.of(context).primaryColor)
          : null,
      selected: isCurrent,
      selectedTileColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      onTap: onTap,
    );
  }
}

/// Chapter drawer for reader screen - with Translations tab
class ChapterDrawer extends ConsumerStatefulWidget {
  final EpubBook book;
  final VoidCallback? onClose;

  const ChapterDrawer({super.key, required this.book, this.onClose});

  @override
  ConsumerState<ChapterDrawer> createState() => _ChapterDrawerState();
}

class _ChapterDrawerState extends ConsumerState<ChapterDrawer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 4 tabs: Contents, Bookmarks, Highlights, Translations
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(readerStateProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(context),

            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(text: 'Contents'),
                Tab(text: 'Bookmarks'),
                Tab(text: 'Highlights'),
                Tab(text: 'Translations'),
                Tab(text: 'Audiobook'),
              ],
            ),

            // Content
            Expanded(
              child: readerState.when(
                data: (state) => _buildContent(context, state),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.book.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose ?? () => Navigator.pop(context),
              ),
            ],
          ),
          if (widget.book.author != null)
            Text(
              widget.book.displayAuthor,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ReadingState state) {
    return TabBarView(
      controller: _tabController,
      children: [
        // Contents tab
        ChapterListWidget(
          book: widget.book,
          currentChapterIndex: state.currentChapterIndex,
          onTocEntryTap: (entry) async {
            Navigator.pop(context);
            await ref.read(readerNotifierProvider.notifier).goToTocEntry(entry);
          },
          onChapterTap: (index) async {
            Navigator.pop(context);
            await ref.read(readerNotifierProvider.notifier).goToChapter(index);
          },
        ),

        // Bookmarks tab
        _BookmarksList(
          bookmarks: state.progress?.activeBookmarks ?? [],
          onBookmarkTap: (bookmark) async {
            Navigator.pop(context);
            await ref
                .read(readerNotifierProvider.notifier)
                .goToBookmark(bookmark);
          },
          onBookmarkDelete: (id) {
            ref.read(readerNotifierProvider.notifier).removeBookmark(id);
          },
        ),

        // Highlights tab
        _HighlightsList(
          highlights: state.progress?.activeHighlights ?? [],
          chapters: widget.book.chapters,
          onHighlightTap: (highlight) async {
            Navigator.pop(context);
            await ref
                .read(readerNotifierProvider.notifier)
                .goToChapter(highlight.chapterIndex);
          },
          onHighlightDelete: (id) {
            ref.read(readerNotifierProvider.notifier).removeHighlight(id);
          },
        ),

        // Translations tab (NEW)
        _TranslationsList(
          textTranslations: state.progress?.activeTextTranslations ?? [],
          chapterTranslations: state.progress?.activeChapterTranslations ?? [],
          chapters: widget.book.chapters,
          onTextTranslationTap: (translation) async {
            Navigator.pop(context);
            final chapterIndex = translation.chapterIndex;
            if (chapterIndex != null) {
              await ref
                  .read(readerNotifierProvider.notifier)
                  .goToChapter(chapterIndex);
            }
          },
          onChapterTranslationTap: (translation) async {
            Navigator.pop(context);
            await ref
                .read(readerNotifierProvider.notifier)
                .goToChapter(translation.chapterIndex);
          },
        ),
        AudiobookTab(
          book: widget.book,
          chapters: widget.book.chapters,
          currentChapterIndex: state.currentChapterIndex,
          bookId: widget.book.id,
          getChapterText: (chapterIndex) async {
            try {
              // Load chapter content
              final chapter = await ref
                  .read(readerNotifierProvider.notifier)
                  .goToChapter(chapterIndex);
              return chapter.data!.safeTextContent;
            } catch (e) {
              debugPrint('Failed to get chapter text: $e');
              return null;
            }
          },
          onChapterTap: (index) async {
            Navigator.pop(context);
            await ref.read(readerNotifierProvider.notifier).goToChapter(index);
          },
        ),
      ],
    );
  }
}

// =============================================================================
// BOOKMARKS LIST
// =============================================================================

class _BookmarksList extends StatelessWidget {
  final List<Bookmark> bookmarks;
  final void Function(Bookmark bookmark)? onBookmarkTap;
  final void Function(String id)? onBookmarkDelete;

  const _BookmarksList({
    required this.bookmarks,
    this.onBookmarkTap,
    this.onBookmarkDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (bookmarks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_outline,
        title: 'No Bookmarks',
        subtitle: 'Tap the bookmark icon while reading to add bookmarks',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: bookmarks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        return Dismissible(
          key: Key(bookmark.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => onBookmarkDelete?.call(bookmark.id),
          child: ListTile(
            leading: const Icon(Icons.bookmark, color: Colors.amber),
            title: Text(
              bookmark.chapterTitle ?? 'Chapter ${bookmark.chapterIndex + 1}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bookmark.previewText != null)
                  Text(
                    bookmark.previewText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(bookmark.createdAt),
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                ),
              ],
            ),
            isThreeLine: bookmark.previewText != null,
            onTap: () => onBookmarkTap?.call(bookmark),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} min ago';
      }
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }

    return '${date.day}/${date.month}/${date.year}';
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
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HIGHLIGHTS LIST
// =============================================================================

class _HighlightsList extends StatelessWidget {
  final List<Highlight> highlights;
  final List<EpubChapterMeta> chapters;
  final void Function(Highlight highlight)? onHighlightTap;
  final void Function(String id)? onHighlightDelete;

  const _HighlightsList({
    required this.highlights,
    required this.chapters,
    this.onHighlightTap,
    this.onHighlightDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) {
      return _buildEmptyState(
        icon: Icons.highlight_outlined,
        title: 'No Highlights',
        subtitle: 'Select text while reading to create highlights',
      );
    }

    // Group by chapter
    final grouped = <int, List<Highlight>>{};
    for (final h in highlights) {
      grouped.putIfAbsent(h.chapterIndex, () => []).add(h);
    }

    final sortedChapters = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sortedChapters.length,
      itemBuilder: (context, index) {
        final chapterIndex = sortedChapters[index];
        final chapterHighlights = grouped[chapterIndex]!;
        final chapterTitle = chapterIndex < chapters.length
            ? chapters[chapterIndex].title
            : 'Chapter ${chapterIndex + 1}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapter header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.menu_book, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chapterTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${chapterHighlights.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Highlights
            ...chapterHighlights.map(
              (highlight) => Dismissible(
                key: Key(highlight.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => onHighlightDelete?.call(highlight.id),
                child: ListTile(
                  leading: Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: highlight.color.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text(
                    '"${highlight.selectedText}"',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: highlight.note != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.note,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  highlight.note!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: highlight.color.color.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: highlight.color.color,
                    ),
                  ),
                  onTap: () => onHighlightTap?.call(highlight),
                ),
              ),
            ),

            if (index < sortedChapters.length - 1) const SizedBox(height: 8),
          ],
        );
      },
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
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TRANSLATIONS LIST (NEW TAB)
// =============================================================================

class _TranslationsList extends StatelessWidget {
  final List<TextTranslation> textTranslations;
  final List<ChapterTranslation> chapterTranslations;
  final List<EpubChapterMeta> chapters;
  final void Function(TextTranslation translation)? onTextTranslationTap;
  final void Function(ChapterTranslation translation)? onChapterTranslationTap;

  const _TranslationsList({
    required this.textTranslations,
    required this.chapterTranslations,
    required this.chapters,
    this.onTextTranslationTap,
    this.onChapterTranslationTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAny =
        textTranslations.isNotEmpty || chapterTranslations.isNotEmpty;

    if (!hasAny) {
      return _buildEmptyState(
        icon: Icons.translate,
        title: 'No Translations',
        subtitle:
            'Use the Translate action on selected text to create translations',
      );
    }

    final sortedChapterTranslations = List<ChapterTranslation>.from(
      chapterTranslations,
    )..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));

    final sortedTextTranslations = List<TextTranslation>.from(textTranslations)
      ..sort((a, b) {
        final ai = a.chapterIndex ?? 0;
        final bi = b.chapterIndex ?? 0;
        if (ai != bi) return ai.compareTo(bi);
        return a.createdAt.compareTo(b.createdAt);
      });

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (sortedChapterTranslations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Chapter Translations',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          ...sortedChapterTranslations.map((t) {
            final chapterTitle = t.chapterIndex < chapters.length
                ? chapters[t.chapterIndex].title
                : 'Chapter ${t.chapterIndex + 1}';
            return ListTile(
              leading: const Icon(Icons.translate, color: Colors.blue),
              title: Text(
                chapterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${t.sourceLanguage.toUpperCase()} → ${t.targetLanguage.toUpperCase()}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => onChapterTranslationTap?.call(t),
            );
          }),
          const Divider(),
        ],
        if (sortedTextTranslations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Text Translations',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          ...sortedTextTranslations.map((t) {
            final chapterIndex = t.chapterIndex ?? 0;
            final chapterTitle = chapterIndex < chapters.length
                ? chapters[chapterIndex].title
                : 'Chapter ${chapterIndex + 1}';
            return ListTile(
              leading: const Icon(Icons.subtitles, color: Colors.teal),
              title: Text(
                '"${t.originalText}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              subtitle: Text(
                '$chapterTitle • ${t.sourceLanguage.toUpperCase()} → ${t.targetLanguage.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: t.chapterIndex != null
                  ? () => onTextTranslationTap?.call(t)
                  : null,
            );
          }),
        ],
      ],
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
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// QUICK CHAPTER NAVIGATION BAR (unchanged)
// =============================================================================

class ChapterNavigationBar extends StatelessWidget {
  final int currentChapter;
  final int totalChapters;
  final String? chapterTitle;
  final bool canGoNext;
  final bool canGoPrevious;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onShowChapterList;

  const ChapterNavigationBar({
    super.key,
    required this.currentChapter,
    required this.totalChapters,
    this.chapterTitle,
    this.canGoNext = true,
    this.canGoPrevious = true,
    this.onPrevious,
    this.onNext,
    this.onShowChapterList,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: canGoPrevious ? onPrevious : null,
              tooltip: 'Previous Chapter',
            ),
            Expanded(
              child: InkWell(
                onTap: onShowChapterList,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chapterTitle ?? 'Chapter ${currentChapter + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${currentChapter + 1} of $totalChapters',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: canGoNext ? onNext : null,
              tooltip: 'Next Chapter',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/txt_reader_screen.dart';
import '../../speaker_player/tts_controller.dart';
import '../../speaker_player/providers/tts_provider.dart';

class AudioTab extends ConsumerStatefulWidget {
  final TxtReaderScreenState readerState;

  const AudioTab({super.key, required this.readerState});

  @override
  ConsumerState<AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends ConsumerState<AudioTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ========== LOCAL UI STATE ==========
  bool _showAllBooks = false;
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};
  _AudioSortBy _sortBy = _AudioSortBy.pageNumber;
  bool _sortAscending = true;

  String get _bookId => widget.readerState.identifier;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final textColor = widget.readerState.getTextColor();
    final safeArea = widget.readerState.safeArea;

    // ========== WATCH PROVIDERS ==========
    final cacheStatsAsync = ref.watch(ttsCacheStatsProvider);
    final allEntriesAsync = ref.watch(ttsCachedEntriesProvider);
    final bookEntriesAsync = ref.watch(ttsBookCachedEntriesProvider(_bookId));

    return Column(
      children: [
        // Header with stats
        _buildHeader(textColor, cacheStatsAsync),

        // Filter/Sort bar
        _buildFilterBar(textColor, allEntriesAsync, bookEntriesAsync),

        // Selection actions bar
        if (_isSelectionMode) _buildSelectionBar(textColor),

        // Content
        Expanded(
          child: _buildContent(
            textColor,
            safeArea,
            allEntriesAsync,
            bookEntriesAsync,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    Color textColor,
    AsyncValue<Map<String, dynamic>> cacheStatsAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.audiotrack, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generated Audio',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    cacheStatsAsync.when(
                      data: (stats) => Text(
                        '${stats['entries'] ?? 0} files • ${stats['formattedSize'] ?? '0 B'}',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      loading: () => Text(
                        'Loading...',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      error: (_, __) => Text(
                        'Error loading stats',
                        style: TextStyle(
                          color: Colors.red.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Refresh button
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: textColor.withValues(alpha: 0.6),
                  size: 20,
                ),
                onPressed: _refreshData,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    Color textColor,
    AsyncValue<List<CachedAudioEntry>> allEntriesAsync,
    AsyncValue<List<CachedAudioEntry>> bookEntriesAsync,
  ) {
    final allCount = allEntriesAsync.value?.length ?? 0;
    final bookCount = bookEntriesAsync.value?.length ?? 0;
    final hasEntries = _showAllBooks ? allCount > 0 : bookCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Book toggle
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  icon: Icons.menu_book,
                  label: 'This Book',
                  value: '$bookCount',
                  isActive: !_showAllBooks,
                  onTap: () => setState(() => _showAllBooks = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip(
                  icon: Icons.library_books,
                  label: 'All Books',
                  value: '$allCount',
                  isActive: _showAllBooks,
                  onTap: () => setState(() => _showAllBooks = true),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Sort and actions row
          Row(
            children: [
              // Sort dropdown
              _buildSortDropdown(textColor),

              const Spacer(),

              // Selection mode toggle
              if (hasEntries && !_isSelectionMode)
                TextButton.icon(
                  onPressed: () => setState(() => _isSelectionMode = true),
                  icon: const Icon(Icons.checklist, size: 18),
                  label: const Text('Select'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),

              // Clear all button
              if (hasEntries && !_isSelectionMode)
                TextButton.icon(
                  onPressed: _clearAllCache,
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(
              '$label ($value)',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortDropdown(Color textColor) {
    return PopupMenuButton<_AudioSortBy>(
      initialValue: _sortBy,
      onSelected: (value) {
        setState(() {
          if (_sortBy == value) {
            _sortAscending = !_sortAscending;
          } else {
            _sortBy = value;
            _sortAscending = true;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 16, color: textColor.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(
              _sortBy.label,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: textColor.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => _AudioSortBy.values.map((sort) {
        return PopupMenuItem(
          value: sort,
          child: Row(
            children: [
              Icon(sort.icon, size: 18),
              const SizedBox(width: 8),
              Text(sort.label),
              if (_sortBy == sort) ...[
                const Spacer(),
                Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectionBar(Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedIds.length} selected',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          TextButton(onPressed: _selectAll, child: const Text('All')),
          TextButton(onPressed: _clearSelection, child: const Text('None')),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    Color textColor,
    EdgeInsets safeArea,
    AsyncValue<List<CachedAudioEntry>> allEntriesAsync,
    AsyncValue<List<CachedAudioEntry>> bookEntriesAsync,
  ) {
    final entriesAsync = _showAllBooks ? allEntriesAsync : bookEntriesAsync;

    return entriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return _buildEmptyState(textColor);
        }

        final sortedEntries = _sortEntries(entries);
        return _buildAudioList(sortedEntries, textColor, safeArea);
      },
      loading: () => _buildLoadingState(textColor),
      error: (error, _) => _buildErrorState(textColor, error.toString()),
    );
  }

  List<CachedAudioEntry> _sortEntries(List<CachedAudioEntry> entries) {
    final sorted = List<CachedAudioEntry>.from(entries);

    switch (_sortBy) {
      case _AudioSortBy.pageNumber:
        sorted.sort((a, b) {
          final aPage = a.pageNumber ?? 999999;
          final bPage = b.pageNumber ?? 999999;
          return _sortAscending
              ? aPage.compareTo(bPage)
              : bPage.compareTo(aPage);
        });
        break;
      case _AudioSortBy.duration:
        sorted.sort(
          (a, b) => _sortAscending
              ? a.duration.compareTo(b.duration)
              : b.duration.compareTo(a.duration),
        );
        break;
      case _AudioSortBy.size:
        sorted.sort(
          (a, b) => _sortAscending
              ? a.fileSizeBytes.compareTo(b.fileSizeBytes)
              : b.fileSizeBytes.compareTo(a.fileSizeBytes),
        );
        break;
      case _AudioSortBy.date:
        sorted.sort(
          (a, b) => _sortAscending
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt),
        );
        break;
    }

    return sorted;
  }

  Widget _buildLoadingState(Color textColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading audio cache...',
            style: TextStyle(color: textColor.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color textColor, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load audio cache',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.audiotrack_outlined,
                size: 48,
                color: textColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Audio Generated Yet',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showAllBooks
                  ? 'Generate audio by using the TTS feature\non any page.'
                  : 'Generate audio for this book using\nthe TTS feature.',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                widget.readerState.toggleLeftPanel(false);
                widget.readerState.speakCurrentPage();
              },
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Generate Current Page'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                widget.readerState.toggleLeftPanel(false);
                await widget.readerState.preGenerateAudio(pagesToGenerate: 5);
              },
              icon: const Icon(Icons.queue_music, size: 20),
              label: const Text('Pre-generate 5 Pages'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioList(
    List<CachedAudioEntry> entries,
    Color textColor,
    EdgeInsets safeArea,
  ) {
    return ListView.builder(
      padding: EdgeInsets.only(
        top: 8,
        bottom: safeArea.bottom + 16,
        left: 12,
        right: 12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isCurrentPage =
            entry.bookId == widget.readerState.identifier &&
            entry.pageNumber == widget.readerState.currentPage;
        final isSelected = _selectedIds.contains(entry.id);

        return _AudioListItem(
          entry: entry,
          isCurrentPage: isCurrentPage,
          isSelected: isSelected,
          isSelectionMode: _isSelectionMode,
          showBookId: _showAllBooks,
          textColor: textColor,
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(entry.id);
            } else {
              _playEntry(entry);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedIds.add(entry.id);
              });
              HapticFeedback.mediumImpact();
            }
          },
          onDelete: () => _deleteEntry(entry),
          onSelectionToggle: () => _toggleSelection(entry.id),
        );
      },
    );
  }

  // ========== ACTIONS ==========

  void _refreshData() {
    ref.invalidate(ttsCacheStatsProvider);
    ref.invalidate(ttsCachedEntriesProvider);
    ref.invalidate(ttsBookCachedEntriesProvider(_bookId));
  }

  Future<void> _playEntry(CachedAudioEntry entry) async {
    try {
      HapticFeedback.lightImpact();

      // Navigate to page if from current book
      if (entry.bookId == _bookId && entry.pageNumber != null) {
        widget.readerState.goToPage(entry.pageNumber!);
      }

      await ref
          .read(ttsControllerProvider)
          .playCachedEntry(
            entry: entry,
            context: context,
            showUi: true,
            onError: (error) {
              widget.readerState.showSnackBar('Error: $error');
            },
          );

      widget.readerState.toggleLeftPanel(false);
    } catch (e) {
      widget.readerState.showSnackBar('Failed to play audio');
    }
  }

  Future<void> _deleteEntry(CachedAudioEntry entry) async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete Audio?',
      content: entry.pageNumber != null
          ? 'Delete cached audio for page ${entry.pageNumber! + 1}?'
          : 'Delete this cached audio?',
    );

    if (confirmed) {
      await ref.read(ttsControllerProvider).deleteCachedEntry(entry);
      widget.readerState.showSnackBar('Audio deleted');
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await _showConfirmDialog(
      title: 'Delete Selected?',
      content: 'Delete ${_selectedIds.length} cached audio files?',
    );

    if (confirmed) {
      final entries = _showAllBooks
          ? ref.read(ttsCachedEntriesProvider).value ?? []
          : ref.read(ttsBookCachedEntriesProvider(_bookId)).value ?? [];

      final toDelete = entries
          .where((e) => _selectedIds.contains(e.id))
          .toList();
      final deleted = await ref
          .read(ttsControllerProvider)
          .deleteCachedEntries(toDelete);

      _clearSelection();
      widget.readerState.showSnackBar('Deleted $deleted audio files');
    }
  }

  Future<void> _clearAllCache() async {
    final entriesAsync = _showAllBooks
        ? ref.read(ttsCachedEntriesProvider)
        : ref.read(ttsBookCachedEntriesProvider(_bookId));

    final count = entriesAsync.value?.length ?? 0;

    final confirmed = await _showConfirmDialog(
      title: 'Clear All Cache?',
      content: _showAllBooks
          ? 'This will delete all $count cached audio files.'
          : 'This will delete all $count cached audio files for this book.',
    );

    if (confirmed) {
      if (_showAllBooks) {
        await ref.read(ttsControllerProvider).clearAllCache();
      } else {
        await ref.read(ttsControllerProvider).clearCacheForBook(_bookId);
      }

      widget.readerState.showSnackBar('Cache cleared');
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    final entries = _showAllBooks
        ? ref.read(ttsCachedEntriesProvider).value ?? []
        : ref.read(ttsBookCachedEntriesProvider(_bookId)).value ?? [];

    setState(() {
      _selectedIds = entries.map((e) => e.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ========== AUDIO LIST ITEM WIDGET ==========

class _AudioListItem extends StatelessWidget {
  final CachedAudioEntry entry;
  final bool isCurrentPage;
  final bool isSelected;
  final bool isSelectionMode;
  final bool showBookId;
  final Color textColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onSelectionToggle;

  const _AudioListItem({
    required this.entry,
    required this.isCurrentPage,
    required this.isSelected,
    required this.isSelectionMode,
    required this.showBookId,
    required this.textColor,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrentPage ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentPage
            ? const BorderSide(color: Colors.blue, width: 2)
            : isSelected
            ? const BorderSide(color: Colors.blue, width: 1)
            : BorderSide.none,
      ),
      color: isSelected ? Colors.blue.withValues(alpha: 0.05) : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection checkbox or play button
              if (isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onSelectionToggle(),
                  visualDensity: VisualDensity.compact,
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isCurrentPage
                        ? Colors.blue
                        : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: isCurrentPage ? Colors.white : Colors.blue,
                    size: 24,
                  ),
                ),

              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        if (entry.pageNumber != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrentPage
                                  ? Colors.blue
                                  : Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Page ${entry.pageNumber! + 1}',
                              style: TextStyle(
                                color: isCurrentPage
                                    ? Colors.white
                                    : Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (showBookId && entry.bookId != null)
                          Expanded(
                            child: Text(
                              entry.bookId!,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Text preview
                    Text(
                      entry.textPreview,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Metadata row
                    Row(
                      children: [
                        _buildMetaChip(
                          Icons.timer_outlined,
                          entry.formattedDuration,
                        ),
                        const SizedBox(width: 12),
                        _buildMetaChip(
                          Icons.storage_outlined,
                          entry.formattedSize,
                        ),
                        if (entry.speed != 1.0) ...[
                          const SizedBox(width: 12),
                          _buildMetaChip(Icons.speed, '${entry.speed}x'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button (when not in selection mode)
              if (!isSelectionMode)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: textColor.withValues(alpha: 0.4),
                    size: 20,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: textColor.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ========== SORT OPTIONS ==========

enum _AudioSortBy {
  pageNumber('Page', Icons.format_list_numbered),
  duration('Duration', Icons.timer),
  size('Size', Icons.storage),
  date('Date', Icons.calendar_today);

  final String label;
  final IconData icon;

  const _AudioSortBy(this.label, this.icon);
}

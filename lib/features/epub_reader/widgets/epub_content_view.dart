import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../models/epub_chapter.dart';
import '../models/reading_progress.dart';
import '../providers/epub_provider.dart';
import '../services/epub_reader_service.dart';

/// Content view for displaying EPUB chapter content
class EpubContentView extends ConsumerStatefulWidget {
  final EpubChapter chapter;
  final ReaderSettings settings;
  final List<Highlight> highlights;
  final double initialScrollPosition;
  final void Function(double progress)? onScrollProgress;
  final void Function(String text, int start, int end)? onTextSelected;
  final void Function(ChapterLink link)? onLinkTapped;
  final void Function(ChapterImage image)? onImageTapped;
  final String? translatedText;
  final bool isTranslating;

  const EpubContentView({
    super.key,
    required this.chapter,
    required this.settings,
    this.highlights = const [],
    this.initialScrollPosition = 0.0,
    this.onScrollProgress,
    this.onTextSelected,
    this.onLinkTapped,
    this.onImageTapped,
    this.translatedText,
    this.isTranslating = false,
  });

  @override
  ConsumerState<EpubContentView> createState() => _EpubContentViewState();
}

class _EpubContentViewState extends ConsumerState<EpubContentView> {
  late ScrollController _scrollController;

  // Selection state
  String? _selectedText;
  int _selectionStart = 0;
  int _selectionEnd = 0;
  // ignore: unused_field
  bool _isSelecting = false;

  // Scroll tracking
  double _maxScrollExtent = 0;
  Timer? _scrollDebouncer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScrollPosition();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollDebouncer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(EpubContentView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.chapter.id != widget.chapter.id) {
      // New chapter, reset scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeScrollPosition();
      });
    }
  }

  void _initializeScrollPosition() {
    try {
      if (_scrollController.hasClients) {
        _maxScrollExtent = _scrollController.position.maxScrollExtent;

        if (widget.initialScrollPosition > 0 && _maxScrollExtent > 0) {
          final targetOffset = _maxScrollExtent * widget.initialScrollPosition;
          _scrollController.jumpTo(targetOffset.clamp(0, _maxScrollExtent));
        }

        _scrollController.addListener(_onScroll);
      }
    } catch (e) {
      debugPrint('Initialize scroll error: $e');
    }
  }

  void _onScroll() {
    try {
      _scrollDebouncer?.cancel();
      _scrollDebouncer = Timer(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients && widget.onScrollProgress != null) {
          final maxExtent = _scrollController.position.maxScrollExtent;
          if (maxExtent > 0) {
            final progress = (_scrollController.offset / maxExtent).clamp(
              0.0,
              1.0,
            );
            widget.onScrollProgress!(progress);
          }
        }
      });
    } catch (e) {
      debugPrint('Scroll listener error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildContent(context, constraints);
      },
    );
  }

  Widget _buildContent(BuildContext context, BoxConstraints constraints) {
    try {
      final theme = _getThemeColors();

      final contentWidgets = <Widget>[
        _buildChapterTitle(theme),
        const SizedBox(height: 24),
        ..._buildChapterContent(theme, constraints),
        SizedBox(height: constraints.maxHeight * 0.3),
      ];

      return Container(
        color: theme.backgroundColor,
        child: SelectionArea(
          contextMenuBuilder: (context, selectableRegionState) {
            return const SizedBox.shrink();
          },
          child: GestureDetector(
            onTapUp: _handleTap,
            onLongPressStart: _handleLongPressStart,
            onLongPressMoveUpdate: _handleLongPressMove,
            onLongPressEnd: _handleLongPressEnd,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.settings.margin,
                    vertical: 16,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(contentWidgets),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      return _buildErrorView(e.toString());
    }
  }

  Widget _buildChapterTitle(_ThemeColors theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        widget.chapter.title,
        style: TextStyle(
          fontSize: widget.settings.fontSize + 8,
          fontWeight: FontWeight.bold,
          color: theme.textColor,
          fontFamily: _getFontFamily(),
          height: widget.settings.lineHeight,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  List<Widget> _buildChapterContent(
    _ThemeColors theme,
    BoxConstraints constraints,
  ) {
    try {
      final content =
          widget.translatedText ??
          widget.chapter.htmlContent ??
          widget.chapter.textContent ??
          '';

      if (content.isEmpty) {
        return [_buildEmptyContent(theme)];
      }

      // Parse and render HTML content
      return _parseHtmlContent(content, theme, constraints);
    } catch (e) {
      debugPrint('Build chapter content error: $e');
      return [_buildPlainTextContent(theme)];
    }
  }

  List<Widget> _parseHtmlContent(
    String html,
    _ThemeColors theme,
    BoxConstraints constraints,
  ) {
    final widgets = <Widget>[];

    try {
      // Simple HTML parsing - extract text and basic formatting
      // For production, use a proper HTML parser like flutter_html

      // Remove script and style tags
      String cleanHtml = html
          .replaceAll(
            RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
            '',
          )
          .replaceAll(
            RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
            '',
          );

      // Split by major block elements
      final blocks = cleanHtml.split(
        RegExp(r'<(?:p|div|h[1-6]|br)[^>]*>', caseSensitive: false),
      );

      for (final block in blocks) {
        final cleanText = _stripHtmlTags(block).trim();
        if (cleanText.isEmpty) continue;

        // Check if it's a heading
        final isHeading = block.contains(
          RegExp(r'<h[1-6]', caseSensitive: false),
        );

        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: isHeading ? 16 : 12),
            child: _buildTextWithHighlights(
              cleanText,
              theme,
              isHeading: isHeading,
            ),
          ),
        );
      }

      // Add images if present
      final images = widget.chapter.images;
      debugPrint('Images count: ${images.length}');
      for (final image in images) {
        widgets.add(_buildImage(image, constraints));
      }
    } catch (e) {
      debugPrint('Parse HTML error: $e');
      // Fallback to plain text
      widgets.add(_buildPlainTextContent(theme));
    }

    return widgets.isEmpty ? [_buildPlainTextContent(theme)] : widgets;
  }

  Widget _buildTextWithHighlights(
    String text,
    _ThemeColors theme, {
    bool isHeading = false,
  }) {
    try {
      // Get highlights for this text
      final relevantHighlights = widget.highlights.where((h) {
        return text.contains(h.selectedText);
      }).toList();

      if (relevantHighlights.isEmpty) {
        return SelectableText(
          text,
          style: TextStyle(
            fontSize: isHeading
                ? widget.settings.fontSize + 4
                : widget.settings.fontSize,
            fontWeight: isHeading ? FontWeight.bold : FontWeight.normal,
            color: theme.textColor,
            fontFamily: _getFontFamily(),
            height: widget.settings.lineHeight,
          ),
          onSelectionChanged: (selection, cause) {
            if (selection.baseOffset != selection.extentOffset) {
              _handleTextSelection(
                text,
                selection.baseOffset,
                selection.extentOffset,
              );
            }
          },
        );
      }

      // Build text with highlights
      return _buildHighlightedText(text, relevantHighlights, theme, isHeading);
    } catch (e) {
      debugPrint('Build text with highlights error: $e');
      return Text(
        text,
        style: TextStyle(
          fontSize: widget.settings.fontSize,
          color: theme.textColor,
        ),
      );
    }
  }

  Widget _buildHighlightedText(
    String text,
    List<Highlight> highlights,
    _ThemeColors theme,
    bool isHeading,
  ) {
    final spans = <TextSpan>[];
    int currentIndex = 0;

    // Sort highlights by position in text
    final sortedHighlights =
        highlights
            .map((h) {
              final index = text.indexOf(h.selectedText);
              return index >= 0 ? (highlight: h, index: index) : null;
            })
            .whereType<({Highlight highlight, int index})>()
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));

    for (final item in sortedHighlights) {
      final highlight = item.highlight;
      final startIndex = item.index;
      final endIndex = startIndex + highlight.selectedText.length;

      // Add text before highlight
      if (startIndex > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, startIndex)));
      }

      // Add highlighted text
      spans.add(
        TextSpan(
          text: highlight.selectedText,
          style: TextStyle(
            backgroundColor: highlight.color.color.withValues(alpha: 0.4),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _showHighlightMenu(highlight),
        ),
      );

      currentIndex = endIndex;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          fontSize: isHeading
              ? widget.settings.fontSize + 4
              : widget.settings.fontSize,
          fontWeight: isHeading ? FontWeight.bold : FontWeight.normal,
          color: theme.textColor,
          fontFamily: _getFontFamily(),
          height: widget.settings.lineHeight,
        ),
        children: spans,
      ),
      onSelectionChanged: (selection, cause) {
        if (selection.baseOffset != selection.extentOffset) {
          _handleTextSelection(
            text,
            selection.baseOffset,
            selection.extentOffset,
          );
        }
      },
    );
  }

  Widget _buildPlainTextContent(_ThemeColors theme) {
    final text =
        widget.chapter.textContent ??
        _stripHtmlTags(widget.chapter.htmlContent ?? '');

    return SelectableText(
      text,
      style: TextStyle(
        fontSize: widget.settings.fontSize,
        color: theme.textColor,
        fontFamily: _getFontFamily(),
        height: widget.settings.lineHeight,
      ),
      onSelectionChanged: (selection, cause) {
        if (selection.baseOffset != selection.extentOffset) {
          _handleTextSelection(
            text,
            selection.baseOffset,
            selection.extentOffset,
          );
        }
      },
    );
  }

  Widget _buildImage(ChapterImage image, BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: GestureDetector(
        onTap: () => widget.onImageTapped?.call(image),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth - (widget.settings.margin * 2),
            maxHeight: constraints.maxHeight * 0.6,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image.localPath != null && image.localPath!.isNotEmpty
                ? Image.file(
                    File(image.localPath!), // <-- use file
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                  )
                : _buildImagePlaceholder(),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(Icons.image, size: 48, color: Colors.grey),
      ),
    );
  }

  Widget _buildEmptyContent(_ThemeColors theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: theme.textColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No content available',
              style: TextStyle(
                fontSize: widget.settings.fontSize,
                color: theme.textColor.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load content',
              style: TextStyle(
                fontSize: widget.settings.fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: widget.settings.fontSize - 2,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // INTERACTION HANDLERS
  // ===========================================================================

  void _handleTap(TapUpDetails details) {
    try {
      // Clear selection on tap
      if (_selectedText != null) {
        setState(() {
          _selectedText = null;
        });
      }
    } catch (e) {
      debugPrint('Handle tap error: $e');
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    setState(() {
      _isSelecting = true;
    });
    HapticFeedback.mediumImpact();
  }

  void _handleLongPressMove(LongPressMoveUpdateDetails details) {
    // Handle text selection during long press
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    setState(() {
      _isSelecting = false;
    });
  }

  void _handleTextSelection(String text, int start, int end) {
    try {
      final selectedText = text.substring(
        math.min(start, end),
        math.max(start, end),
      );

      if (selectedText.isNotEmpty) {
        setState(() {
          _selectedText = selectedText;
          _selectionStart = math.min(start, end);
          _selectionEnd = math.max(start, end);
        });

        widget.onTextSelected?.call(
          selectedText,
          _selectionStart,
          _selectionEnd,
        );
        _showSelectionMenu(selectedText);
      }
    } catch (e) {
      debugPrint('Handle text selection error: $e');
    }
  }

  void _showSelectionMenu(String selectedText) {
    // Selection menu will be shown by parent widget
  }

  void _showHighlightMenu(Highlight highlight) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _HighlightOptionsSheet(
        highlight: highlight,
        onColorChange: (color) async {
          Navigator.pop(context);
          await ref
              .read(readerNotifierProvider.notifier)
              .updateHighlightColor(highlight.id, color);
        },
        onDelete: () async {
          Navigator.pop(context);
          await ref
              .read(readerNotifierProvider.notifier)
              .removeHighlight(highlight.id);
        },
        onAddNote: () {
          Navigator.pop(context);
          _showAddNoteDialog(highlight);
        },
      ),
    );
  }

  void _showAddNoteDialog(Highlight highlight) {
    final controller = TextEditingController(text: highlight.note);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter your note...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Update highlight with note
              // This would need to be implemented in the provider
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _getFontFamily() {
    switch (widget.settings.fontFamily) {
      case ReaderFont.serif:
        return 'Georgia';
      case ReaderFont.sansSerif:
        return 'Helvetica';
      case ReaderFont.monospace:
        return 'Courier';
      case ReaderFont.system:
        return null;
    }
  }

  _ThemeColors _getThemeColors() {
    switch (widget.settings.theme) {
      case ReadingTheme.dark:
        return _ThemeColors(
          backgroundColor: AppConstants.darkBackground,
          textColor: AppConstants.darkTextColor,
        );
      case ReadingTheme.sepia:
        return _ThemeColors(
          backgroundColor: AppConstants.sepiaBackground,
          textColor: AppConstants.sepiaTextColor,
        );
      case ReadingTheme.light:
        return _ThemeColors(
          backgroundColor: AppConstants.lightBackground,
          textColor: AppConstants.lightTextColor,
        );
    }
  }
}

class _ThemeColors {
  final Color backgroundColor;
  final Color textColor;

  const _ThemeColors({required this.backgroundColor, required this.textColor});
}

/// Highlight options bottom sheet
class _HighlightOptionsSheet extends StatelessWidget {
  final Highlight highlight;
  final void Function(HighlightColor) onColorChange;
  final VoidCallback onDelete;
  final VoidCallback onAddNote;

  const _HighlightOptionsSheet({
    required this.highlight,
    required this.onColorChange,
    required this.onDelete,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selected text preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: highlight.color.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${highlight.selectedText}"',
                style: const TextStyle(fontStyle: FontStyle.italic),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),

            // Color options
            const Text(
              'Highlight Color',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: HighlightColor.values.map((color) {
                  final isSelected = color == highlight.color;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onColorChange(color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddNote,
                    icon: const Icon(Icons.note_add),
                    label: const Text('Add Note'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Text selection toolbar
class TextSelectionToolbar extends StatelessWidget {
  final String selectedText;
  final VoidCallback onHighlight;
  final VoidCallback onCopy;
  final VoidCallback onTranslate;
  final VoidCallback onNote;
  final VoidCallback onDismiss;
  final VoidCallback onTts;

  const TextSelectionToolbar({
    super.key,
    required this.selectedText,
    required this.onHighlight,
    required this.onCopy,
    required this.onTranslate,
    required this.onNote,
    required this.onDismiss,
    required this.onTts,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolbarButton(
              icon: Icons.highlight,
              label: 'Highlight',
              onTap: onHighlight,
            ),
            _ToolbarButton(icon: Icons.copy, label: 'Copy', onTap: onCopy),
            _ToolbarButton(
              icon: Icons.translate,
              label: 'Translate',
              onTap: onTranslate,
            ),
            _ToolbarButton(
              icon: Icons.record_voice_over,
              label: 'Listen',
              onTap: onTts,
            ),
            _ToolbarButton(icon: Icons.note_add, label: 'Note', onTap: onNote),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

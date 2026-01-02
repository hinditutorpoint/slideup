import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/reader_utils.dart';
import '../screens/txt_reader_screen.dart';

class TranslationsTab extends StatefulWidget {
  final TxtReaderScreenState readerState;

  const TranslationsTab({super.key, required this.readerState});

  @override
  State<TranslationsTab> createState() => _TranslationsTabState();
}

class _TranslationsTabState extends State<TranslationsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<int, String> get translatedPages => widget.readerState.translatedPages;
  String get targetLanguage => widget.readerState.targetLanguage;
  bool get showTranslatedView => widget.readerState.showTranslatedView;

  void _goToPage(int page) {
    widget.readerState.goToPage(page);
    widget.readerState.toggleLeftPanel(false);
    if (!widget.readerState.showTranslatedView) {
      widget.readerState.toggleTranslatedView();
    }
  }

  void _copyTranslation(String text) {
    Clipboard.setData(ClipboardData(text: text));
    widget.readerState.showSnackBar('Translation copied');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final textColor = widget.readerState.getTextColor();
    final safeArea = widget.readerState.safeArea;
    final settings = widget.readerState.settings;

    return Column(
      children: [
        // Header info
        _buildHeaderInfo(textColor, settings),

        // Content
        Expanded(
          child: translatedPages.isEmpty
              ? _buildEmptyState(textColor)
              : _buildTranslationsList(textColor, safeArea),
        ),
      ],
    );
  }

  Widget _buildHeaderInfo(Color textColor, ReaderSettings settings) {
    final language = TranslationLanguage.fromCode(targetLanguage);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                language?.emoji ?? '🌐',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Translating to ${language?.name ?? targetLanguage}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${translatedPages.length} pages translated',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: widget.readerState.showLanguageSelector,
                child: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Auto-translate toggle
          Row(
            children: [
              Icon(
                settings.translationSettings.autoTranslateOnPageChange
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 18,
                color: settings.translationSettings.autoTranslateOnPageChange
                    ? Theme.of(context).primaryColor
                    : textColor.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Auto-translate on page change',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
              Switch.adaptive(
                value: settings.translationSettings.autoTranslateOnPageChange,
                onChanged: (value) {
                  final newSettings = settings.copyWith(
                    translationSettings: settings.translationSettings.copyWith(
                      autoTranslateOnPageChange: value,
                    ),
                  );
                  widget.readerState.updateSettings(newSettings);
                  setState(() {});
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
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
                Icons.translate_rounded,
                size: 48,
                color: textColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Translations Yet',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Translate pages to view them here.\nEnable auto-translate to save automatically.',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                widget.readerState.translateCurrentPage();
              },
              icon: const Icon(Icons.translate_rounded, size: 20),
              label: const Text('Translate Current Page'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationsList(Color textColor, EdgeInsets safeArea) {
    final sortedPages = translatedPages.keys.toList()..sort();

    return ListView.builder(
      padding: EdgeInsets.only(
        top: 4,
        bottom: safeArea.bottom + 16,
        left: 12,
        right: 12,
      ),
      itemCount: sortedPages.length,
      itemBuilder: (context, index) {
        final pageIndex = sortedPages[index];
        final translation = translatedPages[pageIndex]!;
        final isCurrentPage = pageIndex == widget.readerState.currentPage;

        return _buildTranslationItem(
          pageIndex: pageIndex,
          translation: translation,
          isCurrentPage: isCurrentPage,
          textColor: textColor,
        );
      },
    );
  }

  Widget _buildTranslationItem({
    required int pageIndex,
    required String translation,
    required bool isCurrentPage,
    required Color textColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isCurrentPage ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentPage
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _goToPage(pageIndex),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentPage
                          ? Theme.of(context).primaryColor
                          : Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.description_rounded,
                          size: 14,
                          color: isCurrentPage
                              ? Colors.white
                              : Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Page ${pageIndex + 1}',
                          style: TextStyle(
                            color: isCurrentPage
                                ? Colors.white
                                : Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrentPage) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VIEWING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Copy button
                  IconButton(
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    onPressed: () => _copyTranslation(translation),
                    tooltip: 'Copy translation',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Translation preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: textColor.withValues(alpha: 0.08)),
                ),
                child: Text(
                  translation.length > 200
                      ? '${translation.substring(0, 200)}...'
                      : translation,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Tap hint
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 12,
                      color: textColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to view full translation',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.3),
                        fontSize: 11,
                      ),
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
}

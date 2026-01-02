// lib/features/txt_reader/widgets/reader_controls.dart

import 'package:flutter/material.dart';

import '../utils/reader_utils.dart';
import '../screens/txt_reader_screen.dart';

/// Top Controls Bar
class ReaderTopControls extends StatelessWidget {
  final TxtReaderScreenState readerState;

  const ReaderTopControls({super.key, required this.readerState});

  @override
  Widget build(BuildContext context) {
    final animation = readerState.controlsAnimation;
    if (animation == null) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -60 * (1 - animation.value)),
            child: Opacity(
              opacity: animation.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final backgroundColor = readerState.getControlsBackgroundColor();
    final textColor = readerState.getTextColor();

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textColor),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),

              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      readerState.title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (readerState.showTranslatedView)
                      Row(
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            size: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            TranslationLanguage.fromCode(
                                  readerState.targetLanguage,
                                )?.name ??
                                readerState.targetLanguage,
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Search
              IconButton(
                icon: Icon(Icons.search_rounded, color: textColor, size: 22),
                onPressed: readerState.toggleSearchBar,
                tooltip: 'Search',
              ),

              // Left panel toggle
              IconButton(
                icon: Icon(Icons.menu_rounded, color: textColor, size: 22),
                onPressed: () => readerState.toggleLeftPanel(true),
                tooltip: 'Menu',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search Bar
class ReaderSearchBar extends StatelessWidget {
  final TxtReaderScreenState readerState;

  const ReaderSearchBar({super.key, required this.readerState});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = readerState.getControlsBackgroundColor();
    final textColor = readerState.getTextColor();

    return Positioned(
      top: readerState.safeArea.top + 56,
      left: 0,
      right: 0,
      child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: readerState.searchController,
                focusNode: readerState.searchFocusNode,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: textColor.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: textColor.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                onSubmitted: readerState.performSearch,
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: Icon(Icons.close_rounded, color: textColor, size: 22),
              onPressed: readerState.toggleSearchBar,
              tooltip: 'Close',
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom Controls Bar
class ReaderBottomControls extends StatelessWidget {
  final TxtReaderScreenState readerState;

  const ReaderBottomControls({super.key, required this.readerState});

  @override
  Widget build(BuildContext context) {
    final animation = readerState.controlsAnimation;
    if (animation == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 160 * (1 - animation.value)),
            child: Opacity(
              opacity: animation.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final backgroundColor = readerState.getControlsBackgroundColor();
    final textColor = readerState.getTextColor();
    final safeArea = readerState.safeArea;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Page slider
            if (readerState.totalPages > 1) _buildSlider(context, textColor),

            // Page info
            _buildPageInfo(context, textColor),

            const SizedBox(height: 6),

            // Toolbar
            _buildToolbar(context),

            SizedBox(height: safeArea.bottom.clamp(8.0, 20.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(BuildContext context, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SliderTheme(
        data: SliderThemeData(
          activeTrackColor: Theme.of(context).primaryColor,
          inactiveTrackColor: textColor.withValues(alpha: 0.15),
          thumbColor: Theme.of(context).primaryColor,
          overlayColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        ),
        child: Slider(
          value: readerState.currentPage.toDouble().clamp(
            0,
            (readerState.totalPages - 1).toDouble(),
          ),
          min: 0,
          max: (readerState.totalPages - 1).toDouble().clamp(
            0,
            double.infinity,
          ),
          onChanged: (value) => readerState.goToPage(value.round()),
        ),
      ),
    );
  }

  Widget _buildPageInfo(BuildContext context, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${readerState.currentPage + 1} / ${readerState.totalPages}',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              readerState.totalPages > 0
                  ? '${((readerState.currentPage + 1) / readerState.totalPages * 100).toInt()}%'
                  : '0%',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final tools = <ReaderToolItem>[
      // Translate button
      ReaderToolItem(
        id: 'translate',
        icon: Icons.translate_rounded,
        label: 'Translate',
        isLoading: readerState.isTranslatingPage,
        onTap: readerState.translateCurrentPage,
      ),

      // Speak button - NEW!
      ReaderToolItem(
        id: 'speak',
        icon: readerState.isSpeaking
            ? Icons.stop_rounded
            : Icons.volume_up_rounded,
        label: readerState.isSpeaking ? 'Stop' : 'Speak',
        isActive: readerState.isSpeaking,
        activeColor: Colors.orange,
        isLoading: false,
        onTap: () {
          if (readerState.isSpeaking && !readerState.isAudiobookActive) {
            readerState.stopSpeaking();
          } else if (!readerState.isAudiobookActive) {
            readerState.playSpeaker();
          }
        },
      ),

      // Audiobook button - NEW!
      ReaderToolItem(
        id: 'audiobook',
        icon: readerState.isAudiobookActive
            ? Icons.stop_circle_rounded
            : Icons.auto_stories_rounded,
        label: readerState.isAudiobookActive ? 'Stop Book' : 'Audiobook',
        isActive: readerState.isAudiobookActive,
        activeColor: Colors.green,
        onTap: readerState.toggleAudiobookMode,
      ),

      // Toggle Original/Translated view
      ReaderToolItem(
        id: 'toggle',
        icon: readerState.showTranslatedView
            ? Icons.text_snippet_rounded
            : Icons.g_translate_rounded,
        label: readerState.showTranslatedView ? 'Original' : 'Translated',
        isActive: readerState.showTranslatedView,
        activeColor: Theme.of(context).primaryColor,
        onTap: readerState.toggleTranslatedView,
      ),

      // Language selector
      ReaderToolItem(
        id: 'language',
        icon: Icons.language_rounded,
        label:
            TranslationLanguage.fromCode(readerState.targetLanguage)?.name ??
            'Lang',
        onTap: readerState.showLanguageSelector,
      ),

      // Bookmark
      ReaderToolItem(
        id: 'bookmark',
        icon: Icons.bookmark_add_rounded,
        label: 'Bookmark',
        onTap: readerState.addBookmark,
      ),

      // Panel
      ReaderToolItem(
        id: 'panel',
        icon: Icons.menu_rounded,
        label: 'Panel',
        onTap: () => readerState.toggleLeftPanel(true),
      ),
    ];

    return _ResponsiveToolBar(tools: tools);
  }
}

/// Responsive Toolbar that adapts to screen size
class _ResponsiveToolBar extends StatelessWidget {
  final List<ReaderToolItem> tools;

  const _ResponsiveToolBar({required this.tools});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: tools
              .map((tool) => _buildToolButton(context, tool))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildToolButton(BuildContext context, ReaderToolItem tool) {
    final isActive = tool.isActive;
    final activeColor = tool.activeColor ?? Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tool.isLoading ? null : tool.onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: activeColor.withValues(alpha: 0.5))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tool.isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        isActive
                            ? activeColor
                            : Theme.of(context).iconTheme.color,
                      ),
                    ),
                  )
                else
                  Icon(
                    tool.icon,
                    size: 18,
                    color: isActive ? activeColor : null,
                  ),
                const SizedBox(width: 6),
                Text(
                  tool.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? activeColor : null,
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

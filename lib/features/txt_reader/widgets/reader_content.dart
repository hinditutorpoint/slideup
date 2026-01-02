import 'package:flutter/material.dart';

import '../screens/txt_reader_screen.dart';

class ReaderContent extends StatelessWidget {
  final TxtReaderScreenState readerState;

  const ReaderContent({super.key, required this.readerState});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: readerState.onTapUp,
      onDoubleTap: readerState.onDoubleTap,
      onScaleStart: readerState.onScaleStart,
      onScaleUpdate: readerState.onScaleUpdate,
      onScaleEnd: readerState.onScaleEnd,
      behavior: HitTestBehavior.opaque,
      child: Transform(
        transform: Matrix4.identity()
          ..translate(
            readerState.currentZoom > 1.0
                ? readerState.toolPanelPosition.dx -
                      readerState.screenSize.width / 2
                : 0.0,
            readerState.currentZoom > 1.0
                ? readerState.toolPanelPosition.dy -
                      readerState.screenSize.height / 2
                : 0.0,
          )
          ..scale(readerState.currentZoom),
        alignment: Alignment.center,
        child: _buildPageView(context),
      ),
    );
  }

  Widget _buildPageView(BuildContext context) {
    final pageController = readerState.pageController;
    if (pageController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: pageController,
      onPageChanged: readerState.onPageChanged,
      physics: readerState.allowPageTurn
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: readerState.totalPages,
      itemBuilder: (context, index) {
        return _buildPage(context, index);
      },
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    try {
      final showTranslated =
          readerState.showTranslatedView &&
          readerState.translatedPages.containsKey(index) &&
          readerState.translatedPages[index]!.isNotEmpty;

      final displayText = showTranslated
          ? readerState.translatedPages[index]!
          : (index < readerState.pages.length ? readerState.pages[index] : '');

      final settings = readerState.settings;
      final textColor = readerState.getTextColor();

      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: readerState.currentZoom > 1.0
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: settings.margin,
              right: settings.margin,
              top: readerState.showControls ? 70 : 24,
              bottom: readerState.showControls ? 160 : 50,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 230).clamp(
                  100,
                  double.infinity,
                ),
              ),
              child: SelectableText(
                displayText,
                style: TextStyle(
                  color: textColor,
                  fontSize: settings.fontSize * readerState.getScaleFactor(),
                  height: settings.lineHeight,
                  fontFamily: settings.fontFamily == 'System'
                      ? null
                      : settings.fontFamily,
                ),
                textAlign: _getTextAlign(settings.textAlign),
                onSelectionChanged: (selection, cause) {
                  _handleSelectionChanged(selection, displayText);
                },
                contextMenuBuilder: (context, editableTextState) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
        },
      );
    } catch (e) {
      return Center(
        child: Text(
          'Error loading page',
          style: TextStyle(color: readerState.getTextColor()),
        ),
      );
    }
  }

  void _handleSelectionChanged(TextSelection selection, String displayText) {
    try {
      if (selection.baseOffset != selection.extentOffset) {
        final start = selection.baseOffset.clamp(0, displayText.length);
        final end = selection.extentOffset.clamp(0, displayText.length);
        if (start != end) {
          final text = displayText.substring(
            start < end ? start : end,
            start < end ? end : start,
          );
          readerState.onTextSelectionChanged(text);
        }
      }
    } catch (e) {
      debugPrint('Selection error: $e');
    }
  }

  TextAlign _getTextAlign(String align) {
    switch (align) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      case 'left':
      default:
        return TextAlign.left;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/reader_utils.dart';
import '../screens/txt_reader_screen.dart';

class FloatingToolPanel extends StatelessWidget {
  final TxtReaderScreenState readerState;

  const FloatingToolPanel({super.key, required this.readerState});

  double get _panelWidth {
    try {
      final screenWidth = readerState.screenSize.width;
      if (screenWidth < 320) return screenWidth - 32;
      if (screenWidth < 360) return 280;
      return 310;
    } catch (e) {
      debugPrint('[ToolPanel] Panel width calculation error: $e');
      return 310; // Default width
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final animation = readerState.toolPanelAnimation;
      if (animation == null) return const SizedBox.shrink();

      return Positioned(
        left: readerState.toolPanelPosition.dx.clamp(
          8,
          readerState.screenSize.width - _panelWidth - 8,
        ),
        top: readerState.toolPanelPosition.dy.clamp(
          readerState.safeArea.top + 8,
          readerState.screenSize.height - readerState.safeArea.bottom - 300,
        ),
        child: ScaleTransition(
          scale: animation,
          alignment: Alignment.topCenter,
          child: _buildPanel(context),
        ),
      );
    } catch (e, stack) {
      debugPrint('[ToolPanel] Build error: $e\n$stack');
      return const SizedBox.shrink();
    }
  }

  Widget _buildPanel(BuildContext context) {
    try {
      final backgroundColor = readerState.getControlsBackgroundColor();
      final textColor = readerState.getTextColor();

      return Material(
        elevation: 16,
        borderRadius: BorderRadius.circular(20),
        color: backgroundColor,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: Container(
          width: _panelWidth,
          constraints: const BoxConstraints(maxHeight: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildHeader(context, textColor),

                // Selected text
                if (readerState.selectedText != null)
                  _buildSelectedText(textColor),

                // Actions
                _buildActions(context, textColor),

                // Language selector
                _buildLanguageSelector(context, textColor),

                // Translation result
                if (readerState.selectionTranslation != null)
                  _buildTranslationResult(context, textColor),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint('[ToolPanel] Build panel error: $e\n$stack');
      return const SizedBox.shrink();
    }
  }

  Widget _buildHeader(BuildContext context, Color textColor) {
    try {
      return GestureDetector(
        onPanUpdate: (details) {
          readerState.updateToolPanelPosition(details.delta);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.drag_indicator_rounded,
                size: 20,
                color: textColor.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Selection Tools',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _CloseButton(
                onTap: readerState.hideToolPanel,
                textColor: textColor,
              ),
            ],
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint('[ToolPanel] Build header error: $e\n$stack');
      return const SizedBox.shrink();
    }
  }

  Widget _buildSelectedText(Color textColor) {
    final text = readerState.selectedText!;
    final displayText = text.length > 250
        ? '${text.substring(0, 250)}...'
        : text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.08)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildActions(BuildContext context, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive: use column for very small screens
          if (constraints.maxWidth < 260) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.copy_rounded,
                        label: 'Copy',
                        onTap: readerState.copySelectedText,
                        textColor: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.share_rounded,
                        label: 'Share',
                        onTap: readerState.shareSelectedText,
                        textColor: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.translate_rounded,
                        label: 'Translate',
                        onTap: readerState.translateSelectedText,
                        isLoading: readerState.isTranslatingSelection,
                        isPrimary: true,
                        textColor: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.volume_up,
                        label: 'Speak',
                        onTap: readerState.speakSelectedText,
                        isLoading: readerState.isSpeaking,
                        isPrimary: true,
                        textColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                /* SizedBox(
                  width: double.infinity,
                  child: _ActionButton(
                    icon: Icons.translate_rounded,
                    label: 'Translate',
                    onTap: readerState.translateSelectedText,
                    isLoading: readerState.isTranslatingSelection,
                    isPrimary: true,
                    textColor: Theme.of(context).primaryColor,
                  ),
                ), */
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: readerState.copySelectedText,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: readerState.shareSelectedText,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionButton(
                  icon: Icons.translate_rounded,
                  label: 'Translate',
                  onTap: readerState.translateSelectedText,
                  isLoading: readerState.isTranslatingSelection,
                  isPrimary: true,
                  textColor: Theme.of(context).primaryColor,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context, Color textColor) {
    final language = TranslationLanguage.fromCode(readerState.targetLanguage);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: readerState.showLanguageSelector,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                language?.emoji ?? '🌐',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Translate to ${language?.name ?? 'Select'}',
                  style: TextStyle(color: textColor, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 22,
                color: textColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationResult(BuildContext context, Color textColor) {
    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.translate_rounded,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Translation',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _CopyIconButton(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: readerState.selectionTranslation!),
                  );
                  readerState.showSnackBar('Translation copied');
                },
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            readerState.selectionTranslation!,
            style: TextStyle(color: textColor, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Close button widget
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color textColor;

  const _CloseButton({required this.onTap, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.close_rounded, size: 18, color: Colors.red[400]),
      ),
    );
  }
}

/// Action button widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isPrimary;
  final Color textColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.isPrimary = false,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isPrimary
                ? textColor.withValues(alpha: 0.1)
                : textColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: isPrimary
                ? Border.all(color: textColor.withValues(alpha: 0.3))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(textColor),
                  ),
                )
              else
                Icon(icon, size: 20, color: textColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: textColor,
                  fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Copy icon button
class _CopyIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;

  const _CopyIconButton({required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(Icons.copy_rounded, size: 16, color: color),
      ),
    );
  }
}

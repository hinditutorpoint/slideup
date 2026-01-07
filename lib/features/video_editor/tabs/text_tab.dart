import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';

// ═══════════════════════════════════════════════════════
// ✅ SIMPLIFIED TEXT TAB - Compact & Overflow-Safe
// ═══════════════════════════════════════════════════════

class TextTab extends ConsumerStatefulWidget {
  const TextTab({super.key});

  @override
  ConsumerState<TextTab> createState() => _TextTabState();
}

class _TextTabState extends ConsumerState<TextTab> {
  @override
  Widget build(BuildContext context) {
    final textItems = ref.watch(textItemsProvider);
    final currentProject = ref.watch(currentProjectProvider);
    final videoDuration = currentProject?.videoDuration ?? Duration.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 350;

        return Column(
          children: [
            _buildPresetsSection(isCompact),
            Divider(
              color: Colors.white.withValues(alpha: 0.1),
              height: isCompact ? 12 : 20,
            ),
            if (textItems.isNotEmpty) ...[
              _buildTimeline(textItems, videoDuration, isCompact),
              SizedBox(height: isCompact ? 6 : 10),
            ],
            Expanded(
              child: textItems.isEmpty
                  ? _buildEmptyState(isCompact)
                  : _buildTextItemsList(textItems, isCompact),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PRESETS SECTION
  // ═══════════════════════════════════════════════════════

  Widget _buildPresetsSection(bool isCompact) {
    return Padding(
      padding: EdgeInsets.all(isCompact ? 8 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Text Presets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 12 : 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildAddButton(isCompact),
            ],
          ),
          SizedBox(height: isCompact ? 6 : 10),
          SizedBox(
            height: isCompact ? 60 : 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: TextPreset.defaultPresets.length,
              itemBuilder: (context, index) {
                final preset = TextPreset.defaultPresets[index];
                return _buildPresetCard(preset, isCompact);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(bool isCompact) {
    return SizedBox(
      height: isCompact ? 28 : 32,
      child: TextButton.icon(
        onPressed: _addNewText,
        icon: Icon(Icons.add, size: isCompact ? 14 : 16),
        label: Text('Add', style: TextStyle(fontSize: isCompact ? 10 : 11)),
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildPresetCard(TextPreset preset, bool isCompact) {
    final style = preset.style;

    return GestureDetector(
      onTap: () => _addTextFromPreset(preset),
      child: Container(
        width: isCompact ? 70 : 80,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Color(
            style.backgroundColor != 0 ? style.backgroundColor : 0xFF2A2A2A,
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              preset.iconEmoji ?? 'Aa',
              style: TextStyle(
                fontSize: isCompact ? 16 : 18,
                color: Color(style.color),
                fontWeight: style.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                preset.name,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: isCompact ? 8 : 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TIMELINE VISUALIZATION
  // ═══════════════════════════════════════════════════════

  Widget _buildTimeline(
    List<TextTimelineItem> items,
    Duration videoDuration,
    bool isCompact,
  ) {
    if (videoDuration == Duration.zero) return const SizedBox.shrink();

    return Container(
      height: isCompact ? 44 : 52,
      margin: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final totalMs = videoDuration.inMilliseconds.toDouble();
          if (totalMs <= 0) return const SizedBox.shrink();

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              _buildTimeMarkers(width, videoDuration, isCompact),
              ...items.asMap().entries.map((entry) {
                return _buildTimelineBar(
                  entry.value,
                  entry.key,
                  width,
                  totalMs,
                  isCompact,
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimelineBar(
    TextTimelineItem item,
    int index,
    double width,
    double totalMs,
    bool isCompact,
  ) {
    final startX = (item.startTime.inMilliseconds / totalMs) * width;
    final endX = (item.endTime.inMilliseconds / totalMs) * width;
    final barWidth = (endX - startX).clamp(16.0, width - startX);

    return Positioned(
      left: startX.clamp(0, width - 16),
      top: 12 + (index % 2) * (isCompact ? 14.0 : 16.0),
      child: GestureDetector(
        onTap: () => _selectTextItem(item.id),
        child: Container(
          width: barWidth,
          height: isCompact ? 10 : 12,
          decoration: BoxDecoration(
            color: _getItemColor(index).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.center,
          child: barWidth > 30
              ? Text(
                  _truncateText(item.text, 8),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 6 : 7,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildTimeMarkers(double width, Duration duration, bool isCompact) {
    return Stack(
      children: List.generate(6, (i) {
        final x = (width / 5) * i;
        final time = Duration(
          milliseconds: ((duration.inMilliseconds / 5) * i).toInt(),
        );

        return Positioned(
          left: i == 5 ? null : x,
          right: i == 5 ? 0 : null,
          top: 0,
          bottom: 0,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  _formatDuration(time),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: isCompact ? 6 : 7,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TEXT ITEMS LIST
  // ═══════════════════════════════════════════════════════

  Widget _buildTextItemsList(List<TextTimelineItem> items, bool isCompact) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildTextItemCard(items[index], index, isCompact);
      },
    );
  }

  Widget _buildTextItemCard(TextTimelineItem item, int index, bool isCompact) {
    final selectedItemId = ref.watch(selectedItemProvider)?.id;
    final isSelected = selectedItemId == item.id;
    final itemColor = _getItemColor(index);

    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 6 : 8),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.5)
              : itemColor.withValues(alpha: 0.25),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectTextItem(item.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 8 : 10),
            child: Row(
              children: [
                // Preview box
                _buildPreviewBox(item, isCompact),
                SizedBox(width: isCompact ? 8 : 10),

                // Info - Expanded to take remaining space
                Expanded(child: _buildItemInfo(item, isCompact)),

                // Actions - Fixed width
                _buildItemActions(item, isCompact),

                // Selected indicator
                if (isSelected) _buildSelectedIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBox(TextTimelineItem item, bool isCompact) {
    return Container(
      width: isCompact ? 40 : 48,
      height: isCompact ? 28 : 32,
      decoration: BoxDecoration(
        color: Color(
          item.style.backgroundColor != 0
              ? item.style.backgroundColor
              : 0xFF1A1A1A,
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      alignment: Alignment.center,
      child: Text(
        item.text.isNotEmpty ? _truncateText(item.text, 2) : 'Aa',
        style: TextStyle(
          color: Color(item.style.color),
          fontSize: isCompact ? 10 : 11,
          fontWeight: item.style.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: item.style.italic ? FontStyle.italic : FontStyle.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );
  }

  Widget _buildItemInfo(TextTimelineItem item, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.text.isEmpty ? 'Empty text' : item.text,
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 11 : 12,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule,
              size: 9,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                '${_formatDuration(item.startTime)} - ${_formatDuration(item.endTime)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: isCompact ? 9 : 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (_hasAnimation(item))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.animation, size: 9, color: Colors.blue),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    _getAnimationLabel(item.animationIn, item.animationOut),
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: isCompact ? 8 : 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildItemActions(TextTimelineItem item, bool isCompact) {
    final iconSize = isCompact ? 14.0 : 16.0;
    const buttonSize = 28.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: IconButton(
            onPressed: () => _duplicateTextItem(item),
            icon: Icon(Icons.copy, size: iconSize),
            color: Colors.white.withValues(alpha: 0.4),
            padding: EdgeInsets.zero,
            splashRadius: 14,
            tooltip: 'Duplicate',
          ),
        ),
        SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: IconButton(
            onPressed: () => _deleteTextItem(item.id),
            icon: Icon(Icons.delete_outline, size: iconSize),
            color: Colors.red.withValues(alpha: 0.6),
            padding: EdgeInsets.zero,
            splashRadius: 14,
            tooltip: 'Delete',
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedIndicator() {
    return Container(
      width: 3,
      height: 32,
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }

  Widget _buildEmptyState(bool isCompact) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.text_fields_outlined,
              color: Colors.white.withValues(alpha: 0.15),
              size: isCompact ? 36 : 44,
            ),
            SizedBox(height: isCompact ? 8 : 12),
            Text(
              'No text overlays',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: isCompact ? 12 : 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a preset or "Add" to start',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: isCompact ? 10 : 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTIONS
  // ═══════════════════════════════════════════════════════

  void _addNewText() {
    final currentPosition = ref.read(currentPositionProvider);
    ref
        .read(timelineProvider.notifier)
        .addTextItem(
          text: 'New Text',
          startTime: currentPosition,
          duration: const Duration(seconds: 3),
        );
    HapticFeedback.mediumImpact();
    _selectLastItem();
  }

  void _addTextFromPreset(TextPreset preset) {
    final currentPosition = ref.read(currentPositionProvider);
    ref
        .read(timelineProvider.notifier)
        .addTextItem(
          text: preset.name,
          startTime: currentPosition,
          duration: const Duration(seconds: 3),
          style: preset.style,
        );
    HapticFeedback.mediumImpact();
    _selectLastItem();
  }

  void _selectLastItem() {
    Future.delayed(const Duration(milliseconds: 100), () {
      final items = ref.read(textItemsProvider);
      if (items.isNotEmpty) {
        _selectTextItem(items.last.id);
      }
    });
  }

  void _selectTextItem(String itemId) {
    ref
        .read(timelineProvider.notifier)
        .selectItem(itemId, TimelineItemType.text);
    HapticFeedback.selectionClick();
  }

  void _duplicateTextItem(TextTimelineItem item) {
    ref.read(timelineProvider.notifier).duplicateItem(item.id);
    HapticFeedback.mediumImpact();
  }

  void _deleteTextItem(String itemId) {
    ref.read(timelineProvider.notifier).removeTextItem(itemId);
    HapticFeedback.lightImpact();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength);
  }

  bool _hasAnimation(TextTimelineItem item) {
    return item.animationIn != TextAnimation.none ||
        item.animationOut != TextAnimation.none;
  }

  Color _getItemColor(int index) {
    const colors = [
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }

  String _getAnimationLabel(TextAnimation animIn, TextAnimation animOut) {
    if (animIn != TextAnimation.none && animOut != TextAnimation.none) {
      return 'In + Out';
    } else if (animIn != TextAnimation.none) {
      return 'In: ${animIn.name}';
    } else if (animOut != TextAnimation.none) {
      return 'Out: ${animOut.name}';
    }
    return '';
  }
}

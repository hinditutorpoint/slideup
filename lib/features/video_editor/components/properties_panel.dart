import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';
import 'sync_text_field.dart';

const List<String> _fontFamilies = [
  'Arial',
  'Roboto',
  'Helvetica',
  'Times New Roman',
  'Georgia',
  'Courier New',
  'Verdana',
  'Impact',
  'Comic Sans MS',
  'Montserrat',
];

// ═══════════════════════════════════════════════════════
// ✅ PROPERTIES PANEL (COMPREHENSIVE)
// ═══════════════════════════════════════════════════════

class PropertiesPanel extends ConsumerStatefulWidget {
  final TimelineItem item;

  const PropertiesPanel({super.key, required this.item});

  @override
  ConsumerState<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends ConsumerState<PropertiesPanel> {
  bool _isTransformExpanded = true;
  bool _isStyleExpanded = true;
  bool _isAnimationExpanded = false;
  bool _isAudioExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Scrollable properties
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: _buildPropertiesContent(),
            ),
          ),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title = '';
    IconData icon = Icons.layers;
    Color color = Colors.grey;

    if (widget.item is TextTimelineItem) {
      final textItem = widget.item as TextTimelineItem;
      title = textItem.text.length > 30
          ? '${textItem.text.substring(0, 30)}...'
          : textItem.text;
      icon = Icons.text_fields;
      color = Colors.orange;
    } else if (widget.item is ImageTimelineItem) {
      title = 'Image Properties';
      icon = Icons.image;
      color = Colors.green;
    } else if (widget.item is AudioTimelineItem) {
      final audioItem = widget.item as AudioTimelineItem;
      title = audioItem.title.isNotEmpty ? audioItem.title : 'Audio';
      icon = Icons.music_note;
      color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDuration(widget.item.duration),
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(timelineProvider.notifier).clearSelection();
            },
            icon: const Icon(Icons.close, size: 18),
            color: Colors.white54,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesContent() {
    if (widget.item is TextTimelineItem) {
      return _buildTextProperties(widget.item as TextTimelineItem);
    } else if (widget.item is ImageTimelineItem) {
      return _buildImageProperties(widget.item as ImageTimelineItem);
    } else if (widget.item is VideoOverlayTimelineItem) {
      return _buildVideoOverlayProperties(
          widget.item as VideoOverlayTimelineItem);
    } else if (widget.item is AudioTimelineItem) {
      return _buildAudioProperties(widget.item as AudioTimelineItem);
    } else if (widget.item is SolidColorTimelineItem) {
      return _buildSolidColorProperties(widget.item as SolidColorTimelineItem);
    }

    return const Center(
      child: Text(
        'No properties available',
        style: TextStyle(color: Colors.white54),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TEXT PROPERTIES
  // ═══════════════════════════════════════════════════════

  Widget _buildTextProperties(TextTimelineItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text content
        _buildSection(
          title: 'Content',
          child: SyncTextField(
            text: item.text,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
            onChanged: (value) {
              _updateTextItem(item.copyWith(text: value));
            },
          ),
        ),

        const SizedBox(height: 16),

        // Common: lock & visibility
        _buildCommonItemControls(item),

        // Keyframes
        _buildKeyframeSection(item),

        const SizedBox(height: 16),

        // Transform
        _buildExpandableSection(
          title: 'Transform',
          icon: Icons.transform,
          isExpanded: _isTransformExpanded,
          onToggle: () {
            setState(() => _isTransformExpanded = !_isTransformExpanded);
          },
          child: _buildTransformControls(item),
        ),

        const SizedBox(height: 16),

        // Style
        _buildExpandableSection(
          title: 'Style',
          icon: Icons.style,
          isExpanded: _isStyleExpanded,
          onToggle: () {
            setState(() => _isStyleExpanded = !_isStyleExpanded);
          },
          child: _buildTextStyleControls(item),
        ),

        const SizedBox(height: 16),

        // Animation
        _buildExpandableSection(
          title: 'Animation',
          icon: Icons.animation,
          isExpanded: _isAnimationExpanded,
          onToggle: () {
            setState(() => _isAnimationExpanded = !_isAnimationExpanded);
          },
          child: _buildAnimationControls(item),
        ),
      ],
    );
  }

  Widget _buildTextStyleControls(TextTimelineItem item) {
    return Column(
      children: [
        // Font size
        _buildSliderControl(
          label: 'Font Size',
          value: item.style.fontSize,
          min: 12,
          max: 120,
          onChanged: (value) {
            _updateTextItem(
              item.copyWith(style: item.style.copyWith(fontSize: value)),
            );
          },
        ),

        const SizedBox(height: 12),

        // Font family
        _buildDropdown<String>(
          label: 'Font Family',
          value: item.style.fontFamily.isNotEmpty
              ? item.style.fontFamily
              : _fontFamilies.first,
          items: _fontFamilies,
          onChanged: (value) {
            if (value != null) {
              _updateTextItem(
                item.copyWith(style: item.style.copyWith(fontFamily: value)),
              );
            }
          },
        ),

        const SizedBox(height: 12),

        // Bold & Italic toggles
        Row(
          children: [
            Expanded(
              child: _buildToggleButton(
                label: 'Bold',
                icon: Icons.format_bold,
                isActive: item.style.bold,
                onTap: () {
                  _updateTextItem(
                    item.copyWith(
                      style: item.style.copyWith(bold: !item.style.bold),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                label: 'Italic',
                icon: Icons.format_italic,
                isActive: item.style.italic,
                onTap: () {
                  _updateTextItem(
                    item.copyWith(
                      style: item.style.copyWith(italic: !item.style.italic),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Text color
        _buildColorPicker(
          label: 'Text Color',
          color: Color(item.style.color),
          onColorChanged: (color) {
            _updateTextItem(
              item.copyWith(
                style: item.style.copyWith(color: color.toARGB32()),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Background color
        _buildColorPicker(
          label: 'Background',
          color: Color(item.style.backgroundColor),
          onColorChanged: (color) {
            _updateTextItem(
              item.copyWith(
                style: item.style.copyWith(backgroundColor: color.toARGB32()),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Shadow blur
        _buildSliderControl(
          label: 'Shadow Blur',
          value: item.style.shadowBlur,
          min: 0,
          max: 20,
          onChanged: (value) {
            _updateTextItem(
              item.copyWith(style: item.style.copyWith(shadowBlur: value)),
            );
          },
        ),

        const SizedBox(height: 12),

        // Shadow color
        _buildColorPicker(
          label: 'Shadow Color',
          color: Color(item.style.shadowColor),
          onColorChanged: (color) {
            _updateTextItem(
              item.copyWith(
                style: item.style.copyWith(shadowColor: color.toARGB32()),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Stroke width
        _buildSliderControl(
          label: 'Stroke Width',
          value: item.style.strokeWidth,
          min: 0,
          max: 10,
          onChanged: (value) {
            _updateTextItem(
              item.copyWith(style: item.style.copyWith(strokeWidth: value)),
            );
          },
        ),

        if (item.style.strokeWidth > 0) ...[
          const SizedBox(height: 12),
          _buildColorPicker(
            label: 'Stroke Color',
            color: Color(item.style.strokeColor),
            onColorChanged: (color) {
              _updateTextItem(
                item.copyWith(
                  style: item.style.copyWith(strokeColor: color.toARGB32()),
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 12),

        // Letter spacing
        _buildSliderControl(
          label: 'Letter Spacing',
          value: item.style.letterSpacing,
          min: -5,
          max: 20,
          onChanged: (value) {
            _updateTextItem(
              item.copyWith(
                style: item.style.copyWith(letterSpacing: value),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // Line height
        _buildSliderControl(
          label: 'Line Height',
          value: item.style.lineHeight,
          min: 0.5,
          max: 3,
          divisions: 25,
          onChanged: (value) {
            _updateTextItem(
              item.copyWith(style: item.style.copyWith(lineHeight: value)),
            );
          },
        ),

        const SizedBox(height: 12),

        // Text alignment
        _buildAlignmentControls(item),
      ],
    );
  }

  Widget _buildAlignmentControls(TextTimelineItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alignment',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildAlignButton(
              icon: Icons.format_align_left,
              isActive: item.style.textAlign == TextAlignCustom.left,
              onTap: () {
                _updateTextItem(
                  item.copyWith(
                    style: item.style.copyWith(textAlign: TextAlignCustom.left),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            _buildAlignButton(
              icon: Icons.format_align_center,
              isActive: item.style.textAlign == TextAlignCustom.center,
              onTap: () {
                _updateTextItem(
                  item.copyWith(
                    style: item.style.copyWith(
                      textAlign: TextAlignCustom.center,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            _buildAlignButton(
              icon: Icons.format_align_right,
              isActive: item.style.textAlign == TextAlignCustom.right,
              onTap: () {
                _updateTextItem(
                  item.copyWith(
                    style: item.style.copyWith(
                      textAlign: TextAlignCustom.right,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlignButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: isActive
            ? Colors.blue.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? Colors.blue : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimationControls(TextTimelineItem item) {
    return Column(
      children: [
        // Animation In
        _buildDropdown<TextAnimation>(
          label: 'Animation In',
          value: item.animationIn,
          items: TextAnimation.values,
          onChanged: (value) {
            if (value != null) {
              _updateTextItem(item.copyWith(animationIn: value));
            }
          },
        ),

        const SizedBox(height: 12),

        // Animation Out
        _buildDropdown<TextAnimation>(
          label: 'Animation Out',
          value: item.animationOut,
          items: TextAnimation.values,
          onChanged: (value) {
            if (value != null) {
              _updateTextItem(item.copyWith(animationOut: value));
            }
          },
        ),

        const SizedBox(height: 12),

        // Animation Duration
        _buildSliderControl(
          label: 'Duration (ms)',
          value: item.animationDuration.inMilliseconds.toDouble(),
          min: 100,
          max: 2000,
          divisions: 19,
          onChanged: (value) {
            _updateTextItem(
              item.copyWith(
                animationDuration: Duration(milliseconds: value.toInt()),
              ),
            );
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ IMAGE PROPERTIES
  // ═══════════════════════════════════════════════════════

  Widget _buildImageProperties(ImageTimelineItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image info
        _buildSection(
          title: 'Image Info',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Resolution', '${item.width}x${item.height}'),
              _buildInfoRow(
                'Aspect Ratio',
                item.aspectRatio.toStringAsFixed(2),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Common: lock & visibility
        _buildCommonItemControls(item),

        // Keyframes
        _buildKeyframeSection(item),

        const SizedBox(height: 16),

        // Transform
        _buildExpandableSection(
          title: 'Transform',
          icon: Icons.transform,
          isExpanded: _isTransformExpanded,
          onToggle: () {
            setState(() => _isTransformExpanded = !_isTransformExpanded);
          },
          child: _buildTransformControls(item),
        ),

        const SizedBox(height: 16),

        // Style
        _buildExpandableSection(
          title: 'Style',
          icon: Icons.style,
          isExpanded: _isStyleExpanded,
          onToggle: () {
            setState(() => _isStyleExpanded = !_isStyleExpanded);
          },
          child: _buildImageStyleControls(item),
        ),
      ],
    );
  }

  Widget _buildCommonItemControls(TimelineItem item) {
    return _buildSection(
      title: 'Object',
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              label: 'Visible',
              icon: item.isVisible ? Icons.visibility : Icons.visibility_off,
              isActive: item.isVisible,
              onTap: () => _updateCommon(
                item,
                visible: !item.isVisible,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildToggleButton(
              label: 'Lock',
              icon: Icons.lock,
              isActive: item.isLocked,
              color: Colors.orange,
              onTap: () => _updateCommon(
                item,
                locked: !item.isLocked,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // KEYFRAME SECTION
  // ═══════════════════════════════════════════════════════

  Widget _buildKeyframeSection(TimelineItem item) {
    final state = ref.watch(timelineProvider);
    final kfs = state.keyframes[item.id] ?? [];
    final position = state.currentPosition;
    final relativePos = position - item.startTime;

    // Find if there's a keyframe at the current position (within 100ms)
    final nearbyKf = kfs
        .where((k) => (k.time - relativePos).inMilliseconds.abs() < 100)
        .fold<KeyframeData?>(
          null,
          (prev, k) => prev == null || (k.time - relativePos).abs() < (prev.time - relativePos).abs() ? k : prev,
        );

    return _buildSection(
      title: 'Keyframes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addKeyframe(item, relativePos),
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Add at Playhead'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (nearbyKf != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _removeKeyframe(item.id, nearbyKf.id),
                    icon: const Icon(Icons.remove_circle_outline, size: 16),
                    label: const Text('Remove Here'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (kfs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${kfs.length} keyframe${kfs.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            ...kfs.map((kf) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (kf.time - relativePos).inMilliseconds.abs() < 100
                      ? const Color(0xFF6C63FF)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 6,
                    color: const Color(0xFF6C63FF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    kf.time.toString().split('.').first,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  ..._keyframeIndicators(kf),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _removeKeyframe(item.id, kf.id),
                    child: Icon(Icons.close, size: 12, color: Colors.red.shade300),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  List<Widget> _keyframeIndicators(KeyframeData kf) {
    final props = <Widget>[];
    if (kf.x != null || kf.y != null) {
      props.add(_kfDot(Colors.blue, 'P'));
    }
    if (kf.scale != null) {
      props.add(_kfDot(Colors.green, 'S'));
    }
    if (kf.rotation != null) {
      props.add(_kfDot(Colors.orange, 'R'));
    }
    if (kf.opacity != null) {
      props.add(_kfDot(Colors.purple, 'O'));
    }
    if (kf.volume != null) {
      props.add(_kfDot(Colors.teal, 'V'));
    }
    if (kf.speed != null) {
      props.add(_kfDot(Colors.orangeAccent, '⚡'));
    }
    return props;
  }

  Widget _kfDot(Color color, String label) => Container(
    width: 14,
    height: 14,
    margin: const EdgeInsets.only(right: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Center(
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.bold),
      ),
    ),
  );

  void _addKeyframe(TimelineItem item, Duration relativePos) {
    final kf = KeyframeData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      time: relativePos,
      x: item.x,
      y: item.y,
      scale: item.scale,
      rotation: item.rotation,
      opacity: 1.0,
    );
    ref.read(timelineProvider.notifier).addKeyframe(item.id, kf);
    HapticFeedback.mediumImpact();
  }

  void _removeKeyframe(String itemId, String keyframeId) {
    ref.read(timelineProvider.notifier).removeKeyframe(itemId, keyframeId);
    HapticFeedback.lightImpact();
  }

  void _updateCommon(
    TimelineItem item, {
    bool? locked,
    bool? visible,
  }) {
    final notifier = ref.read(timelineProvider.notifier);
    if (item is TextTimelineItem) {
      notifier.updateTextItem(
        item.id,
        item.copyWith(isLocked: locked, isVisible: visible),
      );
    } else if (item is ImageTimelineItem) {
      notifier.updateImageItem(
        item.id,
        item.copyWith(isLocked: locked, isVisible: visible),
      );
    } else if (item is AudioTimelineItem) {
      notifier.updateAudioItem(
        item.id,
        item.copyWith(isLocked: locked, isVisible: visible),
      );
    }
  }

  Widget _buildImageStyleControls(ImageTimelineItem item) {
    return Column(
      children: [
        // Opacity
        _buildSliderControl(
          label: 'Opacity',
          value: item.opacity,
          min: 0.0,
          max: 1.0,
          onChanged: (value) {
            _updateImageItem(item.copyWith(opacity: value));
          },
        ),

        const SizedBox(height: 12),

        // Blend mode
        _buildDropdown<BlendMode>(
          label: 'Blend Mode',
          value: item.blendMode ?? BlendMode.srcOver,
          items: BlendMode.values,
          onChanged: (value) {
            if (value != null) {
              _updateImageItem(item.copyWith(blendMode: value));
            }
          },
        ),

        const SizedBox(height: 12),

        // Image fit
        _buildDropdown<ImageFit>(
          label: 'Fit',
          value: item.fit,
          items: ImageFit.values,
          onChanged: (value) {
            if (value != null) {
              _updateImageItem(item.copyWith(fit: value));
            }
          },
        ),

        const SizedBox(height: 12),

        // Border width
        _buildSliderControl(
          label: 'Border Width',
          value: item.borderWidth,
          min: 0,
          max: 20,
          onChanged: (value) {
            _updateImageItem(item.copyWith(borderWidth: value));
          },
        ),

        if (item.borderWidth > 0) ...[
          const SizedBox(height: 12),
          _buildColorPicker(
            label: 'Border Color',
            color: Color(item.borderColor ?? 0xFFFFFFFF),
            onColorChanged: (color) {
              _updateImageItem(item.copyWith(borderColor: color.toARGB32()));
            },
          ),
        ],

        const SizedBox(height: 12),

        // Border radius
        _buildSliderControl(
          label: 'Border Radius',
          value: item.borderRadius,
          min: 0,
          max: 50,
          onChanged: (value) {
            _updateImageItem(item.copyWith(borderRadius: value));
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ AUDIO PROPERTIES
  // ═══════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════
  // ✅ VIDEO OVERLAY LAYER PROPERTIES
  // ═══════════════════════════════════════════════════════

  Widget _buildVideoOverlayProperties(VideoOverlayTimelineItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          title: 'Video Layer',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Duration', _formatDuration(item.duration)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildSection(
          title: 'Layer Controls',
          child: Column(
            children: [
              _buildSliderControl(
                label: 'Volume (${(item.volume * 100).toInt()}%)',
                value: item.volume,
                min: 0.0,
                max: 2.0,
                onChanged: (value) {
                  _updateVideoOverlay(item.copyWith(volume: value));
                },
              ),
              const SizedBox(height: 12),
              _buildSliderControl(
                label: 'Opacity (${(item.opacity * 100).toInt()}%)',
                value: item.opacity,
                min: 0.0,
                max: 1.0,
                onChanged: (value) {
                  _updateVideoOverlay(item.copyWith(opacity: value));
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildCommonItemControls(item),

        // Keyframes
        _buildKeyframeSection(item),
      ],
    );
  }

  void _updateVideoOverlay(VideoOverlayTimelineItem item) {
    ref.read(timelineProvider.notifier).updateVideoOverlayItem(item.id, item);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SOLID COLOR LAYER PROPERTIES
  // ═══════════════════════════════════════════════════════

  Widget _buildSolidColorProperties(SolidColorTimelineItem item) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildSection(
          title: 'Solid Color Layer',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Duration', _formatDuration(item.duration)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Color', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _pickSolidColor(item),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(item.colorValue),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[600]!),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSection(
          title: 'Controls',
          child: Column(
            children: [
              _buildSliderControl(
                label: 'Opacity (${(item.opacity * 100).toInt()}%)',
                value: item.opacity,
                min: 0.0,
                max: 1.0,
                onChanged: (value) => _updateSolidColor(item.copyWith(opacity: value)),
              ),
              const SizedBox(height: 12),
              _buildSliderControl(
                label: 'Width (${(item.width * 100).toInt()}%)',
                value: item.width,
                min: 0.1,
                max: 2.0,
                onChanged: (value) => _updateSolidColor(item.copyWith(width: value)),
              ),
              const SizedBox(height: 12),
              _buildSliderControl(
                label: 'Height (${(item.height * 100).toInt()}%)',
                value: item.height,
                min: 0.1,
                max: 2.0,
                onChanged: (value) => _updateSolidColor(item.copyWith(height: value)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCommonItemControls(item),
        _buildKeyframeSection(item),
      ],
    );
  }

  void _updateSolidColor(SolidColorTimelineItem item) {
    ref.read(timelineProvider.notifier).updateSolidColorItem(item.id, item);
  }

  Future<void> _pickSolidColor(SolidColorTimelineItem item) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (_) => _SolidColorPickerDialog(initialColor: Color(item.colorValue)),
    );
    if (color != null) {
      _updateSolidColor(item.copyWith(colorValue: color.toARGB32()));
    }
  }

  Widget _buildAudioProperties(AudioTimelineItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Audio info
        _buildSection(
          title: 'Audio Info',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Duration', _formatDuration(item.audioDuration)),
              if (item.artist.isNotEmpty) _buildInfoRow('Artist', item.artist),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Audio controls
        _buildExpandableSection(
          title: 'Audio Controls',
          icon: Icons.tune,
          isExpanded: _isAudioExpanded,
          onToggle: () {
            setState(() => _isAudioExpanded = !_isAudioExpanded);
          },
          child: _buildAudioControls(item),
        ),

        const SizedBox(height: 16),

        // Common: lock & visibility
        _buildCommonItemControls(item),

        // Keyframes
        _buildKeyframeSection(item),
      ],
    );
  }

  Widget _buildAudioControls(AudioTimelineItem item) {
    return Column(
      children: [
        // Volume
        _buildSliderControl(
          label: 'Volume (${(item.volume * 100).toInt()}%)',
          value: item.volume,
          min: 0.0,
          max: 2.0,
          onChanged: (value) {
            _updateAudioItem(item.copyWith(volume: value));
          },
        ),

        const SizedBox(height: 12),

        // Mute toggle
        _buildToggleButton(
          label: 'Mute',
          icon: item.isMuted ? Icons.volume_off : Icons.volume_up,
          isActive: item.isMuted,
          color: Colors.red,
          onTap: () {
            _updateAudioItem(item.copyWith(isMuted: !item.isMuted));
          },
        ),

        const SizedBox(height: 12),

        // Fade In
        _buildToggleButton(
          label: 'Fade In',
          icon: Icons.input,
          isActive: item.fadeIn,
          onTap: () {
            _updateAudioItem(item.copyWith(fadeIn: !item.fadeIn));
          },
        ),

        const SizedBox(height: 12),

        // Fade Out
        _buildToggleButton(
          label: 'Fade Out',
          icon: Icons.output,
          isActive: item.fadeOut,
          onTap: () {
            _updateAudioItem(item.copyWith(fadeOut: !item.fadeOut));
          },
        ),

        if (item.fadeIn || item.fadeOut) ...[
          const SizedBox(height: 12),
          _buildSliderControl(
            label: 'Fade Duration (ms)',
            value: item.fadeDuration.inMilliseconds.toDouble(),
            min: 100,
            max: 3000,
            divisions: 29,
            onChanged: (value) {
              _updateAudioItem(
                item.copyWith(
                  fadeDuration: Duration(milliseconds: value.toInt()),
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 16),

        // Trim controls
        const Text(
          'Trim Audio',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        _buildSliderControl(
          label: 'Start (${_formatDuration(item.trimStart)})',
          value: item.trimStart.inMilliseconds.toDouble(),
          min: 0,
          max: item.audioDuration.inMilliseconds.toDouble(),
          onChanged: (value) {
            final newStart = Duration(milliseconds: value.toInt());
            if (newStart < item.trimEnd) {
              _updateAudioItem(item.copyWith(trimStart: newStart));
            }
          },
        ),

        const SizedBox(height: 8),

        _buildSliderControl(
          label: 'End (${_formatDuration(item.trimEnd)})',
          value: item.trimEnd.inMilliseconds.toDouble(),
          min: 0,
          max: item.audioDuration.inMilliseconds.toDouble(),
          onChanged: (value) {
            final newEnd = Duration(milliseconds: value.toInt());
            if (newEnd > item.trimStart) {
              _updateAudioItem(item.copyWith(trimEnd: newEnd));
            }
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ SHARED TRANSFORM CONTROLS
  // ═══════════════════════════════════════════════════════

  Widget _buildTransformControls(TimelineItem item) {
    return Column(
      children: [
        // Position X
        _buildSliderControl(
          label: 'Position X (${(item.x * 100).toInt()}%)',
          value: item.x,
          min: 0.0,
          max: 1.0,
          onChanged: (value) {
            if (item is TextTimelineItem) {
              _updateTextItem(item.copyWith(x: value));
            } else if (item is ImageTimelineItem) {
              _updateImageItem(item.copyWith(x: value));
            }
          },
        ),

        const SizedBox(height: 12),

        // Position Y
        _buildSliderControl(
          label: 'Position Y (${(item.y * 100).toInt()}%)',
          value: item.y,
          min: 0.0,
          max: 1.0,
          onChanged: (value) {
            if (item is TextTimelineItem) {
              _updateTextItem(item.copyWith(y: value));
            } else if (item is ImageTimelineItem) {
              _updateImageItem(item.copyWith(y: value));
            }
          },
        ),

        const SizedBox(height: 12),

        // Scale
        _buildSliderControl(
          label: 'Scale (${(item.scale * 100).toInt()}%)',
          value: item.scale,
          min: 0.1,
          max: 3.0,
          onChanged: (value) {
            if (item is TextTimelineItem) {
              _updateTextItem(item.copyWith(scale: value));
            } else if (item is ImageTimelineItem) {
              _updateImageItem(item.copyWith(scale: value));
            }
          },
        ),

        const SizedBox(height: 12),

        // Rotation
        _buildSliderControl(
          label: 'Rotation (${item.rotation.toInt()}°)',
          value: item.rotation,
          min: 0,
          max: 360,
          divisions: 72,
          onChanged: (value) {
            if (item is TextTimelineItem) {
              _updateTextItem(item.copyWith(rotation: value));
            } else if (item is ImageTimelineItem) {
              _updateImageItem(item.copyWith(rotation: value));
            }
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ UI BUILDING BLOCKS
  // ═══════════════════════════════════════════════════════

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded) ...[const SizedBox(height: 8), child],
      ],
    );
  }

  Widget _buildSliderControl({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.blue,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: Colors.blue,
            overlayColor: Colors.blue.withValues(alpha: 0.1),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    Color? color,
  }) {
    final activeColor = color ?? Colors.blue;

    return Material(
      color: isActive
          ? activeColor.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? activeColor : Colors.white54,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? activeColor : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: const Color(0xFF2D2D2D),
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  item.toString().split('.').last,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker({
    required String label,
    required Color color,
    required ValueChanged<Color> onColorChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showColorPickerDialog(color, onColorChanged),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                style: TextStyle(
                  color: _getContrastColor(color),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTION BUTTONS
  // ═══════════════════════════════════════════════════════

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                ref
                    .read(timelineProvider.notifier)
                    .duplicateItem(widget.item.id);
                HapticFeedback.mediumImpact();
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Duplicate', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(timelineProvider.notifier).deleteSelectedItem();
                HapticFeedback.mediumImpact();
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Delete', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.2),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ UPDATE METHODS
  // ═══════════════════════════════════════════════════════

  void _updateTextItem(TextTimelineItem updatedItem) {
    ref
        .read(timelineProvider.notifier)
        .updateTextItem(widget.item.id, updatedItem);
  }

  void _updateImageItem(ImageTimelineItem updatedItem) {
    ref
        .read(timelineProvider.notifier)
        .updateImageItem(widget.item.id, updatedItem);
  }

  void _updateAudioItem(AudioTimelineItem updatedItem) {
    ref
        .read(timelineProvider.notifier)
        .updateAudioItem(widget.item.id, updatedItem);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  String _formatDuration(Duration d) {
    final seconds = d.inSeconds;
    final ms = d.inMilliseconds % 1000;
    return '${seconds}s ${ms}ms';
  }

  Color _getContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  void _showColorPickerDialog(
    Color currentColor,
    ValueChanged<Color> onColorChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) => _ColorPickerDialog(
        currentColor: currentColor,
        onColorChanged: onColorChanged,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// ✅ COLOR PICKER DIALOG
// ═══════════════════════════════════════════════════════

class _ColorPickerDialog extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;

  const _ColorPickerDialog({
    required this.currentColor,
    required this.onColorChanged,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selectedColor;

  final List<Color> _presetColors = [
    Colors.transparent,
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2D2D2D),
      title: const Text('Pick Color', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 280,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _presetColors.length,
          itemBuilder: (context, index) {
            final color = _presetColors[index];
            final isSelected = _selectedColor.toARGB32() == color.toARGB32();

            return GestureDetector(
              onTap: () {
                setState(() => _selectedColor = color);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    width: isSelected ? 3 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: color == Colors.transparent
                    ? const Icon(Icons.block, color: Colors.red, size: 20)
                    : null,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onColorChanged(_selectedColor);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _SolidColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const _SolidColorPickerDialog({required this.initialColor});

  @override
  State<_SolidColorPickerDialog> createState() => _SolidColorPickerDialogState();
}

class _SolidColorPickerDialogState extends State<_SolidColorPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: const Text('Pick Color', style: TextStyle(color: Colors.white, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!),
            ),
          ),
          const SizedBox(height: 12),
          _buildHueSlider(),
          _buildSatSlider(),
          _buildValSlider(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, color),
          style: ElevatedButton.styleFrom(backgroundColor: color),
          child: const Text('Select'),
        ),
      ],
    );
  }

  Widget _buildHueSlider() => Row(
    children: [
      const SizedBox(width: 16, child: Text('H', style: TextStyle(color: Colors.grey, fontSize: 11))),
      Expanded(
        child: SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _hsv.toColor(),
            thumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[700],
            trackHeight: 2,
          ),
          child: Slider(value: _hsv.hue, min: 0, max: 360, onChanged: (v) => setState(() => _hsv = _hsv.withHue(v))),
        ),
      ),
    ],
  );

  Widget _buildSatSlider() => Row(
    children: [
      const SizedBox(width: 16, child: Text('S', style: TextStyle(color: Colors.grey, fontSize: 11))),
      Expanded(
        child: SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _hsv.toColor(),
            thumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[700],
            trackHeight: 2,
          ),
          child: Slider(value: _hsv.saturation, min: 0, max: 1, onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v))),
        ),
      ),
    ],
  );

  Widget _buildValSlider() => Row(
    children: [
      const SizedBox(width: 16, child: Text('V', style: TextStyle(color: Colors.grey, fontSize: 11))),
      Expanded(
        child: SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _hsv.toColor(),
            thumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[700],
            trackHeight: 2,
          ),
          child: Slider(value: _hsv.value, min: 0, max: 1, onChanged: (v) => setState(() => _hsv = _hsv.withValue(v))),
        ),
      ),
    ],
  );
}

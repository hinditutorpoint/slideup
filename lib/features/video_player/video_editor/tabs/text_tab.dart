import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/video_edit_settings.dart';

class TextTab extends StatefulWidget {
  final List<TextOverlay> overlays;
  final Function(List<TextOverlay>) onOverlaysChanged;
  final Duration videoDuration;

  const TextTab({
    super.key,
    required this.overlays,
    required this.onOverlaysChanged,
    required this.videoDuration,
  });

  @override
  State<TextTab> createState() => _TextTabState();
}

class _TextTabState extends State<TextTab> {
  TextOverlay? _editingOverlay;
  int? _editingIndex;
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 350;

        return Column(
          children: [
            // Presets section
            _buildPresetsSection(isCompact),

            // Divider
            Divider(color: Colors.white12, height: isCompact ? 16 : 24),

            // Content - Editor or List
            Expanded(
              child: _editingOverlay != null
                  ? _buildOverlayEditor(isCompact)
                  : _buildOverlaysList(isCompact),
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
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Text Presets',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _addNewOverlay,
                icon: Icon(Icons.add, size: isCompact ? 16 : 18),
                label: Text(
                  'Add Text',
                  style: TextStyle(fontSize: isCompact ? 11 : 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 8 : 12),
          SizedBox(
            height: isCompact ? 70 : 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: TextPreset.defaultPresets.length,
              itemBuilder: (context, index) {
                try {
                  final preset = TextPreset.defaultPresets[index];
                  return _buildPresetCard(preset, isCompact);
                } catch (e) {
                  debugPrint('❌ Build preset error: $e');
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(TextPreset preset, bool isCompact) {
    // Using TextOverlayStyle from our models (not Flutter's TextStyle)
    final style = preset.style;

    return GestureDetector(
      onTap: () => _addOverlayFromPreset(preset),
      child: Container(
        width: isCompact ? 85 : 95,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Color(
            style.backgroundColor != 0 ? style.backgroundColor : 0xFF2A2A2A,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Preview text with custom style
            Text(
              'Aa',
              style: TextStyle(
                color: Color(style.color),
                fontSize: isCompact ? 18 : 22,
                fontWeight: style.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
                shadows: style.shadowBlur > 0
                    ? [
                        Shadow(
                          color: Color(style.shadowColor),
                          blurRadius: style.shadowBlur,
                        ),
                      ]
                    : null,
              ),
            ),
            SizedBox(height: isCompact ? 4 : 6),
            Text(
              preset.name,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isCompact ? 9 : 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ OVERLAYS LIST
  // ═══════════════════════════════════════════════════════

  Widget _buildOverlaysList(bool isCompact) {
    if (widget.overlays.isEmpty) {
      return _buildEmptyState(isCompact);
    }

    return Column(
      children: [
        // Timeline visualization
        _buildTimeline(isCompact),
        const SizedBox(height: 8),

        // Overlay cards list
        Expanded(
          child: ReorderableListView.builder(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12),
            itemCount: widget.overlays.length,
            onReorder: _reorderOverlays,
            itemBuilder: (context, index) {
              try {
                final overlay = widget.overlays[index];
                return _buildOverlayCard(
                  overlay,
                  index,
                  isCompact,
                  key: ValueKey(overlay.id),
                );
              } catch (e) {
                debugPrint('❌ Build overlay card error: $e');
                return SizedBox.shrink(key: ValueKey('error_$index'));
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isCompact) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.text_fields,
            color: Colors.grey[700],
            size: isCompact ? 40 : 48,
          ),
          SizedBox(height: isCompact ? 12 : 16),
          Text(
            'No text overlays',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: isCompact ? 13 : 14,
            ),
          ),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            'Tap a preset or "Add Text" to start',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isCompact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TIMELINE - Draggable
  // ═══════════════════════════════════════════════════════

  Widget _buildTimeline(bool isCompact) {
    return Container(
      height: isCompact ? 60 : 70,
      margin: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final totalMs = widget.videoDuration.inMilliseconds.toDouble();

          if (totalMs <= 0) return const SizedBox.shrink();

          return Stack(
            children: [
              // Time markers
              _buildTimeMarkers(width, isCompact),

              // Overlay bars
              ...widget.overlays.asMap().entries.map((entry) {
                try {
                  final index = entry.key;
                  final overlay = entry.value;

                  final startX =
                      (overlay.startTime.inMilliseconds / totalMs) * width;
                  final endX =
                      (overlay.endTime.inMilliseconds / totalMs) * width;
                  final barWidth = (endX - startX).clamp(20.0, width);

                  return Positioned(
                    left: startX.clamp(0, width - 20),
                    top: 18 + (index % 2) * 16.0,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        _handleTimelineDrag(
                          index,
                          details.delta.dx,
                          width,
                          totalMs,
                        );
                      },
                      onHorizontalDragEnd: (_) => HapticFeedback.lightImpact(),
                      onTap: () => _editOverlay(overlay, index),
                      child: Container(
                        width: barWidth,
                        height: isCompact ? 12 : 14,
                        decoration: BoxDecoration(
                          color: _getOverlayColor(index),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                        child: Center(
                          child: Text(
                            overlay.text.isNotEmpty
                                ? overlay.text.substring(
                                    0,
                                    overlay.text.length.clamp(0, 6),
                                  )
                                : 'Text',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isCompact ? 7 : 8,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  debugPrint('❌ Timeline bar error: $e');
                  return const SizedBox.shrink();
                }
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeMarkers(double width, bool isCompact) {
    final markers = <Widget>[];
    const count = 5;

    for (int i = 0; i <= count; i++) {
      final x = (width / count) * i;
      final time = Duration(
        milliseconds: ((widget.videoDuration.inMilliseconds / count) * i)
            .toInt(),
      );

      // Time label
      markers.add(
        Positioned(
          left: (x - 12).clamp(0, width - 24),
          bottom: 2,
          child: Text(
            _formatDuration(time),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isCompact ? 7 : 8,
            ),
          ),
        ),
      );

      // Tick line
      markers.add(
        Positioned(
          left: x,
          top: 0,
          bottom: 14,
          child: Container(width: 1, color: Colors.white12),
        ),
      );
    }

    return Stack(children: markers);
  }

  void _handleTimelineDrag(
    int index,
    double deltaX,
    double width,
    double totalMs,
  ) {
    try {
      if (index < 0 || index >= widget.overlays.length) return;

      final overlay = widget.overlays[index];
      final deltaMs = (deltaX / width) * totalMs;

      final newStartMs = (overlay.startTime.inMilliseconds + deltaMs).toInt();
      final duration = overlay.endTime - overlay.startTime;

      // Clamp to valid range
      final clampedStart = newStartMs.clamp(
        0,
        widget.videoDuration.inMilliseconds - duration.inMilliseconds,
      );
      final newStart = Duration(milliseconds: clampedStart);
      final newEnd = newStart + duration;

      if (newEnd <= widget.videoDuration) {
        final updated = overlay.copyWith(startTime: newStart, endTime: newEnd);
        final newList = List<TextOverlay>.from(widget.overlays);
        newList[index] = updated;
        widget.onOverlaysChanged(newList);
      }
    } catch (e) {
      debugPrint('❌ Timeline drag error: $e');
    }
  }

  Color _getOverlayColor(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    return colors[index % colors.length].withValues(alpha: 0.7);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ OVERLAY CARD
  // ═══════════════════════════════════════════════════════

  Widget _buildOverlayCard(
    TextOverlay overlay,
    int index,
    bool isCompact, {
    Key? key,
  }) {
    final style = overlay.style;

    return Container(
      key: key,
      margin: EdgeInsets.only(bottom: isCompact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _getOverlayColor(index).withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _editOverlay(overlay, index),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 10 : 12),
            child: Row(
              children: [
                // Drag handle
                Icon(
                  Icons.drag_handle,
                  color: Colors.grey[600],
                  size: isCompact ? 18 : 20,
                ),
                SizedBox(width: isCompact ? 8 : 10),

                // Preview box
                Container(
                  width: isCompact ? 50 : 60,
                  height: isCompact ? 32 : 38,
                  decoration: BoxDecoration(
                    color: Color(
                      style.backgroundColor != 0
                          ? style.backgroundColor
                          : 0xFF1A1A1A,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Center(
                    child: Text(
                      overlay.text.isNotEmpty
                          ? overlay.text.substring(
                              0,
                              overlay.text.length.clamp(0, 3),
                            )
                          : 'Aa',
                      style: TextStyle(
                        color: Color(style.color),
                        fontSize: isCompact ? 11 : 13,
                        fontWeight: style.bold
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontStyle: style.italic
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                ),
                SizedBox(width: isCompact ? 10 : 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overlay.text.isEmpty ? 'Empty text' : overlay.text,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 12 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isCompact ? 2 : 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 10,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatDuration(overlay.startTime)} → ${_formatDuration(overlay.endTime)}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: isCompact ? 10 : 11,
                            ),
                          ),
                        ],
                      ),
                      if (overlay.animation != TextAnimation.none)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.animation,
                                size: 10,
                                color: Colors.blue[300],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatAnimationName(overlay.animation),
                                style: TextStyle(
                                  color: Colors.blue[300],
                                  fontSize: isCompact ? 9 : 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Delete button
                IconButton(
                  onPressed: () => _deleteOverlay(index),
                  icon: Icon(Icons.delete_outline, size: isCompact ? 18 : 20),
                  color: Colors.red[400],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ OVERLAY EDITOR
  // ═══════════════════════════════════════════════════════

  Widget _buildOverlayEditor(bool isCompact) {
    if (_editingOverlay == null) return const SizedBox.shrink();

    final overlay = _editingOverlay!;
    final style = overlay.style;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildEditorHeader(isCompact),
          SizedBox(height: isCompact ? 12 : 16),

          // Text input
          _buildTextInput(overlay, isCompact),
          SizedBox(height: isCompact ? 12 : 16),

          // Timing with dual slider
          _buildSectionTitle('Timing', isCompact),
          SizedBox(height: isCompact ? 8 : 10),
          _buildTimingSlider(overlay, isCompact),
          SizedBox(height: isCompact ? 12 : 16),

          // Position grid
          _buildSectionTitle('Position', isCompact),
          SizedBox(height: isCompact ? 8 : 10),
          _buildPositionGrid(overlay, isCompact),
          SizedBox(height: isCompact ? 12 : 16),

          // Style options
          _buildSectionTitle('Style', isCompact),
          SizedBox(height: isCompact ? 8 : 10),
          _buildStyleOptions(overlay, style, isCompact),
          SizedBox(height: isCompact ? 12 : 16),

          // Animation
          _buildSectionTitle('Animation', isCompact),
          SizedBox(height: isCompact ? 8 : 10),
          _buildAnimationOptions(overlay, isCompact),

          // Extra padding at bottom
          SizedBox(height: isCompact ? 20 : 30),
        ],
      ),
    );
  }

  Widget _buildEditorHeader(bool isCompact) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _editingOverlay = null;
              _editingIndex = null;
            });
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        Text(
          _editingIndex != null ? 'Edit Text' : 'New Text',
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: _saveOverlay,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(
            'Save',
            style: TextStyle(
              fontSize: isCompact ? 13 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextInput(TextOverlay overlay, bool isCompact) {
    // Set controller text if not already editing
    if (_textController.text != overlay.text) {
      _textController.text = overlay.text;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }

    return TextField(
      controller: _textController,
      style: const TextStyle(color: Colors.white),
      maxLines: 2,
      decoration: InputDecoration(
        labelText: 'Text',
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintText: 'Enter your text here...',
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.white12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.all(isCompact ? 12 : 14),
      ),
      onChanged: (value) {
        try {
          setState(() {
            _editingOverlay = overlay.copyWith(text: value);
          });
        } catch (e) {
          debugPrint('❌ Text change error: $e');
        }
      },
    );
  }

  Widget _buildSectionTitle(String title, bool isCompact) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey[400],
        fontSize: isCompact ? 11 : 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTimingSlider(TextOverlay overlay, bool isCompact) {
    final maxMs = widget.videoDuration.inMilliseconds.toDouble();
    if (maxMs <= 0) return const SizedBox.shrink();

    final startMs = overlay.startTime.inMilliseconds.toDouble().clamp(
      0.0,
      maxMs,
    );
    final endMs = overlay.endTime.inMilliseconds.toDouble().clamp(
      startMs,
      maxMs,
    );

    return Column(
      children: [
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Start: ${_formatDuration(overlay.startTime)}',
              style: TextStyle(
                color: Colors.green,
                fontSize: isCompact ? 11 : 12,
              ),
            ),
            Text(
              'Duration: ${_formatDuration(overlay.endTime - overlay.startTime)}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: isCompact ? 10 : 11,
              ),
            ),
            Text(
              'End: ${_formatDuration(overlay.endTime)}',
              style: TextStyle(
                color: Colors.red,
                fontSize: isCompact ? 11 : 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Range slider
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            rangeThumbShape: RoundRangeSliderThumbShape(
              enabledThumbRadius: isCompact ? 8 : 10,
            ),
            overlayShape: RoundSliderOverlayShape(
              overlayRadius: isCompact ? 14 : 16,
            ),
          ),
          child: RangeSlider(
            values: RangeValues(startMs, endMs),
            min: 0,
            max: maxMs,
            activeColor: Colors.red,
            inactiveColor: Colors.white24,
            onChanged: (values) {
              try {
                setState(() {
                  _editingOverlay = overlay.copyWith(
                    startTime: Duration(milliseconds: values.start.toInt()),
                    endTime: Duration(milliseconds: values.end.toInt()),
                  );
                });
              } catch (e) {
                debugPrint('❌ Range slider error: $e');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPositionGrid(TextOverlay overlay, bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 2,
        children: TextPositionCustom.values.map((pos) {
          final isSelected = overlay.position == pos;
          return GestureDetector(
            onTap: () {
              try {
                setState(() {
                  _editingOverlay = overlay.copyWith(position: pos);
                });
                HapticFeedback.selectionClick();
              } catch (e) {
                debugPrint('❌ Position tap error: $e');
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? Colors.red : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  _getPositionLabel(pos),
                  style: TextStyle(
                    color: isSelected ? Colors.red : Colors.white54,
                    fontSize: isCompact ? 9 : 10,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getPositionLabel(TextPositionCustom pos) {
    switch (pos) {
      case TextPositionCustom.topLeft:
        return 'Top Left';
      case TextPositionCustom.topCenter:
        return 'Top';
      case TextPositionCustom.topRight:
        return 'Top Right';
      case TextPositionCustom.centerLeft:
        return 'Left';
      case TextPositionCustom.center:
        return 'Center';
      case TextPositionCustom.centerRight:
        return 'Right';
      case TextPositionCustom.bottomLeft:
        return 'Bot Left';
      case TextPositionCustom.bottomCenter:
        return 'Bottom';
      case TextPositionCustom.bottomRight:
        return 'Bot Right';
    }
  }

  Widget _buildStyleOptions(
    TextOverlay overlay,
    TextOverlayStyle style,
    bool isCompact,
  ) {
    return Column(
      children: [
        // Font size slider
        _buildSliderRow('Size', style.fontSize, 16, 120, (v) {
          try {
            setState(() {
              _editingOverlay = overlay.copyWith(
                style: style.copyWith(fontSize: v),
              );
            });
          } catch (e) {
            debugPrint('❌ Font size error: $e');
          }
        }, isCompact),
        SizedBox(height: isCompact ? 10 : 12),

        // Bold / Italic toggles
        Row(
          children: [
            Expanded(
              child: _buildToggleButton('Bold', Icons.format_bold, style.bold, (
                v,
              ) {
                try {
                  setState(() {
                    _editingOverlay = overlay.copyWith(
                      style: style.copyWith(bold: v),
                    );
                  });
                } catch (e) {
                  debugPrint('❌ Bold toggle error: $e');
                }
              }, isCompact),
            ),
            SizedBox(width: isCompact ? 8 : 10),
            Expanded(
              child: _buildToggleButton(
                'Italic',
                Icons.format_italic,
                style.italic,
                (v) {
                  try {
                    setState(() {
                      _editingOverlay = overlay.copyWith(
                        style: style.copyWith(italic: v),
                      );
                    });
                  } catch (e) {
                    debugPrint('❌ Italic toggle error: $e');
                  }
                },
                isCompact,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 10 : 12),

        // Color buttons
        Row(
          children: [
            Expanded(
              child: _buildColorButton('Text Color', Color(style.color), (c) {
                try {
                  setState(() {
                    _editingOverlay = overlay.copyWith(
                      style: style.copyWith(color: c.toARGB32()),
                    );
                  });
                } catch (e) {
                  debugPrint('❌ Text color error: $e');
                }
              }, isCompact),
            ),
            SizedBox(width: isCompact ? 8 : 10),
            Expanded(
              child: _buildColorButton(
                'Background',
                Color(style.backgroundColor),
                (c) {
                  try {
                    setState(() {
                      _editingOverlay = overlay.copyWith(
                        style: style.copyWith(backgroundColor: c.toARGB32()),
                      );
                    });
                  } catch (e) {
                    debugPrint('❌ BG color error: $e');
                  }
                },
                isCompact,
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 10 : 12),

        // Shadow slider
        _buildSliderRow('Shadow', style.shadowBlur, 0, 20, (v) {
          try {
            setState(() {
              _editingOverlay = overlay.copyWith(
                style: style.copyWith(shadowBlur: v),
              );
            });
          } catch (e) {
            debugPrint('❌ Shadow error: $e');
          }
        }, isCompact),
      ],
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    bool isCompact,
  ) {
    return Row(
      children: [
        SizedBox(
          width: isCompact ? 50 : 60,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 11 : 12,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: isCompact ? 6 : 7,
              ),
              overlayShape: RoundSliderOverlayShape(
                overlayRadius: isCompact ? 12 : 14,
              ),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: Colors.red,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 35,
          child: Text(
            value.toInt().toString(),
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: isCompact ? 10 : 11,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(
    String label,
    IconData icon,
    bool value,
    Function(bool) onChanged,
    bool isCompact,
  ) {
    return GestureDetector(
      onTap: () {
        onChanged(!value);
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 12),
        decoration: BoxDecoration(
          color: value
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: value ? Colors.red : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: value ? Colors.red : Colors.white70,
              size: isCompact ? 18 : 20,
            ),
            SizedBox(width: isCompact ? 6 : 8),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.red : Colors.white70,
                fontSize: isCompact ? 11 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(
    String label,
    Color color,
    Function(Color) onChanged,
    bool isCompact,
  ) {
    final isTransparent = color.a == 0;

    return GestureDetector(
      onTap: () => _showColorPicker(color, onChanged),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isCompact ? 10 : 12,
          horizontal: isCompact ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: isCompact ? 20 : 24,
              height: isCompact ? 20 : 24,
              decoration: BoxDecoration(
                color: isTransparent ? Colors.grey[800] : color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24),
              ),
              child: isTransparent
                  ? Icon(Icons.block, size: 12, color: Colors.white38)
                  : null,
            ),
            SizedBox(width: isCompact ? 8 : 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isCompact ? 10 : 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimationOptions(TextOverlay overlay, bool isCompact) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TextAnimation.values.map((anim) {
        final isSelected = overlay.animation == anim;
        return GestureDetector(
          onTap: () {
            try {
              setState(() {
                _editingOverlay = overlay.copyWith(animation: anim);
              });
              HapticFeedback.selectionClick();
            } catch (e) {
              debugPrint('❌ Animation tap error: $e');
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 14,
              vertical: isCompact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.red.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.red : Colors.transparent,
              ),
            ),
            child: Text(
              _formatAnimationName(anim),
              style: TextStyle(
                color: isSelected ? Colors.red : Colors.white70,
                fontSize: isCompact ? 10 : 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatAnimationName(TextAnimation anim) {
    switch (anim) {
      case TextAnimation.none:
        return 'None';
      case TextAnimation.fadeIn:
        return 'Fade In';
      case TextAnimation.fadeOut:
        return 'Fade Out';
      case TextAnimation.slideUp:
        return 'Slide Up';
      case TextAnimation.slideDown:
        return 'Slide Down';
      case TextAnimation.typewriter:
        return 'Typewriter';
      case TextAnimation.bounce:
        return 'Bounce';
      case TextAnimation.scale:
        return 'Scale';
      case TextAnimation.rotate:
        return 'Rotate';
      case TextAnimation.slideLeft:
        return 'Slide Left';
      case TextAnimation.slideRight:
        return 'Slide Right';
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ COLOR PICKER
  // ═══════════════════════════════════════════════════════

  void _showColorPicker(Color currentColor, Function(Color) onChanged) {
    final colors = [
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
    ];

    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Color',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: colors.map((color) {
                    final isTransparent = color == Colors.transparent;
                    final isSelected =
                        currentColor == color ||
                        (isTransparent && currentColor.a == 0);

                    return GestureDetector(
                      onTap: () {
                        onChanged(color);
                        Navigator.pop(ctx);
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isTransparent ? Colors.grey[800] : color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.red : Colors.white24,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: isTransparent
                            ? const Center(
                                child: Icon(
                                  Icons.block,
                                  color: Colors.white38,
                                  size: 20,
                                ),
                              )
                            : isSelected
                            ? const Center(
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Color picker error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ACTIONS
  // ═══════════════════════════════════════════════════════

  void _addNewOverlay() {
    try {
      final defaultDuration = widget.videoDuration > const Duration(seconds: 5)
          ? const Duration(seconds: 5)
          : widget.videoDuration;

      final newOverlay = TextOverlay(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: 'New Text',
        startTime: Duration.zero,
        endTime: defaultDuration,
      );

      _textController.text = newOverlay.text;

      setState(() {
        _editingOverlay = newOverlay;
        _editingIndex = null;
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('❌ Add new overlay error: $e');
    }
  }

  void _addOverlayFromPreset(TextPreset preset) {
    try {
      final defaultDuration = widget.videoDuration > const Duration(seconds: 5)
          ? const Duration(seconds: 5)
          : widget.videoDuration;

      final newOverlay = TextOverlay(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: 'Your Text',
        style: preset.style,
        animation: preset.animation,
        startTime: Duration.zero,
        endTime: defaultDuration,
      );

      _textController.text = newOverlay.text;

      setState(() {
        _editingOverlay = newOverlay;
        _editingIndex = null;
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('❌ Add from preset error: $e');
    }
  }

  void _editOverlay(TextOverlay overlay, int index) {
    try {
      _textController.text = overlay.text;

      setState(() {
        _editingOverlay = overlay;
        _editingIndex = index;
      });
    } catch (e) {
      debugPrint('❌ Edit overlay error: $e');
    }
  }

  void _saveOverlay() {
    try {
      if (_editingOverlay == null) return;

      final newList = List<TextOverlay>.from(widget.overlays);

      if (_editingIndex != null && _editingIndex! < newList.length) {
        // Update existing
        newList[_editingIndex!] = _editingOverlay!;
      } else {
        // Add new
        newList.add(_editingOverlay!);
      }

      widget.onOverlaysChanged(newList);

      setState(() {
        _editingOverlay = null;
        _editingIndex = null;
      });

      _textController.clear();
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('❌ Save overlay error: $e');
    }
  }

  void _deleteOverlay(int index) {
    try {
      if (index < 0 || index >= widget.overlays.length) return;

      final newList = List<TextOverlay>.from(widget.overlays);
      newList.removeAt(index);
      widget.onOverlaysChanged(newList);

      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('❌ Delete overlay error: $e');
    }
  }

  void _reorderOverlays(int oldIndex, int newIndex) {
    try {
      if (newIndex > oldIndex) newIndex--;

      final newList = List<TextOverlay>.from(widget.overlays);
      final item = newList.removeAt(oldIndex);
      newList.insert(newIndex, item);

      widget.onOverlaysChanged(newList);
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('❌ Reorder error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  String _formatDuration(Duration d) {
    try {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    } catch (e) {
      return '00:00';
    }
  }
}

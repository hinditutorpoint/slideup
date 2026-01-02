import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/video_player_provider.dart';
import '../services/video_edit_service.dart';
import '../services/thumbnail_service.dart';

class VideoEditorSheet extends ConsumerStatefulWidget {
  final String videoPath;
  final Duration videoDuration;
  final Function(String outputPath)? onExportComplete;
  final VoidCallback? onClose;

  const VideoEditorSheet({
    super.key,
    required this.videoPath,
    required this.videoDuration,
    this.onExportComplete,
    this.onClose,
  });

  @override
  ConsumerState<VideoEditorSheet> createState() => _VideoEditorSheetState();
}

class _VideoEditorSheetState extends ConsumerState<VideoEditorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Thumbnail
  final ThumbnailService _thumbnailService = ThumbnailService();
  List<Uint8List> _timelineThumbnails = [];
  bool _isLoadingThumbnails = false;
  Uint8List? _previewFrame;

  // Trim
  double _trimStartPercent = 0.0;
  double _trimEndPercent = 1.0;
  bool _isDraggingTrimStart = false;
  bool _isDraggingTrimEnd = false;

  // Color grading
  ColorGradeSettings _colorSettings = const ColorGradeSettings();
  bool _showColorPreview = false;
  Uint8List? _colorPreviewImage;

  // Processing
  bool _isProcessing = false;
  double _processProgress = 0.0;
  String _processMessage = '';

  // Clip markers
  final List<ClipMarker> _clipMarkers = [];

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeEditor();
  }

  Future<void> _initializeEditor() async {
    await _loadTimelineThumbnails();
    await _loadPreviewFrame();
  }

  Future<void> _loadTimelineThumbnails() async {
    if (_isLoadingThumbnails || _isDisposed) return;

    setState(() => _isLoadingThumbnails = true);

    try {
      final thumbnails = await _thumbnailService.generateTimelineThumbnails(
        videoPath: widget.videoPath,
        videoDuration: widget.videoDuration,
        count: 10,
        width: 120,
        height: 68,
      );

      if (!_isDisposed && mounted) {
        setState(() {
          _timelineThumbnails = thumbnails;
          _isLoadingThumbnails = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load thumbnails error: $e');
      if (!_isDisposed && mounted) {
        setState(() => _isLoadingThumbnails = false);
      }
    }
  }

  Future<void> _loadPreviewFrame() async {
    if (_isDisposed) return;

    try {
      final frame = await _thumbnailService.getThumbnailAtPosition(
        videoPath: widget.videoPath,
        position: _getTrimStartDuration(),
        width: 640,
        height: 360,
      );

      if (!_isDisposed && mounted) {
        setState(() => _previewFrame = frame);
      }
    } catch (e) {
      debugPrint('❌ Load preview frame error: $e');
    }
  }

  Duration _getTrimStartDuration() {
    return Duration(
      milliseconds: (widget.videoDuration.inMilliseconds * _trimStartPercent)
          .toInt(),
    );
  }

  Duration _getTrimEndDuration() {
    return Duration(
      milliseconds: (widget.videoDuration.inMilliseconds * _trimEndPercent)
          .toInt(),
    );
  }

  Duration get _trimDuration => _getTrimEndDuration() - _getTrimStartDuration();

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    _thumbnailService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          _buildHandleBar(),

          // Header
          _buildHeader(),

          // Preview
          _buildPreview(),

          // Tab bar
          _buildTabBar(),

          // Tab content
          Expanded(child: _buildTabContent()),

          // Bottom actions
          _buildBottomActions(),

          // Processing overlay
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white38,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              widget.onClose?.call();
              Navigator.pop(context);
            },
          ),
          const Expanded(
            child: Text(
              'Edit Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Duration badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
            ),
            child: Text(
              _formatDuration(_trimDuration),
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Preview image with color filter
            if (_previewFrame != null)
              ColorFiltered(
                colorFilter: _buildColorFilter(_colorSettings),
                child: Image.memory(
                  _previewFrame!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _buildPreviewPlaceholder(),
                ),
              )
            else
              _buildPreviewPlaceholder(),

            // Time overlay
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_formatDuration(_getTrimStartDuration())} - ${_formatDuration(_getTrimEndDuration())}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),

            // Refresh preview button
            Positioned(
              right: 8,
              bottom: 8,
              child: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  padding: const EdgeInsets.all(8),
                ),
                onPressed: _loadPreviewFrame,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(Icons.movie, color: Colors.white38, size: 48),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.red,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        tabs: const [
          Tab(icon: Icon(Icons.content_cut), text: 'Trim'),
          Tab(icon: Icon(Icons.palette), text: 'Color'),
          Tab(icon: Icon(Icons.bookmark), text: 'Clips'),
          Tab(icon: Icon(Icons.download), text: 'Export'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTrimTab(),
        _buildColorTab(),
        _buildClipsTab(),
        _buildExportTab(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ TRIM TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildTrimTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimeChip('Start', _getTrimStartDuration()),
              _buildTimeChip('End', _getTrimEndDuration()),
            ],
          ),

          const SizedBox(height: 16),

          // Timeline with thumbnails
          _buildTrimTimeline(),

          const SizedBox(height: 24),

          // Quick trim buttons
          const Text(
            'Quick Trim',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickTrimButton('First 30s', 0, 30),
              _buildQuickTrimButton('First 1m', 0, 60),
              _buildQuickTrimButton('Last 30s', -30, 0),
              _buildQuickTrimButton('Last 1m', -60, 0),
              _buildQuickTrimButton('Middle 50%', 25, 75),
              _buildQuickTrimButton('Reset', 0, 100),
            ],
          ),

          const SizedBox(height: 24),

          // Precise time input
          const Text(
            'Precise Trim',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeInputField(
                  'Start Time',
                  _getTrimStartDuration(),
                  (duration) {
                    final percent =
                        duration.inMilliseconds /
                        widget.videoDuration.inMilliseconds;
                    setState(() {
                      _trimStartPercent = percent.clamp(
                        0.0,
                        _trimEndPercent - 0.01,
                      );
                    });
                    _loadPreviewFrame();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimeInputField('End Time', _getTrimEndDuration(), (
                  duration,
                ) {
                  final percent =
                      duration.inMilliseconds /
                      widget.videoDuration.inMilliseconds;
                  setState(() {
                    _trimEndPercent = percent.clamp(
                      _trimStartPercent + 0.01,
                      1.0,
                    );
                  });
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, Duration time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            _formatDuration(time),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrimTimeline() {
    return SizedBox(
      height: 80,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final startX = width * _trimStartPercent;
          final endX = width * _trimEndPercent;

          return GestureDetector(
            onHorizontalDragStart: (details) {
              final x = details.localPosition.dx;
              if ((x - startX).abs() < 20) {
                setState(() => _isDraggingTrimStart = true);
              } else if ((x - endX).abs() < 20) {
                setState(() => _isDraggingTrimEnd = true);
              }
            },
            onHorizontalDragUpdate: (details) {
              final x = details.localPosition.dx;
              final percent = (x / width).clamp(0.0, 1.0);

              setState(() {
                if (_isDraggingTrimStart) {
                  _trimStartPercent = percent.clamp(
                    0.0,
                    _trimEndPercent - 0.05,
                  );
                } else if (_isDraggingTrimEnd) {
                  _trimEndPercent = percent.clamp(
                    _trimStartPercent + 0.05,
                    1.0,
                  );
                }
              });
            },
            onHorizontalDragEnd: (details) {
              setState(() {
                _isDraggingTrimStart = false;
                _isDraggingTrimEnd = false;
              });
              _loadPreviewFrame();
              HapticFeedback.lightImpact();
            },
            child: Stack(
              children: [
                // Thumbnails
                if (_timelineThumbnails.isNotEmpty)
                  Row(
                    children: _timelineThumbnails.map((thumb) {
                      return Expanded(
                        child: Image.memory(
                          thumb,
                          fit: BoxFit.cover,
                          height: 60,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey[800]),
                        ),
                      );
                    }).toList(),
                  )
                else if (_isLoadingThumbnails)
                  Container(
                    height: 60,
                    color: Colors.grey[800],
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  )
                else
                  Container(height: 60, color: Colors.grey[800]),

                // Dimmed areas
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: startX,
                  child: Container(color: Colors.black54),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: width - endX,
                  child: Container(color: Colors.black54),
                ),

                // Selection border
                Positioned(
                  left: startX,
                  right: width - endX,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.yellow, width: 3),
                    ),
                  ),
                ),

                // Start handle
                Positioned(
                  left: startX - 12,
                  top: 0,
                  bottom: 0,
                  child: _buildTrimHandle(
                    isStart: true,
                    isActive: _isDraggingTrimStart,
                  ),
                ),

                // End handle
                Positioned(
                  left: endX - 12,
                  top: 0,
                  bottom: 0,
                  child: _buildTrimHandle(
                    isStart: false,
                    isActive: _isDraggingTrimEnd,
                  ),
                ),

                // Time indicator at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 20,
                    color: Colors.black54,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '0:00',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(widget.videoDuration),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrimHandle({required bool isStart, required bool isActive}) {
    return Container(
      width: 24,
      decoration: BoxDecoration(
        color: isActive ? Colors.yellow : Colors.yellow.withValues(alpha: 0.9),
        borderRadius: BorderRadius.horizontal(
          left: isStart ? const Radius.circular(4) : Radius.zero,
          right: !isStart ? const Radius.circular(4) : Radius.zero,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.yellow.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: const Icon(Icons.drag_handle, color: Colors.black, size: 16),
    );
  }

  Widget _buildQuickTrimButton(String label, int startOffset, int endOffset) {
    return OutlinedButton(
      onPressed: () {
        final totalSeconds = widget.videoDuration.inSeconds;

        double start, end;

        if (startOffset < 0) {
          // From end
          start = ((totalSeconds + startOffset) / totalSeconds).clamp(0.0, 1.0);
          end = 1.0;
        } else if (endOffset == 0) {
          start = 0.0;
          end = 1.0;
        } else if (label == 'Reset') {
          start = 0.0;
          end = 1.0;
        } else if (startOffset == 25) {
          // Middle 50%
          start = 0.25;
          end = 0.75;
        } else {
          start = 0.0;
          end = (endOffset / totalSeconds).clamp(0.0, 1.0);
        }

        setState(() {
          _trimStartPercent = start;
          _trimEndPercent = end;
        });
        _loadPreviewFrame();
        HapticFeedback.selectionClick();
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildTimeInputField(
    String label,
    Duration currentValue,
    Function(Duration) onChanged,
  ) {
    final controller = TextEditingController(
      text: _formatDuration(currentValue),
    );

    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      keyboardType: TextInputType.datetime,
      onSubmitted: (value) {
        final parsed = _parseDuration(value);
        if (parsed != null) {
          onChanged(parsed);
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ COLOR TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildColorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Presets
          const Text(
            'Presets',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ColorPreset.defaultPresets.length,
              itemBuilder: (context, index) {
                final preset = ColorPreset.defaultPresets[index];
                final isSelected = _colorSettings == preset.settings;

                return GestureDetector(
                  onTap: () {
                    setState(() => _colorSettings = preset.settings);
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.red : Colors.white24,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getPresetColor(preset.settings),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.palette,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset.name,
                          style: TextStyle(
                            color: isSelected ? Colors.red : Colors.white,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Manual adjustments
          const Text(
            'Light',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildColorSlider(
            'Brightness',
            _colorSettings.brightness,
            -1.0,
            1.0,
            (v) {
              setState(
                () => _colorSettings = _colorSettings.copyWith(brightness: v),
              );
            },
          ),
          _buildColorSlider('Contrast', _colorSettings.contrast, 0.0, 2.0, (v) {
            setState(
              () => _colorSettings = _colorSettings.copyWith(contrast: v),
            );
          }),
          _buildColorSlider(
            'Highlights',
            _colorSettings.highlights,
            -1.0,
            1.0,
            (v) {
              setState(
                () => _colorSettings = _colorSettings.copyWith(highlights: v),
              );
            },
          ),
          _buildColorSlider('Shadows', _colorSettings.shadows, -1.0, 1.0, (v) {
            setState(
              () => _colorSettings = _colorSettings.copyWith(shadows: v),
            );
          }),

          const SizedBox(height: 24),

          const Text(
            'Color',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildColorSlider('Saturation', _colorSettings.saturation, 0.0, 2.0, (
            v,
          ) {
            setState(
              () => _colorSettings = _colorSettings.copyWith(saturation: v),
            );
          }),
          _buildColorSlider('Hue', _colorSettings.hue, -180.0, 180.0, (v) {
            setState(() => _colorSettings = _colorSettings.copyWith(hue: v));
          }),
          _buildColorSlider(
            'Temperature',
            _colorSettings.temperature,
            -100.0,
            100.0,
            (v) {
              setState(
                () => _colorSettings = _colorSettings.copyWith(temperature: v),
              );
            },
            activeColor: Colors.orange,
          ),
          _buildColorSlider('Vibrance', _colorSettings.vibrance, -1.0, 1.0, (
            v,
          ) {
            setState(
              () => _colorSettings = _colorSettings.copyWith(vibrance: v),
            );
          }),

          const SizedBox(height: 24),

          const Text(
            'RGB Channels',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildColorSlider('Red', _colorSettings.red, 0.0, 2.0, (v) {
            setState(() => _colorSettings = _colorSettings.copyWith(red: v));
          }, activeColor: Colors.red),
          _buildColorSlider('Green', _colorSettings.green, 0.0, 2.0, (v) {
            setState(() => _colorSettings = _colorSettings.copyWith(green: v));
          }, activeColor: Colors.green),
          _buildColorSlider('Blue', _colorSettings.blue, 0.0, 2.0, (v) {
            setState(() => _colorSettings = _colorSettings.copyWith(blue: v));
          }, activeColor: Colors.blue),

          const SizedBox(height: 24),

          // Reset button
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _colorSettings = const ColorGradeSettings());
                HapticFeedback.mediumImpact();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset All'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged, {
    Color? activeColor,
  }) {
    final defaultValue = _getDefaultValue(label);
    final isDefault = (value - defaultValue).abs() < 0.01;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: isDefault ? Colors.grey[400] : Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: activeColor ?? Colors.red,
                inactiveTrackColor: Colors.white24,
                thumbColor: activeColor ?? Colors.red,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              value.toStringAsFixed(1),
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
          // Reset individual
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: 16,
              color: isDefault ? Colors.grey[700] : Colors.grey[400],
            ),
            onPressed: isDefault
                ? null
                : () {
                    onChanged(defaultValue);
                    HapticFeedback.selectionClick();
                  },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  double _getDefaultValue(String label) {
    switch (label) {
      case 'Contrast':
      case 'Saturation':
      case 'Red':
      case 'Green':
      case 'Blue':
        return 1.0;
      default:
        return 0.0;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CLIPS TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildClipsTab() {
    return Column(
      children: [
        // Add clip button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _addClipMarker,
            icon: const Icon(Icons.add),
            label: const Text('Add Current Selection as Clip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),

        // Clip list
        Expanded(
          child: _clipMarkers.isEmpty
              ? _buildEmptyClipsState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _clipMarkers.length,
                  itemBuilder: (context, index) {
                    final clip = _clipMarkers[index];
                    return _buildClipCard(clip, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyClipsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, color: Colors.grey[600], size: 64),
          const SizedBox(height: 16),
          Text(
            'No clips added yet',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Set trim points and tap "Add Clip"',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildClipCard(ClipMarker clip, int index) {
    return Card(
      color: Colors.white.withValues(alpha: 0.1),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail placeholder
            Container(
              width: 80,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.movie, color: Colors.white38),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clip.label ?? 'Clip ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDuration(clip.startTime)} → ${_formatDuration(clip.endTime)}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  Text(
                    'Duration: ${_formatDuration(clip.duration)}',
                    style: const TextStyle(color: Colors.yellow, fontSize: 12),
                  ),
                  if (clip.colorGrade != null && !clip.colorGrade!.isDefault)
                    Row(
                      children: [
                        Icon(
                          Icons.palette,
                          color: Colors.purple[300],
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Color graded',
                          style: TextStyle(
                            color: Colors.purple[300],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  onPressed: () => _previewClip(clip),
                  tooltip: 'Preview',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeClip(index),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addClipMarker() {
    final clip = ClipMarker(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: _getTrimStartDuration(),
      endTime: _getTrimEndDuration(),
      label: 'Clip ${_clipMarkers.length + 1}',
      colorGrade: _colorSettings.isDefault ? null : _colorSettings,
    );

    setState(() => _clipMarkers.add(clip));
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Clip added: ${_formatDuration(clip.duration)}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeClip(int index) {
    setState(() => _clipMarkers.removeAt(index));
    HapticFeedback.lightImpact();
  }

  void _previewClip(ClipMarker clip) {
    // Seek to clip start in player
    try {
      ref.read(videoPlayerProvider.notifier).seek(clip.startTime);
      ref.read(videoPlayerProvider.notifier).play();
      Navigator.pop(context);
    } catch (e) {
      debugPrint('⚠️ Preview clip error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXPORT TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Export trimmed video
          _buildExportOption(
            icon: Icons.content_cut,
            title: 'Export Trimmed Video',
            subtitle: 'Save ${_formatDuration(_trimDuration)} of video',
            onTap: _exportTrimmedVideo,
          ),

          const SizedBox(height: 12),

          // Export with color grading
          _buildExportOption(
            icon: Icons.palette,
            title: 'Export with Color Grading',
            subtitle: _colorSettings.isDefault
                ? 'No color changes applied'
                : 'Apply current color settings',
            enabled: !_colorSettings.isDefault,
            onTap: _exportWithColorGrading,
          ),

          const SizedBox(height: 12),

          // Export all clips
          _buildExportOption(
            icon: Icons.bookmark,
            title: 'Export All Clips',
            subtitle: '${_clipMarkers.length} clips',
            enabled: _clipMarkers.isNotEmpty,
            onTap: _exportAllClips,
          ),

          const Divider(color: Colors.white24, height: 32),

          // Extract audio
          _buildExportOption(
            icon: Icons.music_note,
            title: 'Extract Audio',
            subtitle: 'Save audio as MP3',
            onTap: _extractAudio,
          ),

          const SizedBox(height: 12),

          // Extract frames
          _buildExportOption(
            icon: Icons.photo_library,
            title: 'Extract Frames',
            subtitle: 'Save frames as images',
            onTap: _extractFrames,
          ),

          const SizedBox(height: 12),

          // Take screenshot
          _buildExportOption(
            icon: Icons.camera_alt,
            title: 'Take Screenshot',
            subtitle: 'Save current frame',
            onTap: _takeScreenshot,
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: enabled
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: enabled ? Colors.red : Colors.grey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: enabled ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: enabled ? Colors.white38 : Colors.grey[700],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BOTTOM ACTIONS
  // ═══════════════════════════════════════════════════════

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  widget.onClose?.call();
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _exportTrimmedVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Export Video'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PROCESSING OVERLAY
  // ═══════════════════════════════════════════════════════

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: _processProgress > 0 ? _processProgress : null,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            Text(
              _processMessage,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (_processProgress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${(_processProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _cancelProcessing,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ EXPORT METHODS
  // ═══════════════════════════════════════════════════════

  Future<void> _exportTrimmedVideo() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _processProgress = 0;
      _processMessage = 'Trimming video...';
    });

    try {
      final editService = VideoEditService();

      final result = await editService.trimVideo(
        inputPath: widget.videoPath,
        startTime: _getTrimStartDuration(),
        endTime: _getTrimEndDuration(),
        onProgress: (progress) {
          if (mounted) {
            setState(() => _processProgress = progress);
          }
        },
      );

      if (result != null) {
        _showSuccess('Video exported: $result');
        widget.onExportComplete?.call(result);
      } else {
        _showError('Export failed');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _exportWithColorGrading() async {
    if (_isProcessing || _colorSettings.isDefault) return;

    setState(() {
      _isProcessing = true;
      _processProgress = 0;
      _processMessage = 'Applying color grading...';
    });

    try {
      final editService = VideoEditService();

      // First trim
      setState(() => _processMessage = 'Trimming video...');
      final trimmedPath = await editService.trimVideo(
        inputPath: widget.videoPath,
        startTime: _getTrimStartDuration(),
        endTime: _getTrimEndDuration(),
        onProgress: (p) {
          if (mounted) setState(() => _processProgress = p * 0.5);
        },
      );

      if (trimmedPath == null) {
        _showError('Trim failed');
        return;
      }

      // Then apply color grading
      setState(() => _processMessage = 'Applying color grading...');
      final result = await editService.applyColorGrading(
        inputPath: trimmedPath,
        settings: _colorSettings,
        onProgress: (p) {
          if (mounted) setState(() => _processProgress = 0.5 + p * 0.5);
        },
      );

      // Cleanup temp file
      try {
        await File(trimmedPath).delete();
      } catch (_) {}

      if (result != null) {
        _showSuccess('Video exported with color grading');
        widget.onExportComplete?.call(result);
      } else {
        _showError('Color grading failed');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _exportAllClips() async {
    if (_isProcessing || _clipMarkers.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _processProgress = 0;
      _processMessage = 'Exporting clips...';
    });

    try {
      final editService = VideoEditService();
      final exportedPaths = <String>[];

      for (int i = 0; i < _clipMarkers.length; i++) {
        final clip = _clipMarkers[i];
        setState(() {
          _processMessage = 'Exporting clip ${i + 1}/${_clipMarkers.length}...';
        });

        final result = await editService.createClipFromMarker(
          inputPath: widget.videoPath,
          marker: clip,
          onProgress: (p) {
            if (mounted) {
              final overallProgress = (i + p) / _clipMarkers.length;
              setState(() => _processProgress = overallProgress);
            }
          },
        );

        if (result != null) {
          exportedPaths.add(result);
        }
      }

      if (exportedPaths.isNotEmpty) {
        _showSuccess('Exported ${exportedPaths.length} clips');
      } else {
        _showError('No clips exported');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _extractAudio() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _processProgress = 0;
      _processMessage = 'Extracting audio...';
    });

    try {
      final editService = VideoEditService();

      final result = await editService.extractAudio(
        inputPath: widget.videoPath,
        format: 'mp3',
        bitrate: 192,
        onProgress: (p) {
          if (mounted) setState(() => _processProgress = p);
        },
      );

      if (result != null) {
        _showSuccess('Audio extracted: $result');
      } else {
        _showError('Audio extraction failed');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _extractFrames() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _processProgress = 0;
      _processMessage = 'Extracting frames...';
    });

    try {
      final editService = VideoEditService();

      final frames = await editService.extractFrames(
        inputPath: widget.videoPath,
        startTime: _getTrimStartDuration(),
        endTime: _getTrimEndDuration(),
        fps: 1,
        maxFrames: 30,
        onProgress: (p) {
          if (mounted) setState(() => _processProgress = p);
        },
      );

      if (frames.isNotEmpty) {
        _showSuccess('Extracted ${frames.length} frames');
      } else {
        _showError('No frames extracted');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _takeScreenshot() async {
    try {
      final screenshot = await ref
          .read(videoPlayerProvider.notifier)
          .takeScreenshot();

      if (screenshot != null) {
        _showSuccess('Screenshot saved');
      } else {
        _showError('Screenshot failed');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _cancelProcessing() {
    VideoEditService().cancelCurrentOperation();
    setState(() => _isProcessing = false);
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Duration? _parseDuration(String value) {
    try {
      final parts = value.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return Duration(minutes: minutes, seconds: seconds);
      } else if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    } catch (e) {
      debugPrint('⚠️ Parse duration error: $e');
    }
    return null;
  }

  ColorFilter _buildColorFilter(ColorGradeSettings settings) {
    final matrix = <double>[
      settings.red * settings.contrast,
      0,
      0,
      0,
      settings.brightness * 50,
      0,
      settings.green * settings.contrast,
      0,
      0,
      settings.brightness * 50,
      0,
      0,
      settings.blue * settings.contrast,
      0,
      settings.brightness * 50,
      0,
      0,
      0,
      1,
      0,
    ];
    return ColorFilter.matrix(matrix);
  }

  Color _getPresetColor(ColorGradeSettings settings) {
    final hue = (settings.hue + 180) / 360;
    final saturation = settings.saturation.clamp(0.3, 1.0);
    final brightness = (settings.brightness + 1) / 2 * 0.5 + 0.25;
    return HSVColor.fromAHSV(1.0, hue * 360, saturation, brightness).toColor();
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// sheets/text_sheet.dart - FIXED VERSION with Position Presets
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video_edit_settings.dart';
import '../providers/providers.dart';

// ═══════════════════════════════════════════════════════
// ✅ POSITION PRESET ENUM
// ═══════════════════════════════════════════════════════

enum PositionPreset {
  topLeft(0.15, 0.12, 'Top Left', Icons.north_west),
  topCenter(0.5, 0.12, 'Top', Icons.north),
  topRight(0.85, 0.12, 'Top Right', Icons.north_east),
  centerLeft(0.15, 0.5, 'Left', Icons.west),
  center(0.5, 0.5, 'Center', Icons.center_focus_strong),
  centerRight(0.85, 0.5, 'Right', Icons.east),
  bottomLeft(0.15, 0.88, 'Bottom Left', Icons.south_west),
  bottomCenter(0.5, 0.88, 'Bottom', Icons.south),
  bottomRight(0.85, 0.88, 'Bottom Right', Icons.south_east);

  final double x;
  final double y;
  final String label;
  final IconData icon;

  const PositionPreset(this.x, this.y, this.label, this.icon);
}

// ═══════════════════════════════════════════════════════
// ✅ TEXT SHEET (YouCut Style)
// ═══════════════════════════════════════════════════════

class TextSheet extends ConsumerStatefulWidget {
  const TextSheet({super.key});

  @override
  ConsumerState<TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends ConsumerState<TextSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  late TabController _tabController;

  // Text settings
  PositionPreset _selectedPosition = PositionPreset.center;
  double _fontSize = 32;
  Color _textColor = Colors.white;
  final Color _backgroundColor = Colors.transparent;
  bool _isBold = false;
  bool _isItalic = false;
  bool _hasShadow = true;
  int _durationSeconds = 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textItems = ref.watch(textItemsProvider);
    final currentProject = ref.watch(currentProjectProvider);
    final videoDuration = currentProject?.videoDuration ?? Duration.zero;
    final currentPosition = ref.watch(currentPositionProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          _buildHeader(),

          // Tabs
          _buildTabs(),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Add Tab
                _buildAddTab(currentPosition, videoDuration),

                // Manage Tab
                _buildManageTab(textItems, videoDuration),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HEADER
  // ═══════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.text_fields, color: Color(0xFFFF9800), size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Text Overlay',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFFFF9800),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: 'Add New'),
          Tab(text: 'Manage'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ADD TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildAddTab(Duration currentPosition, Duration videoDuration) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current time indicator
          _buildTimeIndicator(currentPosition),
          const SizedBox(height: 20),

          // Text input
          _buildTextInput(),
          const SizedBox(height: 20),

          // Position presets
          _buildPositionSection(),
          const SizedBox(height: 20),

          // Duration
          _buildDurationSection(),
          const SizedBox(height: 20),

          // Style section
          _buildStyleSection(),
          const SizedBox(height: 20),

          // Color section
          _buildColorSection(),
          const SizedBox(height: 20),

          // Preview
          _buildPreview(),
          const SizedBox(height: 24),

          // Quick presets
          _buildPresetsSection(),
          const SizedBox(height: 24),

          // Add button
          _buildAddButton(currentPosition),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTimeIndicator(Duration currentPosition) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF9800).withValues(alpha: 0.15),
            const Color(0xFFFF9800).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF9800).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 20, color: Color(0xFFFF9800)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Text will appear at',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              Text(
                _formatDuration(currentPosition),
                style: const TextStyle(
                  color: Color(0xFFFF9800),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Duration: ${_durationSeconds}s',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Text Content',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _textController,
          focusNode: _textFocusNode,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Enter your text here...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF9800), width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
            suffixIcon: _textController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38),
                    onPressed: () {
                      _textController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ POSITION SECTION - 9 POSITION GRID
  // ═══════════════════════════════════════════════════════

  Widget _buildPositionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Position',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _selectedPosition.label,
                style: const TextStyle(
                  color: Color(0xFFFF9800),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              // Top row
              Row(
                children: [
                  _buildPositionButton(PositionPreset.topLeft),
                  _buildPositionButton(PositionPreset.topCenter),
                  _buildPositionButton(PositionPreset.topRight),
                ],
              ),
              // Center row
              Row(
                children: [
                  _buildPositionButton(PositionPreset.centerLeft),
                  _buildPositionButton(PositionPreset.center),
                  _buildPositionButton(PositionPreset.centerRight),
                ],
              ),
              // Bottom row
              Row(
                children: [
                  _buildPositionButton(PositionPreset.bottomLeft),
                  _buildPositionButton(PositionPreset.bottomCenter),
                  _buildPositionButton(PositionPreset.bottomRight),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPositionButton(PositionPreset preset) {
    final isSelected = _selectedPosition == preset;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPosition = preset);
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFF9800)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFF9800)
                  : Colors.white.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            preset.icon,
            size: 20,
            color: isSelected ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Duration',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFFFF9800),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  thumbColor: const Color(0xFFFF9800),
                  overlayColor: const Color(0xFFFF9800).withValues(alpha: 0.2),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _durationSeconds.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: (v) =>
                      setState(() => _durationSeconds = v.round()),
                ),
              ),
            ),
            Container(
              width: 60,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_durationSeconds}s',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStyleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Style',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Font size
        Row(
          children: [
            const Icon(Icons.format_size, size: 18, color: Colors.white54),
            const SizedBox(width: 8),
            const Text('Size:', style: TextStyle(color: Colors.white70)),
            Expanded(
              child: Slider(
                value: _fontSize,
                min: 16,
                max: 72,
                activeColor: const Color(0xFFFF9800),
                inactiveColor: Colors.white.withValues(alpha: 0.1),
                onChanged: (v) => setState(() => _fontSize = v),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${_fontSize.round()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Style toggles
        Row(
          children: [
            _buildStyleToggle(
              icon: Icons.format_bold,
              label: 'Bold',
              isSelected: _isBold,
              onTap: () => setState(() => _isBold = !_isBold),
            ),
            const SizedBox(width: 8),
            _buildStyleToggle(
              icon: Icons.format_italic,
              label: 'Italic',
              isSelected: _isItalic,
              onTap: () => setState(() => _isItalic = !_isItalic),
            ),
            const SizedBox(width: 8),
            _buildStyleToggle(
              icon: Icons.blur_on,
              label: 'Shadow',
              isSelected: _hasShadow,
              onTap: () => setState(() => _hasShadow = !_hasShadow),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStyleToggle({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFF9800).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFF9800)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFFFF9800) : Colors.white54,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? const Color(0xFFFF9800) : Colors.white54,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorSection() {
    final colors = [
      Colors.white,
      Colors.black,
      const Color(0xFFFF5252),
      const Color(0xFFFF9800),
      const Color(0xFFFFEB3B),
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Text Color',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((color) => _buildColorButton(color)).toList(),
        ),
      ],
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _textColor == color;

    return GestureDetector(
      onTap: () {
        setState(() => _textColor = color);
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)]
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 20,
                color: color == Colors.white || color == Colors.yellow
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }

  Widget _buildPreview() {
    final text = _textController.text.isEmpty
        ? 'Sample Text'
        : _textController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Stack(
            children: [
              // Position indicator dots
              ...PositionPreset.values.map((preset) {
                return Positioned(
                  left: preset.x * (MediaQuery.of(context).size.width - 80) - 3,
                  top: preset.y * 100 - 3,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: preset == _selectedPosition
                          ? const Color(0xFFFF9800)
                          : Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),

              // Text preview
              Positioned(
                left:
                    _selectedPosition.x *
                        (MediaQuery.of(context).size.width - 80) -
                    50,
                top: _selectedPosition.y * 100 - 15,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width - 100,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: _fontSize * 0.4,
                      color: _textColor,
                      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                      fontStyle: _isItalic
                          ? FontStyle.italic
                          : FontStyle.normal,
                      shadows: _hasShadow
                          ? [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ PRESETS SECTION
  // ═══════════════════════════════════════════════════════

  Widget _buildPresetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Presets',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: TextPreset.defaultPresets.length,
            itemBuilder: (context, index) {
              final preset = TextPreset.defaultPresets[index];
              return _buildPresetCard(preset);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPresetCard(TextPreset preset) {
    final style = preset.style;

    return GestureDetector(
      onTap: () {
        setState(() {
          _fontSize = style.fontSize;
          _textColor = Color(style.color);
          _isBold = style.bold;
          _isItalic = style.italic;
          _hasShadow = style.shadowBlur > 0;
          if (_textController.text.isEmpty) {
            _textController.text = preset.name;
          }
        });
        HapticFeedback.selectionClick();
      },
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(style.color).withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              preset.iconEmoji ?? 'Aa',
              style: TextStyle(
                fontSize: 24,
                color: Color(style.color),
                fontWeight: style.bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              preset.name,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(Duration currentPosition) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () => _addText(currentPosition),
        icon: const Icon(Icons.add, size: 22),
        label: const Text(
          'Add Text',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF9800),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
          shadowColor: const Color(0xFFFF9800).withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MANAGE TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildManageTab(List<TextTimelineItem> items, Duration videoDuration) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline visualization
          if (items.isNotEmpty && videoDuration != Duration.zero) ...[
            _buildTimelineSection(items, videoDuration),
            const SizedBox(height: 24),
          ],

          // Text items list
          _buildTextItemsSection(items),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(
    List<TextTimelineItem> items,
    Duration videoDuration,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Timeline',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'Total: ${_formatDuration(videoDuration)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          clipBehavior: Clip.hardEdge,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final totalMs = videoDuration.inMilliseconds.toDouble();

              if (totalMs <= 0) return const SizedBox.shrink();

              return Stack(
                children: [
                  _buildTimeMarkers(width, videoDuration),
                  ...items.asMap().entries.map((entry) {
                    return _buildTimelineBar(
                      entry.value,
                      entry.key,
                      width,
                      totalMs,
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeMarkers(double width, Duration duration) {
    return Positioned.fill(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) {
          final time = Duration(
            milliseconds: ((duration.inMilliseconds / 5) * i).toInt(),
          );
          return Column(
            children: [
              Expanded(
                child: Container(
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _formatDuration(time),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTimelineBar(
    TextTimelineItem item,
    int index,
    double width,
    double totalMs,
  ) {
    final startX = (item.startTime.inMilliseconds / totalMs) * width;
    final endX = (item.endTime.inMilliseconds / totalMs) * width;
    final maxW = (width - startX).clamp(0.0, double.infinity);
    final barWidth = (endX - startX).clamp(20.0, maxW < 20.0 ? 20.0 : maxW);
    final color = _getItemColor(index);

    return Positioned(
      left: startX.clamp(0, width - 20),
      top: 18 + (index % 3) * 18.0,
      child: GestureDetector(
        onTap: () => _selectTextItem(item.id),
        child: Container(
          width: barWidth,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.6)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: barWidth > 50
              ? Text(
                  _truncateText(item.text, 8),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildTextItemsSection(List<TextTimelineItem> items) {
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Text Overlays',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${items.length}',
                style: const TextStyle(
                  color: Color(0xFFFF9800),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.asMap().entries.map((entry) {
          return _buildTextItemCard(entry.value, entry.key);
        }),
      ],
    );
  }

  Widget _buildTextItemCard(TextTimelineItem item, int index) {
    final selectedItemId = ref.watch(selectedItemProvider)?.id;
    final isSelected = selectedItemId == item.id;
    final color = _getItemColor(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? color : color.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectTextItem(item.id),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Color indicator
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.text.isEmpty ? 'Empty text' : item.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDuration(item.startTime)} - ${_formatDuration(item.endTime)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  color: Colors.white54,
                  onPressed: () => _duplicateTextItem(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Colors.red.withValues(alpha: 0.7),
                  onPressed: () => _deleteTextItem(item.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.text_fields_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Text(
              'No text overlays yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go to "Add New" tab to add text',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
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

  void _addText(Duration currentPosition) {
    final text = _textController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white),
              SizedBox(width: 8),
              Text('Please enter some text'),
            ],
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    // Use safe clamped position values
    final safeX = _selectedPosition.x.clamp(0.05, 0.95);
    final safeY = _selectedPosition.y.clamp(0.05, 0.95);

    ref
        .read(timelineProvider.notifier)
        .addTextItem(
          text: text,
          startTime: currentPosition,
          duration: Duration(seconds: _durationSeconds),
          style: TextOverlayStyle(
            fontSize: _fontSize,
            color: _textColor.toARGB32(),
            bold: _isBold,
            italic: _isItalic,
            shadowBlur: _hasShadow ? 4 : 0,
            shadowColor: 0x80000000,
          ),
          x: safeX,
          y: safeY,
        );

    _textController.clear();
    HapticFeedback.mediumImpact();

    // Switch to manage tab
    _tabController.animateTo(1);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Text added at ${_formatDuration(currentPosition)}'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
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
    return '${text.substring(0, maxLength)}…';
  }

  Color _getItemColor(int index) {
    const colors = [
      Color(0xFFFF9800),
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
      Color(0xFF9C27B0),
      Color(0xFFE91E63),
      Color(0xFF00BCD4),
      Color(0xFFFFC107),
      Color(0xFF009688),
    ];
    return colors[index % colors.length];
  }
}

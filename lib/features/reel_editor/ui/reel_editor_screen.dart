import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/preview_engine.dart';
import '../models/canvas_preset.dart';
import '../providers/canvas_provider.dart';
import '../providers/playback_provider.dart';
import '../providers/history_provider.dart';
import 'canvas/canvas_editor.dart';
import 'preview/preview_canvas.dart';
import 'panels/properties_panel.dart';

/// Unified editor shell md:799-830 — phone/tablet/landscape responsive, zero overflow md:94-142
/// Mode fits both reel (9:16 default) and generic video editor via canvas preset
enum EditorMode { reel, video }

class ReelEditorScreen extends ConsumerStatefulWidget {
  final EditorMode mode;
  final String? videoPath;
  const ReelEditorScreen({super.key, this.mode = EditorMode.reel, this.videoPath});

  @override
  ConsumerState<ReelEditorScreen> createState() => _ReelEditorScreenState();
}

class _ReelEditorScreenState extends ConsumerState<ReelEditorScreen> {
  late final PreviewEngine _engine;
  static const double _topBarH = 44;
  static const double _controlsH = 48;
  static const double _toolbarH = 60;

  @override
  void initState() {
    super.initState();
    _engine = PreviewEngine();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (widget.videoPath != null) {
      try { await _engine.load(widget.videoPath!); if (mounted) setState(() {}); } catch (e) { debugPrint('load failed: $e'); }
    }
    // default canvas per mode
    if (widget.mode == EditorMode.video) {
      ref.read(canvasProvider.notifier).setPreset(CanvasPreset.landscape169);
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            return LayoutBuilder(
              builder: (context, c) {
                if (isLandscape) return _buildLandscape(c);
                return _buildPortrait(c);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPortrait(BoxConstraints c) {
    // Narrow phone: timeline bottom + properties as collapsible bottom panel md:28
    final isNarrow = c.maxWidth < 600;
    return Column(
      children: [
        SizedBox(height: _topBarH, child: _buildTopBar()),
        Expanded(child: CanvasEditor(engine: _engine)),
        SizedBox(height: _controlsH, child: _buildPlayback()),
        if (isNarrow)
          Container(
            height: 140,
            decoration: BoxDecoration(color: Colors.grey[900], border: Border(top: BorderSide(color: Colors.white10))),
            child: const PropertiesPanel(),
          ),
        SizedBox(height: _toolbarH, child: _buildToolbar()),
      ],
    );
  }

  Widget _buildLandscape(BoxConstraints c) {
    final isNarrow = c.maxWidth < 700;
    if (isNarrow) return _buildPortrait(c);
    // Wide: Row with right-side properties panel 300w md:28 — never overflow via Flexible
    return Column(
      children: [
        SizedBox(height: _topBarH, child: _buildTopBar()),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: PreviewCanvas(engine: _engine)),
              Container(
                width: 300,
                decoration: BoxDecoration(color: Colors.grey[900], border: Border(left: BorderSide(color: Colors.white10))),
                child: const PropertiesPanel(),
              ),
            ],
          ),
        ),
        SizedBox(height: _controlsH, child: _buildPlayback()),
        SizedBox(height: _toolbarH, child: _buildToolbar()),
      ],
    );
  }

  Widget _buildTopBar() {
    final canvas = ref.watch(canvasProvider);
    final history = ref.watch(historyProvider);
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20), onPressed: () => Navigator.maybePop(context), constraints: const BoxConstraints(minWidth: 40)),
          IconButton(icon: Icon(Icons.undo, size: 16, color: history.canUndo ? Colors.white : Colors.white24), onPressed: history.canUndo ? () => _undo() : null, constraints: const BoxConstraints(minWidth: 32)),
          IconButton(icon: Icon(Icons.redo, size: 16, color: history.canRedo ? Colors.white : Colors.white24), onPressed: history.canRedo ? () => _redo() : null, constraints: const BoxConstraints(minWidth: 32)),
          Expanded(child: Text(widget.mode == EditorMode.reel ? 'Reel Editor' : 'Video Editor', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          IconButton(icon: Icon(Icons.grid_on, size: 18, color: canvas.showGrid ? Colors.blue : Colors.white54), onPressed: () => ref.read(canvasProvider.notifier).toggleGrid(), constraints: const BoxConstraints(minWidth: 36)),
          IconButton(icon: Icon(Icons.crop, size: 18, color: canvas.showSafeArea ? Colors.blue : Colors.white54), onPressed: () => ref.read(canvasProvider.notifier).toggleSafeArea(), constraints: const BoxConstraints(minWidth: 36)),
        ],
      ),
    );
  }

  void _undo() {
    // History undo — project revert stub (wired via historyProvider)
    HapticFeedback.selectionClick();
  }

  void _redo() {
    HapticFeedback.selectionClick();
  }

  Widget _buildPlayback() {
    final playback = ref.watch(playbackProvider);
    return Container(
      color: Colors.grey[850],
      child: Row(
        children: [
          IconButton(icon: Icon(playback.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white), onPressed: () async {
            if (playback.isPlaying) { await _engine.pause(); } else { await _engine.play(); }
            ref.read(playbackProvider.notifier).setPlaying(!playback.isPlaying);
            HapticFeedback.selectionClick();
          }),
          Expanded(child: Slider(value: playback.position.inMilliseconds.toDouble().clamp(0, 10000), min: 0, max: 10000, onChanged: (v) { ref.read(playbackProvider.notifier).seekTo(Duration(milliseconds: v.round())); _engine.seekTo(Duration(milliseconds: v.round())); })),
          IconButton(icon: Icon(playback.isMuted ? Icons.volume_off : Icons.volume_up, size: 18, color: Colors.white70), onPressed: () { ref.read(playbackProvider.notifier).toggleMute(); _engine.setVolume(playback.isMuted ? 1 : 0); }),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    // horizontal scroll prevents overflow md:134
    return Container(
      color: Colors.grey[900],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _toolBtn(Icons.content_cut, 'Trim'),
            _toolBtn(Icons.text_fields, 'Text'),
            _toolBtn(Icons.image, 'Sticker'),
            _toolBtn(Icons.music_note, 'Audio'),
            _toolBtn(Icons.filter_alt, 'Filter'),
            _toolBtn(Icons.speed, 'Speed'),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: Colors.white70)), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54))],
      ),
    );
  }
}



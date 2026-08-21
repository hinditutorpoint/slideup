import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/preview_engine.dart';
import '../models/canvas_preset.dart';
import '../models/reel_project.dart';
import '../providers/canvas_provider.dart';
import '../providers/playback_provider.dart';
import '../providers/history_provider.dart';
import '../providers/timeline_provider.dart';
import '../providers/selection_provider.dart';
import '../core/validation/numeric_guard.dart';
import 'preview/preview_canvas.dart';
import 'sheets/text_sheet.dart';

enum EditorMode { reel, video }

enum _Tool { none, trim, text, sticker, audio, filter, speed }

class ReelEditorScreen extends ConsumerStatefulWidget {
  final EditorMode mode;
  final String? videoPath;
  const ReelEditorScreen({super.key, this.mode = EditorMode.reel, this.videoPath});
  @override ConsumerState<ReelEditorScreen> createState() => _ReelEditorScreenState();
}

class _ReelEditorScreenState extends ConsumerState<ReelEditorScreen>
    with SingleTickerProviderStateMixin {
  late final PreviewEngine _engine;
  late final AnimationController _panelCtrl;
  late final Animation<double> _panelAnim;
  _Tool _tool = _Tool.none;
  bool _loaded = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _engine = PreviewEngine();
    _panelCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _panelAnim = CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (widget.videoPath != null) {
      await _loadVideo(widget.videoPath!);
    }
    if (widget.mode == EditorMode.video) {
      ref.read(canvasProvider.notifier).setPreset(CanvasPreset.landscape169);
    }
  }

  Future<void> _loadVideo(String path) async {
    if (!mounted || _loading) return;
    setState(() { _loading = true; });
    try {
      await _engine.load(path);
      if (!mounted) return;

      // Set playback duration from engine
      ref.read(playbackProvider.notifier).setDuration(_engine.duration);

      // Create a ReelProject with this video track
      final track = ReelVideoTrack(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sourcePath: path,
        sourceDuration: _engine.duration,
        trimEnd: _engine.duration,
      );
      final project = ReelProject.create(
        'Reel ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      ).copyWith(videoTracks: [track]);

      // Load into timeline
      ref.read(reelTimelineProvider.notifier).loadProject(project);

      // Set canvas aspect ratio based on video
      if (_engine.controller != null) {
        final size = _engine.controller!.value.size;
        if (size.height > size.width) {
          ref.read(canvasProvider.notifier).setPreset(CanvasPreset.reel916);
        } else {
          ref.read(canvasProvider.notifier).setPreset(CanvasPreset.landscape169);
        }
      }

      setState(() { _loaded = true; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load video: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty || result.files.first.path == null) return;
      await _loadVideo(result.files.first.path!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick video: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  @override
  void dispose() { _engine.dispose(); _panelCtrl.dispose(); super.dispose(); }

  void _tap(_Tool t) {
    setState(() {
      if (_tool == t) { _tool = _Tool.none; _panelCtrl.reverse(); }
      else { _tool = t; _panelCtrl.forward(); }
    });
    HapticFeedback.selectionClick();
  }

  void _undo() {
    final h = ref.read(historyProvider.notifier);
    final hs = ref.read(historyProvider);
    final p = ref.read(reelTimelineProvider.notifier).project;
    if (hs.canUndo && p != null) { final prev = h.undo(p); if (prev != null) ref.read(reelTimelineProvider.notifier).loadProject(prev); }
    HapticFeedback.selectionClick();
  }

  void _redo() {
    final h = ref.read(historyProvider.notifier);
    final hs = ref.read(historyProvider);
    final p = ref.read(reelTimelineProvider.notifier).project;
    if (hs.canRedo && p != null) { final next = h.redo(p); if (next != null) ref.read(reelTimelineProvider.notifier).loadProject(next); }
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final ls = MediaQuery.of(context).orientation == Orientation.landscape;
    final tab = MediaQuery.of(context).size.shortestSide > 600;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(child: (ls && tab) ? _landscape() : _portrait()),
    );
  }

  Widget _portrait() => Column(children: [
    _TopBar(mode: widget.mode, onBack: () => Navigator.maybePop(context), onUndo: _undo, onRedo: _redo),
    Expanded(child: _canvas()),
    _Playback(engine: _engine),
    _Tabs(active: _tool, onTap: _tap),
    SizeTransition(sizeFactor: _panelAnim, axisAlignment: -1, child: _panel()),
    _Timeline(),
  ]);

  Widget _landscape() => Row(children: [
    Expanded(child: Column(children: [
      _TopBar(mode: widget.mode, onBack: () => Navigator.maybePop(context), onUndo: _undo, onRedo: _redo),
      Expanded(child: _canvas()),
      _Playback(engine: _engine),
      _Tabs(active: _tool, onTap: _tap),
    ])),
    AnimatedContainer(
      duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic,
      width: _tool != _Tool.none ? 280 : 0,
      decoration: const BoxDecoration(color: Color(0xFF141414), border: Border(left: BorderSide(color: Colors.white10))),
      child: _tool != _Tool.none ? _panel() : const SizedBox.shrink(),
    ),
  ]);

  Widget _canvas() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(128), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Stack(fit: StackFit.expand, children: [
        PreviewCanvas(engine: _engine),
        if (!_loaded && !_loading) _Empty(onImport: _pickVideo),
        if (_loading) Container(
          color: const Color(0xFF0A0A0A).withAlpha(200),
          child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF3B82F6))),
            SizedBox(height: 12),
            Text('Loading video...', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ])),
        ),
      ])),
    );
  }

  Widget _panel() {
    return Container(
      color: const Color(0xFF141414), constraints: const BoxConstraints(maxHeight: 200),
      child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12), child: switch (_tool) {
        _Tool.trim => _trimP(),
        _Tool.text => _textP(),
        _Tool.sticker => _stickerP(),
        _Tool.audio => _audioP(),
        _Tool.filter => _filterP(),
        _Tool.speed => _speedP(),
        _ => const SizedBox.shrink(),
      })),
    );
  }

  // ── Panels ──
  Widget _trimP() => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    const _PH('Trim & Split'), const SizedBox(height: 8),
    Row(children: [
      _PB(icon: Icons.content_cut_rounded, label: 'Split', onTap: () { ref.read(reelTimelineProvider.notifier).splitAtPlayhead(); HapticFeedback.mediumImpact(); }),
      const SizedBox(width: 8),
      _PB(icon: Icons.copy_rounded, label: 'Duplicate', onTap: () { final s = ref.read(selectionProvider).id; if (s != null) ref.read(reelTimelineProvider.notifier).duplicateClip(s); }),
      const SizedBox(width: 8),
      _PB(icon: Icons.delete_outline_rounded, label: 'Delete', color: const Color(0xFFEF4444), onTap: () { final s = ref.read(selectionProvider).id; if (s != null) ref.read(reelTimelineProvider.notifier).deleteClip(s); }),
    ]),
  ]);

  Widget _textP() => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    const _PH('Text'), const SizedBox(height: 8),
    Row(children: [_PB(icon: Icons.text_fields_rounded, label: 'Add text', onTap: () {
      Navigator.pop(context);
      showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1A1A1A), builder: (_) => const TextSheet());
    })]),
  ]);

  Widget _stickerP() => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    const _PH('Sticker'), const SizedBox(height: 8),
    Row(children: [_PB(icon: Icons.emoji_emotions_rounded, label: 'Add sticker', onTap: () {})]),
  ]);

  Widget _audioP() => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    const _PH('Audio'), const SizedBox(height: 8),
    Row(children: [_PB(icon: Icons.music_note_rounded, label: 'Add audio', onTap: () {})]),
  ]);

  Widget _filterP() => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    const _PH('Filter'), const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: ['None', 'Warm', 'Cool', 'Vintage', 'B&W', 'Vivid']
        .map((l) => _FC(l, selected: l == 'None', onTap: () {})).toList()),
  ]);

  Widget _speedP() {
    final sel = ref.watch(selectionProvider).id;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const _PH('Speed'), const SizedBox(height: 8),
      if (sel != null) _SpeedS(onChanged: (v) => ref.read(reelTimelineProvider.notifier).updateSpeed(sel, v))
      else const Text('Select a clip to adjust speed', style: TextStyle(color: Colors.white38, fontSize: 12)),
    ]);
  }
}

// ═══════ TOP BAR ═══════
class _TopBar extends ConsumerWidget {
  final EditorMode mode;
  final VoidCallback onBack, onUndo, onRedo;
  const _TopBar({required this.mode, required this.onBack, required this.onUndo, required this.onRedo});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(historyProvider);
    return Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 6), child: Row(children: [
      IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white70), onPressed: onBack, constraints: const BoxConstraints(minWidth: 40)),
      const SizedBox(width: 4),
      _UR(Icons.undo_rounded, h.canUndo, onUndo), _UR(Icons.redo_rounded, h.canRedo, onRedo),
      const Spacer(),
      Text(mode == EditorMode.reel ? 'Reel' : 'Video', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
      const Spacer(),
      GestureDetector(onTap: () {}, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]), borderRadius: BorderRadius.circular(8)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.upload_rounded, size: 15, color: Colors.white), SizedBox(width: 5), Text('Export', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))]),
      )),
    ]));
  }
}

class _UR extends StatelessWidget {
  final IconData icon; final bool on; final VoidCallback tap;
  const _UR(this.icon, this.on, this.tap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: on ? tap : null, child: Container(
    width: 32, height: 32, margin: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(color: on ? Colors.white.withAlpha(20) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
    child: Icon(icon, size: 18, color: on ? Colors.white70 : Colors.white24),
  ));
}

// ═══════ PLAYBACK ═══════
class _Playback extends ConsumerWidget {
  final PreviewEngine engine;
  const _Playback({required this.engine});
  String _f(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pb = ref.watch(playbackProvider);
    final dur = engine.duration;
    final maxMs = math.max(1.0, dur.inMilliseconds.toDouble());
    return Container(height: 44, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
      GestureDetector(onTap: () async {
        if (pb.isPlaying) { await engine.pause(); } else { await engine.play(); }
        ref.read(playbackProvider.notifier).setPlaying(!pb.isPlaying);
        HapticFeedback.lightImpact();
      }, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withAlpha(26), shape: BoxShape.circle),
        child: Icon(pb.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 22))),
      const SizedBox(width: 8),
      Text(_f(pb.position), style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
      Expanded(child: SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5), overlayShape: const RoundSliderOverlayShape(overlayRadius: 12), activeTrackColor: const Color(0xFF3B82F6), inactiveTrackColor: Colors.white12, thumbColor: Colors.white, overlayColor: Colors.white12),
        child: Slider(value: pb.position.inMilliseconds.toDouble(), min: 0.0, max: maxMs, onChanged: (v) { final p = Duration(milliseconds: v.round()); ref.read(playbackProvider.notifier).seekTo(p); engine.seekTo(p); }))),
      Text(_f(dur), style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
      const SizedBox(width: 4),
      GestureDetector(onTap: () { ref.read(playbackProvider.notifier).toggleMute(); engine.setVolume(pb.isMuted ? 1 : 0); },
        child: Icon(pb.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 18, color: Colors.white54)),
    ]));
  }
}

// ═══════ TOOL TABS ═══════
class _Tabs extends StatelessWidget {
  final _Tool active; final ValueChanged<_Tool> onTap;
  const _Tabs({required this.active, required this.onTap});
  static const _d = [(_Tool.trim, Icons.content_cut_rounded, 'Trim'), (_Tool.text, Icons.text_fields_rounded, 'Text'),
    (_Tool.sticker, Icons.emoji_emotions_rounded, 'Sticker'), (_Tool.audio, Icons.music_note_rounded, 'Audio'),
    (_Tool.filter, Icons.palette_rounded, 'Filter'), (_Tool.speed, Icons.speed_rounded, 'Speed')];
  @override
  Widget build(BuildContext context) => Container(height: 52, margin: const EdgeInsets.only(top: 4), child: ListView.separated(
    scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    itemCount: _d.length, separatorBuilder: (_, __) => const SizedBox(width: 6),
    itemBuilder: (_, i) { final (t, ic, lb) = _d[i]; final s = active == t; return GestureDetector(onTap: () => onTap(t),
      child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: s ? const Color(0xFF3B82F6).withAlpha(51) : Colors.white.withAlpha(15), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: s ? const Color(0xFF3B82F6).withAlpha(128) : Colors.white.withAlpha(20))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(ic, size: 16, color: s ? const Color(0xFF60A5FA) : Colors.white54),
          const SizedBox(width: 6), Text(lb, style: TextStyle(fontSize: 12, fontWeight: s ? FontWeight.w600 : FontWeight.w400, color: s ? const Color(0xFF60A5FA) : Colors.white54))]))); },
  ));
}

// ═══════ SHARED PANEL WIDGETS ═══════
class _PH extends StatelessWidget {
  final String title; const _PH(this.title);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
  ]);
}

class _PB extends StatelessWidget {
  final IconData icon; final String label; final Color? color; final VoidCallback onTap;
  const _PB({required this.icon, required this.label, this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white70;
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: c.withAlpha(26), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withAlpha(51))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: c), const SizedBox(width: 6), Text(label, style: TextStyle(color: c, fontSize: 12))]),
    ));
  }
}

class _FC extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _FC(this.label, {this.selected = false, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: selected ? const Color(0xFF3B82F6).withAlpha(64) : Colors.white.withAlpha(15), borderRadius: BorderRadius.circular(8), border: Border.all(color: selected ? const Color(0xFF3B82F6) : Colors.white12)),
    child: Text(label, style: TextStyle(fontSize: 12, color: selected ? const Color(0xFF60A5FA) : Colors.white54, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
  ));
}

class _SpeedS extends StatefulWidget {
  final ValueChanged<double> onChanged;
  const _SpeedS({required this.onChanged});
  @override State<_SpeedS> createState() => _SpeedSState();
}

class _SpeedSState extends State<_SpeedS> {
  double _v = 1.0;
  static const _p = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0];
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Row(children: [const Icon(Icons.speed_rounded, size: 14, color: Colors.white38), const SizedBox(width: 8),
      Text('${_v.toStringAsFixed(2)}x', style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'monospace'))]),
    SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), activeTrackColor: const Color(0xFF3B82F6), inactiveTrackColor: Colors.white12, thumbColor: Colors.white, overlayColor: Colors.white12),
      child: Slider(value: _v, min: 0.25, max: 4.0, onChanged: (v) => setState(() { _v = NumericGuard.sanitizeSpeed(v); widget.onChanged(_v); }))),
    Wrap(spacing: 6, runSpacing: 4, children: _p.map((e) { final s = (_v - e).abs() < 0.01; return GestureDetector(onTap: () => setState(() { _v = e; widget.onChanged(e); }),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: s ? const Color(0xFF3B82F6).withAlpha(64) : Colors.white.withAlpha(13), borderRadius: BorderRadius.circular(6)),
        child: Text('${e}x', style: TextStyle(fontSize: 10, color: s ? const Color(0xFF60A5FA) : Colors.white38)))); }).toList()),
  ]);
}

// ═══════ TIMELINE ═══════
class _Timeline extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tl = ref.watch(reelTimelineProvider);
    final proj = ref.read(reelTimelineProvider.notifier).project;
    if (proj == null || proj.videoTracks.isEmpty) {
      return Container(
        height: 48, margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
        child: const Center(child: Text('Add clips to start editing', style: TextStyle(color: Colors.white24, fontSize: 12))),
      );
    }
    final total = proj.computedDuration;
    final pos = tl.currentPosition;
    final frac = total.inMilliseconds > 0 ? (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0) : 0.0;
    return Container(
      height: 56, margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
      child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_fmt(pos), style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 10, fontFamily: 'monospace')),
          Text('${proj.videoTracks.length} clips', style: const TextStyle(color: Colors.white24, fontSize: 10)),
          Text(_fmt(total), style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
        ])),
        Expanded(child: LayoutBuilder(builder: (ctx, c) => GestureDetector(
          onTapDown: (d) { final x = d.localPosition.dx / c.maxWidth; ref.read(reelTimelineProvider.notifier).setPosition(Duration(milliseconds: (x * total.inMilliseconds).round())); },
          child: CustomPaint(size: Size(c.maxWidth, c.maxHeight), painter: _TP(tracks: proj.videoTracks, total: total, frac: frac)),
        ))),
      ]),
    );
  }
  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _TP extends CustomPainter {
  final List tracks; final Duration total; final double frac;
  _TP({required this.tracks, required this.total, required this.frac});
  @override
  void paint(Canvas canvas, Size size) {
    final cs = [const Color(0xFF2563EB), const Color(0xFF16A34A), const Color(0xFFD97706), const Color(0xFF9333EA)];
    final h = size.height / math.min(tracks.length, 4);
    for (int i = 0; i < tracks.length && i < 4; i++) {
      final t = tracks[i];
      final sf = t.startTime.inMilliseconds / math.max(1, total.inMilliseconds);
      final df = t.trimmedDuration.inMilliseconds / math.max(1, total.inMilliseconds);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(sf * size.width, i * h + 2, df * size.width, h - 4), const Radius.circular(4)),
        Paint()..color = cs[i % cs.length].withAlpha(77));
    }
    final x = frac * size.width;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()..color = const Color(0xFFEF4444)..strokeWidth = 2);
    canvas.drawPath(Path()..moveTo(x - 5, 0)..lineTo(x + 5, 0)..lineTo(x, 6)..close(), Paint()..color = const Color(0xFFEF4444));
  }
  @override bool shouldRepaint(covariant _TP o) => o.frac != frac;
}

// ═══════ EMPTY STATE ═══════
class _Empty extends StatelessWidget {
  final VoidCallback onImport;
  const _Empty({required this.onImport});
  @override
  Widget build(BuildContext context) => Container(color: const Color(0xFF0A0A0A), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 72, height: 72, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withAlpha(38), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF3B82F6).withAlpha(77))),
      child: const Icon(Icons.video_library_rounded, size: 32, color: Color(0xFF60A5FA))),
    const SizedBox(height: 16),
    const Text('No video loaded', style: TextStyle(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.w500)),
    const SizedBox(height: 6),
    const Text('Import a video to start editing', style: TextStyle(color: Colors.white24, fontSize: 12)),
    const SizedBox(height: 20),
    GestureDetector(onTap: onImport, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]), borderRadius: BorderRadius.circular(10)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.video_library_rounded, size: 16, color: Colors.white), SizedBox(width: 8), Text('Import Video', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))]),
    )),
  ])));
}



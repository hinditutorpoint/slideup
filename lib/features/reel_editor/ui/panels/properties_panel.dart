// ignore_for_file: prefer_interpolation_to_compose_strings, unnecessary_brace_in_string_interps
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/selection_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../providers/overlay_provider.dart';
import '../../providers/audio_provider.dart';
import '../../providers/filter_provider.dart';
import '../../core/validation/numeric_guard.dart';

/// Root right-side properties panel — context-sensitive per object md:40
/// Performance: watches only selection, not full project — avoids timeline rebuilds
/// Crash-safe: null guards, NumericGuard, mounted checks
/// RenderFlex-free: LayoutBuilder + ConstrainedBox + SingleChildScrollView + Wrap
class PropertiesPanel extends ConsumerWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectionProvider);
    if (sel.isNone) return const _CanvasProperties();

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 320.0;
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: w, minWidth: 0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: switch (sel.type) {
              ReelSelectionType.clip => _ClipProperties(id: sel.id!),
              ReelSelectionType.text => _TextProperties(id: sel.id!),
              ReelSelectionType.sticker => _StickerProperties(id: sel.id!),
              ReelSelectionType.overlay => _OverlayProperties(id: sel.id!),
              ReelSelectionType.audio => _AudioProperties(id: sel.id!),
              _ => const _CanvasProperties(),
            },
          ),
        );
      },
    );
  }
}

class _CanvasProperties extends ConsumerWidget {
  const _CanvasProperties();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Canvas', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Select an object to edit its properties', style: TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 12),
        const Text('Filters', style: TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ReelFilter.all.map((f) {
            final sel = filter.id == f.id;
            return ChoiceChip(
              label: Text(f.name, style: const TextStyle(fontSize: 10)),
              selected: sel,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                ref.read(filterProvider.notifier).select(f.id);
              },
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Clip ─────────────────────────────────────────────────────────
class _ClipProperties extends ConsumerStatefulWidget {
  final String id;
  const _ClipProperties({required this.id});
  @override
  ConsumerState<_ClipProperties> createState() => _ClipPropertiesState();
}

class _ClipPropertiesState extends ConsumerState<_ClipProperties> {
  @override
  Widget build(BuildContext context) {
    final proj = ref.watch(reelTimelineProvider.notifier).project;
    final clip = proj?.videoTracks.where((e) => e.id == widget.id).firstOrNull;
    if (clip == null) return const Text('Clip not found', style: TextStyle(color: Colors.white54, fontSize: 11));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header('Clip', widget.id, onDelete: () => ref.read(reelTimelineProvider.notifier).deleteClip(widget.id)),
        _sliderRow('Speed', clip.speed, 0.25, 4.0, (v) => ref.read(reelTimelineProvider.notifier).updateSpeed(widget.id, v)),
        _sliderRow('Volume', clip.volume, 0, 2.0, (v) => ref.read(reelTimelineProvider.notifier).updateVolume(widget.id, v)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _toggleChip('Flip H', clip.flipH, () => _updateFlip(clip.flipH, clip.flipV, true)),
            _toggleChip('Flip V', clip.flipV, () => _updateFlip(clip.flipH, clip.flipV, false)),
            _toggleChip('Mute', clip.mute, () => _updateMute(!clip.mute)),
          ],
        ),
        const SizedBox(height: 8),
        _rotationRow(clip.rotation, (r) => _updateRotation(r)),
        const SizedBox(height: 8),
        Text('Trim: ${clip.trimStart.inMilliseconds}ms → ${clip.trimEnd.inMilliseconds}ms', style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 4),
        Text('Duration: ${clip.trimmedDuration.inMilliseconds}ms @ ${clip.speed}x', style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _header(String title, String id, {VoidCallback? onDelete}) => Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
          if (onDelete != null)
            IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white54), onPressed: onDelete, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        ],
      );

  Widget _sliderRow(String label, double val, double min, double max, ValueChanged<double> onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))), Text(val.toStringAsFixed(2), style: const TextStyle(color: Colors.white54, fontSize: 10))]),
          Slider(value: val.clamp(min, max), min: min, max: max, divisions: 20, onChanged: (v) { HapticFeedback.selectionClick(); onChanged(NumericGuard.sanitizeDouble(v, min, max, val)); }),
        ],
      );

  Widget _toggleChip(String label, bool sel, VoidCallback onTap) => ChoiceChip(label: Text(label, style: const TextStyle(fontSize: 10)), selected: sel, onSelected: (_) { HapticFeedback.selectionClick(); onTap(); }, visualDensity: VisualDensity.compact);

  Widget _rotationRow(double rot, ValueChanged<double> onChanged) => Row(
        children: [
          const Text('Rotation', style: TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 4,
              children: [0, 90, 180, 270].map((d) => ChoiceChip(label: Text('${d}°', style: const TextStyle(fontSize: 10)), selected: rot == d.toDouble(), onSelected: (_) => onChanged(d.toDouble()), visualDensity: VisualDensity.compact)).toList(),
            ),
          ),
        ],
      );

  void _updateFlip(bool h, bool v, bool isH) {
    HapticFeedback.selectionClick();
    final n = ref.read(reelTimelineProvider.notifier);
    if (isH) {
      n.updateFlip(widget.id, flipH: !h);
    } else {
      n.updateFlip(widget.id, flipV: !v);
    }
  }

  void _updateMute(bool m) {
    HapticFeedback.selectionClick();
    ref.read(reelTimelineProvider.notifier).updateMute(widget.id, m);
  }

  void _updateRotation(double r) {
    HapticFeedback.selectionClick();
    ref.read(reelTimelineProvider.notifier).updateRotation(widget.id, r);
  }
}

// ── Text ─────────────────────────────────────────────────────────
class _TextProperties extends ConsumerWidget {
  final String id;
  const _TextProperties({required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proj = ref.watch(overlayProvider);
    final t = proj?.textLayers.where((e) => e.id == id).firstOrNull;
    if (t == null) return const Text('Text not found', style: TextStyle(color: Colors.white54, fontSize: 11));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Expanded(child: Text('Text', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))), IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white54), onPressed: () => ref.read(overlayProvider.notifier).deleteText(id), constraints: const BoxConstraints(minWidth: 28))]),
        const SizedBox(height: 6),
        Text(t.text, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        _slider('Opacity', t.opacity, 0, 1, (v) => ref.read(overlayProvider.notifier).updateText(id, opacity: v)),
        _slider('Scale', t.scale, 0.1, 10, (v) => ref.read(overlayProvider.notifier).updateText(id, scale: v)),
        _slider('Rotation', t.rotation, -180, 180, (v) => ref.read(overlayProvider.notifier).updateText(id, rotation: v)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final c in [0xFFFFFFFF, 0xFF000000, 0xFFe94560, 0xFF00ff00, 0xFF0066ff])
              GestureDetector(
                onTap: () => ref.read(overlayProvider.notifier).updateText(id, color: c),
                child: Container(width: 24, height: 24, decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: t.color == c ? Colors.blue : Colors.white24, width: t.color == c ? 2 : 1))),
              ),
          ],
        ),
      ],
    );
  }

  Widget _slider(String label, double val, double min, double max, ValueChanged<double> onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))), Text(val.toStringAsFixed(2), style: const TextStyle(color: Colors.white54, fontSize: 10))]),
          Slider(value: val.clamp(min, max), min: min, max: max, onChanged: (v) => onChanged(NumericGuard.sanitizeDouble(v, min, max, val))),
        ],
      );
}

// ── Sticker / Overlay ────────────────────────────────────────────
class _StickerProperties extends ConsumerWidget {
  final String id;
  const _StickerProperties({required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proj = ref.watch(overlayProvider);
    final s = proj?.stickerLayers.where((e) => e.id == id).firstOrNull;
    if (s == null) return const Text('Sticker not found', style: TextStyle(color: Colors.white54, fontSize: 11));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('Sticker', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))), IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white54), onPressed: () => ref.read(overlayProvider.notifier).deleteSticker(id), constraints: const BoxConstraints(minWidth: 28))]),
      _stickerSlider('Scale', s.scale, 0.1, 10, (v) => ref.read(overlayProvider.notifier).updateSticker(id, scale: v)),
      _stickerSlider('Opacity', s.opacity, 0, 1, (v) => ref.read(overlayProvider.notifier).updateSticker(id, opacity: v)),
      _stickerSlider('Rotation', s.rotation, -180, 180, (v) => ref.read(overlayProvider.notifier).updateSticker(id, rotation: v)),
    ]);
  }

  Widget _stickerSlider(String l, double v, double min, double max, ValueChanged<double> c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$l ${v.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 11)), Slider(value: v.clamp(min, max), min: min, max: max, onChanged: (x) => c(NumericGuard.sanitizeDouble(x, min, max, v)))]);
}

class _OverlayProperties extends ConsumerWidget {
  final String id;
  const _OverlayProperties({required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proj = ref.watch(overlayProvider);
    final o = proj?.overlayTracks.where((e) => e.id == id).firstOrNull;
    if (o == null) return const Text('Overlay not found', style: TextStyle(color: Colors.white54, fontSize: 11));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('Overlay', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))), IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white54), onPressed: () => ref.read(overlayProvider.notifier).deleteOverlay(id), constraints: const BoxConstraints(minWidth: 28))]),
      _overlaySlider('Opacity', o.opacity, 0, 1, (v) => ref.read(overlayProvider.notifier).updateOverlay(id, opacity: v)),
      _overlaySlider('Scale', o.scale, 0.1, 10, (v) => ref.read(overlayProvider.notifier).updateOverlay(id, scale: v)),
      _overlaySlider('Rotation', o.rotation, -180, 180, (v) => ref.read(overlayProvider.notifier).updateOverlay(id, rotation: v)),
    ]);
  }

  Widget _overlaySlider(String l, double v, double min, double max, ValueChanged<double> c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$l ${v.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 11)), Slider(value: v.clamp(min, max), min: min, max: max, onChanged: (x) => c(NumericGuard.sanitizeDouble(x, min, max, v)))]);
}

// ── Audio ────────────────────────────────────────────────────────
class _AudioProperties extends ConsumerWidget {
  final String id;
  const _AudioProperties({required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proj = ref.watch(audioProvider);
    final a = proj?.audioTracks.where((e) => e.id == id).firstOrNull;
    if (a == null) return const Text('Audio not found', style: TextStyle(color: Colors.white54, fontSize: 11));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('Audio', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))), IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white54), onPressed: () => ref.read(audioProvider.notifier).remove(id), constraints: const BoxConstraints(minWidth: 28))]),
      Row(children: [const Expanded(child: Text('Volume', style: TextStyle(color: Colors.white70, fontSize: 11))), Text(a.volume.toStringAsFixed(2), style: const TextStyle(color: Colors.white54, fontSize: 10))]),
      Slider(value: a.volume.clamp(0, 2), min: 0, max: 2, onChanged: (v) => ref.read(audioProvider.notifier).updateVolume(id, v)),
    ]);
  }
}

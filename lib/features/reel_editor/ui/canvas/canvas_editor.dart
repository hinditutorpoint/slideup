import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../preview/preview_canvas.dart';
import '../../engine/preview_engine.dart';
import '../../providers/canvas_provider.dart';
import '../../models/canvas_preset.dart';
import '../../core/validation/numeric_guard.dart';

/// Canvas editor md:350-378 — drag/pinch/scale/rotate/position/alignment/selection/ordering
/// Gesture isolation: canvas gestures don't conflict with timeline/scroll md:367-374
/// P1 hardening: custom ratio editor + bg color + zero overflow (Wrap/Flexible)
class CanvasEditor extends ConsumerStatefulWidget {
  final PreviewEngine engine;
  const CanvasEditor({super.key, required this.engine});

  @override
  ConsumerState<CanvasEditor> createState() => _CanvasEditorState();
}

class _CanvasEditorState extends ConsumerState<CanvasEditor> {
  final _ratioController = TextEditingController();
  bool _ratioInitialized = false;

  @override
  void dispose() {
    _ratioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvas = ref.watch(canvasProvider);
    final isCustom = canvas.config.preset.isCustom;

    // Sync controller once when entering custom
    if (isCustom && !_ratioInitialized) {
      _ratioController.text = canvas.config.effectiveRatio.toStringAsFixed(2);
      _ratioInitialized = true;
    } else if (!isCustom && _ratioInitialized) {
      _ratioInitialized = false;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Preset selector — horizontal scroll prevents overflow md:134
            SizedBox(
              height: 44,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: CanvasPreset.all.map((p) {
                    final sel = canvas.config.preset.id == p.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(p.name, style: const TextStyle(fontSize: 11)),
                        selected: sel,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          ref.read(canvasProvider.notifier).setPreset(p);
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // Custom ratio + bg color row — Wrap prevents RenderFlex overflow
            if (isCustom)
              Container(
                color: Colors.grey[900],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Flexible(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _ratioController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\.]'))],
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'Ratio',
                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
                            hintText: '0.56 = 9:16',
                            hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                          ),
                          onSubmitted: _applyRatio,
                          onEditingComplete: () => _applyRatio(_ratioController.text),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final c in [0xFF000000, 0xFF1a1a2e, 0xFF0f3460, 0xFFffffff, 0xFFe94560])
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref.read(canvasProvider.notifier).setBackgroundColor(c);
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: canvas.config.backgroundColor == c ? Colors.blue : Colors.white24,
                                    width: canvas.config.backgroundColor == c ? 2 : 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // preview area — Expanded with LayoutBuilder ensures no unbounded height md:119-121
            Expanded(
              child: Container(
                color: Color(canvas.config.backgroundColor),
                child: PreviewCanvas(engine: widget.engine, enableInteraction: true),
              ),
            ),
          ],
        );
      },
    );
  }

  void _applyRatio(String v) {
    final parsed = double.tryParse(v);
    if (parsed == null) return;
    if (!NumericGuard.isValidDouble(parsed)) return;
    final sanitized = NumericGuard.sanitizeDouble(parsed, 0.1, 4.0, 1.0);
    ref.read(canvasProvider.notifier).setCustomRatio(sanitized);
    // Normalize text without triggering rebuild loop
    _ratioController.text = sanitized.toStringAsFixed(2);
    _ratioController.selection = TextSelection.collapsed(offset: _ratioController.text.length);
  }
}

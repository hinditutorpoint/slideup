import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/reel_project.dart';
import '../../providers/overlay_provider.dart';

Future<void> showTextSheet(BuildContext context, WidgetRef ref, {ReelTextLayer? existing}) async {
  await showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, builder: (ctx) => TextSheet(existing: existing));
}

class TextSheet extends ConsumerStatefulWidget {
  final ReelTextLayer? existing;
  const TextSheet({super.key, this.existing});
  @override ConsumerState<TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends ConsumerState<TextSheet> {
  late TextEditingController ctrl;
  double fontSize = 24;
  int color = 0xFFFFFFFF;
  String fontFamily = 'Roboto';
  @override
  void initState() {
    super.initState();
    ctrl = TextEditingController(text: widget.existing?.text ?? 'Hello Reel');
    fontSize = widget.existing?.fontSize ?? 24;
    color = widget.existing?.color ?? 0xFFFFFFFF;
    fontFamily = widget.existing?.fontFamily ?? 'Roboto';
  }
  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return SingleChildScrollView(
          controller: scrollCtrl,
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: Text(widget.existing == null ? 'Add Text' : 'Edit Text', style: Theme.of(ctx).textTheme.titleMedium)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Text'), maxLines: 3),
                const SizedBox(height: 12),
                Text('Size ${fontSize.round()}', style: Theme.of(ctx).textTheme.labelLarge),
                Slider(value: fontSize, min: 10, max: 80, divisions: 14, label: '${fontSize.round()}', onChanged: (v) => setState(() => fontSize = v)),
                Wrap(spacing: 8, children: [['Roboto', 'Roboto'], ['Poppins', 'Poppins'], ['Montserrat', 'Montserrat']].map((f) => ChoiceChip(label: Text(f[0]), selected: fontFamily == f[1], onSelected: (_) => setState(() => fontFamily = f[1]))).toList()),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [0xFFFFFFFF, 0xFF000000, 0xFFE91E63, 0xFF2196F3, 0xFFFFEB3B].map((c) => GestureDetector(onTap: () => setState(() => color = c), child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: color == c ? Theme.of(ctx).colorScheme.primary : Colors.grey))))).toList()),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  FilledButton(
                    onPressed: () {
                      final txt = ctrl.text.trim();
                      if (txt.isEmpty) return;
                      final ov = ref.read(overlayProvider.notifier);
                      if (widget.existing == null) {
                        ov.addText(ReelTextLayer(id: DateTime.now().millisecondsSinceEpoch.toString(), text: txt, startTime: Duration.zero, endTime: const Duration(seconds: 5), fontSize: fontSize, fontFamily: fontFamily, color: color));
                      } else {
                        ov.updateText(widget.existing!.id, text: txt, fontSize: fontSize, color: color, fontFamily: fontFamily);
                      }
                      Navigator.pop(ctx);
                    },
                    child: Text(widget.existing == null ? 'Add' : 'Save'),
                  ),
                  OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

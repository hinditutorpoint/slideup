import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/reel_project.dart';
import '../../providers/timeline_provider.dart';

Future<void> showClipEditSheet(BuildContext context, WidgetRef ref, ReelVideoTrack clip) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => ClipEditSheet(clip: clip),
  );
}

class ClipEditSheet extends ConsumerStatefulWidget {
  final ReelVideoTrack clip;
  const ClipEditSheet({super.key, required this.clip});
  @override
  ConsumerState<ClipEditSheet> createState() => _ClipEditSheetState();
}

class _ClipEditSheetState extends ConsumerState<ClipEditSheet> {
  late Duration trimStart;
  late Duration trimEnd;
  late double speed;
  late double volume;
  @override
  void initState() {
    super.initState();
    trimStart = widget.clip.trimStart;
    trimEnd = widget.clip.trimEnd;
    speed = widget.clip.speed;
    volume = widget.clip.volume;
  }
  @override
  Widget build(BuildContext context) {
    double maxMs = widget.clip.sourceDuration.inMilliseconds.toDouble();
    if (maxMs < 1) maxMs = 1;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, ctrl) {
        return SingleChildScrollView(
          controller: ctrl,
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: Text('Edit Clip', style: Theme.of(ctx).textTheme.titleMedium)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const Divider(),
                Text('Trim', style: Theme.of(ctx).textTheme.labelLarge),
                RangeSlider(
                  min: 0,
                  max: maxMs,
                  values: RangeValues(
                    trimStart.inMilliseconds.toDouble().clamp(0, maxMs).toDouble(),
                    trimEnd.inMilliseconds.toDouble().clamp(0, maxMs).toDouble(),
                  ),
                  labels: RangeLabels('${trimStart.inSeconds}s', '${trimEnd.inSeconds}s'),
                  onChanged: (v) => setState(() {
                    trimStart = Duration(milliseconds: v.start.round());
                    trimEnd = Duration(milliseconds: v.end.round());
                  }),
                ),
                Row(children: [
                  Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Start: ${trimStart.inMilliseconds}ms'))),
                  const Spacer(),
                  Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('End: ${trimEnd.inMilliseconds}ms'))),
                ]),
                const SizedBox(height: 12),
                Text('Speed ${speed.toStringAsFixed(2)}x', style: Theme.of(ctx).textTheme.labelLarge),
                Slider(value: speed, min: 0.25, max: 4.0, divisions: 15, label: '${speed.toStringAsFixed(2)}x', onChanged: (v) => setState(() => speed = v)),
                Text('Volume ${(volume * 100).round()}%', style: Theme.of(ctx).textTheme.labelLarge),
                Slider(value: volume, min: 0, max: 2.0, divisions: 20, label: '${(volume * 100).round()}%', onChanged: (v) => setState(() => volume = v)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  FilledButton(
                    onPressed: () {
                      final tl = ref.read(reelTimelineProvider.notifier);
                      tl.updateTrim(widget.clip.id, trimStart, trimEnd);
                      tl.updateSpeed(widget.clip.id, speed);
                      tl.updateVolume(widget.clip.id, volume);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Apply'),
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

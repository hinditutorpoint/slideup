import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pdf_providers.dart';

class ViewToggleButton extends ConsumerWidget {
  const ViewToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(viewModeProvider);

    return IconButton(
      icon: Icon(
        viewMode == ViewMode.grid
            ? Icons.view_list_rounded
            : Icons.grid_view_rounded,
      ),
      tooltip: viewMode == ViewMode.grid ? 'List view' : 'Grid view',
      onPressed: () {
        ref.read(viewModeProvider.notifier).toggle();
      },
    );
  }
}

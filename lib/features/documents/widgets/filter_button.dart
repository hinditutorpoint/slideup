import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pdf_providers.dart';
import 'filter_bottom_sheet.dart';

class FilterButton extends ConsumerWidget {
  const FilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(pdfSearchProvider);
    final hasActiveFilters = searchState.filter.hasActiveFilters;
    final filterCount = searchState.filter.activeFilterCount;

    return Badge(
      isLabelVisible: hasActiveFilters,
      label: Text('$filterCount'),
      child: IconButton(
        icon: Icon(
          hasActiveFilters ? Icons.filter_list : Icons.filter_list_outlined,
          color: hasActiveFilters
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
        tooltip: 'Filters',
        onPressed: () => _showFilterSheet(context),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const FilterBottomSheet(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/search_filter.dart';
import '../providers/pdf_providers.dart';
import '../../../../core/constants/languages.dart';

class ActiveFilterChips extends ConsumerWidget {
  const ActiveFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(pdfSearchProvider);
    final filter = searchState.filter;

    if (!filter.hasActiveFilters) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Language chip
          if (filter.language.code.isNotEmpty)
            _FilterChip(
              label: filter.language.name,
              icon: Icons.language,
              onRemove: () {
                final newFilter = filter.copyWith(
                  language: const Language(
                    code: '',
                    name: 'All Languages',
                    nativeName: 'All Languages',
                  ),
                );
                ref.read(pdfSearchProvider.notifier).applyFilter(newFilter);
              },
            ),

          // Sort chip
          if (filter.sortOption != SortOption.downloads)
            _FilterChip(
              label: filter.sortOption.displayName,
              icon: Icons.sort,
              onRemove: () {
                final newFilter = filter.copyWith(
                  sortOption: SortOption.downloads,
                );
                ref.read(pdfSearchProvider.notifier).applyFilter(newFilter);
              },
            ),

          // Year range chip
          if (filter.yearRange != YearRange.all)
            _FilterChip(
              label: filter.yearRange == YearRange.custom
                  ? '${filter.startYear ?? '*'} - ${filter.endYear ?? '*'}'
                  : filter.yearRange.displayName,
              icon: Icons.date_range,
              onRemove: () {
                final newFilter = filter.copyWith(yearRange: YearRange.all);
                ref.read(pdfSearchProvider.notifier).applyFilter(newFilter);
              },
            ),

          // Min downloads chip
          if (filter.minDownloads != null)
            _FilterChip(
              label: '${_formatNumber(filter.minDownloads!)}+ downloads',
              icon: Icons.download,
              onRemove: () {
                final newFilter = filter.copyWith(minDownloads: null);
                ref.read(pdfSearchProvider.notifier).applyFilter(newFilter);
              },
            ),

          // Clear all button
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('Clear All'),
            avatar: const Icon(Icons.clear_all, size: 18),
            onPressed: () {
              ref
                  .read(pdfSearchProvider.notifier)
                  .applyFilter(const SearchFilter());
            },
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(0)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toString();
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

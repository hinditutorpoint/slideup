import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/languages.dart';
import '../../documents/models/search_filter.dart';
import '../models/video_filter.dart';
import '../providers/video_providers.dart';

class VideoActiveFilterChips extends ConsumerWidget {
  const VideoActiveFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(videoSearchProvider);
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
          // Category chip
          if (filter.category != VideoCategory.all)
            _FilterChip(
              label: filter.category.displayName,
              icon: Icons.category,
              onRemove: () {
                final newFilter = filter.copyWith(category: VideoCategory.all);
                ref.read(videoSearchProvider.notifier).applyFilter(newFilter);
              },
            ),

          // Duration chip
          if (filter.duration != VideoDuration.all)
            _FilterChip(
              label: filter.duration.displayName,
              icon: Icons.timer,
              onRemove: () {
                final newFilter = filter.copyWith(duration: VideoDuration.all);
                ref.read(videoSearchProvider.notifier).applyFilter(newFilter);
              },
            ),

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
                ref.read(videoSearchProvider.notifier).applyFilter(newFilter);
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
                ref.read(videoSearchProvider.notifier).applyFilter(newFilter);
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
                ref.read(videoSearchProvider.notifier).applyFilter(newFilter);
              },
            ),

          // Min views chip
          if (filter.minDownloads != null)
            _FilterChip(
              label: '${_formatNumber(filter.minDownloads!)}+ views',
              icon: Icons.visibility,
              onRemove: () {
                final newFilter = filter.copyWith(minDownloads: null);
                ref.read(videoSearchProvider.notifier).applyFilter(newFilter);
              },
            ),

          // Clear all button
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('Clear All'),
            avatar: const Icon(Icons.clear_all, size: 18),
            onPressed: () {
              ref
                  .read(videoSearchProvider.notifier)
                  .applyFilter(const VideoFilter());
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

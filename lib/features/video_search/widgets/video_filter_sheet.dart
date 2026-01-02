import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../documents/models/search_filter.dart';
import '../../documents/widgets/filter_bottom_sheet.dart';
import '../models/video_filter.dart';
import '../providers/video_providers.dart';

class VideoFilterSheet extends ConsumerStatefulWidget {
  const VideoFilterSheet({super.key});

  @override
  ConsumerState<VideoFilterSheet> createState() => _VideoFilterSheetState();
}

class _VideoFilterSheetState extends ConsumerState<VideoFilterSheet> {
  late VideoFilter _filter;
  final _startYearController = TextEditingController();
  final _endYearController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter = ref.read(videoSearchProvider).filter;

    if (_filter.customStartYear != null) {
      _startYearController.text = _filter.customStartYear.toString();
    }
    if (_filter.customEndYear != null) {
      _endYearController.text = _filter.customEndYear.toString();
    }
  }

  @override
  void dispose() {
    _startYearController.dispose();
    _endYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            _buildHandle(context),
            _buildHeader(context),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCategoryFilter(context),
                  const SizedBox(height: 24),
                  _buildDurationFilter(context),
                  const SizedBox(height: 24),
                  _buildLanguageFilter(context),
                  const SizedBox(height: 24),
                  _buildSortOption(context),
                  const SizedBox(height: 24),
                  _buildYearRange(context),
                  const SizedBox(height: 24),
                  _buildMinDownloads(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            _buildActions(context),
          ],
        );
      },
    );
  }

  Widget _buildHandle(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.filter_list, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Video Filters',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (_filter.hasActiveFilters)
            TextButton(
              onPressed: _resetFilters,
              child: const Text('Reset All'),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Category', Icons.category),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: VideoCategory.values.map((category) {
            final isSelected = _filter.category == category;
            return ChoiceChip(
              label: Text(category.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _filter = _filter.copyWith(category: category);
                  });
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDurationFilter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Duration', Icons.timer),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: VideoDuration.values.map((duration) {
            final isSelected = _filter.duration == duration;
            return ChoiceChip(
              label: Text(duration.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _filter = _filter.copyWith(duration: duration);
                  });
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLanguageFilter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Language', Icons.language),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _showLanguagePicker(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _filter.language.name,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (_filter.language.code.isNotEmpty)
                        Text(
                          _filter.language.nativeName,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSortOption(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Sort By', Icons.sort),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SortOption.values.map((option) {
            final isSelected = _filter.sortOption == option;
            return ChoiceChip(
              label: Text(option.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _filter = _filter.copyWith(sortOption: option);
                  });
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildYearRange(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Year Range', Icons.date_range),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: YearRange.values.map((range) {
            final isSelected = _filter.yearRange == range;
            return ChoiceChip(
              label: Text(range.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _filter = _filter.copyWith(yearRange: range);
                  });
                }
              },
            );
          }).toList(),
        ),
        if (_filter.yearRange == YearRange.custom) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startYearController,
                  decoration: const InputDecoration(
                    labelText: 'From Year',
                    hintText: 'e.g., 1990',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final year = int.tryParse(value);
                    setState(() {
                      _filter = _filter.copyWith(customStartYear: year);
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _endYearController,
                  decoration: const InputDecoration(
                    labelText: 'To Year',
                    hintText: 'e.g., 2024',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final year = int.tryParse(value);
                    setState(() {
                      _filter = _filter.copyWith(customEndYear: year);
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMinDownloads(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Minimum Views', Icons.visibility),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildDownloadChip(null, 'Any'),
            _buildDownloadChip(1000, '1K+'),
            _buildDownloadChip(10000, '10K+'),
            _buildDownloadChip(100000, '100K+'),
            _buildDownloadChip(1000000, '1M+'),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadChip(int? value, String label) {
    final isSelected = _filter.minDownloads == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filter = _filter.copyWith(minDownloads: value);
          });
        }
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _applyFilters,
                child: Text(
                  _filter.hasActiveFilters
                      ? 'Apply (${_filter.activeFilterCount})'
                      : 'Apply Filters',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => LanguagePickerSheet(
        selectedLanguage: _filter.language,
        onSelected: (language) {
          setState(() {
            _filter = _filter.copyWith(language: language);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _filter = const VideoFilter();
      _startYearController.clear();
      _endYearController.clear();
    });
  }

  void _applyFilters() {
    ref.read(videoSearchProvider.notifier).applyFilter(_filter);
    Navigator.pop(context);
  }
}

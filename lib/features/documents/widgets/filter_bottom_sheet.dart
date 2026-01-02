import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/languages.dart';
import '../models/search_filter.dart';
import '../providers/pdf_providers.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late SearchFilter _filter;
  final _startYearController = TextEditingController();
  final _endYearController = TextEditingController();
  final _minDownloadsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter = ref.read(pdfSearchProvider).filter;

    if (_filter.customStartYear != null) {
      _startYearController.text = _filter.customStartYear.toString();
    }
    if (_filter.customEndYear != null) {
      _endYearController.text = _filter.customEndYear.toString();
    }
    if (_filter.minDownloads != null) {
      _minDownloadsController.text = _filter.minDownloads.toString();
    }
  }

  @override
  void dispose() {
    _startYearController.dispose();
    _endYearController.dispose();
    _minDownloadsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            _buildHandle(context),

            // Header
            _buildHeader(context),

            const Divider(height: 1),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Language Filter
                  _buildLanguageFilter(context),

                  const SizedBox(height: 24),

                  // Sort Option
                  _buildSortOption(context),

                  const SizedBox(height: 24),

                  // Year Range
                  _buildYearRange(context),

                  const SizedBox(height: 24),

                  // Min Downloads
                  _buildMinDownloads(context),

                  const SizedBox(height: 32),
                ],
              ),
            ),

            // Actions
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
            'Filters',
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

        // Custom year range inputs
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
        _buildSectionTitle(context, 'Minimum Downloads', Icons.download),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildDownloadChip(null, 'Any'),
            _buildDownloadChip(100, '100+'),
            _buildDownloadChip(1000, '1K+'),
            _buildDownloadChip(10000, '10K+'),
            _buildDownloadChip(100000, '100K+'),
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
      _filter = const SearchFilter();
      _startYearController.clear();
      _endYearController.clear();
      _minDownloadsController.clear();
    });
  }

  void _applyFilters() {
    ref.read(pdfSearchProvider.notifier).applyFilter(_filter);
    Navigator.pop(context);
  }
}

// Language Picker Sheet
class LanguagePickerSheet extends StatefulWidget {
  final Language selectedLanguage;
  final ValueChanged<Language> onSelected;

  const LanguagePickerSheet({
    super.key,
    required this.selectedLanguage,
    required this.onSelected,
  });

  @override
  State<LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<LanguagePickerSheet> {
  final _searchController = TextEditingController();
  List<Language> _filteredLanguages = AppLanguages.supportedLanguages;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredLanguages = AppLanguages.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Select Language',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search languages...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Language list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filteredLanguages.length,
                itemBuilder: (context, index) {
                  final language = _filteredLanguages[index];
                  final isSelected = language == widget.selectedLanguage;

                  return ListTile(
                    leading: language.code.isEmpty
                        ? const Icon(Icons.public)
                        : CircleAvatar(
                            backgroundColor: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            child: Text(
                              language.code.toUpperCase().substring(0, 2),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                    title: Text(language.name),
                    subtitle: language.code.isNotEmpty
                        ? Text(language.nativeName)
                        : null,
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    selected: isSelected,
                    onTap: () => widget.onSelected(language),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

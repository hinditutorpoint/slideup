import '../../../../core/constants/languages.dart';

enum SortOption { relevance, downloads, dateDesc, dateAsc, titleAsc, titleDesc }

extension SortOptionExtension on SortOption {
  String get displayName {
    switch (this) {
      case SortOption.relevance:
        return 'Relevance';
      case SortOption.downloads:
        return 'Most Downloaded';
      case SortOption.dateDesc:
        return 'Newest First';
      case SortOption.dateAsc:
        return 'Oldest First';
      case SortOption.titleAsc:
        return 'Title (A-Z)';
      case SortOption.titleDesc:
        return 'Title (Z-A)';
    }
  }

  String get apiValue {
    switch (this) {
      case SortOption.relevance:
        return '';
      case SortOption.downloads:
        return 'downloads desc';
      case SortOption.dateDesc:
        return 'date desc';
      case SortOption.dateAsc:
        return 'date asc';
      case SortOption.titleAsc:
        return 'title asc';
      case SortOption.titleDesc:
        return 'title desc';
    }
  }
}

enum YearRange {
  all,
  last1Year,
  last5Years,
  last10Years,
  last20Years,
  before1900,
  custom,
}

extension YearRangeExtension on YearRange {
  String get displayName {
    switch (this) {
      case YearRange.all:
        return 'All Time';
      case YearRange.last1Year:
        return 'Last Year';
      case YearRange.last5Years:
        return 'Last 5 Years';
      case YearRange.last10Years:
        return 'Last 10 Years';
      case YearRange.last20Years:
        return 'Last 20 Years';
      case YearRange.before1900:
        return 'Before 1900';
      case YearRange.custom:
        return 'Custom Range';
    }
  }

  ({int? startYear, int? endYear}) get years {
    final currentYear = DateTime.now().year;
    switch (this) {
      case YearRange.all:
        return (startYear: null, endYear: null);
      case YearRange.last1Year:
        return (startYear: currentYear - 1, endYear: currentYear);
      case YearRange.last5Years:
        return (startYear: currentYear - 5, endYear: currentYear);
      case YearRange.last10Years:
        return (startYear: currentYear - 10, endYear: currentYear);
      case YearRange.last20Years:
        return (startYear: currentYear - 20, endYear: currentYear);
      case YearRange.before1900:
        return (startYear: null, endYear: 1899);
      case YearRange.custom:
        return (startYear: null, endYear: null);
    }
  }
}

class SearchFilter {
  final Language language;
  final SortOption sortOption;
  final YearRange yearRange;
  final int? customStartYear;
  final int? customEndYear;
  final bool onlyWithDownloads;
  final int? minDownloads;

  const SearchFilter({
    this.language = const Language(
      code: '',
      name: 'All Languages',
      nativeName: 'All Languages',
    ),
    this.sortOption = SortOption.downloads,
    this.yearRange = YearRange.all,
    this.customStartYear,
    this.customEndYear,
    this.onlyWithDownloads = false,
    this.minDownloads,
  });

  bool get hasActiveFilters {
    return language.code.isNotEmpty ||
        sortOption != SortOption.downloads ||
        yearRange != YearRange.all ||
        onlyWithDownloads ||
        minDownloads != null;
  }

  int get activeFilterCount {
    int count = 0;
    if (language.code.isNotEmpty) count++;
    if (sortOption != SortOption.downloads) count++;
    if (yearRange != YearRange.all) count++;
    if (onlyWithDownloads) count++;
    if (minDownloads != null) count++;
    return count;
  }

  int? get startYear {
    if (yearRange == YearRange.custom) return customStartYear;
    return yearRange.years.startYear;
  }

  int? get endYear {
    if (yearRange == YearRange.custom) return customEndYear;
    return yearRange.years.endYear;
  }

  SearchFilter copyWith({
    Language? language,
    SortOption? sortOption,
    YearRange? yearRange,
    int? customStartYear,
    int? customEndYear,
    bool? onlyWithDownloads,
    int? minDownloads,
  }) {
    return SearchFilter(
      language: language ?? this.language,
      sortOption: sortOption ?? this.sortOption,
      yearRange: yearRange ?? this.yearRange,
      customStartYear: customStartYear ?? this.customStartYear,
      customEndYear: customEndYear ?? this.customEndYear,
      onlyWithDownloads: onlyWithDownloads ?? this.onlyWithDownloads,
      minDownloads: minDownloads ?? this.minDownloads,
    );
  }

  SearchFilter reset() {
    return const SearchFilter();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchFilter &&
          runtimeType == other.runtimeType &&
          language == other.language &&
          sortOption == other.sortOption &&
          yearRange == other.yearRange &&
          customStartYear == other.customStartYear &&
          customEndYear == other.customEndYear &&
          onlyWithDownloads == other.onlyWithDownloads &&
          minDownloads == other.minDownloads;

  @override
  int get hashCode =>
      language.hashCode ^
      sortOption.hashCode ^
      yearRange.hashCode ^
      customStartYear.hashCode ^
      customEndYear.hashCode ^
      onlyWithDownloads.hashCode ^
      minDownloads.hashCode;
}

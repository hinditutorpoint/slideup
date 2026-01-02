import '../../../../core/constants/languages.dart';
import 'package:slideup/features/documents/models/search_filter.dart';

enum VideoCategory {
  all,
  movies,
  tvShows,
  documentary,
  animation,
  shortFilms,
  musicVideos,
  educational,
  newsPublicAffairs,
  sports,
}

extension VideoCategoryExtension on VideoCategory {
  String get displayName {
    switch (this) {
      case VideoCategory.all:
        return 'All Videos';
      case VideoCategory.movies:
        return 'Movies';
      case VideoCategory.tvShows:
        return 'TV Shows';
      case VideoCategory.documentary:
        return 'Documentary';
      case VideoCategory.animation:
        return 'Animation';
      case VideoCategory.shortFilms:
        return 'Short Films';
      case VideoCategory.musicVideos:
        return 'Music Videos';
      case VideoCategory.educational:
        return 'Educational';
      case VideoCategory.newsPublicAffairs:
        return 'News';
      case VideoCategory.sports:
        return 'Sports';
    }
  }

  String? get collectionQuery {
    switch (this) {
      case VideoCategory.all:
        return null;
      case VideoCategory.movies:
        return 'collection:(feature_films OR moviesandfilms)';
      case VideoCategory.tvShows:
        return 'collection:(classic_tv OR television)';
      case VideoCategory.documentary:
        return 'collection:(documentary OR documentaries)';
      case VideoCategory.animation:
        return 'collection:(animation_movies OR animationandcartoons)';
      case VideoCategory.shortFilms:
        return 'collection:(short_films OR shortfilms)';
      case VideoCategory.musicVideos:
        return 'collection:(music_videos OR musicvideos)';
      case VideoCategory.educational:
        return 'collection:(educationalfilms OR prelinger)';
      case VideoCategory.newsPublicAffairs:
        return 'collection:(newsandpublicaffairs OR news)';
      case VideoCategory.sports:
        return 'collection:(sports OR sports_videos)';
    }
  }
}

enum VideoDuration {
  all,
  short, // < 10 min
  medium, // 10-30 min
  long, // 30-60 min
  movie, // > 60 min
}

extension VideoDurationExtension on VideoDuration {
  String get displayName {
    switch (this) {
      case VideoDuration.all:
        return 'Any Duration';
      case VideoDuration.short:
        return '< 10 min';
      case VideoDuration.medium:
        return '10-30 min';
      case VideoDuration.long:
        return '30-60 min';
      case VideoDuration.movie:
        return '> 60 min';
    }
  }
}

class VideoFilter {
  final Language language;
  final SortOption sortOption;
  final YearRange yearRange;
  final int? customStartYear;
  final int? customEndYear;
  final int? minDownloads;
  final VideoCategory category;
  final VideoDuration duration;

  const VideoFilter({
    this.language = const Language(
      code: '',
      name: 'All Languages',
      nativeName: 'All Languages',
    ),
    this.sortOption = SortOption.downloads,
    this.yearRange = YearRange.all,
    this.customStartYear,
    this.customEndYear,
    this.minDownloads,
    this.category = VideoCategory.all,
    this.duration = VideoDuration.all,
  });

  bool get hasActiveFilters {
    return language.code.isNotEmpty ||
        sortOption != SortOption.downloads ||
        yearRange != YearRange.all ||
        minDownloads != null ||
        category != VideoCategory.all ||
        duration != VideoDuration.all;
  }

  int get activeFilterCount {
    int count = 0;
    if (language.code.isNotEmpty) count++;
    if (sortOption != SortOption.downloads) count++;
    if (yearRange != YearRange.all) count++;
    if (minDownloads != null) count++;
    if (category != VideoCategory.all) count++;
    if (duration != VideoDuration.all) count++;
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

  VideoFilter copyWith({
    Language? language,
    SortOption? sortOption,
    YearRange? yearRange,
    int? customStartYear,
    int? customEndYear,
    int? minDownloads,
    VideoCategory? category,
    VideoDuration? duration,
  }) {
    return VideoFilter(
      language: language ?? this.language,
      sortOption: sortOption ?? this.sortOption,
      yearRange: yearRange ?? this.yearRange,
      customStartYear: customStartYear ?? this.customStartYear,
      customEndYear: customEndYear ?? this.customEndYear,
      minDownloads: minDownloads ?? this.minDownloads,
      category: category ?? this.category,
      duration: duration ?? this.duration,
    );
  }

  VideoFilter reset() {
    return const VideoFilter();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoFilter &&
          runtimeType == other.runtimeType &&
          language == other.language &&
          sortOption == other.sortOption &&
          yearRange == other.yearRange &&
          customStartYear == other.customStartYear &&
          customEndYear == other.customEndYear &&
          minDownloads == other.minDownloads &&
          category == other.category &&
          duration == other.duration;

  @override
  int get hashCode =>
      language.hashCode ^
      sortOption.hashCode ^
      yearRange.hashCode ^
      customStartYear.hashCode ^
      customEndYear.hashCode ^
      minDownloads.hashCode ^
      category.hashCode ^
      duration.hashCode;
}

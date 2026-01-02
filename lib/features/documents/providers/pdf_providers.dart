import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/networks/network_service.dart';
import '../../../core/constants/languages.dart';
import '../datasources/pdf_local_datasource.dart';
import '../datasources/pdf_remote_datasource.dart';
import '../models/archive_item.dart';
import '../models/search_filter.dart';
import '../repositories/pdf_repository.dart';

// ============ Service Providers ============

final networkServiceProvider = Provider<NetworkService>((ref) {
  final service = NetworkService();
  ref.onDispose(() => service.dispose());
  return service;
});

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

// ============ Data Source Providers ============

final pdfRemoteDataSourceProvider = Provider<PdfRemoteDataSource>((ref) {
  return PdfRemoteDataSourceImpl(
    networkService: ref.watch(networkServiceProvider),
  );
});

final pdfLocalDataSourceProvider = Provider<PdfLocalDataSource>((ref) {
  return PdfLocalDataSourceImpl(
    databaseHelper: ref.watch(databaseHelperProvider),
  );
});

// ============ Repository Provider ============

final pdfRepositoryProvider = Provider<PdfRepository>((ref) {
  return PdfRepositoryImpl(
    remoteDataSource: ref.watch(pdfRemoteDataSourceProvider),
    localDataSource: ref.watch(pdfLocalDataSourceProvider),
  );
});

// ============ UI State Providers ============

// View mode (grid/list)
enum ViewMode { grid, list }

final viewModeProvider = NotifierProvider<ViewModeNotifier, ViewMode>(
  ViewModeNotifier.new,
);

class ViewModeNotifier extends Notifier<ViewMode> {
  @override
  ViewMode build() => ViewMode.grid;

  void toggle() {
    state = state == ViewMode.grid ? ViewMode.list : ViewMode.grid;
  }
}

// Search query
final searchQueryProvider = Provider<String>((ref) => '');

// Current page for pagination
final currentPageProvider = Provider<int>((ref) => 1);

// ============ Search State ============

// Search filter
final searchFilterProvider =
    NotifierProvider<SearchFilterNotifier, SearchFilter>(() {
      return SearchFilterNotifier();
    });

class SearchFilterNotifier extends Notifier<SearchFilter> {
  @override
  SearchFilter build() {
    return const SearchFilter();
  }

  void updateFilter(SearchFilter filter) {
    state = filter;
  }

  void resetFilter() {
    state = const SearchFilter();
  }

  void setLanguage(Language language) {
    state = state.copyWith(language: language);
  }

  void setSortOption(SortOption sortOption) {
    state = state.copyWith(sortOption: sortOption);
  }

  void setYearRange(YearRange yearRange) {
    state = state.copyWith(yearRange: yearRange);
  }

  void setCustomYearRange(int? startYear, int? endYear) {
    state = state.copyWith(
      yearRange: YearRange.custom,
      customStartYear: startYear,
      customEndYear: endYear,
    );
  }

  void setMinDownloads(int? minDownloads) {
    state = state.copyWith(minDownloads: minDownloads);
  }

  void toggleOnlyWithDownloads() {
    state = state.copyWith(onlyWithDownloads: !state.onlyWithDownloads);
  }
}

class PdfSearchState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<ArchiveItem> items;
  final String languageCode;
  final String? error;
  final bool hasMore;
  final int totalResults;
  final String query;
  final SearchFilter filter;

  const PdfSearchState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.items = const [],
    this.languageCode = '',
    this.error,
    this.hasMore = true,
    this.totalResults = 0,
    this.query = '',
    this.filter = const SearchFilter(),
  });

  PdfSearchState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<ArchiveItem>? items,
    String? languageCode,
    String? error,
    bool? hasMore,
    int? totalResults,
    String? query,
    SearchFilter? filter,
  }) {
    return PdfSearchState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      languageCode: languageCode ?? this.languageCode,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      totalResults: totalResults ?? this.totalResults,
      query: query ?? this.query,
      filter: filter ?? this.filter,
    );
  }
}

// ============ Search Notifier ============

class PdfSearchNotifier extends Notifier<PdfSearchState> {
  late PdfRepository _repository;
  int _currentPage = 1;

  @override
  PdfSearchState build() {
    _repository = ref.watch(pdfRepositoryProvider);
    return const PdfSearchState();
  }

  Future<void> search(String query, {SearchFilter? filter}) async {
    if (query.trim().isEmpty) {
      state = const PdfSearchState();
      return;
    }

    _currentPage = 1;
    final searchFilter = filter ?? state.filter;
    state = PdfSearchState(isLoading: true, query: query, filter: searchFilter);

    try {
      final response = await _repository.searchPdfs(
        query: query,
        page: _currentPage,
        filter: searchFilter,
      );

      state = state.copyWith(
        isLoading: false,
        items: response.items,
        hasMore: response.hasMore,
        totalResults: response.numFound,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.query.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);
    _currentPage++;

    try {
      final response = await _repository.searchPdfs(
        query: state.query,
        page: _currentPage,
        filter: state.filter,
      );

      state = state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...response.items],
        hasMore: response.hasMore,
      );
    } catch (e) {
      _currentPage--;
      state = state.copyWith(isLoadingMore: false, error: _getErrorMessage(e));
    }
  }

  Future<void> applyFilter(SearchFilter filter) async {
    if (state.query.isNotEmpty) {
      await search(state.query, filter: filter);
    } else {
      state = state.copyWith(filter: filter);
    }
  }

  Future<void> toggleLike(ArchiveItem item) async {
    try {
      await _repository.toggleLike(item);

      // Update the item in the list
      final updatedItems = state.items.map((i) {
        if (i.identifier == item.identifier) {
          return i.copyWith(isLiked: !i.isLiked);
        }
        return i;
      }).toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {
      // Silently fail, could show a snackbar
    }
  }

  Future<void> refresh() async {
    if (state.query.isNotEmpty) {
      await search(state.query, filter: state.filter);
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('No internet')) {
      return 'No internet connection. Please check your network.';
    } else if (error.toString().contains('timed out')) {
      return 'Request timed out. Please try again.';
    } else if (error.toString().contains('Server error')) {
      return 'Server error. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final pdfSearchProvider = NotifierProvider<PdfSearchNotifier, PdfSearchState>(
  PdfSearchNotifier.new,
);

// ============ Liked Items Provider ============

final likedPdfsProvider = FutureProvider<List<ArchiveItem>>((ref) async {
  final repository = ref.watch(pdfRepositoryProvider);
  return await repository.getLikedPdfs();
});

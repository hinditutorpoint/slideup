import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../documents/providers/pdf_providers.dart';
import '../datasources/video_local_datasource.dart';
import '../datasources/video_remote_datasource.dart';
import '../models/video_filter.dart';
import '../models/video_item.dart';
import '../repositories/video_repository.dart';

// ============ Data Source Providers ============

final videoRemoteDataSourceProvider = Provider<VideoRemoteDataSource>((ref) {
  return VideoRemoteDataSourceImpl(
    networkService: ref.watch(networkServiceProvider),
  );
});

final videoLocalDataSourceProvider = Provider<VideoLocalDataSource>((ref) {
  return VideoLocalDataSourceImpl(
    databaseHelper: ref.watch(databaseHelperProvider),
  );
});

// ============ Repository Provider ============

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  return VideoRepositoryImpl(
    remoteDataSource: ref.watch(videoRemoteDataSourceProvider),
    localDataSource: ref.watch(videoLocalDataSourceProvider),
  );
});

// ============ UI State Providers ============

// View mode (grid/list) - shared with PDF
final videoViewModeProvider = NotifierProvider<ViewModeNotifier, ViewMode>(
  ViewModeNotifier.new,
);

class ViewModeNotifier extends Notifier<ViewMode> {
  @override
  ViewMode build() => ViewMode.grid;

  void toggle() {
    state = state == ViewMode.grid ? ViewMode.list : ViewMode.grid;
  }
}

// ============ Video Search State ============

class VideoSearchState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<VideoItem> items;
  final String? error;
  final bool hasMore;
  final int totalResults;
  final String query;
  final VideoFilter filter;

  const VideoSearchState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.items = const [],
    this.error,
    this.hasMore = true,
    this.totalResults = 0,
    this.query = '',
    this.filter = const VideoFilter(),
  });

  VideoSearchState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<VideoItem>? items,
    String? error,
    bool? hasMore,
    int? totalResults,
    String? query,
    VideoFilter? filter,
  }) {
    return VideoSearchState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      totalResults: totalResults ?? this.totalResults,
      query: query ?? this.query,
      filter: filter ?? this.filter,
    );
  }
}

// ============ Video Search Notifier ============

class VideoSearchNotifier extends Notifier<VideoSearchState> {
  late final VideoRepository _repository;
  int _currentPage = 1;

  @override
  VideoSearchState build() {
    _repository = ref.watch(videoRepositoryProvider);
    return const VideoSearchState();
  }

  Future<void> search(String query, {VideoFilter? filter}) async {
    if (query.trim().isEmpty) {
      state = const VideoSearchState();
      return;
    }

    _currentPage = 1;
    final searchFilter = filter ?? state.filter;
    state = VideoSearchState(
      isLoading: true,
      query: query,
      filter: searchFilter,
    );

    try {
      final response = await _repository.searchVideos(
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
      final response = await _repository.searchVideos(
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

  Future<void> applyFilter(VideoFilter filter) async {
    if (state.query.isNotEmpty) {
      await search(state.query, filter: filter);
    } else {
      state = state.copyWith(filter: filter);
    }
  }

  Future<void> toggleSave(VideoItem item) async {
    try {
      await _repository.toggleSave(item);

      final updatedItems = state.items.map((i) {
        if (i.identifier == item.identifier) {
          return i.copyWith(isSaved: !i.isSaved);
        }
        return i;
      }).toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> toggleLike(VideoItem item) async {
    try {
      await _repository.toggleLike(item);

      final updatedItems = state.items.map((i) {
        if (i.identifier == item.identifier) {
          return i.copyWith(isLiked: !i.isLiked);
        }
        return i;
      }).toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> refresh() async {
    if (state.query.isNotEmpty) {
      await search(state.query, filter: state.filter);
    }
  }

  /// Load all Hindi movies from the Archive.
  Future<void> loadTodayArchive() async {
    final query =
        'mediatype:movies AND '
        '(language:hindi OR language:hin OR title:"hindi dubbed" '
        'OR title:hindi OR description:"hindi dubbed" OR description:hindi '
        'OR subject:"hindi dubbed" OR subject:hindi)';
    await search(query);
  }

  void clearError() {
    state = state.copyWith(error: null);
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

final videoSearchProvider =
    NotifierProvider<VideoSearchNotifier, VideoSearchState>(
      VideoSearchNotifier.new,
    );

// ============ Liked Videos Provider ============

final likedVideosProvider = FutureProvider<List<VideoItem>>((ref) async {
  final repository = ref.watch(videoRepositoryProvider);
  return await repository.getLikedVideos();
});

// ============ Saved Videos Provider ============

final savedVideosProvider = FutureProvider<List<VideoItem>>((ref) async {
  final repository = ref.watch(videoRepositoryProvider);
  return await repository.getSavedVideos();
});

// ============ Video Metadata Provider ============

final videoMetadataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((
      ref,
      identifier,
    ) async {
      final repository = ref.watch(videoRepositoryProvider);
      return await repository.getVideoMetadata(identifier);
    });

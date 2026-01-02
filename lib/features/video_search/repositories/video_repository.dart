import '../../../../core/errors/app_exceptions.dart';
import '../datasources/video_local_datasource.dart';
import '../datasources/video_remote_datasource.dart';
import '../models/video_filter.dart';
import '../models/video_item.dart';
import '../models/video_search_response.dart';

abstract class VideoRepository {
  Future<VideoSearchResponse> searchVideos({
    required String query,
    int page = 1,
    VideoFilter? filter,
  });
  Future<void> toggleLike(VideoItem item);
  Future<bool> isLiked(String identifier);
  Future<List<VideoItem>> getLikedVideos();
  Future<Set<String>> getLikedIdentifiers();
  Future<Map<String, dynamic>> getVideoMetadata(String identifier);
}

class VideoRepositoryImpl implements VideoRepository {
  final VideoRemoteDataSource _remoteDataSource;
  final VideoLocalDataSource _localDataSource;

  VideoRepositoryImpl({
    required VideoRemoteDataSource remoteDataSource,
    required VideoLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  @override
  Future<VideoSearchResponse> searchVideos({
    required String query,
    int page = 1,
    VideoFilter? filter,
  }) async {
    try {
      final response = await _remoteDataSource.searchVideos(
        query: query,
        page: page,
        filter: filter,
      );

      // Get liked identifiers to mark items as liked
      final likedIds = await _localDataSource.getLikedIdentifiers();

      // Update items with liked status
      final updatedItems = response.items.map((item) {
        return item.copyWith(isLiked: likedIds.contains(item.identifier));
      }).toList();

      return VideoSearchResponse(
        numFound: response.numFound,
        start: response.start,
        items: updatedItems,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(
        message: 'Failed to search videos',
        originalError: e,
      );
    }
  }

  @override
  Future<void> toggleLike(VideoItem item) async {
    try {
      final isCurrentlyLiked = await _localDataSource.isLiked(item.identifier);

      if (isCurrentlyLiked) {
        await _localDataSource.unlikeItem(item.identifier);
      } else {
        await _localDataSource.likeItem(item);
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException(
        message: 'Failed to update like status',
        originalError: e,
      );
    }
  }

  @override
  Future<bool> isLiked(String identifier) async {
    try {
      return await _localDataSource.isLiked(identifier);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<VideoItem>> getLikedVideos() async {
    try {
      return await _localDataSource.getLikedItems();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException(
        message: 'Failed to get liked videos',
        originalError: e,
      );
    }
  }

  @override
  Future<Set<String>> getLikedIdentifiers() async {
    try {
      return await _localDataSource.getLikedIdentifiers();
    } catch (e) {
      return {};
    }
  }

  @override
  Future<Map<String, dynamic>> getVideoMetadata(String identifier) async {
    try {
      return await _remoteDataSource.getVideoMetadata(identifier);
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(
        message: 'Failed to get video metadata',
        originalError: e,
      );
    }
  }
}

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

  Future<void> toggleSave(VideoItem item);
  Future<bool> isSaved(String identifier);
  Future<List<VideoItem>> getSavedVideos();
  Future<Set<String>> getSavedIdentifiers();

  Future<Map<String, dynamic>> getVideoMetadata(String identifier);
  Future<VideoSearchResponse> getRelatedVideos({
    required String identifier,
    String? collection,
    String? subject,
    String? creator,
  });
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

      // Get saved and liked identifiers to mark items
      final savedIds = await _localDataSource.getSavedIdentifiers();
      final likedIds = await _localDataSource.getLikedIdentifiers();

      // Update items with saved and liked status
      final updatedItems = response.items.map((item) {
        return item.copyWith(
          isSaved: savedIds.contains(item.identifier),
          isLiked: likedIds.contains(item.identifier),
        );
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
      final isCurrentlyLiked = await _localDataSource.isLiked(
        item.identifier,
        mediatype: item.mediaType,
      );

      if (isCurrentlyLiked) {
        await _localDataSource.unlikeItem(
          item.identifier,
          mediatype: item.mediaType,
        );
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
  Future<void> toggleSave(VideoItem item) async {
    try {
      final isCurrentlySaved = await _localDataSource.isSaved(
        item.identifier,
        mediatype: item.mediaType,
      );

      if (isCurrentlySaved) {
        await _localDataSource.unsaveItem(
          item.identifier,
          mediatype: item.mediaType,
        );
      } else {
        await _localDataSource.saveItem(item);
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException(
        message: 'Failed to update save status',
        originalError: e,
      );
    }
  }

  @override
  Future<bool> isSaved(String identifier) async {
    try {
      return await _localDataSource.isSaved(identifier);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<VideoItem>> getSavedVideos() async {
    try {
      return await _localDataSource.getSavedItems();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException(
        message: 'Failed to get saved videos',
        originalError: e,
      );
    }
  }

  @override
  Future<Set<String>> getSavedIdentifiers() async {
    try {
      return await _localDataSource.getSavedIdentifiers();
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

  @override
  Future<VideoSearchResponse> getRelatedVideos({
    required String identifier,
    String? collection,
    String? subject,
    String? creator,
  }) async {
    try {
      final response = await _remoteDataSource.searchRelatedVideos(
        identifier: identifier,
        collection: collection,
        subject: subject,
        creator: creator,
      );

      // Mark saved and liked items
      final savedIds = await _localDataSource.getSavedIdentifiers();
      final likedIds = await _localDataSource.getLikedIdentifiers();
      final updatedItems = response.items.map((item) {
        return item.copyWith(
          isSaved: savedIds.contains(item.identifier),
          isLiked: likedIds.contains(item.identifier),
        );
      }).toList();

      return VideoSearchResponse(
        numFound: response.numFound,
        start: response.start,
        items: updatedItems,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(
        message: 'Failed to get related videos',
        originalError: e,
      );
    }
  }
}

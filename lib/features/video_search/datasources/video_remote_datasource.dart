import '../../../../core/constants/archive_constants.dart';
import '../../../../core/networks/network_service.dart';
import '../../documents/models/search_filter.dart';
import '../models/video_filter.dart';
import '../models/video_search_response.dart';

abstract class VideoRemoteDataSource {
  Future<VideoSearchResponse> searchVideos({
    required String query,
    int page = 1,
    int pageSize = ArchiveConstants.defaultPageSize,
    VideoFilter? filter,
  });

  Future<Map<String, dynamic>> getVideoMetadata(String identifier);
}

class VideoRemoteDataSourceImpl implements VideoRemoteDataSource {
  final NetworkService _networkService;

  VideoRemoteDataSourceImpl({required NetworkService networkService})
    : _networkService = networkService;

  @override
  Future<VideoSearchResponse> searchVideos({
    required String query,
    int page = 1,
    int pageSize = ArchiveConstants.defaultPageSize,
    VideoFilter? filter,
  }) async {
    // Build search query
    final queryParts = <String>[];

    // Add main search query
    if (query.isNotEmpty) {
      queryParts.add(query);
    }

    // Add media type filter for videos
    queryParts.add('mediatype:${ArchiveConstants.mediaTypeVideo}');

    // Add language filter
    if (filter != null && filter.language.code.isNotEmpty) {
      queryParts.add('language:${filter.language.code}');
    }

    // Add category/collection filter
    if (filter != null && filter.category.collectionQuery != null) {
      queryParts.add(filter.category.collectionQuery!);
    }

    // Add year range filter
    if (filter != null) {
      final startYear = filter.startYear;
      final endYear = filter.endYear;

      if (startYear != null && endYear != null) {
        queryParts.add('year:[$startYear TO $endYear]');
      } else if (startYear != null) {
        queryParts.add('year:[$startYear TO *]');
      } else if (endYear != null) {
        queryParts.add('year:[* TO $endYear]');
      }
    }

    // Add downloads filter
    if (filter != null && filter.minDownloads != null) {
      queryParts.add('downloads:[${filter.minDownloads} TO *]');
    }

    final searchQuery = queryParts.join(' AND ');

    // Determine sort order
    String sortOrder = 'downloads desc';
    if (filter != null && filter.sortOption.apiValue.isNotEmpty) {
      sortOrder = filter.sortOption.apiValue;
    }

    // Extended fields for video
    final videoFields = [
      'identifier',
      'title',
      'description',
      'creator',
      'date',
      'mediatype',
      'downloads',
      'item_size',
      'format',
      'runtime',
      'length',
      'subject',
      'collection',
      'language',
      'year',
    ];

    final queryParams = {
      'q': searchQuery,
      'output': 'json',
      'rows': pageSize.toString(),
      'page': page.toString(),
      'fl[]': videoFields.join(','),
      'sort': sortOrder,
    };

    final url =
        '${ArchiveConstants.archiveBaseUrl}${ArchiveConstants.advancedSearchPath}';

    final response = await _networkService.get(url, queryParams: queryParams);

    return VideoSearchResponse.fromJson(response);
  }

  @override
  Future<Map<String, dynamic>> getVideoMetadata(String identifier) async {
    final url =
        '${ArchiveConstants.archiveBaseUrl}${ArchiveConstants.metadataPath}/$identifier';

    return await _networkService.get(url);
  }
}

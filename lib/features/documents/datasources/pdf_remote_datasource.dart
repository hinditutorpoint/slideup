import '../../../../core/constants/archive_constants.dart';
import '../../../../core/networks/network_service.dart';
import '../models/search_filter.dart';
import '../models/search_response.dart';
import '../models/pdf_metadata.dart';

abstract class PdfRemoteDataSource {
  Future<SearchResponse> searchPdfs({
    required String query,
    int page = 1,
    int pageSize = ArchiveConstants.defaultPageSize,
    SearchFilter? filter,
  });

  Future<PdfMetadata> getPdfMetadata(String identifier);
}

class PdfRemoteDataSourceImpl implements PdfRemoteDataSource {
  final NetworkService _networkService;

  PdfRemoteDataSourceImpl({required NetworkService networkService})
    : _networkService = networkService;

  @override
  Future<SearchResponse> searchPdfs({
    required String query,
    int page = 1,
    int pageSize = ArchiveConstants.defaultPageSize,
    SearchFilter? filter,
  }) async {
    // Build search query
    final queryParts = <String>[];

    // Add main search query
    if (query.isNotEmpty) {
      queryParts.add(query);
    }

    // Add media type filter for PDFs
    queryParts.add('mediatype:${ArchiveConstants.mediaTypePdf}');

    // Add language filter
    if (filter != null && filter.language.code.isNotEmpty) {
      queryParts.add('language:${filter.language.code}');
    }

    // Add year range filter
    if (filter != null) {
      final startYear = filter.startYear;
      final endYear = filter.endYear;

      if (startYear != null && endYear != null) {
        queryParts.add('date:[$startYear TO $endYear]');
      } else if (startYear != null) {
        queryParts.add('date:[$startYear TO *]');
      } else if (endYear != null) {
        queryParts.add('date:[* TO $endYear]');
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

    final queryParams = {
      'q': searchQuery,
      'output': 'json',
      'rows': pageSize.toString(),
      'page': page.toString(),
      'fl[]': ApiFields.searchFields.join(','),
      'sort': sortOrder,
    };

    final url =
        '${ArchiveConstants.archiveBaseUrl}${ArchiveConstants.advancedSearchPath}';

    final response = await _networkService.get(url, queryParams: queryParams);

    return SearchResponse.fromJson(response);
  }

  @override
  Future<PdfMetadata> getPdfMetadata(String identifier) async {
    final url =
        '${ArchiveConstants.archiveBaseUrl}${ArchiveConstants.metadataPath}/$identifier';
    final response = await _networkService.get(url);
    return PdfMetadata.fromJson(response);
  }
}

import '../../../../core/constants/archive_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../models/archive_item.dart';

abstract class PdfLocalDataSource {
  Future<void> likeItem(ArchiveItem item);
  Future<void> unlikeItem(String identifier);
  Future<bool> isLiked(String identifier);
  Future<List<ArchiveItem>> getLikedItems({String? mediaType});
  Future<Set<String>> getLikedIdentifiers();
}

class PdfLocalDataSourceImpl implements PdfLocalDataSource {
  final DatabaseHelper _databaseHelper;

  PdfLocalDataSourceImpl({required DatabaseHelper databaseHelper})
    : _databaseHelper = databaseHelper;

  @override
  Future<void> likeItem(ArchiveItem item) async {
    final likeAt = DateTime.now().toString();
    await _databaseHelper.insert(ArchiveConstants.likedItemsTable, {
      'identifier': item.identifier,
      'title': item.title,
      'description': item.description,
      'creator': item.creator,
      'date': item.date,
      'mediatype': item.mediaType,
      'downloads': item.downloads,
      'item_size': item.itemSize,
      'thumbnail_url': item.thumbnailUrl,
      'liked_at': likeAt,
      'format': item.format,
    });
  }

  @override
  Future<void> unlikeItem(String identifier) async {
    await _databaseHelper.delete(
      ArchiveConstants.likedItemsTable,
      where: 'identifier = ?',
      whereArgs: [identifier],
    );
  }

  @override
  Future<bool> isLiked(String identifier) async {
    return await _databaseHelper.exists(
      ArchiveConstants.likedItemsTable,
      'identifier',
      identifier,
    );
  }

  @override
  Future<List<ArchiveItem>> getLikedItems({String? mediaType}) async {
    final results = await _databaseHelper.query(
      ArchiveConstants.likedItemsTable,
      where: mediaType != null ? 'mediatype = ?' : null,
      whereArgs: mediaType != null ? [mediaType] : null,
      orderBy: 'liked_at DESC',
    );

    return results.map((map) => ArchiveItem.fromDbMap(map)).toList();
  }

  @override
  Future<Set<String>> getLikedIdentifiers() async {
    final results = await _databaseHelper.query(
      ArchiveConstants.likedItemsTable,
    );

    return results.map((map) => map['identifier'] as String).toSet();
  }
}

import '../../../../core/constants/archive_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../models/video_item.dart';

abstract class VideoLocalDataSource {
  Future<void> likeItem(VideoItem item);
  Future<void> unlikeItem(String identifier);
  Future<bool> isLiked(String identifier);
  Future<List<VideoItem>> getLikedItems();
  Future<Set<String>> getLikedIdentifiers();
}

class VideoLocalDataSourceImpl implements VideoLocalDataSource {
  final DatabaseHelper _databaseHelper;

  VideoLocalDataSourceImpl({required DatabaseHelper databaseHelper})
    : _databaseHelper = databaseHelper;

  @override
  Future<void> likeItem(VideoItem item) async {
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
  Future<List<VideoItem>> getLikedItems() async {
    final results = await _databaseHelper.query(
      ArchiveConstants.likedItemsTable,
      where: 'mediatype = ?',
      whereArgs: [ArchiveConstants.mediaTypeVideo],
      orderBy: 'liked_at DESC',
    );

    return results.map((map) => VideoItem.fromDbMap(map)).toList();
  }

  @override
  Future<Set<String>> getLikedIdentifiers() async {
    final results = await _databaseHelper.query(
      ArchiveConstants.likedItemsTable,
      where: 'mediatype = ?',
      whereArgs: [ArchiveConstants.mediaTypeVideo],
    );

    return results.map((map) => map['identifier'] as String).toSet();
  }
}

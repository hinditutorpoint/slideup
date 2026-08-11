import '../../../../core/constants/archive_constants.dart';
import '../../../../core/database/database_helper.dart';
import '../models/video_item.dart';

abstract class VideoLocalDataSource {
  Future<void> likeItem(VideoItem item);
  Future<void> unlikeItem(String identifier, {String mediatype = ''});
  Future<bool> isLiked(String identifier, {String mediatype = ''});
  Future<List<VideoItem>> getLikedItems();
  Future<Set<String>> getLikedIdentifiers();

  Future<void> saveItem(VideoItem item);
  Future<void> unsaveItem(String identifier, {String mediatype = ''});
  Future<bool> isSaved(String identifier, {String mediatype = ''});
  Future<List<VideoItem>> getSavedItems();
  Future<Set<String>> getSavedIdentifiers();
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
  Future<void> unlikeItem(String identifier, {String mediatype = ''}) async {
    await _databaseHelper.delete(
      ArchiveConstants.likedItemsTable,
      where: 'identifier = ? AND mediatype = ?',
      whereArgs: [identifier, mediatype],
    );
  }

  @override
  Future<bool> isLiked(String identifier, {String mediatype = ''}) async {
    final results = await _databaseHelper.query(
      ArchiveConstants.likedItemsTable,
      where: 'identifier = ? AND mediatype = ?',
      whereArgs: [identifier, mediatype],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  @override
  Future<List<VideoItem>> getLikedItems() async {
    final results = await _databaseHelper.query(
      ArchiveConstants.likedItemsTable,
      where: 'mediatype = ?',
      whereArgs: [ArchiveConstants.mediaTypeVideo],
      orderBy: 'liked_at DESC',
    );

    return results
        .map((map) => VideoItem.fromDbMap(map).copyWith(isLiked: true))
        .toList();
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

  @override
  Future<void> saveItem(VideoItem item) async {
    final saveAt = DateTime.now().toString();
    await _databaseHelper.insert(ArchiveConstants.savedItemsTable, {
      'identifier': item.identifier,
      'title': item.title,
      'description': item.description,
      'creator': item.creator,
      'date': item.date,
      'mediatype': item.mediaType,
      'downloads': item.downloads,
      'item_size': item.itemSize,
      'thumbnail_url': item.thumbnailUrl,
      'saved_at': saveAt,
      'format': item.format,
    });
  }

  @override
  Future<void> unsaveItem(String identifier, {String mediatype = ''}) async {
    await _databaseHelper.delete(
      ArchiveConstants.savedItemsTable,
      where: 'identifier = ? AND mediatype = ?',
      whereArgs: [identifier, mediatype],
    );
  }

  @override
  Future<bool> isSaved(String identifier, {String mediatype = ''}) async {
    final results = await _databaseHelper.query(
      ArchiveConstants.savedItemsTable,
      where: 'identifier = ? AND mediatype = ?',
      whereArgs: [identifier, mediatype],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  @override
  Future<List<VideoItem>> getSavedItems() async {
    final results = await _databaseHelper.query(
      ArchiveConstants.savedItemsTable,
      where: 'mediatype = ?',
      whereArgs: [ArchiveConstants.mediaTypeVideo],
      orderBy: 'saved_at DESC',
    );

    // Using fromDbMap as it sets the basic fields.
    // We'll need to set isSaved
    return results
        .map((map) => VideoItem.fromDbMap(map).copyWith(isSaved: true))
        .toList();
  }

  @override
  Future<Set<String>> getSavedIdentifiers() async {
    final results = await _databaseHelper.query(
      ArchiveConstants.savedItemsTable,
      where: 'mediatype = ?',
      whereArgs: [ArchiveConstants.mediaTypeVideo],
    );

    return results.map((map) => map['identifier'] as String).toSet();
  }
}

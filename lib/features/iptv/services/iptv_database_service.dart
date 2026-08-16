import 'package:sqflite/sqflite.dart';

import '../../../services/database_service.dart';
import '../models/iptv_models.dart';

/// Persistence layer for IPTV playlists & channels (sqflite via DatabaseService).
class IptvDatabaseService {
  static final IptvDatabaseService instance = IptvDatabaseService._init();

  IptvDatabaseService._init();

  Future<Database> get _database async => await DatabaseService.instance.database;

  // ─── Playlists ────────────────────────────────────────────────────────────

  Future<void> upsertPlaylist(IptvPlaylist playlist) async {
    final db = await _database;
    await db.insert(
      'iptv_playlists',
      playlist.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<IptvPlaylist>> getAllPlaylists() async {
    final db = await _database;
    final result = await db.query(
      'iptv_playlists',
      orderBy: 'createdAt DESC',
    );
    return result.map((j) => IptvPlaylist.fromJson(j)).toList();
  }

  Future<IptvPlaylist?> getPlaylist(String id) async {
    final db = await _database;
    final result = await db.query(
      'iptv_playlists',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return IptvPlaylist.fromJson(result.first);
  }

  Future<void> deletePlaylist(String id) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('iptv_channels', where: 'playlistId = ?', whereArgs: [id]);
      await txn.delete('iptv_playlists', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ─── Channels ─────────────────────────────────────────────────────────────

  Future<void> replaceChannels(String playlistId, List<IptvChannel> channels) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('iptv_channels', where: 'playlistId = ?', whereArgs: [playlistId]);
      for (var i = 0; i < channels.length; i++) {
        await txn.insert(
          'iptv_channels',
          channels[i].toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<IptvChannel>> getChannels(String playlistId) async {
    final db = await _database;
    final result = await db.query(
      'iptv_channels',
      where: 'playlistId = ?',
      whereArgs: [playlistId],
      orderBy: 'position ASC',
    );
    return result.map((j) => IptvChannel.fromJson(j)).toList();
  }

  Future<List<IptvChannel>> getChannelsByGroup(
    String playlistId,
    String group,
  ) async {
    final db = await _database;
    final result = await db.query(
      'iptv_channels',
      where: 'playlistId = ? AND grp = ?',
      whereArgs: [playlistId, group],
      orderBy: 'position ASC',
    );
    return result.map((j) => IptvChannel.fromJson(j)).toList();
  }

  Future<List<IptvChannel>> searchChannels(String playlistId, String query) async {
    final db = await _database;
    final result = await db.query(
      'iptv_channels',
      where: 'playlistId = ? AND (name LIKE ? OR tvgName LIKE ?)',
      whereArgs: [playlistId, '%$query%', '%$query%'],
      orderBy: 'position ASC',
      limit: 200,
    );
    return result.map((j) => IptvChannel.fromJson(j)).toList();
  }

  Future<List<String>> getGroups(String playlistId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT grp FROM iptv_channels WHERE playlistId = ? GROUP BY grp ORDER BY grp ASC',
      [playlistId],
    );
    return result.map((r) => r['grp'] as String).toList();
  }

  Future<void> toggleFavoriteChannel(String channelId) async {
    final db = await _database;
    final result = await db.query(
      'iptv_channels',
      where: 'id = ?',
      whereArgs: [channelId],
      limit: 1,
    );
    if (result.isEmpty) return;
    final channel = IptvChannel.fromJson(result.first);
    await db.update(
      'iptv_channels',
      {'isFavorite': channel.isFavorite ? 0 : 1},
      where: 'id = ?',
      whereArgs: [channelId],
    );
  }

  Future<List<IptvChannel>> getFavoriteChannels() async {
    final db = await _database;
    final result = await db.query(
      'iptv_channels',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return result.map((j) => IptvChannel.fromJson(j)).toList();
  }
}
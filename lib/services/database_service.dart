import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/media_file.dart';
import '../models/playlist.dart';
import '../models/recent_file.dart';
import '../models/url_history.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('slideup_media.db');
    return _database!;
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      singleInstance: true,
    ).then((db) async {
      // Set busy timeout and WAL mode for better concurrency.
      // PRAGMA statements must use rawQuery on Android (execute uses execSQL).
      try {
        await db.rawQuery('PRAGMA busy_timeout = 30000;');
        await db.rawQuery('PRAGMA journal_mode = WAL;');
      } catch (e) {
        debugPrint('Error setting PRAGMA: $e');
      }
      return db;
    });
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const boolType = 'INTEGER NOT NULL';

    // Media Files Table
    await db.execute('''
      CREATE TABLE media_files (
        id $idType,
        name $textType,
        path $textType,
        displayPath TEXT,
        type $intType,
        documentType INTEGER,
        size $intType,
        dateModified $textType,
        dateAdded TEXT,
        mimeType TEXT,
        thumbnailPath TEXT,
        duration INTEGER,
        isLocked $boolType,
        parentFolder TEXT,
        album TEXT,
        artist TEXT,
        genre TEXT,
        year INTEGER,
        height INTEGER,
        width INTEGER,
        isSelected $boolType,
        isFavorite $boolType
      )
    ''');

    // Playlists Table
    await db.execute('''
      CREATE TABLE playlists (
        id $idType,
        name $textType,
        description TEXT,
        createdAt $textType,
        updatedAt $textType,
        mediaIds TEXT,
        thumbnailPath TEXT,
        isLocked $boolType,
        passwordHash TEXT
      )
    ''');

    // URL History Table
    await db.execute('''
      CREATE TABLE url_history (
        id $idType,
        url $textType,
        title TEXT,
        mimeType TEXT,
        mediaType $intType,
        lastPlayed $textType,
        playCount $intType,
        isFavorite $boolType
      )
    ''');

    // Recent Files Table
    await db.execute('''
      CREATE TABLE recent_files (
        id $idType,
        mediaId $textType,
        lastAccessed $textType,
        lastPosition INTEGER,
        accessCount $intType
      )
    ''');

    // Bookmarks Table (for PDF and video)
    await db.execute('''
      CREATE TABLE bookmarks (
        id $idType,
        mediaId $textType,
        position INTEGER,
        pageNumber INTEGER,
        title TEXT,
        createdAt $textType
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_media_type ON media_files(type)');
    await db.execute('CREATE INDEX idx_media_path ON media_files(path)');
    await db.execute(
      'CREATE INDEX idx_recent_accessed ON recent_files(lastAccessed DESC)',
    );
    await db.execute('''
      CREATE INDEX idx_url_history_lastPlayed ON url_history(lastPlayed DESC)
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add URL History Table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS url_history (
          id TEXT PRIMARY KEY,
          url TEXT NOT NULL,
          title TEXT,
          mimeType TEXT,
          mediaType INTEGER NOT NULL,
          lastPlayed TEXT NOT NULL,
          playCount INTEGER NOT NULL,
          isFavorite INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_url_history_lastPlayed ON url_history(lastPlayed DESC)
      ''');
    }
  }

  // Media File Operations
  Future<void> insertMediaFile(MediaFile file) async {
    final db = await database;
    await db.insert(
      'media_files',
      file.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertMediaFiles(List<MediaFile> files) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        for (var file in files) {
          await txn.insert(
            'media_files',
            file.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      debugPrint('Error inserting media files: $e');
      rethrow;
    }
  }

  Future<List<MediaFile>> getAllMediaFiles() async {
    final db = await database;
    final result = await db.query('media_files');
    return result.map((json) => MediaFile.fromJson(json)).toList();
  }

  Future<List<MediaFile>> getMediaFilesByType(MediaType type) async {
    final db = await database;
    final result = await db.query(
      'media_files',
      where: 'type = ?',
      whereArgs: [type.index],
      orderBy: 'dateModified DESC',
    );
    return result.map((json) => MediaFile.fromJson(json)).toList();
  }

  Future<MediaFile?> getMediaFileById(String id) async {
    final db = await database;
    final result = await db.query(
      'media_files',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return MediaFile.fromJson(result.first);
  }

  Future<MediaFile?> getMediaFileByPath(String filePath) async {
    final db = await instance.database;
    final maps = await db.query(
      'media_files',
      where: 'path = ?',
      whereArgs: [filePath],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return MediaFile.fromJson(maps.first);
    }
    return null;
  }

  Future<List<MediaFile>> getFavoriteMediaFiles() async {
    final db = await database;
    final result = await db.query(
      'media_files',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'dateAdded DESC',
    );
    return result.map((json) => MediaFile.fromJson(json)).toList();
  }

  Future<List<MediaFile>> getRecentMediaFiles() async {
    final db = await database;
    final result = await db.query(
      'media_files',
      orderBy: 'lastAccessed DESC',
      limit: 10,
    );
    return result.map((json) => MediaFile.fromJson(json)).toList();
  }

  Future<List<MediaFile>> getRecentMediaFilesByType(MediaType type) async {
    final db = await database;
    final result = await db.query(
      'media_files',
      where: 'type = ?',
      whereArgs: [type.index],
      orderBy: 'lastAccessed DESC',
      limit: 10,
    );
    return result.map((json) => MediaFile.fromJson(json)).toList();
  }

  Future<void> toggleFavoriteMediaFile(String id, MediaFile? mediaFile) async {
    final db = await database;
    final mediaFile = await getMediaFileById(id);
    if (mediaFile != null) {
      await db.update(
        'media_files',
        {'isFavorite': !mediaFile.isFavorite},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await insertMediaFile(mediaFile!);
    }
  }

  Future<bool> isMediaFileFavorite(String id) async {
    final db = await database;
    final result = await db.query(
      'media_files',
      where: 'id = ? AND isFavorite = ?',
      whereArgs: [id, 1],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> updateMediaFile(MediaFile file) async {
    final db = await database;
    await db.update(
      'media_files',
      file.toJson(),
      where: 'id = ?',
      whereArgs: [file.id],
    );
  }

  Future<void> deleteMediaFile(String id) async {
    final db = await database;
    await db.delete('media_files', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete multiple media files by IDs
  Future<void> deleteMediaFiles(List<String> ids) async {
    final db = await database;
    final batch = db.batch();

    for (final id in ids) {
      batch.delete('media_files', where: 'id = ?', whereArgs: [id]);
    }

    await batch.commit(noResult: true);
  }

  /// Delete media file by path
  Future<void> deleteMediaFileByPath(String path) async {
    final db = await database;
    await db.delete('media_files', where: 'path = ?', whereArgs: [path]);
  }

  Future<void> clearMediaFiles() async {
    final db = await database;
    await db.delete('media_files');
  }

  // Playlist Operations
  Future<void> insertPlaylist(Playlist playlist) async {
    final db = await database;
    await db.insert(
      'playlists',
      playlist.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Playlist>> getAllPlaylists() async {
    final db = await database;
    final result = await db.query('playlists', orderBy: 'updatedAt DESC');
    return result.map((json) => Playlist.fromJson(json)).toList();
  }

  Future<Playlist?> getPlaylistById(String id) async {
    final db = await database;
    final result = await db.query(
      'playlists',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Playlist.fromJson(result.first);
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    final db = await database;
    await db.update(
      'playlists',
      playlist.toJson(),
      where: 'id = ?',
      whereArgs: [playlist.id],
    );
  }

  Future<void> deletePlaylist(String id) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  // Recent Files Operations
  Future<void> insertOrUpdateRecentFile(RecentFile recentFile) async {
    final db = await database;
    final existing = await db.query(
      'recent_files',
      where: 'mediaId = ?',
      whereArgs: [recentFile.mediaId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final existingFile = RecentFile.fromJson(existing.first);
      final updated = existingFile.copyWith(
        lastAccessed: recentFile.lastAccessed,
        lastPosition: recentFile.lastPosition,
        accessCount: existingFile.accessCount + 1,
      );
      await db.update(
        'recent_files',
        updated.toJson(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );
    } else {
      await db.insert(
        'recent_files',
        recentFile.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<RecentFile>> getRecentFiles({int limit = 50}) async {
    final db = await database;
    final result = await db.query(
      'recent_files',
      orderBy: 'lastAccessed DESC',
      limit: limit,
    );
    return result.map((json) => RecentFile.fromJson(json)).toList();
  }

  Future<void> deleteRecentFile(String id) async {
    final db = await database;
    await db.delete('recent_files', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearRecentFiles() async {
    final db = await database;
    await db.delete('recent_files');
  }

  // URL History Methods
  Future<void> saveUrlHistory(UrlHistory urlHistory) async {
    final db = await database;
    await db.insert(
      'url_history',
      urlHistory.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateUrlHistory(UrlHistory urlHistory) async {
    final db = await database;
    await db.update(
      'url_history',
      urlHistory.toJson(),
      where: 'id = ?',
      whereArgs: [urlHistory.id],
    );
  }

  Future<List<UrlHistory>> getUrlHistory({int limit = 50}) async {
    final db = await database;
    final result = await db.query(
      'url_history',
      orderBy: 'lastPlayed DESC',
      limit: limit,
    );
    return result.map((json) => UrlHistory.fromJson(json)).toList();
  }

  Future<List<UrlHistory>> getFavoriteUrls() async {
    final db = await database;
    final result = await db.query(
      'url_history',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'lastPlayed DESC',
    );
    return result.map((json) => UrlHistory.fromJson(json)).toList();
  }

  Future<UrlHistory?> getUrlHistoryByUrl(String url) async {
    final db = await database;
    final result = await db.query(
      'url_history',
      where: 'url = ?',
      whereArgs: [url],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return UrlHistory.fromJson(result.first);
  }

  Future<void> deleteUrlHistory(String id) async {
    final db = await database;
    await db.delete('url_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearUrlHistory() async {
    final db = await database;
    await db.delete('url_history');
  }

  Future<void> close() async {
    await closeDatabase();
  }
}

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/archive_constants.dart';
import '../errors/app_exceptions.dart' as ae;

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, ArchiveConstants.databaseName);

      return await openDatabase(
        path,
        version: ArchiveConstants.databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      throw ae.DatabaseException(
        message: 'Failed to initialize database',
        originalError: e,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Liked Items Table
    await db.execute('''
      CREATE TABLE ${ArchiveConstants.likedItemsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        identifier TEXT UNIQUE NOT NULL,
        title TEXT,
        description TEXT,
        creator TEXT,
        date TEXT,
        mediatype TEXT,
        downloads INTEGER DEFAULT 0,
        item_size INTEGER DEFAULT 0,
        thumbnail_url TEXT,
        liked_at TEXT NOT NULL,
        format TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${ArchiveConstants.downloadsTable} (
        id TEXT PRIMARY KEY,
        identifier TEXT NOT NULL,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT,
        thumbnail_url TEXT,
        total_bytes INTEGER DEFAULT 0,
        downloaded_bytes INTEGER DEFAULT 0,
        status INTEGER DEFAULT 0,
        error TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        media_type TEXT NOT NULL
      )
    ''');

    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_liked_items_identifier 
      ON ${ArchiveConstants.likedItemsTable} (identifier)
    ''');

    await db.execute('''
      CREATE INDEX idx_liked_items_mediatype 
      ON ${ArchiveConstants.likedItemsTable} (mediatype)
    ''');

    await db.execute('''
      CREATE INDEX idx_downloads_status 
      ON ${ArchiveConstants.downloadsTable} (status)
    ''');

    await db.execute('''
      CREATE INDEX idx_downloads_identifier 
      ON ${ArchiveConstants.downloadsTable} (identifier)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < 2) {
      // Migration for version 2
    }
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    try {
      final db = await database;
      return await db.insert(
        table,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw ae.DatabaseException(
        message: 'Failed to insert data',
        originalError: e,
      );
    }
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await database;
      return await db.query(
        table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw ae.DatabaseException(
        message: 'Failed to query data',
        originalError: e,
      );
    }
  }

  Future<Map<String, dynamic>?> getById(String table, String id) async {
    try {
      final db = await database;
      final result = await db.query(
        table,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      throw ae.DatabaseException(
        message: 'Failed to get by id',
        originalError: e,
      );
    }
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    try {
      final db = await database;
      return await db.delete(table, where: where, whereArgs: whereArgs);
    } catch (e) {
      throw ae.DatabaseException(
        message: 'Failed to delete data',
        originalError: e,
      );
    }
  }

  Future<bool> exists(String table, String column, dynamic value) async {
    try {
      final db = await database;
      final result = await db.query(
        table,
        where: '$column = ?',
        whereArgs: [value],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      throw ae.DatabaseException(
        message: 'Failed to check existence',
        originalError: e,
      );
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

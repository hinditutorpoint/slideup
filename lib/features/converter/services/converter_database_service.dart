import 'package:sqflite/sqflite.dart';

import '../../../services/database_service.dart';
import '../models/conversion_job.dart';
import '../models/conversion_models.dart';
import '../models/converter_preset.dart';
import 'converter_constants.dart';

/// Persists conversion jobs and presets in the shared app database
/// (`slideup_media.db`, tables created at version 3).
class ConverterDatabaseService {
  ConverterDatabaseService._();

  static final ConverterDatabaseService instance = ConverterDatabaseService._();

  Future<Database> get _db => DatabaseService.instance.database;

  // ─────────────────────────────── Jobs ───────────────────────────────

  Future<void> upsertJob(ConversionJob job) async {
    final db = await _db;
    await db.insert(
      ConverterConstants.dbTableJobs,
      job.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ConversionJob>> getAllJobs() async {
    final db = await _db;
    final rows = await db.query(
      ConverterConstants.dbTableJobs,
      orderBy: 'queuedAt DESC',
    );
    return rows.map((r) => ConversionJob.fromJson(r)).toList();
  }

  Future<List<ConversionJob>> getActiveJobs() async {
    final db = await _db;
    final rows = await db.query(
      ConverterConstants.dbTableJobs,
      where: 'status IN (?, ?, ?)',
      whereArgs: [
        ConversionStatus.pending.index,
        ConversionStatus.queued.index,
        ConversionStatus.processing.index,
      ],
      orderBy: 'queuedAt ASC',
    );
    return rows.map((r) => ConversionJob.fromJson(r)).toList();
  }

  Future<List<ConversionJob>> getJobsByStatus(ConversionStatus status) async {
    final db = await _db;
    final rows = await db.query(
      ConverterConstants.dbTableJobs,
      where: 'status = ?',
      whereArgs: [status.index],
      orderBy: 'queuedAt DESC',
    );
    return rows.map((r) => ConversionJob.fromJson(r)).toList();
  }

  Future<ConversionJob?> getJob(String id) async {
    final db = await _db;
    final rows = await db.query(
      ConverterConstants.dbTableJobs,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ConversionJob.fromJson(rows.first);
  }

  Future<void> updateJob(ConversionJob job) async {
    final db = await _db;
    await db.update(
      ConverterConstants.dbTableJobs,
      job.toJson(),
      where: 'id = ?',
      whereArgs: [job.id],
    );
  }

  Future<void> deleteJobs(List<String> ids) async {
    final db = await _db;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete(ConverterConstants.dbTableJobs, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearJobs() async {
    final db = await _db;
    await db.delete(ConverterConstants.dbTableJobs);
  }

  Future<int> countJobs() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM ${ConverterConstants.dbTableJobs}');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ───────────────────────────── Presets ─────────────────────────────

  Future<void> upsertPreset(ConverterPreset preset) async {
    final db = await _db;
    await db.insert(
      ConverterConstants.dbTablePresets,
      preset.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ConverterPreset>> getAllPresets() async {
    final db = await _db;
    final rows = await db.query(
      ConverterConstants.dbTablePresets,
      orderBy: 'createdAt ASC',
    );
    return rows.map((r) => ConverterPreset.fromJson(r)).toList();
  }

  Future<void> deletePreset(String id) async {
    final db = await _db;
    await db.delete(ConverterConstants.dbTablePresets, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearPresets() async {
    final db = await _db;
    await db.delete(ConverterConstants.dbTablePresets);
  }
}
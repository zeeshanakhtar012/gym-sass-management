import 'dart:developer';

import '../../../../core/database/database_helper.dart';

class PackageDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> getAll(String gymId) async {
    log('[PackageDao] getAll called gymId=$gymId');
    final db = await _dbHelper.database;
    final results = await db.query('packages', where: 'gym_id = ?', whereArgs: [gymId], orderBy: 'created_at DESC');
    log('[PackageDao] getAll returned ${results.length} rows');
    return results;
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    log('[PackageDao] getById called id=$id');
    final db = await _dbHelper.database;
    final results = await db.query('packages', where: 'package_id = ?', whereArgs: [id]);
    log('[PackageDao] getById found=${results.isNotEmpty}');
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insert(Map<String, dynamic> data) async {
    log('[PackageDao] insert called package_id=${data['package_id']}');
    final db = await _dbHelper.database;
    await db.insert('packages', data);
    log('[PackageDao] insert completed');
  }

  Future<void> update(Map<String, dynamic> data) async {
    log('[PackageDao] update called package_id=${data['package_id']}');
    final db = await _dbHelper.database;
    await db.update('packages', data, where: 'package_id = ?', whereArgs: [data['package_id']]);
    log('[PackageDao] update completed');
  }

  Future<void> delete(String id) async {
    log('[PackageDao] delete called id=$id');
    final db = await _dbHelper.database;
    await db.delete('packages', where: 'package_id = ?', whereArgs: [id]);
    log('[PackageDao] delete completed');
  }
}

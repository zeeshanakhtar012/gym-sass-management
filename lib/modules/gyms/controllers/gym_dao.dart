import 'dart:developer';

import 'package:get/get.dart';
import '../../../core/database/database_helper.dart';

class GymDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> getAll() async {
    log('[GymDao] getAll called');
    final db = await _dbHelper.database;
    final results = await db.query('gyms', orderBy: 'created_at DESC');
    log('[GymDao] getAll returned ${results.length} rows');
    return results;
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    log('[GymDao] getById called id=$id');
    final db = await _dbHelper.database;
    final results = await db.query('gyms', where: 'gym_id = ?', whereArgs: [id]);
    log('[GymDao] getById found=${results.isNotEmpty}');
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insert(Map<String, dynamic> data) async {
    log('[GymDao] insert called gym_id=${data['gym_id']}');
    final db = await _dbHelper.database;
    await db.insert('gyms', data);
    log('[GymDao] insert completed');
  }

  Future<void> update(Map<String, dynamic> data) async {
    log('[GymDao] update called gym_id=${data['gym_id']}');
    final db = await _dbHelper.database;
    await db.update(
      'gyms',
      data,
      where: 'gym_id = ?',
      whereArgs: [data['gym_id']],
    );
    log('[GymDao] update completed');
  }

  Future<void> delete(String id) async {
    log('[GymDao] delete called id=$id');
    final db = await _dbHelper.database;
    await db.delete('gyms', where: 'gym_id = ?', whereArgs: [id]);
    log('[GymDao] delete completed');
  }

  Future<void> toggleStatus(String id) async {
    log('[GymDao] toggleStatus called id=$id');
    final db = await _dbHelper.database;
    final gym = await getById(id);
    if (gym == null) {
      log('[GymDao] toggleStatus - gym not found');
      return;
    }
    final newStatus = gym['status'] == 'active' ? 'paused' : 'active';
    await db.update(
      'gyms',
      {'status': newStatus, 'updated_at': DateTime.now().toIso8601String()},
      where: 'gym_id = ?',
      whereArgs: [id],
    );
    log('[GymDao] toggleStatus - status changed to $newStatus');
  }

  Future<int> getMemberCount(String gymId) async {
    log('[GymDao] getMemberCount called gymId=$gymId');
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM members WHERE gym_id = ?',
      [gymId],
    );
    final count = (result.first['count'] as int?) ?? 0;
    log('[GymDao] getMemberCount returned $count');
    return count;
  }

  Future<Map<String, int>> getStats() async {
    log('[GymDao] getStats called');
    final db = await _dbHelper.database;
    final totalResult = await db.rawQuery('SELECT COUNT(*) as c FROM gyms');
    final activeResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM gyms WHERE status = 'active'",
    );
    final pausedResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM gyms WHERE status = 'paused'",
    );
    final membersResult = await db.rawQuery(
      'SELECT COUNT(*) as c FROM members',
    );
    final stats = {
      'totalGyms': (totalResult.first['c'] as int?) ?? 0,
      'activeGyms': (activeResult.first['c'] as int?) ?? 0,
      'pausedGyms': (pausedResult.first['c'] as int?) ?? 0,
      'totalMembers': (membersResult.first['c'] as int?) ?? 0,
    };
    log('[GymDao] getStats returned $stats');
    return stats;
  }
}

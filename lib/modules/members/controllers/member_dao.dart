import 'dart:developer';
import 'dart:typed_data';

import '../../../../core/database/database_helper.dart';

class MemberDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> getAll(String gymId) async {
    log('[MemberDao] getAll called gymId=$gymId');
    final db = await _dbHelper.database;
    final results = await db.query('members', where: 'gym_id = ?', whereArgs: [gymId], orderBy: 'created_at DESC');
    log('[MemberDao] getAll returned ${results.length} rows');
    return results;
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    log('[MemberDao] getById called id=$id');
    final db = await _dbHelper.database;
    final results = await db.query('members', where: 'member_id = ?', whereArgs: [id]);
    log('[MemberDao] getById found=${results.isNotEmpty}');
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insert(Map<String, dynamic> data) async {
    log('[MemberDao] insert called member_id=${data['member_id']}');
    final db = await _dbHelper.database;
    await db.insert('members', data);
    log('[MemberDao] insert completed');
  }

  Future<void> update(Map<String, dynamic> data) async {
    log('[MemberDao] update called member_id=${data['member_id']}');
    final db = await _dbHelper.database;
    await db.update('members', data, where: 'member_id = ?', whereArgs: [data['member_id']]);
    log('[MemberDao] update completed');
  }

  Future<void> delete(String id) async {
    log('[MemberDao] delete called id=$id');
    final db = await _dbHelper.database;
    await db.delete('members', where: 'member_id = ?', whereArgs: [id]);
    log('[MemberDao] delete completed');
  }

  Future<List<Map<String, dynamic>>> search(String gymId, String query) async {
    log('[MemberDao] search called gymId=$gymId query=$query');
    final db = await _dbHelper.database;
    final q = '%$query%';
    final results = await db.rawQuery(
      'SELECT * FROM members WHERE gym_id = ? AND (full_name LIKE ? OR phone LIKE ? OR cnic LIKE ?) ORDER BY created_at DESC',
      [gymId, q, q, q],
    );
    log('[MemberDao] search returned ${results.length} rows');
    return results;
  }

  Future<List<Map<String, dynamic>>> getByStatus(String gymId, String status) async {
    log('[MemberDao] getByStatus called gymId=$gymId status=$status');
    final db = await _dbHelper.database;
    final results = await db.query('members', where: 'gym_id = ? AND status = ?', whereArgs: [gymId, status], orderBy: 'created_at DESC');
    log('[MemberDao] getByStatus returned ${results.length} rows');
    return results;
  }

  Future<List<Map<String, dynamic>>> getExpiringSoon(String gymId, int days) async {
    log('[MemberDao] getExpiringSoon called gymId=$gymId days=$days');
    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      "SELECT * FROM members WHERE gym_id = ? AND status = 'active' AND expiry_date IS NOT NULL AND expiry_date <= date('now', '+$days days') AND expiry_date >= date('now') ORDER BY expiry_date ASC",
      [gymId],
    );
    log('[MemberDao] getExpiringSoon returned ${results.length} rows');
    return results;
  }

  Future<Map<String, dynamic>?> getByFingerprint(String gymId, Uint8List template) async {
    log('[MemberDao] getByFingerprint called gymId=$gymId');
    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      'SELECT * FROM members WHERE gym_id = ? AND fingerprint_template = ?',
      [gymId, template],
    );
    log('[MemberDao] getByFingerprint found=${results.isNotEmpty}');
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getByPhone(String gymId, String phone) async {
    log('[MemberDao] getByPhone called gymId=$gymId phone=$phone');
    final db = await _dbHelper.database;
    final results = await db.query('members', where: 'gym_id = ? AND phone = ?', whereArgs: [gymId, phone]);
    log('[MemberDao] getByPhone found=${results.isNotEmpty}');
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> getCount(String gymId) async {
    log('[MemberDao] getCount called gymId=$gymId');
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM members WHERE gym_id = ?', [gymId]);
    final count = (result.first['c'] as int?) ?? 0;
    log('[MemberDao] getCount returned $count');
    return count;
  }
}

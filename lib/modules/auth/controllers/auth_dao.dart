import 'dart:developer';

import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';

class AuthDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Map<String, dynamic>?> getSuperAdmin(String username) async {
    log('[AuthDao] getSuperAdmin called with username=$username');
    final db = await _dbHelper.database;
    final results = await db.query(
      'super_admin',
      where: 'username = ?',
      whereArgs: [username],
    );
    log('[AuthDao] getSuperAdmin found=${results.isNotEmpty}');
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getGymByPhone(String phone) async {
    log('[AuthDao] getGymByPhone called with phone=$phone');
    final db = await _dbHelper.database;
    final results = await db.query(
      'gyms',
      where: 'phone = ?',
      whereArgs: [phone],
    );
    log('[AuthDao] getGymByPhone found=${results.isNotEmpty}');
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getGymById(String id) async {
    log('[AuthDao] getGymById called with id=$id');
    final db = await _dbHelper.database;
    final results = await db.query(
      'gyms',
      where: 'gym_id = ?',
      whereArgs: [id],
    );
    log('[AuthDao] getGymById found=${results.isNotEmpty}');
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateSuperAdminPassword(int id, String newHash) async {
    log('[AuthDao] updateSuperAdminPassword called for id=$id');
    final db = await _dbHelper.database;
    await db.update(
      'super_admin',
      {'password_hash': newHash},
      where: 'id = ?',
      whereArgs: [id],
    );
    log('[AuthDao] updateSuperAdminPassword completed');
  }

  Future<void> updateGymPassword(String gymId, String newHash) async {
    log('[AuthDao] updateGymPassword called for gymId=$gymId');
    final db = await _dbHelper.database;
    await db.update(
      'gyms',
      {'password_hash': newHash},
      where: 'gym_id = ?',
      whereArgs: [gymId],
    );
    log('[AuthDao] updateGymPassword completed');
  }

  Future<void> updateSuperAdminMustChangePassword(int id, int value) async {
    log('[AuthDao] updateSuperAdminMustChangePassword called for id=$id value=$value');
    final db = await _dbHelper.database;
    await db.update(
      'super_admin',
      {'must_change_password': value},
      where: 'id = ?',
      whereArgs: [id],
    );
    log('[AuthDao] updateSuperAdminMustChangePassword completed');
  }

  Future<void> saveSession(String sessionJson) async {
    log('[AuthDao] saveSession called');
    final db = await _dbHelper.database;
    await db.insert(
      'app_session',
      {'id': 1, 'session_data': sessionJson, 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    log('[AuthDao] saveSession completed');
  }

  Future<String?> getSession() async {
    log('[AuthDao] getSession called');
    final db = await _dbHelper.database;
    final results = await db.query('app_session', where: 'id = 1');
    log('[AuthDao] getSession found=${results.isNotEmpty}');
    return results.isNotEmpty ? results.first['session_data'] as String? : null;
  }

  Future<void> clearSession() async {
    log('[AuthDao] clearSession called');
    final db = await _dbHelper.database;
    await db.delete('app_session', where: 'id = 1');
    log('[AuthDao] clearSession completed');
  }
}

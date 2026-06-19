import 'dart:developer';

import '../../../../core/database/database_helper.dart';

class AttendanceDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> getAll(String gymId, {String? dateFrom, String? dateTo, String? memberId}) async {
    log('[AttendanceDao] getAll called gymId=$gymId dateFrom=$dateFrom dateTo=$dateTo memberId=$memberId');
    final db = await _dbHelper.database;
    final conditions = <String>['a.gym_id = ?'];
    final args = <dynamic>[gymId];

    if (dateFrom != null) {
      conditions.add('a.date >= ?');
      args.add(dateFrom);
    }
    if (dateTo != null) {
      conditions.add('a.date <= ?');
      args.add(dateTo);
    }
    if (memberId != null) {
      conditions.add('a.member_id = ?');
      args.add(memberId);
    }

    final results = await db.rawQuery(
      '''SELECT a.*, m.full_name as member_name, m.photo_path as member_photo, m.status as member_status
         FROM attendance a
         LEFT JOIN members m ON a.member_id = m.member_id
         WHERE ${conditions.join(' AND ')}
         ORDER BY a.date DESC, a.created_at DESC''',
      args,
    );
    log('[AttendanceDao] getAll returned ${results.length} rows');
    return results;
  }

  Future<Map<String, dynamic>?> getTodayAttendance(String gymId, String memberId) async {
    log('[AttendanceDao] getTodayAttendance called gymId=$gymId memberId=$memberId');
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final results = await db.rawQuery(
      'SELECT * FROM attendance WHERE gym_id = ? AND member_id = ? AND date = ?',
      [gymId, memberId, today],
    );
    log('[AttendanceDao] getTodayAttendance found=${results.isNotEmpty}');
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insert(Map<String, dynamic> data) async {
    log('[AttendanceDao] insert called gym_id=${data['gym_id']} member_id=${data['member_id']}');
    final db = await _dbHelper.database;
    await db.insert('attendance', data);
    log('[AttendanceDao] insert completed');
  }

  Future<void> updateCheckOut(int attendanceId, String time) async {
    log('[AttendanceDao] updateCheckOut called attendanceId=$attendanceId time=$time');
    final db = await _dbHelper.database;
    await db.update(
      'attendance',
      {'check_out': time},
      where: 'attendance_id = ?',
      whereArgs: [attendanceId],
    );
    log('[AttendanceDao] updateCheckOut completed');
  }

  Future<int> getCount(String gymId, {String? dateFrom, String? dateTo}) async {
    log('[AttendanceDao] getCount called gymId=$gymId dateFrom=$dateFrom dateTo=$dateTo');
    final db = await _dbHelper.database;
    final conditions = <String>['gym_id = ?'];
    final args = <dynamic>[gymId];

    if (dateFrom != null) {
      conditions.add('date >= ?');
      args.add(dateFrom);
    }
    if (dateTo != null) {
      conditions.add('date <= ?');
      args.add(dateTo);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM attendance WHERE ${conditions.join(' AND ')}',
      args,
    );
    final count = (result.first['c'] as int?) ?? 0;
    log('[AttendanceDao] getCount returned $count');
    return count;
  }

  Future<List<Map<String, dynamic>>> getDailyCounts(String gymId, int days) async {
    log('[AttendanceDao] getDailyCounts called gymId=$gymId days=$days');
    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      '''SELECT date, COUNT(*) as count
         FROM attendance
         WHERE gym_id = ? AND date >= date('now', '-$days days')
         GROUP BY date
         ORDER BY date ASC''',
      [gymId],
    );
    log('[AttendanceDao] getDailyCounts returned ${results.length} rows');
    return results;
  }

  Future<List<Map<String, dynamic>>> getMemberAttendanceHistory(String memberId, {int limit = 30}) async {
    log('[AttendanceDao] getMemberAttendanceHistory called memberId=$memberId limit=$limit');
    final db = await _dbHelper.database;
    final results = await db.rawQuery(
      '''SELECT a.*, m.full_name as member_name, m.photo_path as member_photo, m.status as member_status
         FROM attendance a
         LEFT JOIN members m ON a.member_id = m.member_id
         WHERE a.member_id = ?
         ORDER BY a.date DESC
         LIMIT ?''',
      [memberId, limit],
    );
    log('[AttendanceDao] getMemberAttendanceHistory returned ${results.length} rows');
    return results;
  }
}

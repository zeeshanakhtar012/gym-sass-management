import 'dart:developer';

import 'package:intl/intl.dart';
import 'attendance_dao.dart';
import 'attendance_record.dart';

class AttendanceRepository {
  final AttendanceDao _attendanceDao;

  AttendanceRepository(this._attendanceDao);

  Future<List<AttendanceRecord>> getAttendance(String gymId, {String? dateFrom, String? dateTo, String? memberId}) async {
    log('[AttendanceRepository] getAttendance called gymId=$gymId');
    final data = await _attendanceDao.getAll(gymId, dateFrom: dateFrom, dateTo: dateTo, memberId: memberId);
    final records = data.map((e) => AttendanceRecord.fromMap(e)).toList();
    log('[AttendanceRepository] getAttendance returned ${records.length} records');
    return records;
  }

  Future<bool> recordCheckIn(String gymId, String memberId, String method) async {
    log('[AttendanceRepository] recordCheckIn called gymId=$gymId memberId=$memberId method=$method');
    try {
      final existing = await _attendanceDao.getTodayAttendance(gymId, memberId);
      if (existing != null) {
        log('[AttendanceRepository] recordCheckIn - already checked in today');
        return false;
      }
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timeStr = DateFormat('HH:mm').format(now);
      final createdAtStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      await _attendanceDao.insert({
        'gym_id': gymId,
        'member_id': memberId,
        'date': dateStr,
        'check_in': timeStr,
        'method': method,
        'created_at': createdAtStr,
      });
      log('[AttendanceRepository] recordCheckIn successful');
      return true;
    } catch (e, stack) {
      log('[AttendanceRepository] recordCheckIn failed: $e');
      log('[AttendanceRepository] stack: $stack');
      return false;
    }
  }

  Future<bool> recordCheckOut(int attendanceId) async {
    log('[AttendanceRepository] recordCheckOut called attendanceId=$attendanceId');
    try {
      final now = DateFormat('HH:mm').format(DateTime.now());
      await _attendanceDao.updateCheckOut(attendanceId, now);
      log('[AttendanceRepository] recordCheckOut successful');
      return true;
    } catch (e, stack) {
      log('[AttendanceRepository] recordCheckOut failed: $e');
      log('[AttendanceRepository] stack: $stack');
      return false;
    }
  }

  Future<bool> isAlreadyCheckedInToday(String gymId, String memberId) async {
    log('[AttendanceRepository] isAlreadyCheckedInToday called gymId=$gymId memberId=$memberId');
    final existing = await _attendanceDao.getTodayAttendance(gymId, memberId);
    final result = existing != null && existing['check_out'] == null;
    log('[AttendanceRepository] isAlreadyCheckedInToday result=$result');
    return result;
  }

  Future<List<Map<String, dynamic>>> getDailyStats(String gymId, int days) async {
    log('[AttendanceRepository] getDailyStats called gymId=$gymId days=$days');
    return _attendanceDao.getDailyCounts(gymId, days);
  }
}

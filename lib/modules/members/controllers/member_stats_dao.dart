import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import 'member_stats.dart';

class MemberStatsDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> getAttendanceCount(String memberId, {int? year, int? month}) async {
    final db = await _dbHelper.database;
    if (year != null && month != null) {
      final prefix = DateFormat('$year-${month.toString().padLeft(2, '0')}');
      final result = await db.rawQuery(
        "SELECT COUNT(*) as c FROM attendance WHERE member_id = ? AND date LIKE ?",
        [memberId, '$prefix%'],
      );
      return (result.first['c'] as int?) ?? 0;
    }
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM attendance WHERE member_id = ?',
      [memberId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<DateTime?> getLastVisit(String memberId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT date FROM attendance WHERE member_id = ? ORDER BY date DESC LIMIT 1',
      [memberId],
    );
    if (result.isEmpty) return null;
    return DateTime.tryParse(result.first['date'] as String);
  }

  Future<DateTime?> getLastCheckIn(String memberId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT check_in FROM attendance WHERE member_id = ? AND check_in IS NOT NULL ORDER BY attendance_id DESC LIMIT 1',
      [memberId],
    );
    if (result.isEmpty) return null;
    return DateTime.tryParse(result.first['check_in'] as String);
  }

  Future<DateTime?> getLastCheckOut(String memberId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT check_out FROM attendance WHERE member_id = ? AND check_out IS NOT NULL ORDER BY attendance_id DESC LIMIT 1',
      [memberId],
    );
    if (result.isEmpty) return null;
    return DateTime.tryParse(result.first['check_out'] as String);
  }

  Future<int> getTotalPaid(String memberId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) as c FROM payments WHERE member_id = ?',
      [memberId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> getTotalDue(String memberId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as c FROM payments WHERE member_id = ?',
      [memberId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<DateTime?> getLastPaymentDate(String memberId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT payment_date FROM payments WHERE member_id = ? ORDER BY payment_date DESC LIMIT 1',
      [memberId],
    );
    if (result.isEmpty) return null;
    return DateTime.tryParse(result.first['payment_date'] as String);
  }

  Future<MemberStats> getMemberStats(String memberId) async {
    final now = DateTime.now();
    final currentMonthPrefix = DateFormat('yyyy-MM').format(now);
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final previousMonthPrefix = DateFormat('yyyy-MM').format(previousMonth);

    final db = await _dbHelper.database;

    final currentMonthResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM attendance WHERE member_id = ? AND date LIKE ?",
      [memberId, '$currentMonthPrefix%'],
    );
    final currentMonthAttendance = (currentMonthResult.first['c'] as int?) ?? 0;

    final prevMonthResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM attendance WHERE member_id = ? AND date LIKE ?",
      [memberId, '$previousMonthPrefix%'],
    );
    final previousMonthAttendance = (prevMonthResult.first['c'] as int?) ?? 0;

    final lifetimeResult = await db.rawQuery(
      'SELECT COUNT(*) as c FROM attendance WHERE member_id = ?',
      [memberId],
    );
    final lifetimeAttendance = (lifetimeResult.first['c'] as int?) ?? 0;

    final lastVisitResult = await db.rawQuery(
      'SELECT date FROM attendance WHERE member_id = ? ORDER BY date DESC LIMIT 1',
      [memberId],
    );
    final lastVisit = lastVisitResult.isNotEmpty
        ? DateTime.tryParse(lastVisitResult.first['date'] as String)
        : null;

    final lastCheckInResult = await db.rawQuery(
      'SELECT check_in FROM attendance WHERE member_id = ? AND check_in IS NOT NULL ORDER BY attendance_id DESC LIMIT 1',
      [memberId],
    );
    final lastCheckIn = lastCheckInResult.isNotEmpty
        ? DateTime.tryParse(lastCheckInResult.first['check_in'] as String)
        : null;

    final lastCheckOutResult = await db.rawQuery(
      'SELECT check_out FROM attendance WHERE member_id = ? AND check_out IS NOT NULL ORDER BY attendance_id DESC LIMIT 1',
      [memberId],
    );
    final lastCheckOut = lastCheckOutResult.isNotEmpty
        ? DateTime.tryParse(lastCheckOutResult.first['check_out'] as String)
        : null;

    final totalPaidResult = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) as c FROM payments WHERE member_id = ?',
      [memberId],
    );
    final totalPaid = (totalPaidResult.first['c'] as int?) ?? 0;

    final totalDueResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as c FROM payments WHERE member_id = ?',
      [memberId],
    );
    final totalDue = (totalDueResult.first['c'] as int?) ?? 0;

    final lastPaymentResult = await db.rawQuery(
      'SELECT payment_date FROM payments WHERE member_id = ? ORDER BY payment_date DESC LIMIT 1',
      [memberId],
    );
    final lastPaymentDate = lastPaymentResult.isNotEmpty
        ? DateTime.tryParse(lastPaymentResult.first['payment_date'] as String)
        : null;

    final monthsSinceRegistration = await _monthsSinceRegistration(memberId);
    final avgVisits = monthsSinceRegistration > 0
        ? lifetimeAttendance / monthsSinceRegistration
        : 0.0;

    return MemberStats(
      currentMonthAttendance: currentMonthAttendance,
      previousMonthAttendance: previousMonthAttendance,
      lifetimeAttendance: lifetimeAttendance,
      attendancePercent: monthsSinceRegistration > 0
          ? (lifetimeAttendance / (monthsSinceRegistration * 30) * 100)
          : 0.0,
      lastVisit: lastVisit,
      lastCheckIn: lastCheckIn,
      lastCheckOut: lastCheckOut,
      totalVisits: lifetimeAttendance,
      avgVisitsPerMonth: avgVisits,
      totalPaid: totalPaid,
      totalDue: totalDue,
      lastPaymentDate: lastPaymentDate,
    );
  }

  Future<int> _monthsSinceRegistration(String memberId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT registration_date FROM members WHERE member_id = ?',
      [memberId],
    );
    if (result.isEmpty) return 0;
    final dateStr = result.first['registration_date'] as String?;
    if (dateStr == null) return 0;
    final regDate = DateTime.tryParse(dateStr);
    if (regDate == null) return 0;
    final now = DateTime.now();
    return ((now.year - regDate.year) * 12) + (now.month - regDate.month);
  }
}

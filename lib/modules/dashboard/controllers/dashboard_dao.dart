import 'dart:developer';

import 'package:intl/intl.dart';
import '../../../../core/database/database_helper.dart';
import 'dashboard_stats.dart';

class DashboardDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String _gymFilter(String gymId) => gymId.isNotEmpty ? 'gym_id = ? AND ' : '';
  List _gymArgs(String gymId) => gymId.isNotEmpty ? [gymId] : [];

  Future<int> getTotalMembers(String gymId) async {
    final db = await _dbHelper.database;
    final filter = _gymFilter(gymId);
    final args = _gymArgs(gymId);
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM members WHERE $filter 1=1',
      args,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> getActiveMembers(String gymId) async {
    final db = await _dbHelper.database;
    final filter = _gymFilter(gymId);
    final args = _gymArgs(gymId);
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM members WHERE ${filter}status = 'active'",
      args,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> getExpiredMembers(String gymId) async {
    final db = await _dbHelper.database;
    final filter = _gymFilter(gymId);
    final args = _gymArgs(gymId);
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM members WHERE ${filter}status = 'expired'",
      args,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> getTodayAttendance(String gymId) async {
    final db = await _dbHelper.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final filter = _gymFilter(gymId);
    final args = [..._gymArgs(gymId), today];
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM attendance WHERE ${filter}date = ?',
      args,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> getCurrentlyInside(String gymId) async {
    final db = await _dbHelper.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final filter = _gymFilter(gymId);
    final args = [..._gymArgs(gymId), today];
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM attendance WHERE ${filter}date = ? AND check_out IS NULL',
      args,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> getMonthlyRevenue(String gymId) async {
    final db = await _dbHelper.database;
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final filter = _gymFilter(gymId);
    final args = [..._gymArgs(gymId), '$month%'];
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as c FROM payments WHERE ${filter}payment_date LIKE ?",
      args,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> getMonthlyExpenses(String gymId) async {
    final db = await _dbHelper.database;
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final filter = _gymFilter(gymId);
    final args = [..._gymArgs(gymId), '$month%'];
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as c FROM expenses WHERE ${filter}expense_date LIKE ?",
      args,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<int> getPendingPayments(String gymId) async {
    final db = await _dbHelper.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final filter = _gymFilter(gymId);
    final args = [..._gymArgs(gymId), today];
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM members WHERE ${filter}status = 'active' AND expiry_date < ?",
      args,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<DashboardStats> getAllStats(String gymId) async {
    log('[DashboardDao] getAllStats called with gymId: "$gymId" (super admin: ${gymId.isEmpty})');
    final results = await Future.wait([
      getTotalMembers(gymId),
      getActiveMembers(gymId),
      getExpiredMembers(gymId),
      getTodayAttendance(gymId),
      getCurrentlyInside(gymId),
      getMonthlyRevenue(gymId),
      getMonthlyExpenses(gymId),
      getPendingPayments(gymId),
    ]);
    log('[DashboardDao] Stats results: totalMembers=${results[0]}, active=${results[1]}, revenue=${results[5]}');
    return DashboardStats(
      totalMembers: results[0],
      activeMembers: results[1],
      expiredMembers: results[2],
      todayAttendance: results[3],
      currentlyInside: results[4],
      monthlyRevenue: results[5],
      monthlyExpenses: results[6],
      monthlyProfit: results[5] - results[6],
      pendingPayments: results[7],
    );
  }

  Future<List<Map<String, dynamic>>> getMonthlyRevenueData(String gymId) async {
    final db = await _dbHelper.database;
    final sixMonthsAgo = DateFormat('yyyy-MM-dd').format(
      DateTime.now().subtract(const Duration(days: 180)),
    );
    final filter = _gymFilter(gymId);
    final args = [..._gymArgs(gymId), sixMonthsAgo];
    return db.rawQuery(
      "SELECT strftime('%Y-%m', payment_date) as month, COALESCE(SUM(total), 0) as revenue "
      'FROM payments '
      'WHERE ${filter}payment_date >= ? '
      "GROUP BY strftime('%Y-%m', payment_date) "
      'ORDER BY month ASC',
      args,
    );
  }

  Future<List<Map<String, dynamic>>> getDailyAttendanceData(String gymId) async {
    final db = await _dbHelper.database;
    final thirtyDaysAgo = DateFormat('yyyy-MM-dd').format(
      DateTime.now().subtract(const Duration(days: 30)),
    );
    final filter = _gymFilter(gymId);
    final args = [..._gymArgs(gymId), thirtyDaysAgo];
    return db.rawQuery(
      'SELECT date, COUNT(*) as count '
      'FROM attendance '
      'WHERE ${filter}date >= ? '
      'GROUP BY date '
      'ORDER BY date ASC',
      args,
    );
  }

  Future<List<Map<String, dynamic>>> getMembershipGrowthData(String gymId) async {
    final db = await _dbHelper.database;
    final sixMonthsAgo = DateFormat('yyyy-MM-dd').format(
      DateTime.now().subtract(const Duration(days: 180)),
    );
    final filter = _gymFilter(gymId);
    final args = [..._gymArgs(gymId), sixMonthsAgo];
    return db.rawQuery(
      "SELECT strftime('%Y-%m', registration_date) as month, COUNT(*) as count "
      'FROM members '
      'WHERE ${filter}registration_date >= ? '
      "GROUP BY strftime('%Y-%m', registration_date) "
      'ORDER BY month ASC',
      args,
    );
  }
}

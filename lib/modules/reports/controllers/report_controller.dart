import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/database/database_helper.dart';

class ReportController extends GetxController {
  final RxMap<String, dynamic> reportData = <String, dynamic>{}.obs;
  final RxBool isLoading = true.obs;
  final Rx<DateTimeRange?> selectedDateRange = Rx<DateTimeRange?>(null);

  @override
  void onInit() {
    super.onInit();
    log('[ReportController] onInit');
    loadOverviewReport('');
  }

  @override
  void onClose() {
    log('[ReportController] onClose');
    super.onClose();
  }

  Future<void> loadOverviewReport(String gymId) async {
    log('[ReportController] loadOverviewReport called gymId=$gymId');
    isLoading.value = true;
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);
      final monthStart = firstOfMonth.toIso8601String().substring(0, 10);
      final today = now.toIso8601String().substring(0, 10);

      final memberCount = await db.rawQuery(
        'SELECT COUNT(*) as total FROM members WHERE gym_id = ?', [gymId],
      );
      final activeCount = await db.rawQuery(
        "SELECT COUNT(*) as total FROM members WHERE gym_id = ? AND status = 'active'", [gymId],
      );
      final expiredCount = await db.rawQuery(
        "SELECT COUNT(*) as total FROM members WHERE gym_id = ? AND status = 'expired'", [gymId],
      );
      final attendanceThisMonth = await db.rawQuery(
        'SELECT COUNT(*) as total FROM attendance WHERE gym_id = ? AND date >= ?', [gymId, monthStart],
      );

      final totalRevenue = await db.rawQuery(
        'SELECT COALESCE(SUM(total), 0) as total FROM payments WHERE gym_id = ?', [gymId],
      );
      final revenueThisMonth = await db.rawQuery(
        'SELECT COALESCE(SUM(total), 0) as total FROM payments WHERE gym_id = ? AND payment_date >= ?',
        [gymId, monthStart],
      );

      final totalExpenses = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE gym_id = ?', [gymId],
      );
      final expensesThisMonth = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE gym_id = ? AND expense_date >= ?',
        [gymId, monthStart],
      );

      final pendingDues = await db.rawQuery(
        'SELECT COALESCE(SUM(p.total), 0) as total FROM payments p '
        'JOIN members m ON p.member_id = m.member_id '
        "WHERE p.gym_id = ? AND m.status = 'active'", [gymId],
      );

      final totalMembers = (memberCount.first['total'] as num).toInt();
      final active = (activeCount.first['total'] as num).toInt();
      final expired = (expiredCount.first['total'] as num).toInt();
      final attCount = (attendanceThisMonth.first['total'] as num).toInt();
      final rev = (totalRevenue.first['total'] as num).toInt();
      final revMonth = (revenueThisMonth.first['total'] as num).toInt();
      final exp = (totalExpenses.first['total'] as num).toInt();
      final expMonth = (expensesThisMonth.first['total'] as num).toInt();
      final dues = (pendingDues.first['total'] as num).toInt();

      final attPct = totalMembers > 0 ? (attCount / (totalMembers * now.day) * 100) : 0.0;

      reportData.value = {
        'totalMembers': totalMembers,
        'activeMembers': active,
        'expiredMembers': expired,
        'attendancePercent': attPct,
        'attendanceCount': attCount,
        'totalRevenue': rev,
        'monthlyRevenue': revMonth,
        'totalExpenses': exp,
        'monthlyExpenses': expMonth,
        'monthlyProfit': revMonth - expMonth,
        'pendingDues': dues,
        'today': today,
        'monthStart': monthStart,
      };
      log('[ReportController] loadOverviewReport completed');
    } catch (e, stack) {
      log('[ReportController] loadOverviewReport failed: $e');
      log('[ReportController] stack: $stack');
      Get.snackbar('Error', 'Failed to load overview report');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMemberReport(String gymId) async {
    log('[ReportController] loadMemberReport called gymId=$gymId');
    isLoading.value = true;
    try {
      final db = await DatabaseHelper.instance.database;

      final byPackage = await db.rawQuery(
        'SELECT COALESCE(p.name, ?) as package_name, COUNT(*) as count FROM members m '
        'LEFT JOIN packages p ON m.package_id = p.package_id '
        'WHERE m.gym_id = ? GROUP BY m.package_id',
        ['No Package', gymId],
      );

      final byStatus = await db.rawQuery(
        'SELECT status, COUNT(*) as count FROM members WHERE gym_id = ? GROUP BY status',
        [gymId],
      );

      reportData.value = {
        ...reportData,
        'membersByPackage': byPackage,
        'membersByStatus': byStatus,
      };
      log('[ReportController] loadMemberReport completed');
    } catch (e, stack) {
      log('[ReportController] loadMemberReport failed: $e');
      log('[ReportController] stack: $stack');
      Get.snackbar('Error', 'Failed to load member report');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadFinancialReport(String gymId, String startDate, String endDate) async {
    log('[ReportController] loadFinancialReport called gymId=$gymId from=$startDate to=$endDate');
    isLoading.value = true;
    try {
      final db = await DatabaseHelper.instance.database;

      final payments = await db.rawQuery(
        'SELECT COALESCE(SUM(total), 0) as total FROM payments WHERE gym_id = ? AND payment_date BETWEEN ? AND ?',
        [gymId, startDate, endDate],
      );

      final expenses = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE gym_id = ? AND expense_date BETWEEN ? AND ?',
        [gymId, startDate, endDate],
      );

      final byMethod = await db.rawQuery(
        'SELECT method, COALESCE(SUM(total), 0) as total FROM payments WHERE gym_id = ? AND payment_date BETWEEN ? AND ? GROUP BY method',
        [gymId, startDate, endDate],
      );

      final dailyRevenue = await db.rawQuery(
        'SELECT payment_date as date, SUM(total) as total FROM payments WHERE gym_id = ? AND payment_date BETWEEN ? AND ? GROUP BY payment_date ORDER BY payment_date',
        [gymId, startDate, endDate],
      );

      final rev = (payments.first['total'] as num).toInt();
      final exp = (expenses.first['total'] as num).toInt();

      reportData.value = {
        ...reportData,
        'financialRevenue': rev,
        'financialExpenses': exp,
        'financialProfit': rev - exp,
        'paymentByMethod': byMethod,
        'dailyRevenue': dailyRevenue,
      };
      log('[ReportController] loadFinancialReport completed');
    } catch (e, stack) {
      log('[ReportController] loadFinancialReport failed: $e');
      log('[ReportController] stack: $stack');
      Get.snackbar('Error', 'Failed to load financial report');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAttendanceReport(String gymId, String startDate, String endDate) async {
    log('[ReportController] loadAttendanceReport called gymId=$gymId from=$startDate to=$endDate');
    isLoading.value = true;
    try {
      final db = await DatabaseHelper.instance.database;

      final dailyCounts = await db.rawQuery(
        'SELECT date, COUNT(*) as count FROM attendance WHERE gym_id = ? AND date BETWEEN ? AND ? GROUP BY date ORDER BY date',
        [gymId, startDate, endDate],
      );

      reportData.value = {
        ...reportData,
        'attendanceDaily': dailyCounts,
      };
      log('[ReportController] loadAttendanceReport completed');
    } catch (e, stack) {
      log('[ReportController] loadAttendanceReport failed: $e');
      log('[ReportController] stack: $stack');
      Get.snackbar('Error', 'Failed to load attendance report');
    } finally {
      isLoading.value = false;
    }
  }
}

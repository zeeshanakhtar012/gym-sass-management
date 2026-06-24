import 'dart:io';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/helpers/formatters.dart';
import '../../auth/controllers/auth_service.dart';
import '../../../widgets/popups/app_popup.dart';

class ReportController extends GetxController {
  final RxMap<String, dynamic> reportData = <String, dynamic>{}.obs;
  final RxBool isLoading = true.obs;
  final Rx<DateTimeRange?> selectedDateRange = Rx<DateTimeRange?>(null);
  final AuthService _authService = Get.find<AuthService>();

  String _resolveGymId(String gymId) {
    if (gymId.isNotEmpty) return gymId;
    return _authService.currentGymId ?? '';
  }

  @override
  void onInit() {
    super.onInit();
    log('[ReportController] onInit');
    _autoLoad();
  }

  void _autoLoad() {
    final gymId = _resolveGymId('');
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    selectedDateRange.value = DateTimeRange(start: start, end: now);
    loadAll(gymId,
      startDate: Formatters.date(start),
      endDate: Formatters.date(now),
    );
  }

  @override
  void onClose() {
    log('[ReportController] onClose');
    super.onClose();
  }

  Future<void> loadAll(String gymId, {String? startDate, String? endDate}) async {
    gymId = _resolveGymId(gymId);
    log('[ReportController] loadAll called gymId=$gymId start=$startDate end=$endDate');
    isLoading.value = true;
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();

      // --- Overview data ---
      final firstOfMonth = DateTime(now.year, now.month, 1);
      final monthStartStr = firstOfMonth.toIso8601String().substring(0, 10);
      final todayStr = now.toIso8601String().substring(0, 10);
      final useStart = startDate ?? monthStartStr;
      final useEnd = endDate ?? todayStr;

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
        'SELECT COUNT(*) as total FROM attendance WHERE gym_id = ? AND date BETWEEN ? AND ?', [gymId, useStart, useEnd],
      );

      final totalRevenue = await db.rawQuery(
        'SELECT COALESCE(SUM(total), 0) as total FROM payments WHERE gym_id = ?', [gymId],
      );
      final revenueThisMonth = await db.rawQuery(
        'SELECT COALESCE(SUM(total), 0) as total FROM payments WHERE gym_id = ? AND payment_date BETWEEN ? AND ?',
        [gymId, useStart, useEnd],
      );

      final totalExpenses = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE gym_id = ?', [gymId],
      );
      final expensesThisMonth = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE gym_id = ? AND expense_date BETWEEN ? AND ?',
        [gymId, useStart, useEnd],
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

      final startDt = DateTime.parse(useStart);
      final endDt = DateTime.parse(useEnd);
      final daysInPeriod = endDt.difference(startDt).inDays + 1;
      final attPct = totalMembers > 0 ? (attCount / (totalMembers * daysInPeriod) * 100) : 0.0;

      // --- Members tab ---
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

      // --- Financial tab ---
      int financialRevenue = 0, financialExpenses = 0;
      List<Map<String, dynamic>> paymentByMethod = [];
      List<Map<String, dynamic>> dailyRevenue = [];

      if (startDate != null && endDate != null) {
        final paymentsSum = await db.rawQuery(
          'SELECT COALESCE(SUM(total), 0) as total FROM payments WHERE gym_id = ? AND payment_date BETWEEN ? AND ?',
          [gymId, startDate, endDate],
        );
        final expensesSum = await db.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE gym_id = ? AND expense_date BETWEEN ? AND ?',
          [gymId, startDate, endDate],
        );
        paymentByMethod = await db.rawQuery(
          'SELECT method, COALESCE(SUM(total), 0) as total FROM payments WHERE gym_id = ? AND payment_date BETWEEN ? AND ? GROUP BY method',
          [gymId, startDate, endDate],
        ) as List<Map<String, dynamic>>;
        dailyRevenue = await db.rawQuery(
          'SELECT payment_date as date, SUM(total) as total FROM payments WHERE gym_id = ? AND payment_date BETWEEN ? AND ? GROUP BY payment_date ORDER BY payment_date',
          [gymId, startDate, endDate],
        ) as List<Map<String, dynamic>>;

        financialRevenue = (paymentsSum.first['total'] as num).toInt();
        financialExpenses = (expensesSum.first['total'] as num).toInt();
      }

      // --- Attendance tab ---
      List<Map<String, dynamic>> attendanceDaily = [];
      if (startDate != null && endDate != null) {
        attendanceDaily = await db.rawQuery(
          'SELECT date, COUNT(*) as count FROM attendance WHERE gym_id = ? AND date BETWEEN ? AND ? GROUP BY date ORDER BY date',
          [gymId, startDate, endDate],
        ) as List<Map<String, dynamic>>;
      }

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
        'today': todayStr,
        'monthStart': monthStartStr,
        'membersByPackage': byPackage,
        'membersByStatus': byStatus,
        'financialRevenue': financialRevenue,
        'financialExpenses': financialExpenses,
        'financialProfit': financialRevenue - financialExpenses,
        'paymentByMethod': paymentByMethod,
        'dailyRevenue': dailyRevenue,
        'attendanceDaily': attendanceDaily,
      };
      log('[ReportController] loadAll completed');
    } catch (e, stack) {
      log('[ReportController] loadAll failed: $e');
      log('[ReportController] stack: $stack');
      AppPopup.error('Failed to load report: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// ---------- Export Methods ----------

  Future<void> exportExcel(String gymId) async {
    gymId = _resolveGymId(gymId);
    log('[ReportController] exportExcel called gymId=$gymId');
    try {
      final db = await DatabaseHelper.instance.database;
      final excel = Excel.createExcel();
      final bold = CellStyle(bold: true, fontColorHex: ExcelColor.fromHexString('FFFFFFFF'), backgroundColorHex: ExcelColor.fromHexString('FFC9A96E'));

      // ---- Sheet 1: Overview ----
      final overview = excel['Overview'];
      overview.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
      _styleRow(overview, 0, bold);

      final data = reportData;
      final kpis = [
        ['Total Members', '${data['totalMembers'] ?? 0}'],
        ['Active Members', '${data['activeMembers'] ?? 0}'],
        ['Expired Members', '${data['expiredMembers'] ?? 0}'],
        ['Attendance %', '${(data['attendancePercent'] ?? 0.0).toStringAsFixed(1)}%'],
        ['Monthly Revenue', Formatters.currency(data['monthlyRevenue'] ?? 0)],
        ['Monthly Expenses', Formatters.currency(data['monthlyExpenses'] ?? 0)],
        ['Monthly Profit', Formatters.currency(data['monthlyProfit'] ?? 0)],
        ['Pending Dues', Formatters.currency(data['pendingDues'] ?? 0)],
      ];
      for (final row in kpis) {
        overview.appendRow([TextCellValue(row[0]), TextCellValue(row[1])]);
      }

      // ---- Sheet 2: Members ----
      final memberSheet = excel['Members'];
      memberSheet.appendRow([
        TextCellValue('Name'), TextCellValue('Phone'), TextCellValue('Status'),
        TextCellValue('Package'), TextCellValue('Start Date'), TextCellValue('Expiry Date'),
      ]);
      _styleRow(memberSheet, 0, bold);

      final members = await db.query('members',
        where: 'gym_id = ?', whereArgs: [gymId],
        orderBy: 'full_name ASC',
      );
      for (final m in members) {
        String? pkgName;
        if (m['package_id'] != null) {
          final pkg = await db.query('packages',
            where: 'package_id = ?', whereArgs: [m['package_id']],
          );
          pkgName = pkg.isNotEmpty ? pkg.first['name'] as String? : null;
        }
        memberSheet.appendRow([
          TextCellValue(m['full_name'] as String? ?? ''),
          TextCellValue(m['phone'] as String? ?? ''),
          TextCellValue(m['status'] as String? ?? ''),
          TextCellValue(pkgName ?? '-'),
          TextCellValue(m['start_date'] as String? ?? '-'),
          TextCellValue(m['expiry_date'] as String? ?? '-'),
        ]);
      }

      // ---- Sheet 3: Financial ----
      final finSheet = excel['Financial'];
      finSheet.appendRow([
        TextCellValue('Date'), TextCellValue('Revenue'), TextCellValue('Expenses'),
        TextCellValue('Profit'),
      ]);
      _styleRow(finSheet, 0, bold);

      final range = selectedDateRange.value;
      final start = range != null ? Formatters.date(range.start) : null;
      final end = range != null ? Formatters.date(range.end) : null;

      if (start != null && end != null) {
        final dailyRev = await db.rawQuery(
          'SELECT payment_date as date, SUM(total) as total FROM payments '
          'WHERE gym_id = ? AND payment_date BETWEEN ? AND ? GROUP BY payment_date ORDER BY payment_date',
          [gymId, start, end],
        );
        final dailyExp = await db.rawQuery(
          'SELECT expense_date as date, SUM(amount) as total FROM expenses '
          'WHERE gym_id = ? AND expense_date BETWEEN ? AND ? GROUP BY expense_date ORDER BY expense_date',
          [gymId, start, end],
        );

        final allDates = <String>{};
        for (final r in dailyRev) { allDates.add(r['date'] as String); }
        for (final e in dailyExp) { allDates.add(e['date'] as String); }
        final sorted = allDates.toList()..sort();

        for (final d in sorted) {
          final rev = dailyRev.firstWhere(
            (r) => r['date'] == d,
            orElse: () => {'total': 0},
          );
          final exp = dailyExp.firstWhere(
            (e) => e['date'] == d,
            orElse: () => {'total': 0},
          );
          final rAmt = (rev['total'] as num).toInt();
          final eAmt = (exp['total'] as num).toInt();
          finSheet.appendRow([
            TextCellValue(d),
            TextCellValue(Formatters.currency(rAmt)),
            TextCellValue(Formatters.currency(eAmt)),
            TextCellValue(Formatters.currency(rAmt - eAmt)),
          ]);
        }
      }

      // ---- Sheet 4: Attendance ----
      final attSheet = excel['Attendance'];
      attSheet.appendRow([
        TextCellValue('Date'), TextCellValue('Check-ins'), TextCellValue('Percentage'),
      ]);
      _styleRow(attSheet, 0, bold);

      if (start != null && end != null) {
        final dailyAtt = await db.rawQuery(
          'SELECT date, COUNT(*) as count FROM attendance '
          'WHERE gym_id = ? AND date BETWEEN ? AND ? GROUP BY date ORDER BY date',
          [gymId, start, end],
        );
        final totalMembers = (await db.rawQuery(
          'SELECT COUNT(*) as c FROM members WHERE gym_id = ?', [gymId],
        )).first['c'] as int;
        for (final a in dailyAtt) {
          final count = (a['count'] as num).toInt();
          final pct = totalMembers > 0 ? (count / totalMembers * 100).toStringAsFixed(1) : '0.0';
          attSheet.appendRow([
            TextCellValue(a['date'] as String),
            TextCellValue('$count'),
            TextCellValue('$pct%'),
          ]);
        }
      }

      // ---- Sheet 5: Payments Detail ----
      final paySheet = excel['Payments'];
      paySheet.appendRow([
        TextCellValue('Date'), TextCellValue('Member'), TextCellValue('Method'),
        TextCellValue('Amount'), TextCellValue('Discount'), TextCellValue('Tax'),
        TextCellValue('Total'), TextCellValue('Remarks'),
      ]);
      _styleRow(paySheet, 0, bold);

      final payments = await db.rawQuery('''
        SELECT p.*, m.full_name AS member_name
        FROM payments p
        LEFT JOIN members m ON p.member_id = m.member_id
        WHERE p.gym_id = ? ${start != null && end != null ? 'AND p.payment_date BETWEEN ? AND ?' : ''}
        ORDER BY p.created_at DESC
      ''', start != null && end != null ? [gymId, start, end] : [gymId]);
      for (final p in payments) {
        paySheet.appendRow([
          TextCellValue(p['payment_date'] as String? ?? ''),
          TextCellValue(p['member_name'] as String? ?? ''),
          TextCellValue(p['method'] as String? ?? ''),
          TextCellValue('${p['amount'] as int? ?? 0}'),
          TextCellValue('${p['discount'] as int? ?? 0}'),
          TextCellValue('${p['tax'] as int? ?? 0}'),
          TextCellValue('${p['total'] as int? ?? 0}'),
          TextCellValue(p['remarks'] as String? ?? ''),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) {
        AppPopup.error('Failed to generate Excel file');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'Gym_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(fileBytes);
      log('[ReportController] Excel saved to ${file.path}');

      AppPopup.success('Excel report saved to Downloads');
    } catch (e, stack) {
      log('[ReportController] exportExcel failed: $e');
      log('[ReportController] stack: $stack');
      AppPopup.error('Failed to export Excel: $e');
    }
  }

  void _styleRow(Sheet sheet, int rowIndex, CellStyle style) {
    for (var col = 0; col < 20; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(rowIndex: rowIndex, columnIndex: col));
      cell.cellStyle = style;
    }
  }

  Future<void> exportPdf(String gymId) async {
    gymId = _resolveGymId(gymId);
    log('[ReportController] exportPdf called gymId=$gymId');
    try {
      final db = await DatabaseHelper.instance.database;
      final data = reportData;

      final range = selectedDateRange.value;
      final pdfStart = range != null ? Formatters.date(range.start) : null;
      final pdfEnd = range != null ? Formatters.date(range.end) : null;

      final members = await db.query('members',
        where: 'gym_id = ?', whereArgs: [gymId],
        orderBy: 'full_name ASC',
      );
      final payments = await db.rawQuery('''
        SELECT p.*, m.full_name AS member_name
        FROM payments p
        LEFT JOIN members m ON p.member_id = m.member_id
        WHERE p.gym_id = ? ${pdfStart != null && pdfEnd != null ? 'AND p.payment_date BETWEEN ? AND ?' : ''}
        ORDER BY p.created_at DESC LIMIT 50
      ''', pdfStart != null && pdfEnd != null ? [gymId, pdfStart, pdfEnd] : [gymId]);

      final nowStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

      final memberRows = members.map((m) {
        return [
          m['full_name'] as String? ?? '',
          m['phone'] as String? ?? '',
          m['status'] as String? ?? '',
          m['package_id'] as String? ?? '-',
          m['start_date'] as String? ?? '-',
          m['expiry_date'] as String? ?? '-',
        ];
      }).toList();

      final paymentRows = payments.map((p) {
        return [
          p['payment_date'] as String? ?? '',
          p['member_name'] as String? ?? '',
          p['method'] as String? ?? '',
          Formatters.currency(p['total'] as int? ?? 0),
        ];
      }).toList();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Gym Management Report',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Paragraph(text: 'Generated: $nowStr'),
              if (pdfStart != null && pdfEnd != null)
                pw.Paragraph(text: 'Period: $pdfStart to $pdfEnd'),
              pw.Divider(),
              pw.Header(level: 1, text: 'Overview'),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                headers: ['Metric', 'Value'],
                data: [
                  ['Total Members', '${data['totalMembers'] ?? 0}'],
                  ['Active Members', '${data['activeMembers'] ?? 0}'],
                  ['Expired Members', '${data['expiredMembers'] ?? 0}'],
                  ['Attendance %', '${(data['attendancePercent'] ?? 0.0).toStringAsFixed(1)}%'],
                  ['Period Revenue', Formatters.currency(data['monthlyRevenue'] ?? 0)],
                  ['Period Expenses', Formatters.currency(data['monthlyExpenses'] ?? 0)],
                  ['Period Profit', Formatters.currency(data['monthlyProfit'] ?? 0)],
                  ['Pending Dues', Formatters.currency(data['pendingDues'] ?? 0)],
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Header(level: 1, text: 'Members'),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                headers: ['Name', 'Phone', 'Status', 'Package', 'Start', 'Expiry'],
                data: memberRows,
              ),
              pw.SizedBox(height: 16),
              pw.Header(level: 1, text: 'Financial Summary'),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                headers: ['Item', 'Amount'],
                data: [
                  ['Period Revenue', Formatters.currency(data['monthlyRevenue'] ?? 0)],
                  ['Period Expenses', Formatters.currency(data['monthlyExpenses'] ?? 0)],
                  ['Period Profit', Formatters.currency(data['monthlyProfit'] ?? 0)],
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Header(level: 1, text: 'Recent Payments'),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                headers: ['Date', 'Member', 'Method', 'Total'],
                data: paymentRows,
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Gym_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );

      log('[ReportController] PDF shared successfully');
      AppPopup.success('PDF report generated successfully');
    } catch (e, stack) {
      log('[ReportController] exportPdf failed: $e');
      log('[ReportController] stack: $stack');
      AppPopup.error('Failed to export PDF: $e');
    }
  }
}

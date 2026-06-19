import 'dart:developer';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_helper.dart';

class AttendanceController extends GetxController {
  final RxList<Map<String, dynamic>> attendanceRecords = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredRecords = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> members = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredMembers = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> checkedInMembers = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxString selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now()).obs;
  final RxString searchQuery = ''.obs;
  final RxBool isCheckInMode = true.obs;

  int get todayPresentCount =>
      checkedInMembers.where((m) => m['check_out'] == null).length;

  @override
  void onInit() {
    super.onInit();
    log('[AttendanceController] onInit');
    loadAttendance('');
    loadMembers('');
    loadCheckedInToday('');
  }

  @override
  void onClose() {
    log('[AttendanceController] onClose');
    super.onClose();
  }

  Future<void> loadAttendance(String gymId) async {
    log('[AttendanceController] loadAttendance called gymId=$gymId');
    isLoading.value = true;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT a.*, m.full_name AS member_name, m.photo_path AS member_photo
        FROM attendance a
        LEFT JOIN members m ON a.member_id = m.member_id
        WHERE a.gym_id = ?
        ORDER BY a.date DESC, a.check_in DESC
      ''', [gymId]);
      attendanceRecords.value = rows;
      _applyFilters();
      log('[AttendanceController] loadAttendance loaded ${rows.length} records');
    } catch (e, stack) {
      log('[AttendanceController] loadAttendance failed: $e');
      log('[AttendanceController] stack: $stack');
      Get.snackbar('Error', 'Failed to load attendance: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMembers(String gymId) async {
    log('[AttendanceController] loadMembers called gymId=$gymId');
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('members',
        where: 'gym_id = ? AND status = ?',
        whereArgs: [gymId, 'active'],
        orderBy: 'full_name ASC',
      );
      members.value = rows;
      filteredMembers.value = rows;
      log('[AttendanceController] loadMembers loaded ${rows.length} members');
    } catch (e, stack) {
      log('[AttendanceController] loadMembers failed: $e');
      log('[AttendanceController] stack: $stack');
      Get.snackbar('Error', 'Failed to load members: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFingerprintMembers(String gymId) async {
    log('[AttendanceController] getFingerprintMembers called gymId=$gymId');
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('members',
        where: 'gym_id = ? AND status = ? AND fingerprint_template IS NOT NULL',
        whereArgs: [gymId, 'active'],
        orderBy: 'full_name ASC',
      );
      log('[AttendanceController] getFingerprintMembers found ${rows.length} members');
      return rows;
    } catch (e, stack) {
      log('[AttendanceController] getFingerprintMembers failed: $e');
      log('[AttendanceController] stack: $stack');
      return [];
    }
  }

  Future<void> loadCheckedInToday(String gymId) async {
    log('[AttendanceController] loadCheckedInToday called gymId=$gymId');
    try {
      final db = await DatabaseHelper.instance.database;
      final today = selectedDate.value;
      final rows = await db.rawQuery('''
        SELECT a.*, m.full_name AS member_name, m.photo_path AS member_photo
        FROM attendance a
        LEFT JOIN members m ON a.member_id = m.member_id
        WHERE a.gym_id = ? AND a.date = ?
        ORDER BY a.check_in DESC
      ''', [gymId, today]);
      checkedInMembers.value = rows;
      log('[AttendanceController] loadCheckedInToday found ${rows.length} checked in');
    } catch (e, stack) {
      log('[AttendanceController] loadCheckedInToday failed: $e');
      log('[AttendanceController] stack: $stack');
      Get.snackbar('Error', 'Failed to load today attendance: $e');
    }
  }

  void setDate(DateTime date) {
    log('[AttendanceController] setDate called date=${DateFormat('yyyy-MM-dd').format(date)}');
    selectedDate.value = DateFormat('yyyy-MM-dd').format(date);
    _applyFilters();
  }

  void setSearchQuery(String query) {
    log('[AttendanceController] setSearchQuery called query=$query');
    searchQuery.value = query;
    _applyFilters();
    _filterMembers();
  }

  void toggleMode() {
    log('[AttendanceController] toggleMode - was isCheckInMode=${isCheckInMode.value}');
    isCheckInMode.value = !isCheckInMode.value;
    searchQuery.value = '';
    filteredMembers.value = members;
    log('[AttendanceController] toggleMode - now isCheckInMode=${isCheckInMode.value}');
  }

  void _applyFilters() {
    final query = searchQuery.value.toLowerCase();
    final date = selectedDate.value;
    var filtered = attendanceRecords.where((r) {
      final matchesDate = r['date'] == date;
      final matchesSearch = query.isEmpty ||
          (r['member_name']?.toString().toLowerCase().contains(query) ?? false);
      return matchesDate && matchesSearch;
    }).toList();
    filteredRecords.value = filtered;
    log('[AttendanceController] _applyFilters filtered ${filtered.length} records');
  }

  void _filterMembers() {
    final query = searchQuery.value.toLowerCase();
    if (query.isEmpty) {
      filteredMembers.value = members;
      return;
    }
    filteredMembers.value = members.where((m) {
      final name = (m['full_name'] as String?)?.toLowerCase() ?? '';
      final phone = (m['phone'] as String?)?.toLowerCase() ?? '';
      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  Future<String> checkIn(String gymId, String memberId, {String method = 'manual'}) async {
    log('[AttendanceController] checkIn called gymId=$gymId memberId=$memberId method=$method');
    try {
      final db = await DatabaseHelper.instance.database;
      final today = selectedDate.value;
      final now = DateFormat('HH:mm').format(DateTime.now());

      final existing = await db.query('attendance',
        where: 'gym_id = ? AND member_id = ? AND date = ? AND check_out IS NULL',
        whereArgs: [gymId, memberId, today],
      );
      if (existing.isNotEmpty) {
        log('[AttendanceController] checkIn - already checked in today');
        return 'Member already checked in today';
      }

      await db.insert('attendance', {
        'gym_id': gymId,
        'member_id': memberId,
        'date': today,
        'check_in': now,
        'method': method,
        'created_at': DateTime.now().toIso8601String(),
      });
      await loadCheckedInToday(gymId);
      await loadAttendance(gymId);
      log('[AttendanceController] checkIn successful');
      return 'Check-in recorded successfully';
    } catch (e, stack) {
      log('[AttendanceController] checkIn failed: $e');
      log('[AttendanceController] stack: $stack');
      return 'Failed to record check-in: $e';
    }
  }

  Future<String> checkOut(String gymId, int attendanceId) async {
    log('[AttendanceController] checkOut called gymId=$gymId attendanceId=$attendanceId');
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateFormat('HH:mm').format(DateTime.now());
      await db.update(
        'attendance',
        {'check_out': now},
        where: 'attendance_id = ?',
        whereArgs: [attendanceId],
      );
      await loadCheckedInToday(gymId);
      await loadAttendance(gymId);
      log('[AttendanceController] checkOut successful');
      return 'Check-out recorded successfully';
    } catch (e, stack) {
      log('[AttendanceController] checkOut failed: $e');
      log('[AttendanceController] stack: $stack');
      return 'Failed to record check-out: $e';
    }
  }

  Future<void> getTodaysAttendance(String gymId) async {
    log('[AttendanceController] getTodaysAttendance called gymId=$gymId');
    selectedDate.value = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await loadCheckedInToday(gymId);
    _applyFilters();
  }
}

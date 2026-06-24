import 'dart:developer';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/dartafis_service.dart';
import '../../../core/services/zkteco_scanner_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/controllers/auth_service.dart';
import '../../../widgets/popups/app_popup.dart';

class AttendanceController extends GetxController {
  final ZKTecoBiometricService _scanner = ZKTecoBiometricService();
  final DartafisService _dartafis = DartafisService();
  final AuthService _authService = Get.find<AuthService>();

  final RxList<Map<String, dynamic>> attendanceRecords = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredRecords = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> members = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredMembers = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> checkedInMembers = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxString selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now()).obs;
  final RxString searchQuery = ''.obs;
  final RxBool isCheckInMode = true.obs;

  String _resolveGymId(String gymId) {
    if (gymId.isNotEmpty) return gymId;
    return _authService.currentGymId ?? '';
  }

  int get todayPresentCount =>
      checkedInMembers.where((m) => m['check_out'] == null).length;

  @override
  void onInit() {
    super.onInit();
    log('[AttendanceController] onInit');
    final gymId = _resolveGymId('');
    loadAttendance(gymId);
    loadMembers(gymId);
    loadCheckedInToday(gymId);
  }

  @override
  void onClose() {
    log('[AttendanceController] onClose');
    super.onClose();
  }

  Future<void> loadAttendance(String gymId) async {
    gymId = _resolveGymId(gymId);
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
      AppPopup.error('Failed to load attendance: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMembers(String gymId) async {
    gymId = _resolveGymId(gymId);
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
      AppPopup.error('Failed to load members: $e');
    }
  }

  /// Load members who have fingerprint data available.
  ///
  /// Supports both the new `fingerprint_data` column (dartafis serialized
  /// template) and legacy `fingerprint_image` (raw grayscale image).
  /// Legacy members are migrated on-the-fly: the raw image is loaded,
  /// a dartafis template is extracted, and the result is saved to
  /// `fingerprint_data` so that future lookups are instant.
  Future<List<Map<String, dynamic>>> getFingerprintMembers(String gymId) async {
    gymId = _resolveGymId(gymId);
    log('[AttendanceController] getFingerprintMembers called gymId=$gymId');
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT m.*, p.name AS package_name
        FROM members m
        LEFT JOIN packages p ON m.package_id = p.package_id
        WHERE m.gym_id = ? AND m.status = 'active'
          AND (m.fingerprint_data IS NOT NULL OR m.fingerprint_image IS NOT NULL)
        ORDER BY m.full_name ASC
      ''', [gymId]);

      if (rows.isEmpty) {
        log('[AttendanceController] getFingerprintMembers: none found');
        return [];
      }

      // --- On-the-fly migration of legacy fingerprint_image records ---
      int migrated = 0;
      for (final row in rows) {
        final fpData = row['fingerprint_data'] as Uint8List?;
        if (fpData != null) continue;

        final fpImage = row['fingerprint_image'] as Uint8List?;
        if (fpImage == null || fpImage.length != AppConstants.fingerprintImageSize) {
          continue;
        }

        log('[AttendanceController] migrating legacy fingerprint for '
            'member ${row['member_id']}');
        final serialized = await _dartafis.migrateLegacyImage(fpImage);
        if (serialized != null && _dartafis.isValidTemplate(serialized)) {
          await db.update(
            'members',
            {'fingerprint_data': serialized},
            where: 'member_id = ?',
            whereArgs: [row['member_id']],
          );
          row['fingerprint_data'] = serialized;
          migrated++;
          log('[AttendanceController] migrated legacy fingerprint for '
              'member ${row['member_id']}');
        }
      }
      if (migrated > 0) {
        log('[AttendanceController] migrated $migrated legacy fingerprint records');
      }

      // Return only members with valid fingerprint_data
      final fpMembers = rows.where((r) =>
          r['fingerprint_data'] is Uint8List &&
          (r['fingerprint_data'] as Uint8List).isNotEmpty)
          .toList();
      log('[AttendanceController] getFingerprintMembers: '
          '${fpMembers.length} members ready');
      return fpMembers;
    } catch (e, stack) {
      log('[AttendanceController] getFingerprintMembers failed: $e');
      log('[AttendanceController] stack: $stack');
      return [];
    }
  }

  /// Perform a fingerprint-based check-in using dartafis template matching.
  ///
  /// Returns a user-facing status message.
  Future<String> fingerprintCheckIn(String gymId) async {
    gymId = _resolveGymId(gymId);
    log('[AttendanceController] fingerprintCheckIn called gymId=$gymId');

    final fpMembers = await getFingerprintMembers(gymId);
    if (fpMembers.isEmpty) {
      log('[AttendanceController] No members with registered fingerprints found');
      return 'No members with registered fingerprints found.';
    }

    // Build the candidate template list, keeping the member order stable.
    final memberIds = fpMembers.map((m) => m['member_id'] as String).toList();
    final candidateTemplates = fpMembers
        .map((m) => m['fingerprint_data'] as Uint8List)
        .toList();

    log('[AttendanceController] Matching against ${candidateTemplates.length} '
        'templates');
    final matchResult = await _scanner.identifyByDartafis(
      candidateTemplates: candidateTemplates,
      scoreThreshold: AppConstants.fingerprintMatchThreshold,
    );

    if (matchResult == null || !matchResult.isMatched) {
      log('[AttendanceController] Fingerprint not recognized '
          '(threshold=${AppConstants.fingerprintMatchThreshold})');
      return 'Fingerprint not recognized. Please try again.';
    }

    if (matchResult.templateIndex < 0 ||
        matchResult.templateIndex >= memberIds.length) {
      log('[AttendanceController] Match index ${matchResult.templateIndex} '
          'out of range (0-${memberIds.length - 1})');
      return 'Fingerprint not recognized. Please try again.';
    }

    final matchedMemberId = memberIds[matchResult.templateIndex];
    log('[AttendanceController] Match score: '
        '${matchResult.score.toStringAsFixed(1)} '
        'for template #${matchResult.templateIndex}');
    log('[AttendanceController] User matched: '
        '${fpMembers[matchResult.templateIndex]['full_name']} '
        '(score=${matchResult.score.toStringAsFixed(1)}, '
        'threshold=${AppConstants.fingerprintMatchThreshold})');

    return await checkIn(gymId, matchedMemberId, method: 'fingerprint');
  }

  Future<void> loadCheckedInToday(String gymId) async {
    gymId = _resolveGymId(gymId);
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
      AppPopup.error('Failed to load today attendance: $e');
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
    gymId = _resolveGymId(gymId);
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
    gymId = _resolveGymId(gymId);
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
    gymId = _resolveGymId(gymId);
    log('[AttendanceController] getTodaysAttendance called gymId=$gymId');
    selectedDate.value = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await loadCheckedInToday(gymId);
    _applyFilters();
  }
}

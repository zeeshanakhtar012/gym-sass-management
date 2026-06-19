import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' hide log;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/constants/app_constants.dart';
import '../../members/controllers/member_model.dart';

class KioskController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final RxList<MemberModel> members = <MemberModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString searchQuery = ''.obs;
  final Rx<MemberModel?> checkedInMember = Rx<MemberModel?>(null);
  final RxString successMessage = ''.obs;
  final RxBool showSuccess = false.obs;
  final RxInt todayCheckInCount = 0.obs;

  final RxList<MemberModel> fingerprintMembers = <MemberModel>[].obs;
  final RxInt scanningIndex = 0.obs;
  final RxBool isScanning = true.obs;
  final RxString detectedName = ''.obs;

  Timer? _autoDismissTimer;
  Timer? _scanTimer;
  final Random _random = Random();

  @override
  void onInit() {
    super.onInit();
    log('[KioskController] onInit');
    loadMembers('');
    getTodaysCheckIns('');
    _startFingerprintScan();
  }

  @override
  void onClose() {
    log('[KioskController] onClose');
    _autoDismissTimer?.cancel();
    _scanTimer?.cancel();
    super.onClose();
  }

  void _startFingerprintScan() {
    _scanTimer?.cancel();
    isScanning.value = true;
    _scanTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (fingerprintMembers.isEmpty) return;
      final next = scanningIndex.value + 1;
      if (next >= fingerprintMembers.length) {
        scanningIndex.value = 0;
      } else {
        scanningIndex.value = next;
      }
      detectedName.value = fingerprintMembers[scanningIndex.value].fullName;
    });
  }

  Future<void> autoDetectAndCheckIn() async {
    if (fingerprintMembers.isEmpty) return;
    final member = fingerprintMembers[_random.nextInt(fingerprintMembers.length)];
    await checkInMember('', member.memberId);
  }

  List<MemberModel> get filteredMembers {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return members;
    return members.where((m) {
      return m.fullName.toLowerCase().contains(query) ||
          (m.phone?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> loadMembers(String gymId) async {
    log('[KioskController] loadMembers called gymId=$gymId');
    isLoading.value = true;
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'members',
        where: 'gym_id = ? AND status = ?',
        whereArgs: [gymId, 'active'],
        orderBy: 'full_name ASC',
      );
      members.value = rows.map((e) => MemberModel.fromJson(e)).toList();
      fingerprintMembers.value = members.where((m) => m.fingerprintTemplate != null).toList();
      log('[KioskController] loadMembers loaded ${rows.length} members (${fingerprintMembers.length} with fingerprints)');
    } catch (e, stack) {
      log('[KioskController] loadMembers failed: $e');
      log('[KioskController] stack: $stack');
      Get.snackbar('Error', 'Failed to load members: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void searchMembers(String query) {
    log('[KioskController] searchMembers query=$query');
    searchQuery.value = query;
  }

  Future<void> checkInMember(String gymId, String memberId) async {
    log('[KioskController] checkInMember called gymId=$gymId memberId=$memberId');
    try {
      final db = await _dbHelper.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final now = DateFormat('HH:mm').format(DateTime.now());

      final existing = await db.query(
        'attendance',
        where: 'gym_id = ? AND member_id = ? AND date = ?',
        whereArgs: [gymId, memberId, today],
      );
      if (existing.isNotEmpty) {
        log('[KioskController] checkInMember - already checked in today');
        Get.snackbar('Notice', 'Member already checked in today');
        return;
      }

      await db.insert('attendance', {
        'gym_id': gymId,
        'member_id': memberId,
        'date': today,
        'check_in': now,
        'method': 'kiosk',
        'created_at': DateTime.now().toIso8601String(),
      });

      final member = members.firstWhereOrNull((m) => m.memberId == memberId);
      checkedInMember.value = member;
      successMessage.value = 'Checked In!';
      showSuccess.value = true;
      log('[KioskController] checkInMember successful');

      await getTodaysCheckIns(gymId);

      _autoDismissTimer?.cancel();
      _autoDismissTimer = Timer(
        Duration(milliseconds: AppConstants.kioskAutoDismissMs),
        () {
          showSuccess.value = false;
          checkedInMember.value = null;
          successMessage.value = '';
          log('[KioskController] auto-dismiss success message');
        },
      );
    } catch (e, stack) {
      log('[KioskController] checkInMember failed: $e');
      log('[KioskController] stack: $stack');
      Get.snackbar('Error', 'Check-in failed: $e');
    }
  }

  Future<void> getTodaysCheckIns(String gymId) async {
    log('[KioskController] getTodaysCheckIns called gymId=$gymId');
    try {
      final db = await _dbHelper.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final result = await db.rawQuery(
        "SELECT COUNT(*) as c FROM attendance WHERE gym_id = ? AND date = ? AND method = 'kiosk'",
        [gymId, today],
      );
      todayCheckInCount.value = (result.first['c'] as int?) ?? 0;
      log('[KioskController] getTodaysCheckIns count=${todayCheckInCount.value}');
    } catch (e, stack) {
      log('[KioskController] getTodaysCheckIns failed: $e');
      log('[KioskController] stack: $stack');
    }
  }

  void dismissSuccess() {
    log('[KioskController] dismissSuccess');
    _autoDismissTimer?.cancel();
    showSuccess.value = false;
    checkedInMember.value = null;
    successMessage.value = '';
  }
}

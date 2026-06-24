import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/dartafis_service.dart';
import '../../../core/services/zkteco_scanner_service.dart';
import '../../auth/controllers/auth_service.dart';
import '../../members/controllers/member_model.dart';
import '../../../widgets/popups/app_popup.dart';

class KioskController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ZKTecoBiometricService _scanner = ZKTecoBiometricService();
  final DartafisService _dartafis = DartafisService();
  final AuthService _authService = Get.find<AuthService>();

  final RxList<MemberModel> members = <MemberModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString searchQuery = ''.obs;
  final Rx<MemberModel?> checkedInMember = Rx<MemberModel?>(null);
  final RxString successMessage = ''.obs;
  final RxBool showSuccess = false.obs;
  final RxInt todayCheckInCount = 0.obs;

  /// Members who have a valid fingerprint template enrolled.
  final RxList<MemberModel> fingerprintMembers = <MemberModel>[].obs;
  final RxBool isDeviceConnected = false.obs;
  final RxBool isScanning = false.obs;
  final RxString detectedName = ''.obs;
  final RxString scanStatus = ''.obs;

  Timer? _autoDismissTimer;
  bool _scanLoopActive = false;

  @override
  void onInit() {
    super.onInit();
    log('[KioskController] onInit');
    final gymId = _authService.currentGymId ?? '';
    loadMembers(gymId);
    getTodaysCheckIns(gymId);
    _initScanner();
  }

  @override
  void onClose() {
    log('[KioskController] onClose');
    _autoDismissTimer?.cancel();
    _scanLoopActive = false;
    _scanner.disconnect();
    super.onClose();
  }

  Future<void> _initScanner() async {
    log('[KioskController] _initScanner');
    final connected = await _scanner.isScannerConnected();
    isDeviceConnected.value = connected;
    log('[KioskController] scanner connected=$connected');
    if (connected && fingerprintMembers.isNotEmpty) {
      log('[KioskController] loaded ${fingerprintMembers.length} '
          'fingerprint members');
      _startContinuousScan();
    }
  }

  void _startContinuousScan() {
    if (_scanLoopActive) return;
    _scanLoopActive = true;
    isScanning.value = true;
    _runScanLoop();
  }

  Future<void> _runScanLoop() async {
    while (_scanLoopActive) {
      try {
        if (fingerprintMembers.isEmpty) {
          scanStatus.value = 'No fingerprint members registered';
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        if (!isDeviceConnected.value) {
          scanStatus.value = 'Device not connected';
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        scanStatus.value = 'Waiting for finger...';
        final candidateTemplates = fingerprintMembers
            .map((m) => m.fingerprintData)
            .whereType<Uint8List>()
            .toList();
        final matchResult = await _scanner.identifyByDartafis(
          candidateTemplates: candidateTemplates,
          scoreThreshold: AppConstants.fingerprintMatchThreshold,
        );

        if (!_scanLoopActive) break;

        if (matchResult == null ||
            !matchResult.isMatched ||
            matchResult.templateIndex < 0 ||
            matchResult.templateIndex >= fingerprintMembers.length) {
          log('[KioskController] No match found '
              '(threshold=${AppConstants.fingerprintMatchThreshold})');
          scanStatus.value = 'Unknown fingerprint';
          detectedName.value = '';
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        final matchedMember = fingerprintMembers[matchResult.templateIndex];
        log('[KioskController] Match score: '
            '${matchResult.score.toStringAsFixed(1)} '
            'for template #${matchResult.templateIndex}');
        scanStatus.value = 'Identifying...';
        log('[KioskController] User matched: ${matchedMember.fullName} '
            '(score=${matchResult.score.toStringAsFixed(1)}, '
            'threshold=${AppConstants.fingerprintMatchThreshold})');

        detectedName.value = matchedMember.fullName;
        scanStatus.value = 'Match found: ${matchedMember.fullName}';

        final alreadyCheckedIn =
            await _isAlreadyCheckedIn(matchedMember.memberId);
        if (!alreadyCheckedIn) {
          await checkInMember(
              _authService.currentGymId ?? '', matchedMember.memberId);
        }
        await Future.delayed(const Duration(seconds: 2));
      } catch (e, stack) {
        log('[KioskController] scan loop error: $e');
        log('[KioskController] stack: $stack');
        scanStatus.value = 'Error: ${e.toString().substring(0, 60)}';
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<bool> _isAlreadyCheckedIn(String memberId) async {
    try {
      final db = await _dbHelper.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final existing = await db.query(
        'attendance',
        where: 'member_id = ? AND date = ? AND check_out IS NULL',
        whereArgs: [memberId, today],
      );
      return existing.isNotEmpty;
    } catch (_) {
      return false;
    }
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

      // Build fp member list – migrate legacy fingerprint_image on-the-fly.
      final fpList = <MemberModel>[];
      int migrated = 0;
      for (final m in members) {
        if (m.fingerprintData != null) {
          fpList.add(m);
          continue;
        }
        if (m.fingerprintImage != null &&
            m.fingerprintImage!.length == AppConstants.fingerprintImageSize) {
          log('[KioskController] migrating legacy fingerprint for ${m.memberId}');
          final serialized =
              await _dartafis.migrateLegacyImage(m.fingerprintImage!);
          if (serialized != null && _dartafis.isValidTemplate(serialized)) {
            await db.update(
              'members',
              {'fingerprint_data': serialized},
              where: 'member_id = ?',
              whereArgs: [m.memberId],
            );
            final migratedMember = m.copyWith(fingerprintData: serialized);
            fpList.add(migratedMember);
            migrated++;
            log('[KioskController] migrated legacy fingerprint for ${m.memberId}');
          }
        }
      }
      if (migrated > 0) {
        log('[KioskController] migrated $migrated legacy records');
        // Reload members to pick up migrated data
        final updatedRows = await db.query(
          'members',
          where: 'gym_id = ? AND status = ?',
          whereArgs: [gymId, 'active'],
          orderBy: 'full_name ASC',
        );
        members.value = updatedRows.map((e) => MemberModel.fromJson(e)).toList();
        fingerprintMembers.value = members
            .where((m) => m.fingerprintData != null)
            .toList();
      } else {
        fingerprintMembers.value = fpList;
      }

      for (final m in fingerprintMembers) {
        log('[KioskController] fingerprintMember - ${m.fullName} '
            'hasData=${m.fingerprintData != null}');
      }
      log('[KioskController] loadMembers loaded ${members.length} members '
          '(${fingerprintMembers.length} with fingerprint data)');
    } catch (e, stack) {
      log('[KioskController] loadMembers failed: $e');
      log('[KioskController] stack: $stack');
      AppPopup.error('Failed to load members: $e');
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
        AppPopup.info('Member already checked in today');
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
      AppPopup.error('Check-in failed: $e');
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

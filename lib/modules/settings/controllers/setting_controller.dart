import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/controllers/auth_service.dart';
import '../../auth/controllers/auth_repository.dart';
import '../../auth/controllers/auth_dao.dart';
import '../../auth/screens/login_view.dart';

class SettingController extends GetxController {
  final RxMap<String, dynamic> settings = <String, dynamic>{}.obs;
  final RxBool isLoading = true.obs;
  final AuthService _authService = Get.find<AuthService>();
  final AuthRepository _authRepository = Get.find<AuthRepository>();
  final AuthDao _authDao = Get.find<AuthDao>();

  // Password change state
  final RxBool isChangingPassword = false.obs;
  final RxBool passwordChangeSuccess = false.obs;
  final RxString passwordError = ''.obs;

  // Gym reset state
  final RxList<Map<String, dynamic>> allGyms = <Map<String, dynamic>>[].obs;
  final RxString selectedGymId = ''.obs;
  final RxBool isResettingGymPassword = false.obs;
  final RxString gymResetError = ''.obs;
  final RxBool gymResetSuccess = false.obs;

  String _resolveGymId(String gymId) {
    if (gymId.isNotEmpty) return gymId;
    return _authService.currentGymId ?? '';
  }

  @override
  void onInit() {
    super.onInit();
    log('[SettingController] onInit');
    loadSettings('');
    if (_authService.isSuperAdmin) {
      loadAllGyms();
    }
  }

  @override
  void onClose() {
    log('[SettingController] onClose');
    super.onClose();
  }

  Future<void> loadSettings(String gymId) async {
    gymId = _resolveGymId(gymId);
    log('[SettingController] loadSettings called gymId=$gymId');
    isLoading.value = true;
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('settings',
        where: 'gym_id = ?',
        whereArgs: [gymId],
        limit: 1,
      );
      if (result.isNotEmpty) {
        settings.value = Map<String, dynamic>.from(result.first);
        log('[SettingController] loadSettings loaded');
      } else {
        log('[SettingController] loadSettings - no settings found, creating defaults');
        await _createDefaults(db, gymId);
        await loadSettings(gymId);
      }
    } catch (e, stack) {
      log('[SettingController] loadSettings failed: $e');
      log('[SettingController] stack: $stack');
      Get.snackbar('Error', 'Failed to load settings');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _createDefaults(Database db, String gymId) async {
    log('[SettingController] _createDefaults for gymId=$gymId');
    await db.insert('settings', {
      'gym_id': gymId,
      'theme': 'system',
      'currency': 'PKR',
      'backup_frequency': 'daily',
      'receipt_header': '',
      'receipt_footer': '',
      'expiry_warning_days': 7,
    });
    log('[SettingController] _createDefaults completed');
  }

  Future<void> updateSetting(String gymId, String key, dynamic value) async {
    gymId = _resolveGymId(gymId);
    log('[SettingController] updateSetting called gymId=$gymId key=$key value=$value');
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update('settings', {key: value},
        where: 'gym_id = ?',
        whereArgs: [gymId],
      );
      settings[key] = value;
      log('[SettingController] updateSetting successful');
    } catch (e, stack) {
      log('[SettingController] updateSetting failed: $e');
      log('[SettingController] stack: $stack');
      Get.snackbar('Error', 'Failed to update setting');
    }
  }

  Future<void> updateTheme(String gymId, String value) async {
    await updateSetting(gymId, 'theme', value);
    Get.snackbar('Success', 'Theme updated to $value');
  }

  Future<void> updateCurrency(String gymId, String value) async {
    await updateSetting(gymId, 'currency', value);
    Get.snackbar('Success', 'Currency updated to $value');
  }

  Future<void> updateBackupFrequency(String gymId, String value) async {
    await updateSetting(gymId, 'backup_frequency', value);
    Get.snackbar('Success', 'Backup frequency updated to $value');
  }

  /// Change the current user's password (verifies old password).
  Future<void> changeMyPassword(String oldPassword, String newPassword) async {
    log('[SettingController] changeMyPassword called');
    isChangingPassword.value = true;
    passwordError.value = '';
    passwordChangeSuccess.value = false;
    try {
      final session = _authService.currentSession.value;
      if (session == null) {
        passwordError.value = 'No active session';
        return;
      }
      final success = await _authRepository.changePassword(
        session, oldPassword, newPassword,
      );
      if (success) {
        passwordChangeSuccess.value = true;
        log('[SettingController] changeMyPassword successful');
      } else {
        passwordError.value = 'Current password is incorrect';
        log('[SettingController] changeMyPassword failed - wrong password');
      }
    } catch (e, stack) {
      log('[SettingController] changeMyPassword error: $e');
      log('[SettingController] stack: $stack');
      passwordError.value = 'Failed to change password: $e';
    } finally {
      isChangingPassword.value = false;
    }
  }

  /// Superadmin: reset a gym's password without verifying old password.
  Future<void> resetGymPassword(String newPassword) async {
    log('[SettingController] resetGymPassword called');
    gymResetError.value = '';
    gymResetSuccess.value = false;
    isResettingGymPassword.value = true;
    try {
      final gymId = selectedGymId.value;
      if (gymId.isEmpty) {
        gymResetError.value = 'Please select a gym';
        return;
      }
      final success = await _authService.resetGymPassword(gymId, newPassword);
      if (success) {
        gymResetSuccess.value = true;
        log('[SettingController] resetGymPassword successful');
      } else {
        gymResetError.value = 'Failed to reset password';
      }
    } catch (e, stack) {
      log('[SettingController] resetGymPassword error: $e');
      log('[SettingController] stack: $stack');
      gymResetError.value = 'Failed to reset password: $e';
    } finally {
      isResettingGymPassword.value = false;
    }
  }

  Future<void> loadAllGyms() async {
    log('[SettingController] loadAllGyms called');
    try {
      final gyms = await _authDao.getAllGyms();
      allGyms.value = gyms;
      log('[SettingController] loadAllGyms loaded ${gyms.length} gyms');
    } catch (e, stack) {
      log('[SettingController] loadAllGyms failed: $e');
      log('[SettingController] stack: $stack');
    }
  }

  Future<void> exportDatabase() async {
    log('[SettingController] exportDatabase called');
    try {
      final dbPath = await DatabaseHelper.databasePath;
      final file = File(dbPath);
      if (!file.existsSync()) {
        Get.snackbar('Error', 'Database file not found');
        return;
      }
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Database',
        fileName: 'gym_erp_backup.db',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      if (result == null) {
        log('[SettingController] exportDatabase - cancelled');
        return;
      }
      await file.copy(result);
      log('[SettingController] exportDatabase - exported to $result');
      Get.snackbar('Success', 'Database exported successfully');
    } catch (e, stack) {
      log('[SettingController] exportDatabase failed: $e');
      log('[SettingController] stack: $stack');
      Get.snackbar('Error', 'Failed to export database: $e');
    }
  }

  Future<void> importDatabase() async {
    log('[SettingController] importDatabase called');
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import Database',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      if (result == null || result.files.single.path == null) {
        log('[SettingController] importDatabase - cancelled');
        return;
      }
      final source = File(result.files.single.path!);
      if (!source.existsSync()) {
        Get.snackbar('Error', 'Selected file not found');
        return;
      }
      final confirm = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Import Database'),
          content: const Text(
            'This will replace your current database with the imported one. '
            'All current data will be lost. Continue?',
          ),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Replace', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      await DatabaseHelper.instance.close();
      final dbPath = await DatabaseHelper.databasePath;
      await source.copy(dbPath);
      log('[SettingController] importDatabase - replaced with $dbPath');
      Get.snackbar('Success', 'Database imported. Restarting app...');
      await Future.delayed(const Duration(seconds: 1));
      _authService.logout();
      Get.offAll(() => const LoginView());
    } catch (e, stack) {
      log('[SettingController] importDatabase failed: $e');
      log('[SettingController] stack: $stack');
      Get.snackbar('Error', 'Failed to import database: $e');
    }
  }
}

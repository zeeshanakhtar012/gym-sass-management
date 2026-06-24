import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/popups/app_popup.dart';

class BackupController extends GetxController {
  final BackupService _backupService = BackupService.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final RxBool isLoading = false.obs;
  final RxDouble progress = 0.0.obs;
  final RxString lastBackupTime = 'Never'.obs;
  final RxList<Map<String, dynamic>> backupFiles = <Map<String, dynamic>>[].obs;
  final RxString databaseSize = ''.obs;

  @override
  void onInit() {
    super.onInit();
    log('[BackupController] onInit');
    loadDatabaseInfo();
    getBackupFiles();
  }

  @override
  void onClose() {
    log('[BackupController] onClose');
    super.onClose();
  }

  Future<void> loadDatabaseInfo() async {
    log('[BackupController] loadDatabaseInfo');
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dir.path, AppConstants.dbName));
      if (dbFile.existsSync()) {
        final size = dbFile.lengthSync();
        databaseSize.value = _formatFileSize(size);
        log('[BackupController] loadDatabaseInfo - db size=${databaseSize.value}');
      } else {
        log('[BackupController] loadDatabaseInfo - db file not found');
      }
    } catch (e, stack) {
      log('[BackupController] loadDatabaseInfo failed: $e');
      log('[BackupController] stack: $stack');
    }
  }

  Future<void> createBackup(String gymId) async {
    log('[BackupController] createBackup called gymId=$gymId');
    isLoading.value = true;
    progress.value = 0.0;
    try {
      progress.value = 0.3;
      final filePath = await _backupService.exportBackup(gymId);
      progress.value = 1.0;
      lastBackupTime.value = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      await getBackupFiles();
      log('[BackupController] createBackup successful - filePath=$filePath');
      AppPopup.success('Backup created successfully');
    } catch (e, stack) {
      log('[BackupController] createBackup failed: $e');
      log('[BackupController] stack: $stack');
      AppPopup.error('Backup failed: $e');
    } finally {
      isLoading.value = false;
      progress.value = 0.0;
    }
  }

  Future<void> restoreBackup(String gymId) async {
    log('[BackupController] restoreBackup called gymId=$gymId');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null || result.files.isEmpty) {
        log('[BackupController] restoreBackup - no file selected');
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        log('[BackupController] restoreBackup - file path null');
        return;
      }
      log('[BackupController] restoreBackup - selected file=$filePath');

      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Restore Backup'),
          content: const Text(
            'This will replace all current data with the backup. This action cannot be undone. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        log('[BackupController] restoreBackup - cancelled by user');
        return;
      }

      isLoading.value = true;
      progress.value = 0.0;
      try {
        progress.value = 0.3;
        final success = await _backupService.importBackup(filePath, gymId);
        progress.value = 1.0;
        if (success) {
          log('[BackupController] restoreBackup successful');
          AppPopup.success('Backup restored successfully');
        } else {
          log('[BackupController] restoreBackup failed - service returned false');
          AppPopup.error('Failed to restore backup');
        }
      } finally {
        isLoading.value = false;
        progress.value = 0.0;
      }
    } catch (e, stack) {
      log('[BackupController] restoreBackup failed: $e');
      log('[BackupController] stack: $stack');
      AppPopup.error('Restore failed: $e');
    }
  }

  Future<void> getBackupFiles() async {
    log('[BackupController] getBackupFiles');
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupPattern = RegExp(r'gym_backup_.*\.zip$');
      final files = dir.listSync().where((f) {
        return f is File && backupPattern.hasMatch(p.basename(f.path));
      }).map((f) {
        final file = f as File;
        final stat = file.statSync();
        return {
          'path': file.path,
          'name': p.basename(file.path),
          'size': stat.size,
          'modified': stat.modified.toIso8601String(),
        };
      }).toList();
      files.sort((a, b) => (b['modified'] as String).compareTo(a['modified'] as String));
      backupFiles.value = files;
      if (files.isNotEmpty) {
        lastBackupTime.value = DateFormat('yyyy-MM-dd HH:mm').format(
          DateTime.parse(files.first['modified'] as String),
        );
      }
      log('[BackupController] getBackupFiles found ${files.length} files');
    } catch (e, stack) {
      log('[BackupController] getBackupFiles failed: $e');
      log('[BackupController] stack: $stack');
    }
  }

  Future<void> deleteBackupFile(String filePath) async {
    log('[BackupController] deleteBackupFile called filePath=$filePath');
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
        backupFiles.removeWhere((f) => f['path'] == filePath);
        log('[BackupController] deleteBackupFile successful');
        AppPopup.success('Backup file deleted');
      } else {
        log('[BackupController] deleteBackupFile - file not found');
      }
    } catch (e, stack) {
      log('[BackupController] deleteBackupFile failed: $e');
      log('[BackupController] stack: $stack');
      AppPopup.error('Failed to delete backup: $e');
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

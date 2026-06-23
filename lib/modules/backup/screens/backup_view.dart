import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/helpers/formatters.dart';
import '../../../widgets/app_drawer.dart';
import '../controllers/backup_controller.dart';

class BackupView extends GetView<BackupController> {
  final String gymId;
  const BackupView({super.key, this.gymId = ''});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) return _buildProgress();
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _buildStatusCard(),
            const SizedBox(height: AppSpacing.md),
            _buildActionButtons(),
            const SizedBox(height: AppSpacing.lg),
            _buildBackupFilesList(),
          ],
        );
      }),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIconsRegular.database, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Database Info', style: AppTextStyles.headingSm),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            _buildInfoRow('Last Backup', controller.lastBackupTime.value),
            const SizedBox(height: AppSpacing.sm),
            _buildInfoRow('Database Size', controller.databaseSize.value),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondaryD)),
        Text(value, style: AppTextStyles.bodyMd),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => controller.createBackup(gymId),
              icon: const Icon(PhosphorIconsRegular.cloudArrowUp, size: 22),
              label: const Text('Create Backup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => controller.restoreBackup(gymId),
              icon: const Icon(PhosphorIconsRegular.cloudArrowDown, size: 22),
              label: const Text('Restore Backup'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            const SizedBox(height: AppSpacing.lg),
            Obx(() {
              final pct = (controller.progress.value * 100).toInt();
              return Text('Processing... $pct%', style: AppTextStyles.bodyLg);
            }),
            const SizedBox(height: AppSpacing.md),
            Obx(() => LinearProgressIndicator(value: controller.progress.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupFilesList() {
    return Obx(() {
      if (controller.backupFiles.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: Column(
              children: [
                Icon(PhosphorIconsRegular.fileCloud, size: 48, color: AppColors.neutralGray),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No backup files yet',
                  style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondaryD),
                ),
              ],
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text('Backup Files', style: AppTextStyles.headingSm),
          ),
          ...controller.backupFiles.map((file) => _buildBackupFileItem(file)),
        ],
      );
    });
  }

  Widget _buildBackupFileItem(Map<String, dynamic> file) {
    final size = file['size'] as int;
    final modified = DateTime.tryParse(file['modified'] as String? ?? '');

    return Dismissible(
      key: ValueKey(file['path']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: const Icon(PhosphorIconsRegular.trash, color: Colors.white),
      ),
      onDismissed: (_) => _confirmDelete(file['path'] as String),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ListTile(
          leading: const Icon(PhosphorIconsRegular.fileZip, color: AppColors.primary),
          title: Text(file['name'] as String, style: AppTextStyles.bodyMd),
          subtitle: Text(
            '${_formatSize(size)} • ${modified != null ? Formatters.dateTime(modified) : '-'}',
            style: AppTextStyles.bodySm,
          ),
          trailing: IconButton(
            icon: const Icon(PhosphorIconsRegular.trash, color: AppColors.danger),
            onPressed: () => _confirmDelete(file['path'] as String),
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _confirmDelete(String filePath) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Backup'),
        content: const Text('Are you sure you want to delete this backup file?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteBackupFile(filePath);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

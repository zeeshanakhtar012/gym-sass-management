import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/helpers/formatters.dart';
import '../../../widgets/app_drawer.dart';
import '../controllers/notification_controller.dart';

class NotificationView extends GetView<NotificationController> {
  final String gymId;
  const NotificationView({super.key, this.gymId = ''});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Obx(() => Text('Notifications${controller.unreadCount > 0 ? ' (${controller.unreadCount})' : ''}')),
        actions: [
          Obx(() {
            if (controller.unreadCount == 0) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(PhosphorIconsRegular.checkFat),
              tooltip: 'Mark All Read',
              onPressed: () => controller.markAllAsRead(gymId),
            );
          }),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.trash),
            tooltip: 'Clear All',
            onPressed: () => _confirmClearAll(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.notifications.isEmpty) return _buildEmpty();
        return _buildList();
      }),
    );
  }

  Widget _buildList() {
    final groups = NotificationController.groupByDate(controller.notifications);
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: groups.length,
      itemBuilder: (_, sectionIndex) {
        final section = groups[sectionIndex];
        final items = section['items'] as List<Map<String, dynamic>>;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
              child: Text(
                section['header'] as String,
                style: AppTextStyles.label.copyWith(color: AppColors.textSecondaryD),
              ),
            ),
            ...items.map((item) => _buildNotificationItem(item)),
          ],
        );
      },
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isUnread = notification['is_read'] == 0;
    final type = notification['type'] as String? ?? '';
    final createdAt = DateTime.tryParse(notification['created_at'] as String? ?? '');
    final timeAgo = createdAt != null ? _timeAgo(createdAt) : '';

    return Dismissible(
      key: ValueKey(notification['notification_id']),
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
      onDismissed: (_) => controller.deleteNotification(notification['notification_id'] as int),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: () {
            if (isUnread) {
              controller.markAsRead(notification['notification_id'] as int);
            }
            _navigateToReference(notification);
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeIcon(type),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'] as String? ?? '',
                              style: AppTextStyles.headingSm.copyWith(
                                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(timeAgo, style: AppTextStyles.bodySm),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        notification['message'] as String? ?? '',
                        style: AppTextStyles.bodyMd,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: AppSpacing.sm, top: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'expiry':
        icon = PhosphorIconsRegular.warning;
        color = AppColors.warning;
      case 'payment':
        icon = PhosphorIconsRegular.coin;
        color = AppColors.success;
      case 'attendance':
        icon = PhosphorIconsRegular.clock;
        color = AppColors.info;
      case 'system':
      default:
        icon = PhosphorIconsRegular.gear;
        color = AppColors.neutralGray;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return Formatters.shortDate(date);
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsRegular.bellSlash, size: 64, color: AppColors.neutralGray),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No notifications',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondaryD),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You\'re all caught up!',
            style: AppTextStyles.bodySm,
          ),
        ],
      ),
    );
  }

  void _navigateToReference(Map<String, dynamic> notification) {
    final refType = notification['reference_type'] as String?;
    final refId = notification['reference_id'] as String?;
    if (refType == null || refId == null) return;
  }

  void _confirmClearAll() {
    Get.dialog(
      AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.clearAll(gymId);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

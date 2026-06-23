import 'dart:developer';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';

class NotificationController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxInt unreadCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    log('[NotificationController] onInit');
    loadNotifications('');
  }

  @override
  void onClose() {
    log('[NotificationController] onClose');
    super.onClose();
  }

  Future<void> loadNotifications(String gymId) async {
    log('[NotificationController] loadNotifications called gymId=$gymId');
    isLoading.value = true;
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'notifications',
        where: 'gym_id = ?',
        whereArgs: [gymId],
        orderBy: 'created_at DESC',
      );
      notifications.value = rows;
      unreadCount.value = rows.where((n) => n['is_read'] == 0).length;
      log('[NotificationController] loadNotifications loaded ${rows.length} notifications, unread=${unreadCount.value}');
    } catch (e, stack) {
      log('[NotificationController] loadNotifications failed: $e');
      log('[NotificationController] stack: $stack');
      Get.snackbar('Error', 'Failed to load notifications: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAsRead(int notificationId) async {
    log('[NotificationController] markAsRead called notificationId=$notificationId');
    try {
      final db = await _dbHelper.database;
      await db.update(
        'notifications',
        {'is_read': 1},
        where: 'notification_id = ?',
        whereArgs: [notificationId],
      );
      final index = notifications.indexWhere((n) => n['notification_id'] == notificationId);
      if (index != -1) {
        notifications[index]['is_read'] = 1;
        notifications.refresh();
        unreadCount.value = notifications.where((n) => n['is_read'] == 0).length;
        log('[NotificationController] markAsRead successful');
      }
    } catch (e, stack) {
      log('[NotificationController] markAsRead failed: $e');
      log('[NotificationController] stack: $stack');
      Get.snackbar('Error', 'Failed to mark as read: $e');
    }
  }

  Future<void> markAllAsRead(String gymId) async {
    log('[NotificationController] markAllAsRead called gymId=$gymId');
    try {
      final db = await _dbHelper.database;
      await db.update(
        'notifications',
        {'is_read': 1},
        where: 'gym_id = ? AND is_read = 0',
        whereArgs: [gymId],
      );
      for (final n in notifications) {
        n['is_read'] = 1;
      }
      notifications.refresh();
      unreadCount.value = 0;
      log('[NotificationController] markAllAsRead successful');
      Get.snackbar('Success', 'All notifications marked as read');
    } catch (e, stack) {
      log('[NotificationController] markAllAsRead failed: $e');
      log('[NotificationController] stack: $stack');
      Get.snackbar('Error', 'Failed to mark all as read: $e');
    }
  }

  Future<void> deleteNotification(int id) async {
    log('[NotificationController] deleteNotification called id=$id');
    try {
      final db = await _dbHelper.database;
      await db.delete('notifications', where: 'notification_id = ?', whereArgs: [id]);
      notifications.removeWhere((n) => n['notification_id'] == id);
      unreadCount.value = notifications.where((n) => n['is_read'] == 0).length;
      log('[NotificationController] deleteNotification successful');
    } catch (e, stack) {
      log('[NotificationController] deleteNotification failed: $e');
      log('[NotificationController] stack: $stack');
      Get.snackbar('Error', 'Failed to delete notification: $e');
    }
  }

  Future<void> clearAll(String gymId) async {
    log('[NotificationController] clearAll called gymId=$gymId');
    try {
      final db = await _dbHelper.database;
      await db.delete('notifications', where: 'gym_id = ?', whereArgs: [gymId]);
      notifications.clear();
      unreadCount.value = 0;
      log('[NotificationController] clearAll successful');
      Get.snackbar('Success', 'All notifications cleared');
    } catch (e, stack) {
      log('[NotificationController] clearAll failed: $e');
      log('[NotificationController] stack: $stack');
      Get.snackbar('Error', 'Failed to clear notifications: $e');
    }
  }

  Future<void> createNotification(
    String gymId,
    String type,
    String title,
    String message, {
    String? referenceId,
    String? referenceType,
  }) async {
    log('[NotificationController] createNotification called gymId=$gymId type=$type title=$title');
    try {
      final db = await _dbHelper.database;
      await db.insert('notifications', {
        'gym_id': gymId,
        'type': type,
        'title': title,
        'message': message,
        'reference_id': referenceId,
        'reference_type': referenceType,
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      await loadNotifications(gymId);
      log('[NotificationController] createNotification successful');
    } catch (e, stack) {
      log('[NotificationController] createNotification failed: $e');
      log('[NotificationController] stack: $stack');
      Get.snackbar('Error', 'Failed to create notification: $e');
    }
  }

  static List<Map<String, dynamic>> groupByDate(List<Map<String, dynamic>> items) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final createdAt = DateTime.tryParse(item['created_at'] as String? ?? '');
      if (createdAt == null) continue;
      String key;
      if (DateFormat('yyyy-MM-dd').format(createdAt) == DateFormat('yyyy-MM-dd').format(today)) {
        key = 'Today';
      } else if (DateFormat('yyyy-MM-dd').format(createdAt) == DateFormat('yyyy-MM-dd').format(yesterday)) {
        key = 'Yesterday';
      } else if (createdAt.isAfter(weekStart)) {
        key = 'This Week';
      } else {
        key = 'Earlier';
      }
      groups.putIfAbsent(key, () => []);
      groups[key]!.add(item);
    }
    return groups.entries.map((e) => {'header': e.key, 'items': e.value}).toList();
  }
}

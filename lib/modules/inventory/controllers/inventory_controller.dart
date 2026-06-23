import 'dart:developer';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';

class InventoryController extends GetxController {
  final RxList<Map<String, dynamic>> items = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxString searchQuery = ''.obs;
  final RxBool lowStockOnly = false.obs;

  @override
  void onInit() {
    super.onInit();
    log('[InventoryController] onInit');
    loadItems('');
  }

  @override
  void onClose() {
    log('[InventoryController] onClose');
    super.onClose();
  }

  List<Map<String, dynamic>> get filteredItems {
    final query = searchQuery.value.trim().toLowerCase();
    var list = items;
    if (lowStockOnly.value) {
      list = items.where((i) => (i['quantity'] as int) <= (i['reorder_level'] as int)).toList().obs;
    }
    if (query.isEmpty) return list;
    return list.where((i) {
      return (i['name'] as String? ?? '').toLowerCase().contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get lowStockItems {
    return items.where((i) => (i['quantity'] as int) <= (i['reorder_level'] as int)).toList();
  }

  Future<void> loadItems(String gymId) async {
    log('[InventoryController] loadItems called gymId=$gymId');
    isLoading.value = true;
    try {
      final db = await DatabaseHelper.instance.database;
      final data = await db.query('inventory',
        where: 'gym_id = ?',
        whereArgs: [gymId],
        orderBy: 'name ASC',
      );
      items.value = data;
      log('[InventoryController] loadItems loaded ${data.length} items');
    } catch (e, stack) {
      log('[InventoryController] loadItems failed: $e');
      log('[InventoryController] stack: $stack');
      Get.snackbar('Error', 'Failed to load inventory');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> createItem(Map<String, dynamic> data) async {
    log('[InventoryController] createItem called name=${data['name']}');
    try {
      final db = await DatabaseHelper.instance.database;
      final id = const Uuid().v4();
      final now = DateTime.now().toIso8601String();
      await db.insert('inventory', {
        'item_id': id,
        'gym_id': data['gym_id'],
        'name': data['name'],
        'quantity': data['quantity'],
        'cost_price': data['cost_price'],
        'selling_price': data['selling_price'],
        'reorder_level': data['reorder_level'],
        'created_at': now,
        'updated_at': now,
      });
      await loadItems(data['gym_id']);
      log('[InventoryController] createItem successful id=$id');
      Get.snackbar('Success', 'Item added successfully');
      return true;
    } catch (e, stack) {
      log('[InventoryController] createItem failed: $e');
      log('[InventoryController] stack: $stack');
      Get.snackbar('Error', 'Failed to add item');
      return false;
    }
  }

  Future<bool> updateItem(Map<String, dynamic> data) async {
    log('[InventoryController] updateItem called item_id=${data['item_id']}');
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update('inventory', {
        'name': data['name'],
        'quantity': data['quantity'],
        'cost_price': data['cost_price'],
        'selling_price': data['selling_price'],
        'reorder_level': data['reorder_level'],
        'updated_at': DateTime.now().toIso8601String(),
      }, where: 'item_id = ?', whereArgs: [data['item_id']]);
      await loadItems(data['gym_id']);
      log('[InventoryController] updateItem successful');
      Get.snackbar('Success', 'Item updated successfully');
      return true;
    } catch (e, stack) {
      log('[InventoryController] updateItem failed: $e');
      log('[InventoryController] stack: $stack');
      Get.snackbar('Error', 'Failed to update item');
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    log('[InventoryController] deleteItem called id=$id');
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('inventory', where: 'item_id = ?', whereArgs: [id]);
      items.removeWhere((i) => i['item_id'] == id);
      log('[InventoryController] deleteItem successful');
      Get.snackbar('Success', 'Item deleted successfully');
      return true;
    } catch (e, stack) {
      log('[InventoryController] deleteItem failed: $e');
      log('[InventoryController] stack: $stack');
      Get.snackbar('Error', 'Failed to delete item');
      return false;
    }
  }
}

import 'dart:developer';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/controllers/auth_service.dart';
import '../../../widgets/popups/app_popup.dart';

class ExpenseController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  final RxList<Map<String, dynamic>> expenses = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxString searchQuery = ''.obs;
  final RxString selectedCategory = 'all'.obs;

  String _resolveGymId(String gymId) {
    if (gymId.isNotEmpty) return gymId;
    return _authService.currentGymId ?? '';
  }

  @override
  void onInit() {
    super.onInit();
    log('[ExpenseController] onInit');
    loadExpenses('');
  }

  @override
  void onClose() {
    log('[ExpenseController] onClose');
    super.onClose();
  }

  List<Map<String, dynamic>> get filteredExpenses {
    final query = searchQuery.value.trim().toLowerCase();
    final category = selectedCategory.value;
    var list = expenses;
    if (category != 'all') {
      list = expenses.where((e) => e['category'] == category).toList().obs;
    }
    if (query.isEmpty) return list;
    return list.where((e) {
      final desc = (e['description'] as String? ?? '').toLowerCase();
      return desc.contains(query);
    }).toList();
  }

  Future<void> loadExpenses(String gymId) async {
    gymId = _resolveGymId(gymId);
    log('[ExpenseController] loadExpenses called gymId=$gymId');
    isLoading.value = true;
    try {
      final db = await DatabaseHelper.instance.database;
      final data = await db.query('expenses',
        where: 'gym_id = ?',
        whereArgs: [gymId],
        orderBy: 'expense_date DESC',
      );
      expenses.value = data;
      log('[ExpenseController] loadExpenses loaded ${data.length} records');
    } catch (e, stack) {
      log('[ExpenseController] loadExpenses failed: $e');
      log('[ExpenseController] stack: $stack');
      AppPopup.error('Failed to load expenses');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> createExpense(Map<String, dynamic> data) async {
    final resolvedGymId = _resolveGymId(data['gym_id'] as String? ?? '');
    log('[ExpenseController] createExpense called gym_id=$resolvedGymId amount=${data['amount']}');
    try {
      final db = await DatabaseHelper.instance.database;
      final id = const Uuid().v4();
      await db.insert('expenses', {
        'expense_id': id,
        'gym_id': resolvedGymId,
        'category': data['category'],
        'amount': data['amount'],
        'description': data['description'],
        'expense_date': data['expense_date'],
        'created_at': DateTime.now().toIso8601String(),
      });
      await loadExpenses(resolvedGymId);
      log('[ExpenseController] createExpense successful');
      AppPopup.success('Expense added successfully');
      return true;
    } catch (e, stack) {
      log('[ExpenseController] createExpense failed: $e');
      log('[ExpenseController] stack: $stack');
      AppPopup.error('Failed to add expense');
      return false;
    }
  }

  Future<bool> updateExpense(Map<String, dynamic> data) async {
    final resolvedGymId = _resolveGymId(data['gym_id'] as String? ?? '');
    log('[ExpenseController] updateExpense called expense_id=${data['expense_id']}');
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update('expenses', {
        'category': data['category'],
        'amount': data['amount'],
        'description': data['description'],
        'expense_date': data['expense_date'],
      }, where: 'expense_id = ?', whereArgs: [data['expense_id']]);
      await loadExpenses(resolvedGymId);
      log('[ExpenseController] updateExpense successful');
      AppPopup.success('Expense updated successfully');
      return true;
    } catch (e, stack) {
      log('[ExpenseController] updateExpense failed: $e');
      log('[ExpenseController] stack: $stack');
      AppPopup.error('Failed to update expense');
      return false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    log('[ExpenseController] deleteExpense called id=$id');
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('expenses', where: 'expense_id = ?', whereArgs: [id]);
      expenses.removeWhere((e) => e['expense_id'] == id);
      log('[ExpenseController] deleteExpense successful');
      AppPopup.success('Expense deleted successfully');
      return true;
    } catch (e, stack) {
      log('[ExpenseController] deleteExpense failed: $e');
      log('[ExpenseController] stack: $stack');
      AppPopup.error('Failed to delete expense');
      return false;
    }
  }

  Future<Map<String, int>> getTotalByCategory(String gymId) async {
    log('[ExpenseController] getTotalByCategory called gymId=$gymId');
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        'SELECT category, SUM(amount) as total FROM expenses WHERE gym_id = ? GROUP BY category',
        [gymId],
      );
      final map = <String, int>{};
      for (final row in result) {
        map[row['category'] as String] = (row['total'] as num).toInt();
      }
      log('[ExpenseController] getTotalByCategory returned ${map.length} categories');
      return map;
    } catch (e, stack) {
      log('[ExpenseController] getTotalByCategory failed: $e');
      log('[ExpenseController] stack: $stack');
      return {};
    }
  }

  Future<int> getTotalExpenses(String gymId, String startDate, String endDate) async {
    log('[ExpenseController] getTotalExpenses called gymId=$gymId from=$startDate to=$endDate');
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE gym_id = ? AND expense_date BETWEEN ? AND ?',
        [gymId, startDate, endDate],
      );
      final total = (result.first['total'] as num).toInt();
      log('[ExpenseController] getTotalExpenses returned $total');
      return total;
    } catch (e, stack) {
      log('[ExpenseController] getTotalExpenses failed: $e');
      log('[ExpenseController] stack: $stack');
      return 0;
    }
  }
}

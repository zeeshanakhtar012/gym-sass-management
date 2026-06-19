import 'dart:developer';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';

class PaymentController extends GetxController {
  final RxList<Map<String, dynamic>> payments = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredPayments = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> packages = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxString searchQuery = ''.obs;

  final RxInt todayRevenue = 0.obs;
  final RxInt monthRevenue = 0.obs;
  final RxInt totalPaymentsCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    log('[PaymentController] onInit');
    loadPayments('');
  }

  @override
  void onClose() {
    log('[PaymentController] onClose');
    super.onClose();
  }

  Future<void> loadPayments(String gymId) async {
    log('[PaymentController] loadPayments called gymId=$gymId');
    isLoading.value = true;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT p.*, m.full_name AS member_name
        FROM payments p
        LEFT JOIN members m ON p.member_id = m.member_id
        WHERE p.gym_id = ?
        ORDER BY p.created_at DESC
      ''', [gymId]);
      payments.value = rows;
      _applyFilters();
      _calculateSummaries();
      log('[PaymentController] loadPayments loaded ${rows.length} payments');
    } catch (e, stack) {
      log('[PaymentController] loadPayments failed: $e');
      log('[PaymentController] stack: $stack');
      Get.snackbar('Error', 'Failed to load payments: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadPackages(String gymId) async {
    log('[PaymentController] loadPackages called gymId=$gymId');
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('packages',
        where: 'gym_id = ?',
        whereArgs: [gymId],
        orderBy: 'name ASC',
      );
      packages.value = rows;
      log('[PaymentController] loadPackages loaded ${rows.length} packages');
    } catch (e, stack) {
      log('[PaymentController] loadPackages failed: $e');
      log('[PaymentController] stack: $stack');
    }
  }

  void _calculateSummaries() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final thisMonth = DateFormat('yyyy-MM').format(DateTime.now());
    int tRev = 0, mRev = 0;
    for (final p in payments) {
      final date = (p['payment_date'] as String? ?? '').substring(0, 10);
      final total = p['total'] as int? ?? 0;
      if (date == today) tRev += total;
      if (date.startsWith(thisMonth)) mRev += total;
    }
    todayRevenue.value = tRev;
    monthRevenue.value = mRev;
    totalPaymentsCount.value = payments.length;
    log('[PaymentController] _calculateSummaries todayRev=$tRev monthRev=$mRev totalCount=${payments.length}');
  }

  void setSearchQuery(String query) {
    log('[PaymentController] setSearchQuery query=$query');
    searchQuery.value = query;
    _applyFilters();
  }

  void _applyFilters() {
    final query = searchQuery.value.toLowerCase();
    if (query.isEmpty) {
      filteredPayments.value = payments;
      return;
    }
    filteredPayments.value = payments.where((p) {
      final name = (p['member_name'] as String?)?.toLowerCase() ?? '';
      final method = (p['method'] as String?)?.toLowerCase() ?? '';
      final remarks = (p['remarks'] as String?)?.toLowerCase() ?? '';
      return name.contains(query) || method.contains(query) || remarks.contains(query);
    }).toList();
    log('[PaymentController] _applyFilters filtered=${filteredPayments.length}/${payments.length}');
  }

  Future<void> createPayment(Map<String, dynamic> data) async {
    log('[PaymentController] createPayment called member_id=${data['member_id']} amount=${data['amount']}');
    try {
      final db = await DatabaseHelper.instance.database;
      final paymentId = const Uuid().v4();
      final nowDt = DateTime.now();
      final now = nowDt.toIso8601String();
      final paymentDate = data['payment_date'] as String? ?? DateFormat('yyyy-MM-dd').format(nowDt);

      final amount = data['amount'] as int;
      final discount = data['discount'] as int? ?? 0;
      final tax = data['tax'] as int? ?? 0;
      final total = amount - discount + tax;

      await db.insert('payments', {
        'payment_id': paymentId,
        'gym_id': data['gym_id'],
        'member_id': data['member_id'],
        'package_id': data['package_id'],
        'amount': amount,
        'discount': discount,
        'tax': tax,
        'total': total,
        'method': data['method'],
        'remarks': data['remarks'],
        'received_by': data['received_by'],
        'payment_date': paymentDate,
        'created_at': now,
      });

      final invoiceId = const Uuid().v4();
      final gymCode = (data['gym_id'] as String).length > 4
          ? (data['gym_id'] as String).substring(0, 4).toUpperCase()
          : 'GYM';
      final count = await db.query('invoices', where: 'gym_id = ?', whereArgs: [data['gym_id']]);
      final invoiceNumber = 'INV-$gymCode-${(count.length + 1).toString().padLeft(4, '0')}';

      await db.insert('invoices', {
        'invoice_id': invoiceId,
        'gym_id': data['gym_id'],
        'member_id': data['member_id'],
        'payment_id': paymentId,
        'invoice_number': invoiceNumber,
        'package_name': data['package_name'],
        'amount': amount,
        'discount': discount,
        'tax': tax,
        'total': total,
        'status': 'paid',
        'invoice_date': paymentDate,
      });

      await loadPayments(data['gym_id']);
      log('[PaymentController] createPayment successful paymentId=$paymentId invoiceNumber=$invoiceNumber');
      Get.snackbar('Success', 'Payment recorded successfully');
    } catch (e, stack) {
      log('[PaymentController] createPayment failed: $e');
      log('[PaymentController] stack: $stack');
      Get.snackbar('Error', 'Failed to create payment: $e');
    }
  }

  Future<void> deletePayment(String id, String gymId) async {
    log('[PaymentController] deletePayment called id=$id gymId=$gymId');
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('payments', where: 'payment_id = ?', whereArgs: [id]);
      await loadPayments(gymId);
      log('[PaymentController] deletePayment successful');
      Get.snackbar('Success', 'Payment deleted');
    } catch (e, stack) {
      log('[PaymentController] deletePayment failed: $e');
      log('[PaymentController] stack: $stack');
      Get.snackbar('Error', 'Failed to delete payment: $e');
    }
  }

  List<Map<String, dynamic>> getPaymentsByMember(String memberId) {
    return payments.where((p) => p['member_id'] == memberId).toList();
  }
}

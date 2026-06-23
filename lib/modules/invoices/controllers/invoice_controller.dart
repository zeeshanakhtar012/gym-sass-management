import 'dart:developer';

import 'package:get/get.dart';
import '../../../core/database/database_helper.dart';

class InvoiceController extends GetxController {
  final RxList<Map<String, dynamic>> invoices = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredInvoices = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxString searchQuery = ''.obs;
  final RxString statusFilter = 'All'.obs;

  @override
  void onInit() {
    super.onInit();
    log('[InvoiceController] onInit');
    loadInvoices('');
  }

  @override
  void onClose() {
    log('[InvoiceController] onClose');
    super.onClose();
  }

  Future<void> loadInvoices(String gymId) async {
    log('[InvoiceController] loadInvoices called gymId=$gymId');
    isLoading.value = true;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT i.*, m.full_name AS member_name, m.phone AS member_phone,
               m.address AS member_address, p.method AS payment_method
        FROM invoices i
        LEFT JOIN members m ON i.member_id = m.member_id
        LEFT JOIN payments p ON i.payment_id = p.payment_id
        WHERE i.gym_id = ?
        ORDER BY i.invoice_date DESC
      ''', [gymId]);
      invoices.value = rows;
      _applyFilters();
      log('[InvoiceController] loadInvoices loaded ${rows.length} invoices');
    } catch (e, stack) {
      log('[InvoiceController] loadInvoices failed: $e');
      log('[InvoiceController] stack: $stack');
      Get.snackbar('Error', 'Failed to load invoices: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void setSearchQuery(String query) {
    log('[InvoiceController] setSearchQuery query=$query');
    searchQuery.value = query;
    _applyFilters();
  }

  void setStatusFilter(String status) {
    log('[InvoiceController] setStatusFilter status=$status');
    statusFilter.value = status;
    _applyFilters();
  }

  void _applyFilters() {
    final query = searchQuery.value.toLowerCase();
    final status = statusFilter.value;
    filteredInvoices.value = invoices.where((inv) {
      final matchesStatus = status == 'All' || (inv['status'] as String?) == status.toLowerCase();
      final matchesSearch = query.isEmpty ||
          (inv['invoice_number'] as String?)?.toLowerCase().contains(query) == true ||
          (inv['member_name'] as String?)?.toLowerCase().contains(query) == true ||
          (inv['package_name'] as String?)?.toLowerCase().contains(query) == true;
      return matchesStatus && matchesSearch;
    }).toList();
    log('[InvoiceController] _applyFilters filtered=${filteredInvoices.length}/${invoices.length}');
  }

  List<Map<String, dynamic>> getInvoicesByMember(String memberId) {
    log('[InvoiceController] getInvoicesByMember called memberId=$memberId');
    return invoices.where((i) => i['member_id'] == memberId).toList();
  }

  Future<void> deleteInvoice(String id, String gymId) async {
    log('[InvoiceController] deleteInvoice called id=$id gymId=$gymId');
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('invoices', where: 'invoice_id = ?', whereArgs: [id]);
      await loadInvoices(gymId);
      log('[InvoiceController] deleteInvoice successful');
      Get.snackbar('Success', 'Invoice deleted');
    } catch (e, stack) {
      log('[InvoiceController] deleteInvoice failed: $e');
      log('[InvoiceController] stack: $stack');
      Get.snackbar('Error', 'Failed to delete invoice: $e');
    }
  }

  void printInvoice(Map<String, dynamic> invoice) {
    log('[InvoiceController] printInvoice called number=${invoice['invoice_number']}');
    Get.snackbar('Print', 'Printing invoice ${invoice['invoice_number']}...');
  }
}

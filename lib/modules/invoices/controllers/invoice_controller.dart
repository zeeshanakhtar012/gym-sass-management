import 'dart:developer';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/helpers/formatters.dart';
import '../../../widgets/popups/app_popup.dart';
import '../../auth/controllers/auth_service.dart';

class InvoiceController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  final RxList<Map<String, dynamic>> invoices = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredInvoices = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxString searchQuery = ''.obs;
  final RxString statusFilter = 'All'.obs;

  String _resolveGymId(String gymId) {
    if (gymId.isNotEmpty) return gymId;
    return _authService.currentGymId ?? '';
  }

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
    gymId = _resolveGymId(gymId);
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
      AppPopup.error('Failed to load invoices: $e');
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
    gymId = _resolveGymId(gymId);
    log('[InvoiceController] deleteInvoice called id=$id gymId=$gymId');
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('invoices', where: 'invoice_id = ?', whereArgs: [id]);
      await loadInvoices(gymId);
      log('[InvoiceController] deleteInvoice successful');
      AppPopup.success('Invoice deleted');
    } catch (e, stack) {
      log('[InvoiceController] deleteInvoice failed: $e');
      log('[InvoiceController] stack: $stack');
      AppPopup.error('Failed to delete invoice: $e');
    }
  }

  Future<Uint8List> _generateInvoicePdf(Map<String, dynamic> invoice) async {
    final invoiceNumber = invoice['invoice_number'] as String? ?? '-';
    final memberName = invoice['member_name'] as String? ?? '';
    final memberPhone = invoice['member_phone'] as String?;
    final memberAddress = invoice['member_address'] as String?;
    final packageName = invoice['package_name'] as String?;
    final amount = invoice['amount'] as int? ?? 0;
    final discount = invoice['discount'] as int? ?? 0;
    final tax = invoice['tax'] as int? ?? 0;
    final total = invoice['total'] as int? ?? 0;
    final status = invoice['status'] as String? ?? 'paid';
    final date = invoice['invoice_date'] as String? ?? '';
    final paymentMethod = invoice['payment_method'] as String?;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('INVOICE',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(invoiceNumber,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: status == 'paid'
                      ? PdfColor.fromInt(0xFFD4EDDA)
                      : PdfColor.fromInt(0xFFFFE8CC),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(status.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: status == 'paid'
                          ? PdfColor.fromInt(0xFF155724)
                          : PdfColor.fromInt(0xFF856404),
                    )),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text('Date: ${Formatters.shortDate(DateTime.tryParse(date))}',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Divider(),
          pw.Header(level: 1, text: 'Bill To'),
          pw.Text(memberName, style: pw.TextStyle(fontSize: 12)),
          if (memberPhone != null) pw.Text(memberPhone,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          if (memberAddress != null) pw.Text(memberAddress,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Header(level: 2, text: 'Invoice Items'),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: pw.TextStyle(fontSize: 10),
            headers: ['Description', 'Amount'],
            data: [
              if (packageName != null && packageName.isNotEmpty)
                ['Package: $packageName', ''],
              ['Charge Amount', Formatters.currency(amount)],
              ['Discount', '-${Formatters.currency(discount)}'],
              ['Tax', Formatters.currency(tax)],
            ],
          ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
              pw.Text(Formatters.currency(total),
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
            ],
          ),
          if (paymentMethod != null) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Payment Method',
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                pw.Text(paymentMethod,
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              ],
            ),
          ],
          pw.SizedBox(height: 32),
          pw.Divider(),
          pw.Text('Generated on ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
        ],
      ),
    );

    return await pdf.save();
  }

  Future<void> printInvoice(Map<String, dynamic> invoice) async {
    log('[InvoiceController] printInvoice called number=${invoice['invoice_number']}');
    try {
      final bytes = await _generateInvoicePdf(invoice);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Invoice_${invoice['invoice_number']}.pdf',
      );
      log('[InvoiceController] printInvoice successful');
    } catch (e, stack) {
      log('[InvoiceController] printInvoice failed: $e');
      log('[InvoiceController] stack: $stack');
      AppPopup.error('Failed to print invoice: $e');
    }
  }

  Future<void> downloadInvoice(Map<String, dynamic> invoice) async {
    log('[InvoiceController] downloadInvoice called number=${invoice['invoice_number']}');
    try {
      final bytes = await _generateInvoicePdf(invoice);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Invoice_${invoice['invoice_number']}.pdf',
      );
      log('[InvoiceController] downloadInvoice successful');
    } catch (e, stack) {
      log('[InvoiceController] downloadInvoice failed: $e');
      log('[InvoiceController] stack: $stack');
      AppPopup.error('Failed to download invoice: $e');
    }
  }
}

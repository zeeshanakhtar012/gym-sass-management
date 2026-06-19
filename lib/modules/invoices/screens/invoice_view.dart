import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/helpers/responsive.dart';
import '../../../../widgets/app_drawer.dart';
import '../controllers/invoice_controller.dart';

class InvoiceView extends GetView<InvoiceController> {
  const InvoiceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            onPressed: () => controller.loadInvoices(''),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Paid', 'Pending', 'Cancelled'];
    return Obx(() => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Row(
        children: filters.map((f) {
          final isSelected = controller.statusFilter.value == f;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Text(f, style: AppTextStyles.bodySm.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimaryL,
              )),
              selected: isSelected,
              onSelected: (_) => controller.setStatusFilter(f),
              selectedColor: _chipColor(f),
              backgroundColor: AppColors.surfaceLight,
              side: BorderSide(color: AppColors.borderLight),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    ));
  }

  Color _chipColor(String status) {
    switch (status) {
      case 'Paid': return AppColors.success;
      case 'Pending': return AppColors.warning;
      case 'Cancelled': return AppColors.danger;
      default: return AppColors.primary;
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: TextField(
        onChanged: (v) => controller.setSearchQuery(v),
        decoration: InputDecoration(
          hintText: 'Search by invoice no., member, package...',
          prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
          suffixIcon: Obx(() => controller.searchQuery.value.isNotEmpty
              ? IconButton(
                  icon: const Icon(PhosphorIconsRegular.x, size: 18),
                  onPressed: () => controller.setSearchQuery(''),
                )
              : const SizedBox.shrink()),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final invoices = controller.filteredInvoices;
      if (invoices.isEmpty) return _buildEmpty();
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: invoices.length,
        itemBuilder: (_, i) => _buildCard(invoices[i]),
      );
    });
  }

  Widget _buildCard(Map<String, dynamic> invoice) {
    final invoiceNumber = invoice['invoice_number'] as String? ?? '-';
    final memberName = invoice['member_name'] as String? ?? 'Unknown';
    final packageName = invoice['package_name'] as String?;
    final total = invoice['total'] as int? ?? 0;
    final status = invoice['status'] as String? ?? 'paid';
    final date = invoice['invoice_date'] as String? ?? '';
    final invoiceId = invoice['invoice_id'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(invoiceNumber, style: AppTextStyles.headingSm),
                ),
                _buildStatusBadge(status),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(PhosphorIconsRegular.user, size: 14, color: AppColors.neutralGray),
                const SizedBox(width: 4),
                Text(memberName, style: AppTextStyles.bodyMd),
              ],
            ),
            if (packageName != null && packageName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(PhosphorIconsRegular.tag, size: 14, color: AppColors.neutralGray),
                  const SizedBox(width: 4),
                  Text(packageName, style: AppTextStyles.bodySm),
                ],
              ),
            ],
            SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _buildInfoChip(PhosphorIconsRegular.coin, Formatters.currency(total), AppColors.success),
                SizedBox(width: AppSpacing.sm),
                _buildInfoChip(PhosphorIconsRegular.calendarBlank, Formatters.shortDate(DateTime.tryParse(date)), AppColors.info),
                const Spacer(),
                _buildActionButton(
                  PhosphorIconsRegular.eye,
                  AppColors.info,
                  () => _showInvoiceDetail(invoice),
                ),
                const SizedBox(width: 4),
                _buildActionButton(
                  PhosphorIconsRegular.printer,
                  AppColors.primary,
                  () => controller.printInvoice(invoice),
                ),
                const SizedBox(width: 4),
                _buildActionButton(
                  PhosphorIconsRegular.trash,
                  AppColors.danger,
                  () => _confirmDelete(invoiceId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'paid':
        color = AppColors.success;
        break;
      case 'pending':
        color = AppColors.warning;
        break;
      case 'cancelled':
        color = AppColors.danger;
        break;
      default:
        color = AppColors.neutralGray;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTextStyles.bodySm.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.bodySm.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: color,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsRegular.fileText, size: 64, color: AppColors.neutralGray),
          SizedBox(height: AppSpacing.md),
          Text(
            'No invoices found',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondaryL),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Invoices are created automatically when payments are recorded',
            style: AppTextStyles.bodySm,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showInvoiceDetail(Map<String, dynamic> invoice) {
    final invoiceNumber = invoice['invoice_number'] as String? ?? '-';
    final memberName = invoice['member_name'] as String? ?? 'Unknown';
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

    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('INVOICE', style: AppTextStyles.displayLg),
                        Text(invoiceNumber, style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondaryL)),
                      ],
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                Divider(height: AppSpacing.lg),
                Text('Date: ${Formatters.shortDate(DateTime.tryParse(date))}', style: AppTextStyles.bodyMd),
                SizedBox(height: AppSpacing.md),
                Text('Bill To', style: AppTextStyles.label),
                SizedBox(height: AppSpacing.xs),
                Text(memberName, style: AppTextStyles.bodyLg),
                if (memberPhone != null) Text(memberPhone, style: AppTextStyles.bodySm),
                if (memberAddress != null) Text(memberAddress, style: AppTextStyles.bodySm),
                Divider(height: AppSpacing.lg),
                if (packageName != null) ...[
                  _detailRow('Package', packageName),
                  SizedBox(height: AppSpacing.sm),
                ],
                _detailRow('Amount', Formatters.currency(amount)),
                SizedBox(height: AppSpacing.sm),
                _detailRow('Discount', Formatters.currency(discount)),
                SizedBox(height: AppSpacing.sm),
                _detailRow('Tax', Formatters.currency(tax)),
                Divider(height: AppSpacing.md),
                _detailRow('Total', Formatters.currency(total), isTotal: true),
                SizedBox(height: AppSpacing.md),
                if (paymentMethod != null) ...[
                  Divider(height: AppSpacing.sm),
                  _detailRow('Payment Method', paymentMethod),
                ],
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Get.back();
                      controller.printInvoice(invoice);
                    },
                    icon: const Icon(PhosphorIconsRegular.printer, size: 18),
                    label: const Text('Print Invoice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMd.copyWith(
          fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
        )),
        Text(value, style: (isTotal ? AppTextStyles.headingSm : AppTextStyles.bodyMd).copyWith(
          fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
          color: isTotal ? AppColors.primary : AppColors.textPrimaryL,
        )),
      ],
    );
  }

  void _confirmDelete(String invoiceId) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteInvoice(invoiceId, '');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

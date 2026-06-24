import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/database/database_helper.dart';
import '../../../widgets/app_drawer.dart';
import '../controllers/payment_controller.dart';
import '../../../widgets/popups/app_popup.dart';

class PaymentView extends GetView<PaymentController> {
  const PaymentView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Payments'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            onPressed: () => controller.loadPayments(''),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _openPaymentForm(),
        child: const Icon(PhosphorIconsRegular.plus, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Obx(() => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Row(
        children: [
          Expanded(child: _summaryCard('Today', controller.todayRevenue.value, AppColors.primary, PhosphorIconsRegular.coin)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _summaryCard('This Month', controller.monthRevenue.value, AppColors.info, PhosphorIconsRegular.calendarBlank)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _summaryCard('Total', controller.totalPaymentsCount.value, AppColors.accent, PhosphorIconsRegular.receipt, isCount: true)),
        ],
      ),
    ));
  }

  Widget _summaryCard(String label, int value, Color color, IconData icon, {bool isCount = false}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isCount ? value.toString() : Formatters.currency(value),
            style: AppTextStyles.headingSm.copyWith(color: color, fontSize: 15),
          ),
          Text(label, style: AppTextStyles.bodySm.copyWith(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: TextField(
        onChanged: (v) => controller.setSearchQuery(v),
        decoration: InputDecoration(
          hintText: 'Search payments...',
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
      final payments = controller.filteredPayments;
      if (payments.isEmpty) return _buildEmpty();
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: payments.length,
        itemBuilder: (_, i) => _buildCard(payments[i]),
      );
    });
  }

  Widget _buildCard(Map<String, dynamic> payment) {
    final name = payment['member_name'] as String? ?? 'Unknown';
    final method = payment['method'] as String? ?? '';
    final total = payment['total'] as int? ?? 0;
    final date = payment['payment_date'] as String? ?? '';
    final remarks = payment['remarks'] as String?;
    final paymentId = payment['payment_id'] as String;

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
                  child: Text(name, style: AppTextStyles.headingSm),
                ),
                _buildMethodChip(method),
                const SizedBox(width: AppSpacing.sm),
                _buildActionButton(
                  PhosphorIconsRegular.trash,
                  AppColors.danger,
                  () => _confirmDelete(paymentId),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _buildInfoChip(PhosphorIconsRegular.coin, Formatters.currency(total), AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                _buildInfoChip(PhosphorIconsRegular.calendarBlank, Formatters.shortDate(DateTime.tryParse(date)), AppColors.info),
              ],
            ),
            if (remarks != null && remarks.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(remarks, style: AppTextStyles.bodySm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String method) {
    Color color;
    IconData icon;
    switch (method.toLowerCase()) {
      case 'cash':
        color = AppColors.success;
        icon = PhosphorIconsRegular.money;
        break;
      case 'bank transfer':
        color = AppColors.info;
        icon = PhosphorIconsRegular.bank;
        break;
      case 'easypaisa':
        color = AppColors.warning;
        icon = PhosphorIconsRegular.deviceMobile;
        break;
      case 'jazzcash':
        color = AppColors.danger;
        icon = PhosphorIconsRegular.deviceMobile;
        break;
      default:
        color = AppColors.neutralGray;
        icon = PhosphorIconsRegular.currencyCircleDollar;
    }
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
          Text(method, style: AppTextStyles.bodySm.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
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
          Icon(PhosphorIconsRegular.receipt, size: 64, color: AppColors.neutralGray),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No payments found',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondaryD),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap + to record a new payment',
            style: AppTextStyles.bodySm,
          ),
        ],
      ),
    );
  }

  void _openPaymentForm() {
    final memberIdCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final taxCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final selectedMemberId = RxString('');
    final selectedMemberName = RxString('');
    final selectedPackageId = RxString('');
    final selectedPackageName = RxString('');
    final selectedMethod = RxString('Cash');
    final members = <Map<String, dynamic>>[].obs;
    final filteredMembers = <Map<String, dynamic>>[].obs;
    final memberSearchCtrl = TextEditingController();
    final total = RxInt(0);

    void recalcTotal() {
      final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
      final disc = int.tryParse(discountCtrl.text.trim()) ?? 0;
      final tx = int.tryParse(taxCtrl.text.trim()) ?? 0;
      total.value = amt - disc + tx;
    }
    amountCtrl.addListener(recalcTotal);
    discountCtrl.addListener(recalcTotal);
    taxCtrl.addListener(recalcTotal);

    Future<void> loadMembers() async {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('members',
        where: 'gym_id = ? AND status = ?',
        whereArgs: ['', 'active'],
        orderBy: 'full_name ASC',
      );
      members.value = rows;
      filteredMembers.value = rows;
    }

    loadMembers();
    controller.loadPackages('');

    Get.bottomSheet(
      isScrollControlled: true,
      Container(
        height: Get.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderDark)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('New Payment', style: AppTextStyles.headingMd),
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.x),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Member *', style: AppTextStyles.label),
                    const SizedBox(height: AppSpacing.sm),
                    Obx(() {
                      if (selectedMemberId.value.isEmpty) {
                        return TextField(
                          controller: memberSearchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search member...',
                            prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            filteredMembers.value = members.where((m) {
                              final name = (m['full_name'] as String?)?.toLowerCase() ?? '';
                              final phone = (m['phone'] as String?)?.toLowerCase() ?? '';
                              return name.contains(v.toLowerCase()) || phone.contains(v.toLowerCase());
                            }).toList();
                          },
                        );
                      }
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(selectedMemberName.value, style: AppTextStyles.bodyMd),
                        trailing: IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, size: 16),
                          onPressed: () {
                            selectedMemberId.value = '';
                            selectedMemberName.value = '';
                          },
                        ),
                      );
                    }),
                    Obx(() {
                      if (selectedMemberId.value.isEmpty && memberSearchCtrl.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      if (selectedMemberId.value.isNotEmpty) return const SizedBox.shrink();
                      return SizedBox(
                        height: 120,
                        child: ListView.builder(
                          itemCount: filteredMembers.length,
                          itemBuilder: (_, i) {
                            final m = filteredMembers[i];
                            return ListTile(
                              dense: true,
                              title: Text(m['full_name'] as String? ?? '', style: AppTextStyles.bodyMd),
                              subtitle: Text(m['phone'] as String? ?? '', style: AppTextStyles.bodySm),
                              onTap: () {
                                selectedMemberId.value = m['member_id'] as String;
                                selectedMemberName.value = m['full_name'] as String;
                                memberSearchCtrl.text = '';
                              },
                            );
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.md),
                    Text('Package', style: AppTextStyles.label),
                    const SizedBox(height: AppSpacing.sm),
                    Obx(() => DropdownButtonFormField<String>(
                      value: selectedPackageId.value.isEmpty ? null : selectedPackageId.value,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      hint: const Text('Select package'),
                      items: controller.packages.map((p) {
                        return DropdownMenuItem(
                          value: p['package_id'] as String,
                          child: Text('${p['name']} - ${Formatters.currency(p['price'] as int)}'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        selectedPackageId.value = v ?? '';
                        final pkg = controller.packages.firstWhereOrNull(
                          (p) => p['package_id'] == v,
                        );
                        if (pkg != null) {
                          selectedPackageName.value = pkg['name'] as String;
                          amountCtrl.text = (pkg['price'] as int).toString();
                          recalcTotal();
                        }
                      },
                    )),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Amount *',
                              isDense: true,
                              prefixText: 'PKR ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: discountCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Discount',
                              isDense: true,
                              prefixText: 'PKR ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: taxCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tax',
                              isDense: true,
                              prefixText: 'PKR ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Obx(() => InputDecorator(
                            decoration: const InputDecoration(labelText: 'Total', isDense: true),
                            child: Text(
                              Formatters.currency(total.value),
                              style: AppTextStyles.headingSm.copyWith(color: AppColors.primary),
                            ),
                          )),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Payment Method *', style: AppTextStyles.label),
                    const SizedBox(height: AppSpacing.sm),
                    Obx(() => DropdownButtonFormField<String>(
                      value: selectedMethod.value,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'EasyPaisa', child: Text('EasyPaisa')),
                        DropdownMenuItem(value: 'JazzCash', child: Text('JazzCash')),
                      ],
                      onChanged: (v) => selectedMethod.value = v ?? 'Cash',
                    )),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: dateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Payment Date',
                        isDense: true,
                        prefixIcon: Icon(PhosphorIconsRegular.calendarBlank, size: 18),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: Get.context!,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: remarksCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Remarks',
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderDark)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedMemberId.value.isEmpty) {
                      AppPopup.error('Please select a member');
                      return;
                    }
                    final amount = int.tryParse(amountCtrl.text.trim());
                    if (amount == null || amount <= 0) {
                      AppPopup.error('Please enter a valid amount');
                      return;
                    }
                    Get.back();
                    controller.createPayment({
                      'gym_id': '',
                      'member_id': selectedMemberId.value,
                      'package_id': selectedPackageId.value.isEmpty ? null : selectedPackageId.value,
                      'package_name': selectedPackageName.value.isEmpty ? null : selectedPackageName.value,
                      'amount': amount,
                      'discount': int.tryParse(discountCtrl.text.trim()) ?? 0,
                      'tax': int.tryParse(taxCtrl.text.trim()) ?? 0,
                      'method': selectedMethod.value,
                      'remarks': remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
                      'received_by': null,
                      'payment_date': dateCtrl.text.trim(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                  child: const Text('Record Payment'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String paymentId) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Payment'),
        content: const Text('Are you sure you want to delete this payment?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deletePayment(paymentId, '');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

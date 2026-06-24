import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/helpers/responsive.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/app_drawer.dart';
import '../controllers/expense_controller.dart';

class ExpenseView extends GetView<ExpenseController> {
  const ExpenseView({super.key});

  static const _categoryColors = {
    'Electricity': AppColors.warning,
    'Water': AppColors.info,
    'Rent': Color(0xFF7C3AED),
    'Salaries': AppColors.success,
    'Internet': AppColors.primary,
    'Repairs': AppColors.accent,
    'Miscellaneous': AppColors.neutralGray,
  };

  static const _categoryIcons = {
    'Electricity': PhosphorIconsRegular.lightning,
    'Water': PhosphorIconsRegular.drop,
    'Rent': PhosphorIconsRegular.house,
    'Salaries': PhosphorIconsRegular.users,
    'Internet': PhosphorIconsRegular.wifiHigh,
    'Repairs': PhosphorIconsRegular.wrench,
    'Miscellaneous': PhosphorIconsRegular.dotsThree,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Expenses'),

      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _openAddDialog(),
        child: const Icon(PhosphorIconsRegular.plus, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryChips(),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: TextField(
        onChanged: (v) => controller.searchQuery.value = v,
        decoration: InputDecoration(
          hintText: 'Search expenses...',
          prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
          suffixIcon: Obx(() {
            if (controller.searchQuery.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(PhosphorIconsRegular.x),
              onPressed: () => controller.searchQuery.value = '',
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = ['all', ...AppConstants.expenseCategories];
    return Obx(() {
      final current = controller.selectedCategory.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(categories.length, (i) {
              final selected = current == categories[i];
              final color = categories[i] == 'all'
                  ? AppColors.primary
                  : _categoryColors[categories[i]] ?? AppColors.neutralGray;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: FilterChip(
                  label: Text(categories[i] == 'all' ? 'All' : categories[i]),
                  selected: selected,
                  onSelected: (_) => controller.selectedCategory.value = categories[i],
                  selectedColor: color.withValues(alpha: 0.15),
                  checkmarkColor: color,
                  avatar: categories[i] != 'all'
                      ? Icon(_categoryIcons[categories[i]] ?? PhosphorIconsRegular.tag,
                          size: 14, color: selected ? color : null)
                      : null,
                ),
              );
            }),
          ),
        ),
      );
    });
  }

  Widget _buildBody(BuildContext context) {
    return Responsive(
      mobile: _buildCardList(context),
      desktop: _buildTable(context),
    );
  }

  Widget _buildCardList(BuildContext context) {
    return Column(
      children: [
        _buildSummaryCards(),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = controller.filteredExpenses;
            if (items.isEmpty) return _buildEmpty();
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              itemBuilder: (_, i) => _buildCard(items[i]),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Obx(() {
      final items = controller.expenses;
      final thisMonth = items.where((e) {
        final date = DateTime.tryParse(e['expense_date'] as String? ?? '');
        if (date == null) return false;
        final now = DateTime.now();
        return date.month == now.month && date.year == now.year;
      }).toList();
      final monthlyTotal = thisMonth.fold<int>(0, (s, e) => s + (e['amount'] as int));

      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: AppColors.danger.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: const Icon(PhosphorIconsRegular.currencyCircleDollar,
                          color: AppColors.danger, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('This Month Total',
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondaryD)),
                        const SizedBox(height: 4),
                        Text(Formatters.currency(monthlyTotal),
                            style: AppTextStyles.headingLg.copyWith(color: AppColors.danger)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildCategoryBreakdown(items),
          ],
        ),
      );
    });
  }

  Widget _buildCategoryBreakdown(List<Map<String, dynamic>> items) {
    final totals = <String, int>{};
    for (final e in items) {
      final cat = e['category'] as String;
      totals[cat] = (totals[cat] ?? 0) + (e['amount'] as int);
    }
    if (totals.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By Category', style: AppTextStyles.headingSm),
            const SizedBox(height: AppSpacing.sm),
            ...totals.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(_categoryIcons[e.key] ?? PhosphorIconsRegular.tag,
                      size: 16, color: _categoryColors[e.key] ?? AppColors.neutralGray),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(e.key, style: AppTextStyles.bodyMd),
                  ),
                  Text(Formatters.currency(e.value),
                      style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> expense) {
    final category = expense['category'] as String? ?? '';
    final color = _categoryColors[category] ?? AppColors.neutralGray;
    final icon = _categoryIcons[category] ?? PhosphorIconsRegular.tag;
    final date = DateTime.tryParse(expense['expense_date'] as String? ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category, style: AppTextStyles.headingSm),
                      if (expense['description'] != null &&
                          (expense['description'] as String).isNotEmpty)
                        Text(expense['description'] as String,
                            style: AppTextStyles.bodySm),
                    ],
                  ),
                ),
                Text(
                  Formatters.currency(expense['amount'] as int),
                  style: AppTextStyles.headingSm.copyWith(color: AppColors.danger),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null ? Formatters.shortDate(date) : '-',
                  style: AppTextStyles.bodySm,
                ),
                Row(
                  children: [
                    _buildActionButton(
                      PhosphorIconsRegular.pencilSimple,
                      AppColors.info,
                      () => _openEditDialog(expense),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _buildActionButton(
                      PhosphorIconsRegular.trash,
                      AppColors.danger,
                      () => _confirmDelete(expense),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 36, height: 36,
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: color,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final items = controller.filteredExpenses;
      if (items.isEmpty) return _buildEmpty();
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: items.map((e) {
                    final category = e['category'] as String? ?? '';
                    final color = _categoryColors[category] ?? AppColors.neutralGray;
                    return DataRow(cells: [
                      DataCell(Row(
                        children: [
                          Icon(_categoryIcons[category] ?? PhosphorIconsRegular.tag,
                              size: 16, color: color),
                          const SizedBox(width: 6),
                          Text(category),
                        ],
                      )),
                      DataCell(Text(Formatters.currency(e['amount'] as int),
                          style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
                      DataCell(Text(e['description'] as String? ?? '-')),
                      DataCell(Text(Formatters.shortDate(
                          DateTime.tryParse(e['expense_date'] as String? ?? '')))),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                            color: AppColors.info,
                            onPressed: () => _openEditDialog(e),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                            color: AppColors.danger,
                            onPressed: () => _confirmDelete(e),
                            tooltip: 'Delete',
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsRegular.receipt, size: 64, color: AppColors.neutralGray),
          const SizedBox(height: AppSpacing.md),
          Text('No expenses found',
              style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondaryD)),
          const SizedBox(height: AppSpacing.sm),
          Text('Tap + to add an expense',
              style: AppTextStyles.bodySm),
        ],
      ),
    );
  }

  void _openAddDialog() {
    final formKey = GlobalKey<FormState>();
    final categoryCtrl = RxString(AppConstants.expenseCategories.first);
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dateCtrl = Rx<DateTime>(DateTime.now());

    Get.dialog(AlertDialog(
      title: const Text('Add Expense'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() => DropdownButtonFormField<String>(
                value: categoryCtrl.value,
                decoration: const InputDecoration(labelText: 'Category'),
                items: AppConstants.expenseCategories.map((c) =>
                  DropdownMenuItem(value: c, child: Text(c))
                ).toList(),
                onChanged: (v) { if (v != null) categoryCtrl.value = v; },
              )),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(PhosphorIconsRegular.currencyCircleDollar),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(PhosphorIconsRegular.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.sm),
              Obx(() => InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: Get.context!,
                    initialDate: dateCtrl.value,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) dateCtrl.value = picked;
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(PhosphorIconsRegular.calendarBlank),
                  ),
                  child: Text(Formatters.date(dateCtrl.value)),
                ),
              )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (amountCtrl.text.isEmpty) return;
            final success = await controller.createExpense({
              'gym_id': '',
              'category': categoryCtrl.value,
              'amount': int.tryParse(amountCtrl.text) ?? 0,
              'description': descCtrl.text.trim(),
              'expense_date': Formatters.date(dateCtrl.value),
            });
            if (success) Get.back();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _openEditDialog(Map<String, dynamic> expense) {
    final formKey = GlobalKey<FormState>();
    final categoryCtrl = RxString(expense['category'] as String);
    final amountCtrl = TextEditingController(text: '${expense['amount']}');
    final descCtrl = TextEditingController(text: expense['description'] as String? ?? '');
    final dateCtrl = Rx<DateTime>(
      DateTime.tryParse(expense['expense_date'] as String? ?? '') ?? DateTime.now(),
    );

    Get.dialog(AlertDialog(
      title: const Text('Edit Expense'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() => DropdownButtonFormField<String>(
                value: categoryCtrl.value,
                decoration: const InputDecoration(labelText: 'Category'),
                items: AppConstants.expenseCategories.map((c) =>
                  DropdownMenuItem(value: c, child: Text(c))
                ).toList(),
                onChanged: (v) { if (v != null) categoryCtrl.value = v; },
              )),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(PhosphorIconsRegular.currencyCircleDollar),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(PhosphorIconsRegular.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.sm),
              Obx(() => InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: Get.context!,
                    initialDate: dateCtrl.value,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) dateCtrl.value = picked;
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(PhosphorIconsRegular.calendarBlank),
                  ),
                  child: Text(Formatters.date(dateCtrl.value)),
                ),
              )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (amountCtrl.text.isEmpty) return;
            final success = await controller.updateExpense({
              'expense_id': expense['expense_id'],
              'gym_id': expense['gym_id'],
              'category': categoryCtrl.value,
              'amount': int.tryParse(amountCtrl.text) ?? 0,
              'description': descCtrl.text.trim(),
              'expense_date': Formatters.date(dateCtrl.value),
            });
            if (success) Get.back();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _confirmDelete(Map<String, dynamic> expense) {
    Get.dialog(AlertDialog(
      title: const Text('Delete Expense'),
      content: Text('Are you sure you want to delete this ${expense['category']} expense of ${Formatters.currency(expense['amount'] as int)}?'),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Get.back();
            controller.deleteExpense(expense['expense_id'] as String);
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Delete'),
        ),
      ],
    ));
  }
}

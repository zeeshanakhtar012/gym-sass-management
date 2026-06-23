import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/helpers/responsive.dart';
import '../../../widgets/app_drawer.dart';
import '../controllers/inventory_controller.dart';

class InventoryView extends GetView<InventoryController> {
  const InventoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            onPressed: () => controller.loadItems(''),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _openAddDialog(),
        child: const Icon(PhosphorIconsRegular.plus, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => controller.searchQuery.value = v,
            decoration: InputDecoration(
              hintText: 'Search items...',
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
          const SizedBox(height: AppSpacing.sm),
          Obx(() => Row(
            children: [
              FilterChip(
                label: const Text('Low Stock Only'),
                selected: controller.lowStockOnly.value,
                onSelected: (v) => controller.lowStockOnly.value = v,
                selectedColor: AppColors.danger.withValues(alpha: 0.15),
                checkmarkColor: AppColors.danger,
                avatar: const Icon(PhosphorIconsRegular.warning, size: 14, color: AppColors.danger),
              ),
              const SizedBox(width: AppSpacing.sm),
              Obx(() {
                final count = controller.lowStockItems.length;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text('$count low',
                      style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.danger, fontWeight: FontWeight.w600)),
                );
              }),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Responsive(
      mobile: _buildCardList(context),
      desktop: _buildTable(context),
    );
  }

  Widget _buildCardList(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final items = controller.filteredItems;
      if (items.isEmpty) return _buildEmpty();
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildCard(items[i]),
      );
    });
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final quantity = item['quantity'] as int;
    final reorderLevel = item['reorder_level'] as int;
    final isLowStock = quantity <= reorderLevel;

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
                    color: isLowStock
                        ? AppColors.danger.withValues(alpha: 0.1)
                        : AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    isLowStock ? PhosphorIconsRegular.package : PhosphorIconsRegular.package,
                    color: isLowStock ? AppColors.danger : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'] as String, style: AppTextStyles.headingSm),
                      const SizedBox(height: 2),
                      Text('Cost: ${Formatters.currency(item['cost_price'] as int)} | Sell: ${Formatters.currency(item['selling_price'] as int)}',
                          style: AppTextStyles.bodySm),
                    ],
                  ),
                ),
                _buildQuantityBadge(quantity, reorderLevel, isLowStock),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIconsRegular.arrowArcLeft, size: 14, color: AppColors.neutralGray),
                    const SizedBox(width: 4),
                    Text('Reorder at: $reorderLevel',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondaryD)),
                  ],
                ),
                Row(
                  children: [
                    _buildActionButton(
                      PhosphorIconsRegular.pencilSimple,
                      AppColors.info,
                      () => _openEditDialog(item),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _buildActionButton(
                      PhosphorIconsRegular.trash,
                      AppColors.danger,
                      () => _confirmDelete(item),
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

  Widget _buildQuantityBadge(int quantity, int reorderLevel, bool isLowStock) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: isLowStock
            ? AppColors.danger.withValues(alpha: 0.1)
            : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        '$quantity',
        style: AppTextStyles.headingSm.copyWith(
          color: isLowStock ? AppColors.danger : AppColors.success,
          fontWeight: FontWeight.w700,
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
      final items = controller.filteredItems;
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
                  headingRowColor: WidgetStateProperty.all(AppColors.surfaceElevated),
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('Cost')),
                    DataColumn(label: Text('Selling')),
                    DataColumn(label: Text('Reorder')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: items.map((item) {
                    final qty = item['quantity'] as int;
                    final rl = item['reorder_level'] as int;
                    final low = qty <= rl;
                    return DataRow(cells: [
                      DataCell(Text(item['name'] as String)),
                      DataCell(Text('$qty',
                          style: TextStyle(
                              color: low ? AppColors.danger : AppColors.success,
                              fontWeight: FontWeight.w600))),
                      DataCell(Text(Formatters.currency(item['cost_price'] as int))),
                      DataCell(Text(Formatters.currency(item['selling_price'] as int))),
                      DataCell(Text('$rl')),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                            color: AppColors.info,
                            onPressed: () => _openEditDialog(item),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                            color: AppColors.danger,
                            onPressed: () => _confirmDelete(item),
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
          Icon(PhosphorIconsRegular.package, size: 64, color: AppColors.neutralGray),
          const SizedBox(height: AppSpacing.md),
          Text('No items in inventory',
              style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondaryD)),
          const SizedBox(height: AppSpacing.sm),
          Text('Tap + to add an item',
              style: AppTextStyles.bodySm),
        ],
      ),
    );
  }

  void _openAddDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final reorderCtrl = TextEditingController();

    Get.dialog(AlertDialog(
      title: const Text('Add Inventory Item'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  prefixIcon: Icon(PhosphorIconsRegular.package),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(PhosphorIconsRegular.hash),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cost Price',
                  prefixIcon: Icon(PhosphorIconsRegular.currencyCircleDollar),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: sellCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Selling Price',
                  prefixIcon: Icon(PhosphorIconsRegular.trendUp),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: reorderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reorder Level',
                  prefixIcon: Icon(PhosphorIconsRegular.arrowArcLeft),
                ),
              ),
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
            if (nameCtrl.text.trim().isEmpty) return;
            final success = await controller.createItem({
              'gym_id': '',
              'name': nameCtrl.text.trim(),
              'quantity': int.tryParse(qtyCtrl.text) ?? 0,
              'cost_price': int.tryParse(costCtrl.text) ?? 0,
              'selling_price': int.tryParse(sellCtrl.text) ?? 0,
              'reorder_level': int.tryParse(reorderCtrl.text) ?? 0,
            });
            if (success) Get.back();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _openEditDialog(Map<String, dynamic> item) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: item['name'] as String);
    final qtyCtrl = TextEditingController(text: '${item['quantity']}');
    final costCtrl = TextEditingController(text: '${item['cost_price']}');
    final sellCtrl = TextEditingController(text: '${item['selling_price']}');
    final reorderCtrl = TextEditingController(text: '${item['reorder_level']}');

    Get.dialog(AlertDialog(
      title: const Text('Edit Inventory Item'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  prefixIcon: Icon(PhosphorIconsRegular.package),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(PhosphorIconsRegular.hash),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cost Price',
                  prefixIcon: Icon(PhosphorIconsRegular.currencyCircleDollar),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: sellCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Selling Price',
                  prefixIcon: Icon(PhosphorIconsRegular.trendUp),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: reorderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reorder Level',
                  prefixIcon: Icon(PhosphorIconsRegular.arrowArcLeft),
                ),
              ),
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
            if (nameCtrl.text.trim().isEmpty) return;
            final success = await controller.updateItem({
              'item_id': item['item_id'],
              'gym_id': item['gym_id'],
              'name': nameCtrl.text.trim(),
              'quantity': int.tryParse(qtyCtrl.text) ?? 0,
              'cost_price': int.tryParse(costCtrl.text) ?? 0,
              'selling_price': int.tryParse(sellCtrl.text) ?? 0,
              'reorder_level': int.tryParse(reorderCtrl.text) ?? 0,
            });
            if (success) Get.back();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _confirmDelete(Map<String, dynamic> item) {
    Get.dialog(AlertDialog(
      title: const Text('Delete Item'),
      content: Text('Are you sure you want to delete "${item['name']}"?'),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Get.back();
            controller.deleteItem(item['item_id'] as String);
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Delete'),
        ),
      ],
    ));
  }
}

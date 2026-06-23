import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/helpers/formatters.dart';
import '../../../widgets/app_drawer.dart';
import '../controllers/package_model.dart';
import '../controllers/package_controller.dart';

class PackageListView extends GetView<PackageController> {
  const PackageListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Packages'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            onPressed: () => controller.loadPackages(''),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _openModal(),
        child: const Icon(PhosphorIconsRegular.plus, color: Colors.white),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final packages = controller.packages;
        if (packages.isEmpty) return _buildEmpty();
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: packages.length,
          itemBuilder: (_, i) => _buildCard(packages[i]),
        );
      }),
    );
  }

  Widget _buildCard(PackageModel pkg) {
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
                  child: Text(pkg.name, style: AppTextStyles.headingSm),
                ),
                _buildActionButton(
                  PhosphorIconsRegular.pencilSimple,
                  AppColors.info,
                  () => _openModal(pkg),
                ),
                const SizedBox(width: AppSpacing.sm),
                _buildActionButton(
                  PhosphorIconsRegular.trash,
                  AppColors.danger,
                  () => _confirmDelete(pkg),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _buildInfoChip(PhosphorIconsRegular.clock, '${pkg.durationDays} days'),
                const SizedBox(width: AppSpacing.sm),
                _buildInfoChip(PhosphorIconsRegular.coin, 'Reg: ${Formatters.currency(pkg.price)}'),
                if (pkg.monthlyFee > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _buildInfoChip(PhosphorIconsRegular.calendar, 'Monthly: ${Formatters.currency(pkg.monthlyFee)}'),
                ],
              ],
            ),
            if (pkg.description != null && pkg.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                pkg.description!,
                style: AppTextStyles.bodySm,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.bodySm.copyWith(color: AppColors.primary)),
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
          Icon(PhosphorIconsRegular.tag, size: 64, color: AppColors.neutralGray),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No packages found',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondaryD),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap + to add a new package',
            style: AppTextStyles.bodySm,
          ),
        ],
      ),
    );
  }

  void _openModal([PackageModel? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final daysCtrl = TextEditingController(text: existing?.durationDays.toString() ?? '');
    final priceCtrl = TextEditingController(text: existing?.price.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final isEditing = existing != null;

    final monthlyFeeCtrl = TextEditingController(text: existing?.monthlyFee.toString() ?? '');

    Get.dialog(
      AlertDialog(
        title: Text(isEditing ? 'Edit Package' : 'New Package'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'Monthly Basic'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: daysCtrl,
                decoration: const InputDecoration(labelText: 'Duration (days)', hintText: '30'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Registration Fee', hintText: '2000'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: monthlyFeeCtrl,
                decoration: const InputDecoration(labelText: 'Monthly Fee', hintText: '1000'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description', hintText: 'Optional'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final days = int.tryParse(daysCtrl.text.trim());
              final price = int.tryParse(priceCtrl.text.trim());
              final monthlyFee = int.tryParse(monthlyFeeCtrl.text.trim()) ?? 0;
              if (name.isEmpty || days == null || price == null) {
                Get.snackbar('Error', 'Please fill all required fields');
                return;
              }
              Get.back();
              if (isEditing) {
                controller.updatePackage(existing.copyWith(
                  name: name,
                  durationDays: days,
                  price: price,
                  monthlyFee: monthlyFee,
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                ));
              } else {
                controller.createPackage(PackageModel(
                  packageId: '',
                  gymId: '',
                  name: name,
                  durationDays: days,
                  price: price,
                  monthlyFee: monthlyFee,
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  createdAt: '',
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(isEditing ? 'Update' : 'Create', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

  }

  void _confirmDelete(PackageModel pkg) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Package'),
        content: Text('Are you sure you want to delete "${pkg.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deletePackage(pkg.packageId);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

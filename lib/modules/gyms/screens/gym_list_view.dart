import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/helpers/responsive.dart';
import '../../../widgets/app_drawer.dart';
import '../controllers/gym_model.dart';
import '../controllers/gym_list_controller.dart';
import '../controllers/gym_form_controller.dart';
import 'gym_form_view.dart';

class GymListView extends GetView<GymListController> {
  const GymListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Gym Management'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            onPressed: controller.loadGyms,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _openForm(),
        child: const Icon(PhosphorIconsRegular.plus, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: TextField(
        onChanged: (v) => controller.searchQuery.value = v,
        decoration: InputDecoration(
          hintText: 'Search gyms...',
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
      final gyms = controller.filteredGyms;
      if (gyms.isEmpty) return _buildEmpty();
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: gyms.length,
        itemBuilder: (_, i) => _buildCard(gyms[i]),
      );
    });
  }

  Widget _buildCard(GymModel gym) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildLogoThumb(gym),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gym.name, style: AppTextStyles.headingSm),
                      if (gym.ownerName != null)
                        Text(gym.ownerName!, style: AppTextStyles.bodySm),
                    ],
                  ),
                ),
                _buildStatusBadge(gym.status),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            _buildInfoRow(PhosphorIconsRegular.phone, gym.phone),
            if (gym.email != null)
              _buildInfoRow(PhosphorIconsRegular.envelope, gym.email!),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  PhosphorIconsRegular.pause,
                  gym.status == 'active' ? AppColors.warning : AppColors.success,
                  () => controller.toggleStatus(gym.gymId),
                ),
                const SizedBox(width: AppSpacing.sm),
                _buildActionButton(
                  PhosphorIconsRegular.pencilSimple,
                  AppColors.info,
                  () => _openForm(gym),
                ),
                const SizedBox(width: AppSpacing.sm),
                _buildActionButton(
                  PhosphorIconsRegular.trash,
                  AppColors.danger,
                  () => _confirmDelete(gym),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondaryD),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: AppTextStyles.bodySm),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final gyms = controller.filteredGyms;
      if (gyms.isEmpty) return _buildEmpty();
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
                    DataColumn(label: Text('Logo')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Owner')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Created')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: gyms.map((gym) {
                    final created = DateFormat('dd MMM yyyy').format(
                      DateTime.parse(gym.createdAt),
                    );
                    return DataRow(cells: [
                      DataCell(_buildLogoThumb(gym)),
                      DataCell(Text(gym.name)),
                      DataCell(Text(gym.ownerName ?? '-')),
                      DataCell(Text(gym.phone)),
                      DataCell(_buildStatusBadge(gym.status)),
                      DataCell(Text(created)),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              gym.status == 'active'
                                  ? PhosphorIconsRegular.pause
                                  : PhosphorIconsRegular.play,
                              size: 18,
                              color: gym.status == 'active'
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                            onPressed: () => controller.toggleStatus(gym.gymId),
                            tooltip: gym.status == 'active' ? 'Pause' : 'Activate',
                          ),
                          IconButton(
                            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                            color: AppColors.info,
                            onPressed: () => _openForm(gym),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                            color: AppColors.danger,
                            onPressed: () => _confirmDelete(gym),
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

  Widget _buildLogoThumb(GymModel gym) {
    if (gym.logoPath != null && gym.logoPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Image.file(
          File(gym.logoPath!),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildLogoPlaceholder(),
        ),
      );
    }
    return _buildLogoPlaceholder();
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: const Icon(PhosphorIconsRegular.buildings, color: AppColors.primary, size: 22),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTextStyles.bodySm.copyWith(
          color: isActive ? AppColors.success : AppColors.warning,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
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
          Icon(PhosphorIconsRegular.buildings, size: 64, color: AppColors.neutralGray),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No gyms found',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondaryD),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap + to add a new gym',
            style: AppTextStyles.bodySm,
          ),
        ],
      ),
    );
  }

  void _confirmDelete(GymModel gym) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Gym'),
        content: Text('Are you sure you want to delete "${gym.name}"?\n'
            'All related data will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteGym(gym.gymId);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openForm([GymModel? gym]) async {
    final result = await Get.to(
      () => const GymFormView(),
      binding: BindingsBuilder(() {
        final ctrl = Get.put(GymFormController());
        if (gym != null) ctrl.loadGym(gym);
      }),
    );
    if (result == true) {
      controller.loadGyms();
    }
  }
}

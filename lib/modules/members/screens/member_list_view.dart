import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/helpers/responsive.dart';
import '../../../widgets/app_drawer.dart';
import '../controllers/member_model.dart';
import '../controllers/member_list_controller.dart';
import 'member_form_view.dart';
import 'member_detail_view.dart';

class MemberListView extends GetView<MemberListController> {
  MemberListView({super.key, String gymId = ''}) : _gymId = gymId;

  final String _gymId;
  String get gymId => _gymId.isNotEmpty ? _gymId : (Get.parameters['gymId'] ?? '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Members'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            onPressed: () => controller.loadMembers(gymId),
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
          _buildFilterChips(),
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
          hintText: 'Search members...',
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

  Widget _buildFilterChips() {
    final filters = ['all', 'active', 'expired', 'paused'];
    final labels = ['All', 'Active', 'Expired', 'Paused'];
    return Obx(() {
      final current = controller.statusFilter.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(filters.length, (i) {
              final selected = current == filters[i];
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: FilterChip(
                  label: Text(labels[i]),
                  selected: selected,
                  onSelected: (_) => controller.statusFilter.value = filters[i],
                  // selectedColor: AppColors.primarySurface,
                  checkmarkColor: AppColors.primary,
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
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final members = controller.filteredMembers;
      if (members.isEmpty) return _buildEmpty();
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: members.length,
        itemBuilder: (_, i) => _buildCard(members[i]),
      );
    });
  }

  Widget _buildCard(MemberModel member) {
    final expiryDays = member.expiryDate != null
        ? DateTime.parse(member.expiryDate!).difference(DateTime.now()).inDays
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => _openDetail(member),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAvatar(member),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.fullName, style: AppTextStyles.headingSm),
                        if (member.phone != null)
                          Text(
                            Formatters.phone(member.phone!),
                            style: AppTextStyles.bodySm,
                          ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(member.status),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              if (member.packageId != null)
                _buildInfoRow(PhosphorIconsRegular.tag, member.packageId!),
              if (expiryDays != null)
                _buildInfoRow(
                  PhosphorIconsRegular.clock,
                  Formatters.remainingDays(expiryDays),
                  color: expiryDays < 0 ? AppColors.danger : null,
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionButton(
                    PhosphorIconsRegular.eye,
                    AppColors.primary,
                    () => _openDetail(member),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _buildActionButton(
                    PhosphorIconsRegular.pencilSimple,
                    AppColors.info,
                    () => _openForm(member),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _buildActionButton(
                    PhosphorIconsRegular.trash,
                    AppColors.danger,
                    () => _confirmDelete(member),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? AppColors.textSecondaryD),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: AppTextStyles.bodySm.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final members = controller.filteredMembers;
      if (members.isEmpty) return _buildEmpty();
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
                    DataColumn(label: Text('')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Package')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Expiry')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: members.map((member) {
                    final expiryDays = member.expiryDate != null
                        ? DateTime.parse(
                            member.expiryDate!,
                          ).difference(DateTime.now()).inDays
                        : null;
                    return DataRow(
                      cells: [
                        DataCell(_buildAvatar(member)),
                        DataCell(Text(member.fullName)),
                        DataCell(Text(member.phone ?? '-')),
                        DataCell(Text(member.packageId ?? '-')),
                        DataCell(_buildStatusBadge(member.status)),
                        DataCell(
                          Text(
                            expiryDays != null
                                ? expiryDays >= 0
                                      ? '$expiryDays days'
                                      : 'Expired'
                                : '-',
                            style: TextStyle(
                              color: expiryDays != null && expiryDays < 0
                                  ? AppColors.danger
                                  : null,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(PhosphorIconsRegular.eye, size: 18),
                                color: AppColors.primary,
                                onPressed: () => _openDetail(member),
                                tooltip: 'View',
                              ),
                              IconButton(
                                icon: const Icon(
                                  PhosphorIconsRegular.pencilSimple,
                                  size: 18,
                                ),
                                color: AppColors.info,
                                onPressed: () => _openForm(member),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                                color: AppColors.danger,
                                onPressed: () => _confirmDelete(member),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildAvatar(MemberModel member) {
    if (member.photoPath != null && member.photoPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Image.file(
          File(member.photoPath!),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(),
        ),
      );
    }
    return _buildAvatarPlaceholder();
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: const Icon(PhosphorIconsRegular.user, color: AppColors.primary, size: 22),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = AppColors.success;
      case 'expired':
        color = AppColors.danger;
      case 'paused':
        color = AppColors.warning;
      case 'blocked':
        color = AppColors.neutralGray;
      default:
        color = AppColors.neutralGray;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTextStyles.bodySm.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
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
          Icon(
            PhosphorIconsRegular.user,
            size: 64,
            color: AppColors.neutralGray,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No members found',
            style: AppTextStyles.bodyLg.copyWith(
              color: AppColors.textSecondaryD,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Tap + to add a new member', style: AppTextStyles.bodySm),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(MemberModel member) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Member'),
        content: Text(
          'Are you sure you want to delete "${member.fullName}"?\nAll related data will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.deleteMember(member.memberId);
    }
  }

  void _openForm([MemberModel? member]) async {
    log('[MemberListView] _openForm member=${member?.memberId}');
    final result = await Get.to(
      () => MemberFormView(gymId: gymId, member: member),
    );
    log('[MemberListView] _openForm returned result=$result');
    if (result == true) {
      log('[MemberListView] _openForm - triggering list refresh');
      controller.loadMembers(gymId);
    }
  }

  void _openDetail(MemberModel member) {
    Get.to(() => MemberDetailView(member: member, gymId: gymId));
  }
}

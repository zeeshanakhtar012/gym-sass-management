import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/helpers/responsive.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../widgets/app_drawer.dart';
import '../controllers/attendance_controller.dart';

class AttendanceView extends GetView<AttendanceController> {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            onPressed: () {
              controller.loadAttendance('');
              controller.getTodaysAttendance('');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(),
          _buildModeToggle(),
          _buildDatePicker(),
          if (controller.isCheckInMode.value) _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Obx(() => Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.clock, color: Colors.white, size: 32),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Attendance',
                style: AppTextStyles.bodySm.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                '${controller.todayPresentCount} Present',
                style: AppTextStyles.headingMd.copyWith(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildModeToggle() {
    return Obx(() => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!controller.isCheckInMode.value) {
                  controller.toggleMode();
                  controller.loadMembers('');
                  controller.loadCheckedInToday('');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: controller.isCheckInMode.value ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIconsRegular.signIn,
                      size: 16,
                      color: controller.isCheckInMode.value ? Colors.white : AppColors.textPrimaryL,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Check In',
                      style: AppTextStyles.label.copyWith(
                        color: controller.isCheckInMode.value ? Colors.white : AppColors.textPrimaryL,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (controller.isCheckInMode.value) {
                  controller.toggleMode();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: !controller.isCheckInMode.value ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIconsRegular.clock,
                      size: 16,
                      color: !controller.isCheckInMode.value ? Colors.white : AppColors.textPrimaryL,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'History',
                      style: AppTextStyles.label.copyWith(
                        color: !controller.isCheckInMode.value ? Colors.white : AppColors.textPrimaryL,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildDatePicker() {
    return Obx(() => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: Get.context!,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            controller.setDate(picked);
            controller.loadCheckedInToday('');
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            prefixIcon: const Icon(PhosphorIconsRegular.calendarBlank, size: 18),
            suffixIcon: const Icon(PhosphorIconsRegular.caretDown, size: 14),
            isDense: true,
          ),
          child: Text(
            Formatters.shortDate(DateTime.tryParse(controller.selectedDate.value)),
            style: AppTextStyles.bodyMd,
          ),
        ),
      ),
    ));
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: TextField(
        onChanged: (v) => controller.setSearchQuery(v),
        decoration: InputDecoration(
          hintText: 'Search members...',
          prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
          suffixIcon: Obx(() => controller.searchQuery.value.isNotEmpty
              ? IconButton(
                  icon: const Icon(PhosphorIconsRegular.x, size: 18),
                  onPressed: () {
                    controller.setSearchQuery('');
                  },
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
      if (controller.isCheckInMode.value) {
        return _buildCheckInMode();
      }
      return _buildHistoryMode();
    });
  }

  Widget _buildCheckInMode() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _fingerprintCheckIn(),
              icon: const Icon(PhosphorIconsRegular.fingerprint, size: 18),
              label: const Text('Fingerprint Check-in'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            final list = controller.filteredMembers;
            if (list.isEmpty) {
              return _buildEmpty('No members found', PhosphorIconsRegular.users);
            }
            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: list.length,
              itemBuilder: (_, i) => _buildMemberCard(list[i]),
            );
          }),
        ),
        Obx(() {
          if (controller.checkedInMembers.isEmpty) return const SizedBox.shrink();
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: Text(
                    'Checked In Today (${controller.checkedInMembers.length})',
                    style: AppTextStyles.label,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: controller.checkedInMembers.length,
                    itemBuilder: (_, i) => _buildCheckedInCard(controller.checkedInMembers[i]),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final memberId = member['member_id'] as String;
    final name = member['full_name'] as String? ?? 'Unknown';
    final phone = member['phone'] as String?;
    final alreadyCheckedIn = controller.checkedInMembers.any((c) =>
        c['member_id'] == memberId && c['check_out'] == null);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primarySurface,
          child: Icon(PhosphorIconsRegular.user, color: AppColors.primary),
        ),
        title: Text(name, style: AppTextStyles.bodyMd),
        subtitle: phone != null ? Text(phone, style: AppTextStyles.bodySm) : null,
        trailing: alreadyCheckedIn
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Text('Checked In', style: TextStyle(color: Colors.green, fontSize: 11)),
              )
            : ElevatedButton.icon(
                onPressed: () => _doCheckIn(memberId),
                icon: const Icon(PhosphorIconsRegular.signIn, size: 16),
                label: const Text('Check In', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
      ),
    );
  }

  Widget _buildCheckedInCard(Map<String, dynamic> record) {
    final attendanceId = record['attendance_id'] as int;
    final name = record['member_name'] as String? ?? 'Unknown';
    final checkIn = record['check_in'] as String? ?? '-';
    final checkOut = record['check_out'] as String?;
    final isPresent = checkOut == null;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Icon(PhosphorIconsRegular.signIn, size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(checkIn, style: AppTextStyles.bodySm.copyWith(color: AppColors.success)),
                      if (checkOut != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(PhosphorIconsRegular.signOut, size: 12, color: AppColors.neutralGray),
                        const SizedBox(width: 4),
                        Text(checkOut, style: AppTextStyles.bodySm),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isPresent)
              TextButton.icon(
                onPressed: () => _doCheckOut(attendanceId),
                icon: const Icon(PhosphorIconsRegular.signOut, size: 14),
                label: const Text('Check Out', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryMode() {
    return Obx(() {
      final records = controller.filteredRecords;
      if (records.isEmpty) {
        return _buildEmpty('No attendance records', PhosphorIconsRegular.clock);
      }
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: records.length,
        itemBuilder: (_, i) => _buildHistoryCard(records[i]),
      );
    });
  }

  Widget _buildHistoryCard(Map<String, dynamic> record) {
    final name = record['member_name'] as String? ?? 'Unknown';
    final date = record['date'] as String? ?? '';
    final checkIn = record['check_in'] as String? ?? '-';
    final checkOut = record['check_out'] as String?;
    final method = record['method'] as String? ?? 'manual';
    final status = checkOut != null ? 'Present' : 'Present';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.headingSm),
                  const SizedBox(height: 4),
                  Text(Formatters.shortDate(DateTime.tryParse(date)), style: AppTextStyles.bodySm),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildTimeBadge(PhosphorIconsRegular.signIn, checkIn, AppColors.success),
                      const SizedBox(width: AppSpacing.sm),
                      _buildTimeBadge(PhosphorIconsRegular.signOut, checkOut ?? '-', AppColors.danger),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                _buildMethodBadge(method),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    status,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBadge(IconData icon, String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(time, style: AppTextStyles.bodySm.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMethodBadge(String method) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        method.toUpperCase(),
        style: AppTextStyles.bodySm.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildEmpty(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.neutralGray),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondaryL),
          ),
        ],
      ),
    );
  }

  Future<void> _doCheckIn(String memberId, {String method = 'manual'}) async {
    final result = await controller.checkIn('', memberId, method: method);
    Get.snackbar(
      result.startsWith('Check-in recorded') ? 'Success' : 'Notice',
      result,
    );
  }

  Future<void> _doCheckOut(int attendanceId) async {
    final result = await controller.checkOut('', attendanceId);
    Get.snackbar(
      result.startsWith('Check-out recorded') ? 'Success' : 'Notice',
      result,
    );
  }

  Future<void> _fingerprintCheckIn() async {
    final members = await controller.getFingerprintMembers('');
    if (members.isEmpty) {
      Get.snackbar('No Members', 'No members have registered fingerprints yet');
      return;
    }
    final selected = await Get.dialog<Map<String, dynamic>>(
      AlertDialog(
        title: const Text('Fingerprint Check-in'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (_, i) {
              final member = members[i];
              final name = member['full_name'] as String? ?? 'Unknown';
              final phone = member['phone'] as String?;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primarySurface,
                  child: Icon(PhosphorIconsRegular.fingerprint, color: AppColors.primary, size: 20),
                ),
                title: Text(name),
                subtitle: phone != null ? Text(phone) : null,
                onTap: () => Get.back(result: member),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: null), child: const Text('Cancel')),
        ],
      ),
    );
    if (selected != null) {
      final memberId = selected['member_id'] as String;
      await _doCheckIn(memberId, method: 'fingerprint');
    }
  }
}

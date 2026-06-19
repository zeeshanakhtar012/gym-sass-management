import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/helpers/responsive.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../widgets/app_drawer.dart';
import '../../members/screens/member_list_view.dart';
import '../../members/bindings/member_binding.dart';
import '../../attendance/screens/attendance_view.dart';
import '../../attendance/bindings/attendance_binding.dart';
import '../../invoices/screens/invoice_view.dart';
import '../../invoices/bindings/invoice_binding.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/dashboard_stats.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            onPressed: () => controller.loadDashboard(''),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKpiGrid(),
              const SizedBox(height: AppSpacing.lg),
              _buildChartsSection(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildKpiGrid() {
    return Responsive(
      mobile: _buildGrid(columns: 1),
      tablet: _buildGrid(columns: 2),
      desktop: _buildGrid(columns: 4),
    );
  }

  Widget _buildGrid({required int columns}) {
    final stats = controller.stats.value;
    final items = _buildStatItems(stats);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items.map((item) {
        return SizedBox(
          width: _itemWidth(columns),
          child: _StatCard(
            icon: item.icon,
            label: item.label,
            value: item.value,
            color: item.color,
            onTap: item.onTap,
          ),
        );
      }).toList(),
    );
  }

  double _itemWidth(int columns) {
    if (columns == 1) return double.infinity;
    if (columns == 2) return (Get.width - AppSpacing.md * 2 - AppSpacing.sm) / 2;
    return (Get.width - AppSpacing.md * 2 - AppSpacing.sm * 3) / 4;
  }

  List<_StatItem> _buildStatItems(DashboardStats stats) {
    return [
      _StatItem(PhosphorIconsRegular.users, 'Total Members', '${stats.totalMembers}', AppColors.primary, onTap: () {
        MemberBinding().dependencies();
        Get.to(() => MemberListView());
      }),
      _StatItem(PhosphorIconsRegular.userCheck, 'Active', '${stats.activeMembers}', AppColors.success, onTap: () {
        MemberBinding().dependencies();
        Get.to(() => MemberListView());
      }),
      _StatItem(PhosphorIconsRegular.userMinus, 'Expired', '${stats.expiredMembers}', AppColors.danger, onTap: () {
        MemberBinding().dependencies();
        Get.to(() => MemberListView());
      }),
      _StatItem(PhosphorIconsRegular.calendarCheck, "Today's Attendance", '${stats.todayAttendance}', AppColors.info, onTap: () {
        AttendanceBinding().dependencies();
        Get.to(() => AttendanceView());
      }),
      _StatItem(PhosphorIconsRegular.building, 'Currently Inside', '${stats.currentlyInside}', AppColors.primary),
      _StatItem(PhosphorIconsRegular.trendUp, 'Monthly Revenue', Formatters.currency(stats.monthlyRevenue), AppColors.success),
      _StatItem(PhosphorIconsRegular.trendDown, 'Monthly Expenses', Formatters.currency(stats.monthlyExpenses), AppColors.danger),
      _StatItem(PhosphorIconsRegular.coin, 'Monthly Profit', Formatters.currency(stats.monthlyProfit), stats.monthlyProfit >= 0 ? AppColors.success : AppColors.danger),
      _StatItem(PhosphorIconsRegular.clock, 'Pending Payments', '${stats.pendingPayments}', AppColors.warning, onTap: () {
        InvoiceBinding().dependencies();
        Get.to(() => InvoiceView());
      }),
    ];
  }

  Widget _buildChartsSection() {
    return Column(
      children: [
        Responsive(
          mobile: Column(
            children: [
              _buildRevenueChart(),
              const SizedBox(height: AppSpacing.md),
              _buildAttendanceChart(),
            ],
          ),
          desktop: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRevenueChart()),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildAttendanceChart()),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildGrowthChart(),
      ],
    );
  }

  Widget _buildRevenueChart() {
    final data = controller.revenueData;
    if (data.isEmpty) {
      return _buildEmptyChart('No revenue data');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly Revenue', style: AppTextStyles.headingSm),
            const SizedBox(height: AppSpacing.md),
            ...data.map<Widget>((row) {
              final month = row['month'] as String? ?? '';
              final revenue = (row['revenue'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(month, style: AppTextStyles.bodySm),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: revenue > 0 ? 1.0 : 0.0,
                          backgroundColor: AppColors.primarySurface,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                          minHeight: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 100,
                      child: Text(
                        Formatters.currency(revenue),
                        style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceChart() {
    final data = controller.attendanceData;
    if (data.isEmpty) {
      return _buildEmptyChart('No attendance data');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Attendance (30 days)', style: AppTextStyles.headingSm),
            const SizedBox(height: AppSpacing.md),
            ...data.map<Widget>((row) {
              final date = row['date'] as String? ?? '';
              final count = (row['count'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        Formatters.shortDate(DateTime.tryParse(date)),
                        style: AppTextStyles.bodySm,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: count > 0 ? count / 50.0 : 0.0,
                          backgroundColor: AppColors.primarySurface,
                          valueColor: const AlwaysStoppedAnimation(AppColors.info),
                          minHeight: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$count',
                        style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthChart() {
    final data = controller.growthData;
    if (data.isEmpty) {
      return _buildEmptyChart('No growth data');
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Membership Growth', style: AppTextStyles.headingSm),
            const SizedBox(height: AppSpacing.md),
            ...data.map<Widget>((row) {
              final month = row['month'] as String? ?? '';
              final count = (row['count'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(month, style: AppTextStyles.bodySm),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: count > 0 ? count / 30.0 : 0.0,
                          backgroundColor: AppColors.primarySurface,
                          valueColor: const AlwaysStoppedAnimation(AppColors.success),
                          minHeight: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$count',
                        style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return Card(
      child: SizedBox(
        height: 200,
        child: Center(
          child: Text(message, style: AppTextStyles.bodySm),
        ),
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  _StatItem(this.icon, this.label, this.value, this.color, {this.onTap});
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: AppTextStyles.displayLg.copyWith(color: color)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: AppTextStyles.bodySm),
            ],
          ),
        ),
      ),
    );
  }
}

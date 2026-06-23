import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/helpers/responsive.dart';
import '../../../widgets/app_drawer.dart';
import '../controllers/report_controller.dart';

class ReportView extends GetView<ReportController> {
  const ReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text('Reports'),
          actions: [
            IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowClockwise),
              onPressed: () => _loadAll(''),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondaryD,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(icon: Icon(PhosphorIconsRegular.chartBar), text: 'Overview'),
              Tab(icon: Icon(PhosphorIconsRegular.users), text: 'Members'),
              Tab(icon: Icon(PhosphorIconsRegular.trendUp), text: 'Financial'),
              Tab(icon: Icon(PhosphorIconsRegular.fingerprint), text: 'Attendance'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildDateFilter(),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                return const TabBarView(
                  children: [
                    _OverviewTab(),
                    _MembersTab(),
                    _FinancialTab(),
                    _AttendanceTab(),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Obx(() {
        final range = controller.selectedDateRange.value;
        return Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickDateRange(),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date Range',
                    isDense: true,
                    prefixIcon: Icon(PhosphorIconsRegular.calendarBlank, size: 18),
                  ),
                  child: Text(
                    range != null
                        ? '${Formatters.shortDate(range.start)} - ${Formatters.shortDate(range.end)}'
                        : 'This Month',
                    style: AppTextStyles.bodySm,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
              onPressed: () => _loadAll(''),
              color: AppColors.primary,
            ),
            PopupMenuButton<String>(
              icon: const Icon(PhosphorIconsRegular.downloadSimple),
              onSelected: (v) {
                Get.snackbar('Export', '$v export will be available soon');
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'PDF', child: ListTile(
                  leading: Icon(PhosphorIconsRegular.filePdf, color: AppColors.danger),
                  title: Text('Export PDF'),
                  contentPadding: EdgeInsets.zero,
                )),
                const PopupMenuItem(value: 'Excel', child: ListTile(
                  leading: Icon(PhosphorIconsRegular.fileXls, color: AppColors.success),
                  title: Text('Export Excel'),
                  contentPadding: EdgeInsets.zero,
                )),
              ],
            ),
          ],
        );
      }),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: Get.context!,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: controller.selectedDateRange.value ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (picked != null) {
      controller.selectedDateRange.value = picked;
    }
  }

  void _loadAll(String gymId) {
    controller.loadOverviewReport(gymId);
    final range = controller.selectedDateRange.value;
    if (range != null) {
      final start = Formatters.date(range.start);
      final end = Formatters.date(range.end);
      controller.loadFinancialReport(gymId, start, end);
      controller.loadAttendanceReport(gymId, start, end);
    }
    controller.loadMemberReport(gymId);
  }
}

class _OverviewTab extends GetView<ReportController> {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Obx(() {
        final data = controller.reportData;
        return Responsive(
          mobile: Column(
            children: [
              _buildKpiGrid(data, columns: 1),
            ],
          ),
          tablet: Column(
            children: [
              _buildKpiGrid(data, columns: 2),
            ],
          ),
          desktop: Column(
            children: [
              _buildKpiGrid(data, columns: 3),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildKpiGrid(Map<String, dynamic> data, {required int columns}) {
    final items = _kpiItems(data);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items.map((item) {
        return SizedBox(
          width: _itemWidth(columns),
          child: _KpiCard(
            icon: item.icon,
            label: item.label,
            value: item.value,
            color: item.color,
          ),
        );
      }).toList(),
    );
  }

  double _itemWidth(int columns) {
    if (columns == 1) return double.infinity;
    if (columns == 2) return (Get.width - AppSpacing.md * 2 - AppSpacing.sm) / 2;
    return (Get.width - AppSpacing.md * 2 - AppSpacing.sm * 2) / 3;
  }

  List<_KpiItem> _kpiItems(Map<String, dynamic> data) {
    return [
      _KpiItem(PhosphorIconsRegular.users, 'Total Members',
          '${data['totalMembers'] ?? 0}', AppColors.primary),
      _KpiItem(PhosphorIconsRegular.userCheck, 'Active',
          '${data['activeMembers'] ?? 0}', AppColors.success),
      _KpiItem(PhosphorIconsRegular.userMinus, 'Expired',
          '${data['expiredMembers'] ?? 0}', AppColors.danger),
      _KpiItem(PhosphorIconsRegular.fingerprint, 'Attendance %',
          '${(data['attendancePercent'] ?? 0.0).toStringAsFixed(1)}%', AppColors.info),
      _KpiItem(PhosphorIconsRegular.trendUp, 'Monthly Revenue',
          Formatters.currency(data['monthlyRevenue'] ?? 0), AppColors.success),
      _KpiItem(PhosphorIconsRegular.trendDown, 'Monthly Expenses',
          Formatters.currency(data['monthlyExpenses'] ?? 0), AppColors.danger),
      _KpiItem(PhosphorIconsRegular.coin, 'Monthly Profit',
          Formatters.currency(data['monthlyProfit'] ?? 0),
          (data['monthlyProfit'] ?? 0) >= 0 ? AppColors.success : AppColors.danger),
      _KpiItem(PhosphorIconsRegular.clock, 'Pending Dues',
          Formatters.currency(data['pendingDues'] ?? 0), AppColors.warning),
    ];
  }
}

class _MembersTab extends GetView<ReportController> {
  const _MembersTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = controller.reportData;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Members by Package', style: AppTextStyles.headingMd),
            const SizedBox(height: AppSpacing.md),
            _buildPiePlaceholder(
              data['membersByPackage'] as List? ?? [],
              'package_name',
              'count',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Members by Status', style: AppTextStyles.headingMd),
            const SizedBox(height: AppSpacing.md),
            _buildPiePlaceholder(
              data['membersByStatus'] as List? ?? [],
              'status',
              'count',
              isStatus: true,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPiePlaceholder(List items, String labelKey, String valueKey,
      {bool isStatus = false}) {
    if (items.isEmpty) {
      return Card(
        child: SizedBox(
          height: 120,
          child: Center(
            child: Text('No data available', style: AppTextStyles.bodySm),
          ),
        ),
      );
    }

    final colors = [
      AppColors.primary, AppColors.success, AppColors.warning,
      AppColors.danger, AppColors.info, AppColors.accent,
      AppColors.neutralGray,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: List.generate(items.length, (i) {
            final item = items[i] as Map<String, dynamic>;
            final label = item[labelKey] as String? ?? 'Unknown';
            final value = (item[valueKey] as num).toInt();
            final color = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(label, style: AppTextStyles.bodyMd)),
                  Text('$value',
                      style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _FinancialTab extends GetView<ReportController> {
  const _FinancialTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Obx(() {
        final data = controller.reportData;
        final revenue = data['financialRevenue'] as int? ?? 0;
        final expenses = data['financialExpenses'] as int? ?? 0;
        final profit = data['financialProfit'] as int? ?? 0;
        final byMethod = data['paymentByMethod'] as List? ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue vs Expenses', style: AppTextStyles.headingMd),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _buildAmountCard(
                    'Revenue', Formatters.currency(revenue), AppColors.success,
                    PhosphorIconsRegular.trendUp)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _buildAmountCard(
                    'Expenses', Formatters.currency(expenses), AppColors.danger,
                    PhosphorIconsRegular.trendDown)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildAmountCard(
              'Net Profit',
              Formatters.currency(profit),
              profit >= 0 ? AppColors.success : AppColors.danger,
              PhosphorIconsRegular.coin,
              fullWidth: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Payment Methods', style: AppTextStyles.headingMd),
            const SizedBox(height: AppSpacing.md),
            if (byMethod.isEmpty)
              Card(
                child: SizedBox(
                  height: 80,
                  child: Center(
                    child: Text('No payment data for this period',
                        style: AppTextStyles.bodySm),
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: List.generate(byMethod.length, (i) {
                      final m = byMethod[i] as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            Icon(PhosphorIconsRegular.currencyCircleDollar,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(m['method'] as String? ?? '',
                                  style: AppTextStyles.bodyMd),
                            ),
                            Text(Formatters.currency((m['total'] as num).toInt()),
                                style: AppTextStyles.bodyMd.copyWith(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildAmountCard(String label, String value, Color color, IconData icon,
      {bool fullWidth = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondaryD)),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.headingSm.copyWith(color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceTab extends GetView<ReportController> {
  const _AttendanceTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Obx(() {
        final data = controller.reportData;
        final daily = data['attendanceDaily'] as List? ?? [];
        final totalMembers = data['totalMembers'] as int? ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Attendance Summary', style: AppTextStyles.headingMd),
            const SizedBox(height: AppSpacing.md),
            if (daily.isEmpty)
              Card(
                child: SizedBox(
                  height: 120,
                  child: Center(
                    child: Text('No attendance data for this period',
                        style: AppTextStyles.bodySm),
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: List.generate(daily.length, (i) {
                      final row = daily[i] as Map<String, dynamic>;
                      final date = row['date'] as String? ?? '';
                      final count = (row['count'] as num).toInt();
                      final pct = totalMembers > 0 ? count / totalMembers : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                                  value: pct,
                                  backgroundColor: AppColors.primarySurface,
                                  valueColor: AlwaysStoppedAnimation(
                                    pct >= 0.5 ? AppColors.success : AppColors.warning,
                                  ),
                                  minHeight: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '$count (${Formatters.attendancePercent(count, totalMembers)})',
                                style: AppTextStyles.bodySm.copyWith(
                                    fontWeight: FontWeight.w600),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            if (daily.isNotEmpty)
              _buildSummaryStats(daily),
          ],
        );
      }),
    );
  }

  Widget _buildSummaryStats(List daily) {
    final total = daily.fold<int>(0, (s, r) => s + ((r as Map)['count'] as num).toInt());
    final days = daily.length;
    final avg = days > 0 ? (total / days).toStringAsFixed(1) : '0';
    return Row(
      children: [
        Expanded(child: _buildMiniCard('Total Check-ins', '$total')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _buildMiniCard('Days', '$days')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _buildMiniCard('Avg/Day', avg)),
      ],
    );
  }

  Widget _buildMiniCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.headingMd.copyWith(color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyles.bodySm),
          ],
        ),
      ),
    );
  }
}

class _KpiItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  _KpiItem(this.icon, this.label, this.value, this.color);
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: color, size: 22),
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
    );
  }
}

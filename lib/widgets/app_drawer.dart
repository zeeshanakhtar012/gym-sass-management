import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';
import '../modules/auth/controllers/auth_service.dart';
import '../modules/auth/screens/login_view.dart';
import '../modules/members/screens/member_list_view.dart';
import '../modules/members/bindings/member_binding.dart';
import '../modules/packages/screens/package_list_view.dart';
import '../modules/packages/bindings/package_binding.dart';
import '../modules/attendance/screens/attendance_view.dart';
import '../modules/attendance/screens/fingerprint_attendance_view.dart';
import '../modules/attendance/screens/keyboard_attendance_view.dart';
import '../modules/attendance/bindings/attendance_binding.dart';
import '../modules/payments/screens/payment_view.dart';
import '../modules/payments/bindings/payment_binding.dart';
import '../modules/invoices/screens/invoice_view.dart';
import '../modules/invoices/bindings/invoice_binding.dart';
import '../modules/expenses/screens/expense_view.dart';
import '../modules/expenses/bindings/expense_binding.dart';
import '../modules/reports/screens/report_view.dart';
import '../modules/reports/bindings/report_binding.dart';
import '../modules/notifications/screens/notification_view.dart';
import '../modules/notifications/bindings/notification_binding.dart';
import '../modules/kiosk/screens/kiosk_view.dart';
import '../modules/kiosk/bindings/kiosk_binding.dart';
import '../modules/backup/screens/backup_view.dart';
import '../modules/backup/bindings/backup_binding.dart';
import '../modules/inventory/screens/inventory_view.dart';
import '../modules/inventory/bindings/inventory_binding.dart';
import '../modules/settings/screens/setting_view.dart';
import '../modules/settings/bindings/setting_binding.dart';
import '../modules/gyms/screens/gym_list_view.dart';
import '../modules/gyms/bindings/gym_binding.dart';
import '../modules/dashboard/bindings/dashboard_binding.dart';
import '../modules/dashboard/screens/dashboard_view.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();
    final isSuperAdmin = authService.isSuperAdmin;
    final gymName = authService.currentSession.value?.username ?? 'Gym ERP';

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            margin: EdgeInsets.zero,
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.barbell,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    gymName,
                    style: AppTextStyles.headingSm.copyWith(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isSuperAdmin ? 'Super Admin' : 'Gym Admin',
                    style: AppTextStyles.bodySm.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (isSuperAdmin) ...[
                  _navItem(context, 
                    icon: PhosphorIconsRegular.gauge,
                    label: 'Dashboard',
                    builder: () => const DashboardView(),
                    binding: DashboardBinding(),
                  ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.buildings,
                    label: 'Gyms',
                    builder: () => const GymListView(),
                    binding: GymBinding(),
                  ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.chartBar,
                    label: 'Reports',
                    builder: () => const ReportView(),
                    binding: ReportBinding(),
                  ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.gear,
                    label: 'Settings',
                    builder: () => const SettingView(),
                    binding: SettingBinding(),
                  ),
                ] else ...[
                  _navItem(context, 
                    icon: PhosphorIconsRegular.gauge,
                    label: 'Dashboard',
                    builder: () => const DashboardView(),
                    binding: DashboardBinding(),
                  ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.users,
                    label: 'Members',
                    builder: () => MemberListView(),
                    binding: MemberBinding(),
                  ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.tag,
                    label: 'Packages',
                    builder: () => const PackageListView(),
                    binding: PackageBinding(),
                  ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.calendarCheck,
                    label: 'Attendance',
                    builder: () => AttendanceView(),
                    binding: AttendanceBinding(),
                  ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.fingerprint,
                    label: 'FP Attendance',
                    builder: () => const FingerprintAttendanceView(),
                  ),
                  // _navItem(context, 
                  //   icon: PhosphorIconsRegular.keyboard,
                  //   label: 'Keyboard Check-in',
                  //   builder: () => const KeyboardAttendanceView(),
                  // ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.coin,
                    label: 'Payments',
                    builder: () => PaymentView(),
                    binding: PaymentBinding(),
                  ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.receipt,
                    label: 'Invoices',
                    builder: () => InvoiceView(),
                    binding: InvoiceBinding(),
                  ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.receiptX,
                    label: 'Expenses',
                    builder: () => ExpenseView(),
                    binding: ExpenseBinding(),
                  ),
                  // _navItem(context, 
                  //   icon: PhosphorIconsRegular.package,
                  //   label: 'Inventory',
                  //   builder: () => const InventoryView(),
                  //   binding: InventoryBinding(),
                  // ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.chartBar,
                    label: 'Reports',
                    builder: () => const ReportView(),
                    binding: ReportBinding(),
                  ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.bell,
                    label: 'Notifications',
                    builder: () => NotificationView(),
                    binding: NotificationBinding(),
                  ),
                  // _navItem(context, 
                  //   icon: PhosphorIconsRegular.monitor,
                  //   label: 'Kiosk Mode',
                  //   builder: () => const KioskView(),
                  //   binding: KioskBinding(),
                  // ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.database,
                    label: 'Backup',
                    builder: () => const BackupView(),
                    binding: BackupBinding(),
                  ),
                  _navItem(context, 
                    icon: PhosphorIconsRegular.gear,
                    label: 'Settings',
                    builder: () => const SettingView(),
                    binding: SettingBinding(),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.signOut, color: AppColors.danger),
            title: Text('Logout', style: AppTextStyles.bodyMd.copyWith(color: AppColors.danger)),
            onTap: () {
              authService.logout();
              Get.offAll(() => const LoginView());
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget Function() builder,
    Bindings? binding,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 22,
      ),
      title: Text(
        label,
        style: AppTextStyles.bodyMd.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      onTap: () {
        Get.back();
        binding?.dependencies();
        Get.to(builder);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'core/database/database_helper.dart';
import 'core/theme/theme_data.dart';
import 'modules/auth/bindings/auth_binding.dart';
import 'modules/auth/controllers/auth_service.dart';
import 'modules/auth/screens/login_view.dart';
import 'modules/dashboard/screens/dashboard_view.dart';
import 'modules/dashboard/bindings/dashboard_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.ensureInitialized();

  AuthBinding().dependencies();
  final authService = Get.find<AuthService>();
  final session = await authService.restoreSession();

  ThemeMode initialTheme = ThemeMode.dark;

  if (session != null) {
    DashboardBinding().dependencies();

    // Restore persisted theme preference from settings table
    try {
      final gymId = session.gymId;
      if (gymId != null && gymId.isNotEmpty) {
        final db = await DatabaseHelper.instance.database;
        final result = await db.query('settings',
          where: 'gym_id = ?',
          whereArgs: [gymId],
          limit: 1,
        );
        if (result.isNotEmpty) {
          final stored = result.first['theme'] as String? ?? 'dark';
          switch (stored) {
            case 'light':
              initialTheme = ThemeMode.light;
              break;
            case 'system':
              initialTheme = ThemeMode.system;
              break;
          }
        }
      }
    } catch (_) {
      // Use default if settings table/row doesn't exist yet
    }
  }

  runApp(GymErpApp(session != null, initialTheme: initialTheme));
}

class GymErpApp extends StatelessWidget {
  final bool isLoggedIn;
  final ThemeMode initialTheme;
  const GymErpApp(this.isLoggedIn, {super.key, required this.initialTheme});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Gym ERP',
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.fadeIn,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: initialTheme,
      home: isLoggedIn ? const DashboardView() : const LoginView(),
      builder: (context, child) {
        return ResponsiveBreakpoints.builder(
          child: child!,
          breakpoints: [
            const Breakpoint(start: 0, end: 600, name: MOBILE),
            const Breakpoint(start: 601, end: 1024, name: TABLET),
            const Breakpoint(start: 1025, end: double.infinity, name: DESKTOP),
          ],
        );
      },
    );
  }
}

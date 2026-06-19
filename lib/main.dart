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

  if (session != null) {
    DashboardBinding().dependencies();
  }
  runApp(GymErpApp(session != null));
}

class GymErpApp extends StatelessWidget {
  final bool isLoggedIn;
  const GymErpApp(this.isLoggedIn, {super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Gym ERP',
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.fadeIn,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
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

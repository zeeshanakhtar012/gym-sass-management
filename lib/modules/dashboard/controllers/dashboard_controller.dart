import 'dart:developer';

import 'package:get/get.dart';
import '../../auth/controllers/auth_service.dart' as auth;
import '../../../core/services/zkteco_scanner_service.dart';
import '../../../core/services/fingerprint_scanner_service.dart';
import 'dashboard_repository.dart';
import 'dashboard_stats.dart';

class DashboardController extends GetxController {
  final DashboardRepository _dashboardRepository = Get.find<DashboardRepository>();
  final auth.AuthService _authService = Get.find<auth.AuthService>();

  final Rx<DashboardStats> stats = DashboardStats().obs;
  final RxList revenueData = [].obs;
  final RxList attendanceData = [].obs;
  final RxList growthData = [].obs;
  final RxBool isLoading = true.obs;
  final RxBool fingerprintConnected = false.obs;

  final FingerprintScannerService _scanner = ZKTecoBiometricService();

  @override
  void onInit() {
    super.onInit();
    log('[DashboardController] onInit - isSuperAdmin: ${_authService.isSuperAdmin}, gymId: ${_authService.currentGymId}');
    final gymId = _resolveGymId();
    loadDashboard(gymId);
    checkFingerprintConnection();
  }

  String _resolveGymId() {
    if (_authService.isSuperAdmin) {
      log('[DashboardController] Super admin - loading aggregated data from all gyms');
      return '';
    }
    final gymId = _authService.currentGymId ?? '';
    log('[DashboardController] Gym admin - loading data for gym: $gymId');
    return gymId;
  }

  @override
  void onClose() {
    _scanner.disconnect();
    super.onClose();
  }

  Future<void> checkFingerprintConnection() async {
    log('[DashboardController] checkFingerprintConnection called');
    try {
      final connected = await _scanner.isScannerConnected();
      fingerprintConnected.value = connected;
      log('[DashboardController] fingerprint scanner connected: $connected');
    } catch (e) {
      log('[DashboardController] fingerprint check error: $e');
      fingerprintConnected.value = false;
    }
  }

  Future<void> loadDashboard(String gymId) async {
    isLoading.value = true;
    log('[DashboardController] loadDashboard called with gymId: "$gymId"');
    try {
      final results = await Future.wait([
        _dashboardRepository.getStats(gymId),
        _dashboardRepository.getRevenueChartData(gymId),
        _dashboardRepository.getAttendanceChartData(gymId),
        _dashboardRepository.getGrowthChartData(gymId),
      ]);
      stats.value = results[0] as DashboardStats;
      revenueData.value = results[1] as List;
      attendanceData.value = results[2] as List;
      growthData.value = results[3] as List;
      log('[DashboardController] Dashboard loaded successfully');
      log('[DashboardController] Stats: totalMembers=${stats.value.totalMembers}, active=${stats.value.activeMembers}, revenue=${stats.value.monthlyRevenue}');
      log('[DashboardController] Revenue data points: ${revenueData.length}, Attendance points: ${attendanceData.length}, Growth points: ${growthData.length}');
    } catch (e, stack) {
      log('[DashboardController] Error loading dashboard: $e');
      log('[DashboardController] Stack: $stack');
      Get.snackbar('Error', 'Failed to load dashboard data: $e');
    } finally {
      isLoading.value = false;
      log('[DashboardController] isLoading set to false');
    }
  }

}

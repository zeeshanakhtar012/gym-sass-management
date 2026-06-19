import 'dart:developer';

import 'dashboard_dao.dart';
import 'dashboard_stats.dart';

class DashboardRepository {
  final DashboardDao _dashboardDao;

  DashboardRepository(this._dashboardDao);

  Future<DashboardStats> getStats(String gymId) {
    log('[DashboardRepository] getStats called gymId=$gymId');
    return _dashboardDao.getAllStats(gymId);
  }

  Future<List<Map<String, dynamic>>> getRevenueChartData(String gymId) {
    log('[DashboardRepository] getRevenueChartData called gymId=$gymId');
    return _dashboardDao.getMonthlyRevenueData(gymId);
  }

  Future<List<Map<String, dynamic>>> getAttendanceChartData(String gymId) {
    log('[DashboardRepository] getAttendanceChartData called gymId=$gymId');
    return _dashboardDao.getDailyAttendanceData(gymId);
  }

  Future<List<Map<String, dynamic>>> getGrowthChartData(String gymId) {
    log('[DashboardRepository] getGrowthChartData called gymId=$gymId');
    return _dashboardDao.getMembershipGrowthData(gymId);
  }
}

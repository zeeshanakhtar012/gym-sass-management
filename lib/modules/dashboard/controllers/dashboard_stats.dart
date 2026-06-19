class DashboardStats {
  final int totalMembers;
  final int activeMembers;
  final int expiredMembers;
  final int todayAttendance;
  final int currentlyInside;
  final int monthlyRevenue;
  final int monthlyExpenses;
  final int monthlyProfit;
  final int pendingPayments;

  const DashboardStats({
    this.totalMembers = 0,
    this.activeMembers = 0,
    this.expiredMembers = 0,
    this.todayAttendance = 0,
    this.currentlyInside = 0,
    this.monthlyRevenue = 0,
    this.monthlyExpenses = 0,
    this.monthlyProfit = 0,
    this.pendingPayments = 0,
  });
}

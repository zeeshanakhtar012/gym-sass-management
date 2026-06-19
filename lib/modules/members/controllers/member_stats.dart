class MemberStats {
  final int currentMonthAttendance;
  final int previousMonthAttendance;
  final int lifetimeAttendance;
  final double attendancePercent;
  final DateTime? lastVisit;
  final DateTime? lastCheckIn;
  final DateTime? lastCheckOut;
  final int totalVisits;
  final double avgVisitsPerMonth;
  final int totalPaid;
  final int totalDue;
  final DateTime? lastPaymentDate;

  const MemberStats({
    this.currentMonthAttendance = 0,
    this.previousMonthAttendance = 0,
    this.lifetimeAttendance = 0,
    this.attendancePercent = 0.0,
    this.lastVisit,
    this.lastCheckIn,
    this.lastCheckOut,
    this.totalVisits = 0,
    this.avgVisitsPerMonth = 0.0,
    this.totalPaid = 0,
    this.totalDue = 0,
    this.lastPaymentDate,
  });
}

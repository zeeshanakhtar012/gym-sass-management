import '../../members/controllers/member_model.dart';
import 'attendance_record.dart';

class AttendanceValidator {
  static String? validateCheckIn(
    String gymId,
    String memberId,
    MemberModel member,
    AttendanceRecord? todayRecord,
  ) {
    if (member.status != 'active') {
      return 'Membership is not active';
    }

    if (member.expiryDate != null) {
      final expiry = DateTime.tryParse(member.expiryDate!);
      if (expiry != null && expiry.isBefore(DateTime.now())) {
        return 'Membership has expired';
      }
    }

    if (todayRecord != null) {
      if (todayRecord.checkOut == null) {
        return 'Already checked in today';
      }
    }

    return null;
  }
}

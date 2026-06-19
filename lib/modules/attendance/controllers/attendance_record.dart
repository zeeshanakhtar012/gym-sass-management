class AttendanceRecord {
  final int? attendanceId;
  final String gymId;
  final String memberId;
  final String date;
  final String? checkIn;
  final String? checkOut;
  final String method;
  final String createdAt;

  final String? memberName;
  final String? memberPhoto;
  final String? memberStatus;

  const AttendanceRecord({
    this.attendanceId,
    required this.gymId,
    required this.memberId,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.method = 'manual',
    required this.createdAt,
    this.memberName,
    this.memberPhoto,
    this.memberStatus,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      attendanceId: map['attendance_id'] as int?,
      gymId: map['gym_id'] as String,
      memberId: map['member_id'] as String,
      date: map['date'] as String,
      checkIn: map['check_in'] as String?,
      checkOut: map['check_out'] as String?,
      method: map['method'] as String? ?? 'manual',
      createdAt: map['created_at'] as String,
      memberName: map['member_name'] as String?,
      memberPhoto: map['member_photo'] as String?,
      memberStatus: map['member_status'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (attendanceId != null) 'attendance_id': attendanceId,
      'gym_id': gymId,
      'member_id': memberId,
      'date': date,
      'check_in': checkIn,
      'check_out': checkOut,
      'method': method,
      'created_at': createdAt,
    };
  }
}

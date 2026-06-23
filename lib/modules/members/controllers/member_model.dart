import 'dart:typed_data';

class MemberModel {
  final String memberId;
  final String gymId;
  final String fullName;
  final String? fatherName;
  final String? cnic;
  final String? phone;
  final String? emergencyContact;
  final String? gender;
  final String? dob;
  final String? address;
  final String? photoPath;
  final double? height;
  final double? weight;
  final double? bmi;
  final String? fitnessGoal;
  /// Legacy ZK SDK template (~500 bytes). Not used for production matching.
  final Uint8List? fingerprintTemplate;

  /// Legacy raw fingerprint image (300×375 grayscale, 112500 bytes).
  /// Not saved for new enrollments. Existing data is migrated on-the-fly.
  final Uint8List? fingerprintImage;

  /// Dartafis serialised biometric template.
  /// This is the primary fingerprint data used for identification.
  /// Produced by [DartafisService.serializeTemplate].
  final Uint8List? fingerprintData;
  final String? qrData;
  final String registrationDate;
  final String? packageId;
  final String? startDate;
  final String? expiryDate;
  final String status;
  final String feeStatus;
  final String? lastFeePaidDate;
  final String? feeDueDate;
  final String createdAt;
  final String updatedAt;

  const MemberModel({
    required this.memberId,
    required this.gymId,
    required this.fullName,
    this.fatherName,
    this.cnic,
    this.phone,
    this.emergencyContact,
    this.gender,
    this.dob,
    this.address,
    this.photoPath,
    this.height,
    this.weight,
    this.bmi,
    this.fitnessGoal,
    this.fingerprintTemplate,
    this.fingerprintImage,
    this.fingerprintData,
    this.qrData,
    required this.registrationDate,
    this.packageId,
    this.startDate,
    this.expiryDate,
    this.status = 'active',
    this.feeStatus = 'paid',
    this.lastFeePaidDate,
    this.feeDueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      memberId: json['member_id'] as String,
      gymId: json['gym_id'] as String,
      fullName: json['full_name'] as String,
      fatherName: json['father_name'] as String?,
      cnic: json['cnic'] as String?,
      phone: json['phone'] as String?,
      emergencyContact: json['emergency_contact'] as String?,
      gender: json['gender'] as String?,
      dob: json['dob'] as String?,
      address: json['address'] as String?,
      photoPath: json['photo_path'] as String?,
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
      fitnessGoal: json['fitness_goal'] as String?,
      fingerprintTemplate: json['fingerprint_template'] as Uint8List?,
      fingerprintImage: json['fingerprint_image'] as Uint8List?,
      fingerprintData: json['fingerprint_data'] as Uint8List?,
      qrData: json['qr_data'] as String?,
      registrationDate: json['registration_date'] as String,
      packageId: json['package_id'] as String?,
      startDate: json['start_date'] as String?,
      expiryDate: json['expiry_date'] as String?,
      status: json['status'] as String? ?? 'active',
      feeStatus: json['fee_status'] as String? ?? 'paid',
      lastFeePaidDate: json['last_fee_paid_date'] as String?,
      feeDueDate: json['fee_due_date'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  factory MemberModel.fromMap(Map<String, dynamic> map) {
    return MemberModel.fromJson(map);
  }

  Map<String, dynamic> toJson() {
    return {
      'member_id': memberId,
      'gym_id': gymId,
      'full_name': fullName,
      'father_name': fatherName,
      'cnic': cnic,
      'phone': phone,
      'emergency_contact': emergencyContact,
      'gender': gender,
      'dob': dob,
      'address': address,
      'photo_path': photoPath,
      'height': height,
      'weight': weight,
      'bmi': bmi,
      'fitness_goal': fitnessGoal,
      'fingerprint_template': fingerprintTemplate,
      'fingerprint_image': fingerprintImage,
      'fingerprint_data': fingerprintData,
      'qr_data': qrData,
      'registration_date': registrationDate,
      'package_id': packageId,
      'start_date': startDate,
      'expiry_date': expiryDate,
      'status': status,
      'fee_status': feeStatus,
      'last_fee_paid_date': lastFeePaidDate,
      'fee_due_date': feeDueDate,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  MemberModel copyWith({
    String? memberId,
    String? gymId,
    String? fullName,
    String? fatherName,
    String? cnic,
    String? phone,
    String? emergencyContact,
    String? gender,
    String? dob,
    String? address,
    String? photoPath,
    double? height,
    double? weight,
    double? bmi,
    String? fitnessGoal,
    Uint8List? fingerprintTemplate,
    Uint8List? fingerprintImage,
    Uint8List? fingerprintData,
    String? qrData,
    String? registrationDate,
    String? packageId,
    String? startDate,
    String? expiryDate,
    String? status,
    String? feeStatus,
    String? lastFeePaidDate,
    String? feeDueDate,
    String? createdAt,
    String? updatedAt,
  }) {
    return MemberModel(
      memberId: memberId ?? this.memberId,
      gymId: gymId ?? this.gymId,
      fullName: fullName ?? this.fullName,
      fatherName: fatherName ?? this.fatherName,
      cnic: cnic ?? this.cnic,
      phone: phone ?? this.phone,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      address: address ?? this.address,
      photoPath: photoPath ?? this.photoPath,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bmi: bmi ?? this.bmi,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      fingerprintTemplate: fingerprintTemplate ?? this.fingerprintTemplate,
      fingerprintImage: fingerprintImage ?? this.fingerprintImage,
      fingerprintData: fingerprintData ?? this.fingerprintData,
      qrData: qrData ?? this.qrData,
      registrationDate: registrationDate ?? this.registrationDate,
      packageId: packageId ?? this.packageId,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      status: status ?? this.status,
      feeStatus: feeStatus ?? this.feeStatus,
      lastFeePaidDate: lastFeePaidDate ?? this.lastFeePaidDate,
      feeDueDate: feeDueDate ?? this.feeDueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

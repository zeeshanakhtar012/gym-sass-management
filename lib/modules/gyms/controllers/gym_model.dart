class GymModel {
  final String gymId;
  final String name;
  final String? ownerName;
  final String phone;
  final String? address;
  final String? logoPath;
  final String? email;
  final String? whatsapp;
  final String? openingTime;
  final String? closingTime;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? passwordHash;

  const GymModel({
    required this.gymId,
    required this.name,
    this.ownerName,
    required this.phone,
    this.address,
    this.logoPath,
    this.email,
    this.whatsapp,
    this.openingTime,
    this.closingTime,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    this.passwordHash,
  });

  factory GymModel.fromJson(Map<String, dynamic> json) {
    return GymModel(
      gymId: json['gym_id'] as String,
      name: json['name'] as String,
      ownerName: json['owner_name'] as String?,
      phone: json['phone'] as String,
      address: json['address'] as String?,
      logoPath: json['logo_path'] as String?,
      email: json['email'] as String?,
      whatsapp: json['whatsapp'] as String?,
      openingTime: json['opening_time'] as String?,
      closingTime: json['closing_time'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      passwordHash: json['password_hash'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gym_id': gymId,
      'name': name,
      'owner_name': ownerName,
      'phone': phone,
      'address': address,
      'logo_path': logoPath,
      'email': email,
      'whatsapp': whatsapp,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'password_hash': passwordHash,
    };
  }

  GymModel copyWith({
    String? gymId,
    String? name,
    String? ownerName,
    String? phone,
    String? address,
    String? logoPath,
    String? email,
    String? whatsapp,
    String? openingTime,
    String? closingTime,
    String? status,
    String? createdAt,
    String? updatedAt,
    String? passwordHash,
  }) {
    return GymModel(
      gymId: gymId ?? this.gymId,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      logoPath: logoPath ?? this.logoPath,
      email: email ?? this.email,
      whatsapp: whatsapp ?? this.whatsapp,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }
}

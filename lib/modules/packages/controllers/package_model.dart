class PackageModel {
  final String packageId;
  final String gymId;
  final String name;
  final int durationDays;
  final int price;
  final int monthlyFee;
  final String? description;
  final String createdAt;

  const PackageModel({
    required this.packageId,
    required this.gymId,
    required this.name,
    required this.durationDays,
    required this.price,
    this.monthlyFee = 0,
    this.description,
    required this.createdAt,
  });

  factory PackageModel.fromJson(Map<String, dynamic> json) {
    return PackageModel(
      packageId: json['package_id'] as String,
      gymId: json['gym_id'] as String,
      name: json['name'] as String,
      durationDays: json['duration_days'] as int,
      price: json['price'] as int,
      monthlyFee: json['monthly_fee'] as int? ?? 0,
      description: json['description'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  factory PackageModel.fromMap(Map<String, dynamic> map) {
    return PackageModel.fromJson(map);
  }

  Map<String, dynamic> toJson() {
    return {
      'package_id': packageId,
      'gym_id': gymId,
      'name': name,
      'duration_days': durationDays,
      'price': price,
      'monthly_fee': monthlyFee,
      'description': description,
      'created_at': createdAt,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  PackageModel copyWith({
    String? packageId,
    String? gymId,
    String? name,
    int? durationDays,
    int? price,
    int? monthlyFee,
    String? description,
    String? createdAt,
  }) {
    return PackageModel(
      packageId: packageId ?? this.packageId,
      gymId: gymId ?? this.gymId,
      name: name ?? this.name,
      durationDays: durationDays ?? this.durationDays,
      price: price ?? this.price,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

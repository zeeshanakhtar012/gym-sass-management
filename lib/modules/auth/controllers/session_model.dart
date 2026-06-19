class SessionModel {
  final String? userId;
  final String? gymId;
  final String role;
  final String username;
  final bool mustChangePassword;

  const SessionModel({
    this.userId,
    this.gymId,
    required this.role,
    required this.username,
    this.mustChangePassword = false,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      userId: json['user_id'] as String?,
      gymId: json['gym_id'] as String?,
      role: json['role'] as String,
      username: json['username'] as String,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'gym_id': gymId,
      'role': role,
      'username': username,
      'must_change_password': mustChangePassword,
    };
  }

  SessionModel copyWith({
    String? userId,
    String? gymId,
    String? role,
    String? username,
    bool? mustChangePassword,
  }) {
    return SessionModel(
      userId: userId ?? this.userId,
      gymId: gymId ?? this.gymId,
      role: role ?? this.role,
      username: username ?? this.username,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }
}

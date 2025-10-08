class Profile {
  final String id;
  final String? userId;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final String? phone;
  final String? bio;
  final DateTime? dateOfBirth;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Profile({
    required this.id,
    this.userId,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.phone,
    this.bio,
    this.dateOfBirth,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert from JSON (từ Supabase)
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // Convert to JSON (để gửi lên Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'phone': phone,
      'bio': bio,
      'date_of_birth': dateOfBirth?.toIso8601String(),
    };
  }

  // Copy with (để update một số field)
  Profile copyWith({
    String? id,
    String? userId,
    String? email,
    String? fullName,
    String? avatarUrl,
    String? phone,
    String? bio,
    DateTime? dateOfBirth,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Profile(id: $id, userId: $userId, email: $email, fullName: $fullName)';
  }
}
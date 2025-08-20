import 'user_role.dart';

class AppUser {
  String? id; // Changed from int to String for Firestore compatibility
  final String username;
  final String email;
  final String
  passwordHash; // Renamed from password to passwordHash for clarity
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;

  AppUser({
    this.id,
    required this.username,
    required this.email,
    required this.passwordHash, // Now expects hashed password
    required this.role,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password_hash': passwordHash, // Store as password_hash in database
      'role': role.name,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id']?.toString(),
      username: map['username'],
      email: map['email'],
      passwordHash:
          map['password_hash'] ??
          map['password'], // Support both old and new field names
      role: UserRole.fromString(map['role']),
      createdAt: DateTime.parse(map['created_at']),
      isActive: map['is_active'] == true || map['is_active'] == 1,
    );
  }

  AppUser copyWith({
    String? id,
    String? username,
    String? email,
    String? passwordHash,
    UserRole? role,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

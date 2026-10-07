class AppUser {
  AppUser({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.passwordSalt,
    required this.role,
    this.fullName,
    this.active = true,
    required this.createdAt,
  });

  final int? id;
  final String username;
  final String passwordHash;
  final String passwordSalt;
  final String role;
  final String? fullName;
  final bool active;
  final DateTime createdAt;

  bool get isAdmin => role.toLowerCase() == 'admin';

  String get roleLabel => isAdmin ? 'Administrateur' : 'Caissier';

  AppUser copyWith({
    int? id,
    String? username,
    String? passwordHash,
    String? passwordSalt,
    String? role,
    String? fullName,
    bool? active,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'username': username,
        'password_hash': passwordHash,
        'password_salt': passwordSalt,
        'role': role,
        'full_name': fullName,
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
        id: map['id'] as int?,
        username: map['username'] as String,
        passwordHash: map['password_hash'] as String,
        passwordSalt: map['password_salt'] as String,
        role: map['role'] as String,
        fullName: map['full_name'] as String?,
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

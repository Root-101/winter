class User {
  final int id;
  final String name;
  final String email;

  ///Never the plain password, see [PasswordHasher]
  final String passwordHash;
  final Set<String> roles;
  final Set<String> permissions;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    this.roles = const {},
    this.permissions = const {},
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'roles': roles.toList(),
    'permissions': permissions.toList(),
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    passwordHash: json['passwordHash'] as String? ?? '',
    roles: Set.from(json['roles'] as List? ?? []),
    permissions: Set.from(json['permissions'] as List? ?? []),
  );
}

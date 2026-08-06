import 'package:winter/winter.dart';

class User implements Serializable {
  final int id;
  final String name;
  final String email;
  final String password;
  final Set<String> roles;
  final Set<String> permissions;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.roles = const {},
    this.permissions = const {},
  });

  @override
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
    password: json['password'] as String? ?? '',
    roles: Set.from(json['roles'] ?? []),
    permissions: Set.from(json['permissions'] ?? []),
  );
}

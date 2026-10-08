import 'package:winter/winter.dart';

class User {
  final int id;
  final String name;
  final String? nickname;

  User({required this.id, required this.name, this.nickname});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nickname': nickname,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json.field<int>('id'),
    name: json.field<String>('name'),
    nickname: json.field<String?>('nickname'),
  );
}

/// The body of a PATCH: only the fields that came change. `PatchValue` tells a missing field
/// (keep it) from one sent as `null` (clear it).
class UserUpdate {
  final PatchValue<String> name;
  final PatchValue<String?> nickname;

  UserUpdate({required this.name, required this.nickname});

  factory UserUpdate.fromJson(Map<String, dynamic> json) => UserUpdate(
    name: json.patch<String>('name'), // absent or a String (never null)
    nickname: json.patch<String?>('nickname'), // absent, null or a String
  );

  /// [user] after this update
  User applyTo(User user) => User(
    id: user.id,
    name: name.orElse(user.name),
    nickname: nickname.orElse(user.nickname),
  );
}

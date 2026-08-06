import 'package:auth_security_example/auth_security_example.dart';

class UserService {
  final List<User> _users = [
    User(
      id: 1,
      name: 'Admin User',
      email: 'admin@example.com',
      password: 'adminpassword',
      roles: {'admin'},
      permissions: {'user.list', 'user.delete'},
    ),
    User(
      id: 2,
      name: 'Regular User',
      email: 'user@example.com',
      password: 'userpassword',
      roles: {'user'},
      permissions: {},
    ),
  ];

  List<User> getAll() => List.unmodifiable(_users);

  User? getByEmail(String email) {
    return _users.cast<User?>().firstWhere(
      (u) => u?.email == email,
      orElse: () => null,
    );
  }

  User getById(int id) {
    return _users.firstWhere(
      (u) => u.id == id,
      orElse: () =>
          throw NotFoundException(body: {'error': 'User $id not found'}),
    );
  }

  User create(String name, String email, String password) {
    final newUser = User(
      id: _users.length + 1,
      name: name,
      email: email,
      password: password,
      roles: {'user'},
    );
    _users.add(newUser);
    return newUser;
  }

  User delete(int id) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index == -1) {
      throw NotFoundException(body: {'error': 'User $id not found'});
    }
    return _users.removeAt(index);
  }
}

import 'package:auth_security_example/auth_security_example.dart';

class UserService {
  final PasswordHasher passwordHasher;

  late final List<User> _users = [
    User(
      id: 1,
      name: 'Admin User',
      email: 'admin@example.com',
      passwordHash: passwordHasher.hash('adminpassword'),
      roles: {'admin'},
      permissions: {'user.list', 'user.delete'},
    ),
    User(
      id: 2,
      name: 'Regular User',
      email: 'user@example.com',
      passwordHash: passwordHasher.hash('userpassword'),
      roles: {'user'},
      permissions: {},
    ),
  ];

  ///Ids are never reused, even after a user is deleted
  int _lastId = 2;

  UserService(this.passwordHasher);

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
      id: ++_lastId,
      name: name,
      email: email,
      passwordHash: passwordHasher.hash(password),
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

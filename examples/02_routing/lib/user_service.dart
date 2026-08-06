import 'package:winter/winter.dart';
import 'user_model.dart';

class UserService {
  final List<User> _users = [
    User(id: 1, name: 'Alice'),
    User(id: 2, name: 'Bob'),
  ];

  List<User> getAll() => List.unmodifiable(_users);

  User getById(int id) {
    return _users.firstWhere(
      (u) => u.id == id,
      orElse: () => throw NotFoundException(body: {'error': 'User $id not found'}),
    );
  }

  User create(User user) {
    _users.add(user);
    return user;
  }

  User update(int id, User userUpdates) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index == -1) {
      throw NotFoundException(body: {'error': 'User $id not found'});
    }
    _users[index] = userUpdates;
    return userUpdates;
  }

  User delete(int id) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index == -1) {
      throw NotFoundException(body: {'error': 'User $id not found'});
    }
    return _users.removeAt(index);
  }

  void reset() {
    _users.clear();
    _users.addAll([
      User(id: 1, name: 'Alice'),
      User(id: 2, name: 'Bob'),
    ]);
  }
}

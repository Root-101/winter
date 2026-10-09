/// A CRUD over a service registered in `di`: 201 with `Location`, 404 for a missing id, and a
/// PATCH that changes only the fields sent.
///
/// Run: `dart run lib/crud.dart`, then
/// `curl -X POST localhost:8080/users -H 'Content-Type: application/json' -d '{"name": "Carol"}'`
library;

import 'package:winter/winter.dart';

class User {
  final int id;
  final String name;
  final String? nickname;

  User(this.id, this.name, [this.nickname]);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'nickname': nickname,
  };
}

/// The body of a POST: the new user, without its id
class NewUser {
  final String name;

  NewUser(this.name);

  factory NewUser.fromJson(Map<String, dynamic> json) =>
      NewUser(json.field<String>('name'));
}

/// The body of a PATCH: absent keeps a field, null clears the nickname
class UserChanges {
  final PatchValue<String> name;
  final PatchValue<String?> nickname;

  UserChanges(this.name, this.nickname);

  factory UserChanges.fromJson(Map<String, dynamic> json) =>
      UserChanges(json.patch<String>('name'), json.patch<String?>('nickname'));
}

class UserService {
  final Map<int, User> _users = {1: User(1, 'Alice', 'ali'), 2: User(2, 'Bob')};
  int _nextId = 3;

  List<User> all() => _users.values.toList();

  User find(int id) =>
      _users[id] ?? (throw NotFoundException(detail: 'User $id not found'));

  User create(NewUser user) {
    final User created = User(_nextId++, user.name);
    return _users[created.id] = created;
  }

  User change(int id, UserChanges changes) {
    final User user = find(id);
    return _users[id] = User(
      id,
      changes.name.orElse(user.name),
      changes.nickname.orElse(user.nickname),
    );
  }

  void delete(int id) => _users.remove(find(id).id);
}

ObjectMapper objectMapper() => ObjectMapper(
  deserializers: [
    Deserializer<NewUser>.json(NewUser.fromJson),
    Deserializer<UserChanges>.json(UserChanges.fromJson),
  ],
);

WinterRouter router() => WinterRouter(
  routes: [
    Route.parent(
      path: '/users',
      routes: [
        Route.get(
          path: '/',
          handler: (request) =>
              ResponseEntity.ok(body: di.find<UserService>().all()),
        ),
        Route.get(
          path: '/{id|[0-9]+}',
          handler: (request) => ResponseEntity.ok(
            body: di.find<UserService>().find(request.pathParam<int>('id')),
          ),
        ),
        Route.post(
          path: '/',
          handler: (request) async {
            final User user = di.find<UserService>().create(
              await request.body<NewUser>(),
            );
            return ResponseEntity.created(
              location: '/users/${user.id}',
              body: user,
            );
          },
        ),
        Route.patch(
          path: '/{id|[0-9]+}',
          handler: (request) async => ResponseEntity.ok(
            body: di.find<UserService>().change(
              request.pathParam<int>('id'),
              await request.body<UserChanges>(),
            ),
          ),
        ),
        Route.delete(
          path: '/{id|[0-9]+}',
          handler: (request) {
            di.find<UserService>().delete(request.pathParam<int>('id'));
            return ResponseEntity.noContent();
          },
        ),
      ],
    ),
  ],
);

Future<void> main() async {
  di.put(UserService());
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}

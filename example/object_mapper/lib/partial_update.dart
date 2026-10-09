/// A PATCH that tells "absent" from `null`: `{}` changes nothing, `{"nickname": null}` clears the
/// nickname. `json.patch<T>` reads a `PatchValue`.
///
/// Run: `dart run lib/partial_update.dart`, then
/// `curl -X PATCH localhost:8080/me -H 'Content-Type: application/json' -d '{"nickname": null}'`
library;

import 'package:winter/winter.dart';

class User {
  final String name;
  final String? nickname;
  final int age;

  const User(this.name, this.nickname, this.age);

  Map<String, Object?> toJson() => {
    'name': name,
    'nickname': nickname,
    'age': age,
  };
}

class UserChanges {
  final PatchValue<String> name; // absent or a String (null is a 400)
  final PatchValue<String?> nickname; // absent, null or a String
  final PatchValue<int> age;

  UserChanges(this.name, this.nickname, this.age);

  factory UserChanges.fromJson(Map<String, dynamic> json) => UserChanges(
    json.patch<String>('name'),
    json.patch<String?>('nickname'),
    json.patch<int>('age'),
  );

  /// The user with the fields sent changed
  User applyTo(User user) => User(
    name.orElse(user.name),
    nickname.orElse(user.nickname),
    age.orElse(user.age),
  );
}

ObjectMapper objectMapper() => ObjectMapper(
  deserializers: [Deserializer<UserChanges>.json(UserChanges.fromJson)],
);

WinterRouter router() {
  User me = const User('Ann', 'annie', 30);
  return WinterRouter(
    routes: [
      Route.get(
        path: '/me',
        handler: (request) => ResponseEntity.ok(body: me),
      ),
      Route.patch(
        path: '/me',
        handler: (request) async {
          me = (await request.body<UserChanges>()).applyTo(me);
          return ResponseEntity.ok(body: me);
        },
      ),
    ],
  );
}

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}

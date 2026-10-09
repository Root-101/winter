/// The rules of one object: `body<T>()` validates it, and an invalid one is a 422 with every
/// violation (never the values sent).
///
/// Run: `dart run lib/basic_rules.dart`, then
/// `curl localhost:8080/users -H 'Content-Type: application/json' -d '{"email": "x", "age": 16}'`
library;

import 'package:winter/winter.dart';

class CreateUser implements Validatable {
  final String? name;
  final String? email;
  final String? password;
  final int? age;
  final String? website;

  CreateUser({this.name, this.email, this.password, this.age, this.website});

  factory CreateUser.fromJson(Map<String, dynamic> json) => CreateUser(
    name: json.field<String?>('name'),
    email: json.field<String?>('email'),
    password: json.field<String?>('password'),
    age: json.field<int?>('age'),
    website: json.field<String?>('website'),
  );

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('name', name).notNull().notBlank().size(max: 50)
    ..field('email', email).notNull().email()
    // sensitive: the value is never stored in the violation (nor in a log)
    ..field('password', password, sensitive: true).notNull().size(min: 8)
    // Every rule but notNull passes on null: age and website are optional
    ..field('age', age).min(18).max(120)
    ..field('website', website).url();
}

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/users',
      handler: (request) async {
        // Validated here: a 422 if invalid, the handler never sees it
        final CreateUser user = await request.body<CreateUser>();
        return ResponseEntity.created(
          location: '/users/1',
          body: {'name': user.name, 'email': user.email},
        );
      },
    ),
  ],
);

Future<void> main() async {
  om.addDeserializer(Deserializer<CreateUser>.json(CreateUser.fromJson));
  await Winter.start(router: router());
}

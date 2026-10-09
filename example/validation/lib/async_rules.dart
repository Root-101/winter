/// Rules that need an `await` ("the email is already registered"): `AsyncValidatable`. They run
/// only when the synchronous ones passed, so a malformed email never reaches the database.
///
/// Run: `dart run lib/async_rules.dart`, then register `ann@example.com` twice
library;

import 'package:winter/winter.dart';

/// A stand-in for a database
class UserRepository {
  final Set<String> _emails = {'taken@example.com'};

  /// How many times the database was asked (the test checks it)
  int lookups = 0;

  Future<bool> emailExists(String email) async {
    lookups++;
    return _emails.contains(email.toLowerCase());
  }

  Future<void> add(String email) async => _emails.add(email.toLowerCase());
}

class Register implements Validatable, AsyncValidatable {
  final String email;
  final String password;

  Register(this.email, this.password);

  factory Register.fromJson(Map<String, dynamic> json) =>
      Register(json.field<String>('email'), json.field<String>('password'));

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('email', email).email()
    ..field('password', password, sensitive: true).size(min: 8);

  @override
  Future<ConstraintValidatorContext> validateAsync() async {
    final cvc = ConstraintValidatorContext();
    await cvc.check(
      'email',
      () async => !await di.find<UserRepository>().emailExists(email),
      message: () => 'The email is already registered',
      code: 'email.taken',
    );
    return cvc;
  }
}

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/register',
      handler: (request) async {
        // validate(), then validateAsync(): a 422 from either
        final Register body = await request.body<Register>();
        // Two requests can race: the service has the last word (a 409)
        final UserRepository users = di.find<UserRepository>();
        if (await users.emailExists(body.email)) {
          throw const ConflictException();
        }
        await users.add(body.email);
        return ResponseEntity.created(location: '/users/me');
      },
    ),
  ],
);

Future<void> main() async {
  di.put(UserRepository());
  om.addDeserializer(Deserializer<Register>.json(Register.fromJson));
  await Winter.start(router: router());
}

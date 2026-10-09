/// Brute force on a login, stopped twice:
///
/// - Per IP, on the login route only: `RateLimiterFilter` (20 attempts a minute).
/// - Per account, whatever the IP (a botnet tries one password from many IPs): a `RateLimiter`
///   used by the handler, 5 failures in 15 minutes, forgotten after a correct login.
///
/// Run: `dart run lib/login_throttling.dart`, then six times
/// `curl -i -X POST localhost:8080/login -H 'Content-Type: application/json' -d '{"email": "ann@example.com", "password": "x"}'`
library;

import 'package:winter/winter.dart';

class Login {
  final String email;
  final String password;

  const Login(this.email, this.password);

  factory Login.fromJson(Map<String, dynamic> json) => Login(
    json.field<String>('email').toLowerCase(),
    json.field<String>('password'),
  );
}

final ObjectMapper objectMapper = ObjectMapper(
  deserializers: [Deserializer<Login>.json(Login.fromJson)],
);

WinterRouter router({
  required RateLimiter perIp,
  required RateLimiter perAccount,
  required bool Function(Login login) checkPassword,
}) => WinterRouter(
  routes: [
    Route.post(
      path: '/login',
      filterConfig: FilterConfig([
        RateLimiterFilter.fromRateLimiter(rateLimiter: perIp),
      ]),
      handler: (request) async {
        final Login login = await request.body<Login>();

        // peek: is the account blocked? (it doesn't count as an attempt)
        final RateLimitResult state = await perAccount.peek(login.email);
        if (!state.allowed) {
          throw TooManyRequestsException(
            retryAfter: state.retryAfter.inSeconds + 1,
            detail: 'Too many failed logins, try again later',
          );
        }

        if (!checkPassword(login)) {
          await perAccount.check(login.email); // a failure counts
          // The same answer for a wrong email and a wrong password
          throw const UnauthorizedException(detail: 'Wrong email or password');
        }

        await perAccount.reset(login.email);
        return ResponseEntity.ok(body: {'token': 'a-token-for-${login.email}'});
      },
    ),
  ],
);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper);
  await Winter.start(
    router: router(
      perIp: RateLimiter(20, const Duration(minutes: 1)),
      perAccount: RateLimiter(5, const Duration(minutes: 15)),
      checkPassword: (login) => login.password == 'correct horse',
    ),
  );
}

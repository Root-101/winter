import 'package:security_examples/login_throttling.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  // A fake clock: the windows pass without waiting
  late DateTime now;
  late WinterTestClient client;

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper));

  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    client = WinterTestClient.build(
      router: router(
        perIp: RateLimiter(20, const Duration(minutes: 1), clock: () => now),
        perAccount: RateLimiter(
          3,
          const Duration(minutes: 15),
          clock: () => now,
        ),
        checkPassword: (login) => login.password == 'right',
      ),
    );
  });

  Future<TestResponse> login(String email, String password) =>
      client.post('/login', body: {'email': email, 'password': password});

  test(
    'a wrong password is a 401 that does not say which part failed',
    () async {
      final response = await login('ann@example.com', 'wrong');

      expect(response.statusCode, 401);
      expect((response.json as Map)['detail'], 'Wrong email or password');
    },
  );

  test(
    'after 3 failures the account is blocked, even with the right password',
    () async {
      for (int i = 0; i < 3; i++) {
        await login('ann@example.com', 'wrong');
      }

      final blocked = await login('ANN@example.com', 'right');
      expect(blocked.statusCode, 429);
      expect(blocked.headers['retry-after'], isNotNull);

      // Another account is not affected
      expect((await login('bob@example.com', 'right')).statusCode, 200);

      // After the window, the account can log in again
      now = now.add(const Duration(minutes: 16));
      expect((await login('ann@example.com', 'right')).statusCode, 200);
    },
  );

  test('a correct login forgets the failures', () async {
    await login('ann@example.com', 'wrong');
    await login('ann@example.com', 'wrong');
    await login('ann@example.com', 'right');

    await login('ann@example.com', 'wrong');
    await login('ann@example.com', 'wrong');
    expect((await login('ann@example.com', 'right')).statusCode, 200);
  });

  test('the limit per IP covers every account', () async {
    for (int i = 0; i < 20; i++) {
      await login('user$i@example.com', 'wrong');
    }

    final response = await login('new@example.com', 'right');
    expect(response.statusCode, 429);
    expect(response.headers['x-ratelimit-limit'], '20');
  });
}

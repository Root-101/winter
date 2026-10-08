# Testing

Winter is tested in memory: `WinterTestClient` sends requests to the same pipeline as the real
server (filters, routing, exception handler, CORS, security headers...) without opening a port.

- Tests are fast and run in parallel: there are no ports to collide.
- A service that reads the request (`requestPrincipal`, `requestLocale`) is tested with
  `RequestScope.run`, without a server.
- Time is injected (`clock:`), so nothing waits on the real clock.

## Minimal example

```dart
import 'package:test/test.dart';
import 'package:winter/winter.dart';

WinterRouter router() => WinterRouter(
  routes: [
    Route.get(
      path: '/users/{id}',
      handler: (request) => ResponseEntity.ok(body: {'id': request.pathParam<int>('id')}),
    ),
  ],
);

void main() {
  final client = WinterTestClient.build(router: router());

  test('a user by id', () async {
    final response = await client.get('/users/7');

    expect(response.statusCode, 200);
    expect(response.json, {'id': 7});
  });

  test('an id that is not a number is a 400', () async {
    expect((await client.get('/users/abc')).statusCode, 400);
  });
}
```

## How it works

### `WinterTestClient`

`WinterTestClient.build` takes the same parameters as the server: `router`, `globalFilterConfig`,
`securityConfig` and `maxBodySize`.

| Method                                     | Sends                                       |
|--------------------------------------------|---------------------------------------------|
| `get`, `head`, `delete(path, headers:)`    | A request without body                      |
| `post`, `put`, `patch(path, headers:, body:)` | A request with a body                    |
| `request(method, path, headers:, body:, connectionInfo:)` | Any method (`OPTIONS`...)    |

- A `body` that is a `String` or bytes is sent as it is; anything else is JSON (with the object
  mapper, and `Content-Type: application/json`).
- `headers` take a `String` or a `List<String>` per name.
- `connectionInfo` gives the request a client IP (for `clientIp()` and the rate limiter).

`TestResponse` has `statusCode`, `headers` (case insensitive), `headersAll` (every value: several
`Set-Cookie`), `bodyBytes` (the body as it was sent: an image, a file; empty for a `HEAD`), `body`
(the text, decoded with the charset of the response when it's read) and `json` (the body decoded).

The responses are indented by default (`ObjectMapper.prettyPrint`): compare `response.json`, never
the text.

### The context of the tests

`Winter.context` (the object mapper, DI, env, logger, languages) is global, per isolate. Every test
file runs in its own isolate, so a file can change it in `setUp` without touching the others; put
it back in `tearDown` if the next tests of the file need the default:

```dart
setUp(() {
  Winter.context.setUp(
    objectMapper: ObjectMapper(fieldNaming: FieldNaming.snakeCase),
    dependencyInjection: DependencyInjection()..put<UserRepository>(FakeUserRepository()),
  );
});

tearDown(() => Winter.context.setUp(objectMapper: ObjectMapper()));
```

A new `DependencyInjection` per test gives every test its own fakes; `di.child()` does the same
on top of the registrations of the app, which it never changes (see
[dependency injection](dependency-injection.md#replacing-a-dependency-in-a-test)).

### A service without a server

Code that reads the request in progress (`requestPrincipal`, `requestAuthentication`,
`requestLocale`, `requestId`) needs a `RequestScope`:

```dart
final context = RequestSecurityContext<User>.empty()
  ..setAuthentication(Authentication<User>(principal: const User('ann')));

await RequestScope.run(
  RequestScope(securityContext: context, locale: WinterLocale.spanish),
  () async {
    expect(await OrderService().myOrders(), hasLength(2));
  },
);
```

### A filter alone

A `FilterChain` built in the test, without an exception handler, rethrows what the filter throws:

```dart
final chain = FilterChain([MaintenanceFilter(() => true)], (request) => ResponseEntity.ok());

expect(
  () => chain.doFilter(RequestEntity('GET', Uri.parse('http://localhost/'))),
  throwsA(isA<ServiceUnavailableException>()),
);
```

With `exceptionHandler: SimpleExceptionHandler()` it answers like the server.

### Time

Code that depends on the time takes a clock, so a test moves it instead of waiting:

```dart
var now = DateTime.utc(2026);
final limiter = RateLimiter(1, const Duration(minutes: 1), clock: () => now);

await limiter.check('ann');
expect((await limiter.check('ann')).allowed, isFalse);

now = now.add(const Duration(minutes: 1, seconds: 1));
expect((await limiter.check('ann')).allowed, isTrue);
```

The date validators (`past()`, `future()`...) take `ConstraintValidatorContext(clock: ...)`, and the
nested objects use the same clock.

### Logs

A logger of the test records what was logged:

```dart
class MemoryLogger extends WinterLogger {
  final List<String> lines = [];

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => lines.add('${level.name}: $message');
}

Winter.context.setUp(logger: MemoryLogger());
```

### When a real server is worth it

Only to test the server itself: the graceful shutdown, a HTTPS certificate, the headers that
`dart:io` writes, a client that disconnects. Start it on a port of its own (test files run in
parallel) and always close it:

```dart
setUpAll(() => Winter.start(
  config: const ServerConfig(port: 9200, handleSignals: false),
  router: router(),
));

tearDownAll(() => Winter.close(force: true));
```

## Typical mistakes and limitations

- **Comparing the JSON as text**: it's indented; use `response.json`.
- **Starting a real server for a route test**: use `WinterTestClient`, it's the same pipeline.
- **A context changed by a test and not restored**: the next tests of the same file see it.
- **Waiting with `Future.delayed` for a time window**: inject a clock.
- **Two test files on the same port**: they run in parallel; give each one its own.

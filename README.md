# Winter ❄️

A backend framework for Dart, inspired by Spring: routing, filters, dependency injection, JSON
mapping, validation, security and consistent errors, on top of `dart:io` and without code
generation.

```dart
import 'package:winter/winter.dart';

void main() async {
  await Winter.start(
    router: WinterRouter(
      routes: [
        Route.get(path: '/hello', handler: (request) => ResponseEntity.ok(body: 'Hello Winter!')),
        Route.get(
          path: '/users/{id}',
          handler: (request) => ResponseEntity.ok(body: {'id': request.pathParam<int>('id')}),
        ),
      ],
    ),
  );
}
```

## Installation

Requires the Dart SDK 3.13 or newer.

```bash
dart pub add winter
```

Then follow [getting started](doc/getting-started.md): from zero to a JSON API with validation and
tests.

## Features

| Feature                                | What you get                                                        | Guide |
|----------------------------------------|---------------------------------------------------------------------|-------|
| Routing                                | Nested routes, typed path and query params, regex, 404/405, `HEAD` and `OPTIONS` | [routing](doc/routing.md) |
| Filters                                | Global and route filters, ordered, that see every error             | [filters](doc/filters.md) |
| Requests and responses                 | Headers, cookies, a body read as an object, streams (Server-Sent Events) | [requests and responses](doc/requests-and-responses.md) |
| JSON                                   | `toJson()` without interfaces, your own serializers, generics, `snake_case`, clear errors | [object mapper](doc/object-mapper.md) |
| Validation                             | Typed validators, nested objects, a 422 with a code per field       | [validation](doc/validation.md) |
| Errors                                 | Every error is a Problem Details (RFC 9457); a 500 never leaks details | [error handling](doc/error-handling.md) |
| Security                               | Authentication filters, roles and permissions, CORS, security headers, a rate limiter | [security](doc/security.md) |
| Dependency injection                   | Singletons, lazy, factories, one instance per request, disposal on shutdown | [dependency injection](doc/dependency-injection.md) |
| Configuration                          | Typed environment variables, `.env` files and profiles              | [configuration](doc/configuration.md) |
| Logging                                | Console and JSON loggers, a request id in every log                 | [logging](doc/logging.md) |
| i18n                                   | Messages in the language of the request                             | [i18n](doc/i18n.md) |
| WebSockets                             | Routes that go through the filters before the upgrade, closed on shutdown | [routing](doc/routing.md#websockets) |
| OpenAPI                                | The document of the routes and Swagger UI, schemas from an example and its `validate()` | [openapi](doc/openapi.md) |
| Scheduled tasks                        | Intervals and cron expressions, started and stopped with the server | [scheduling](doc/scheduling.md) |
| Testing                                | The whole pipeline in memory, without ports                         | [testing](doc/testing.md) |
| Deployment                             | Native executables, Docker, graceful shutdown, health checks        | [deployment](doc/deployment.md) |

How it fits together: [architecture](doc/architecture.md). Every guide: [`doc/`](doc/README.md).

## A taste

```dart
class CreateUser implements Validatable {
  final String email;

  CreateUser(this.email);

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.field('email', email).email();
    return cvc;
  }
}

Route.post(
  path: '/users',
  filterConfig: hasRole('admin').toFilterConfig(),            // 401 / 403
  handler: (request) async {
    final CreateUser user = await request.body<CreateUser>(); // JSON → object, validated (422)
    final created = di.find<UserService>().create(user);       // throws NotFoundException...
    return ResponseEntity.created(location: '/users/${created.id}', body: created);
  },
)
```

```dart
test('an invalid email is a 422', () async {
  final client = WinterTestClient.build(router: router);

  final response = await client.post('/users', body: {'email': 'nope'});

  expect(response.statusCode, 422);
});
```

## Examples

[`example/`](example) has many small examples by topic, one file per case (routing, request bodies,
validation, object mapper, OpenAPI, real time, i18n), and complete apps: authentication with JWT,
an orders API, a photo gallery with uploads and a chat, and a production setup with Docker.

## More

- [`DECISIONS.md`](DECISIONS.md): why Winter works the way it does.
- [`CHANGELOG.md`](CHANGELOG.md) and [`ROADMAP.md`](ROADMAP.md).
- [`CONTRIBUTING.md`](CONTRIBUTING.md): how to work on Winter.
- [Benchmarks](doc/benchmarks.md): Winter serves ~85 % of the requests per second of raw
  `dart:io`, and the object mapper costs about a tenth more than JSON written by hand.

## License

[Apache 2.0](LICENSE).

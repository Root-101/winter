# Winter ❄️

### A backend framework for the Dart enthusiasts

Winter is a backend framework for Dart, inspired by **Spring**, **ASP.NET Core** and **NestJS**.
It gives you routing, filters, dependency injection, JSON mapping, validation, security and
consistent errors, on top of `dart:io` and without code generation.

> ⚠️ **Winter is an experimental project**, built in our spare time. `1.0.0-rc.1` is a release
> candidate: the API is the one we intend to keep in 1.0, but it may still change before it, and
> the framework has not yet been used by a real application in production. Try it, build with it,
> and [tell us](https://github.com/Root-101/winter/issues) what breaks; use it in production at
> your own discretion.

**What Winter is:**

- A framework for **REST APIs**: routes, filters, JSON in and out, validation, errors, security,
  configuration, logs, scheduled tasks, OpenAPI, WebSockets and Server-Sent Events.
- **Small and explicit**: no reflection, no annotations, no code generation; what you register is
  what runs.
- **Tested and documented**: about 1150 tests (99.7 % of the lines), a guide per module and an
  example for every feature.

**What Winter is not (yet):**

- **Proven in production**: no app runs on it at scale yet, so expect rough edges.
- **A full-stack framework**: no database access (bring your own driver), templates, sessions, CSRF
  protection nor OAuth flows.
- **A distributed system**: the rate limiter and the scheduled tasks live in one process; several
  instances need a shared store of their own.

Now that it's clear what Winter is, let's set it up.

## Getting started

### Install it

You need the Dart SDK 3.13 or newer ([get Dart](https://dart.dev/get-dart)) and a Dart project
(`dart create my_api`). Then add Winter:

```bash
dart pub add winter:^1.0.0-rc.1
```

The version is needed while 1.0.0 is a release candidate: `dart pub add winter` alone only picks
stable versions. That's all the setup there is: no generator to run, no configuration file.

### Your first server

With Winter installed, the smallest server is one route:

```dart
import 'package:winter/winter.dart';

void main() async {
  await Winter.start(
    router: WinterRouter(
      routes: [
        Route.get(path: '/hello', handler: (request) => ResponseEntity.ok(body: 'Hello Winter!')),
      ],
    ),
  );
}
```

Run it with `dart run`, and the server answers on port 8080 (the default):

```bash
curl localhost:8080/hello    # Hello Winter!
```

That's as simple as it gets, but Winter does a lot more.

## Features

| Feature                | What you get                                                                                                  | Guide                                                                                         |
|------------------------|---------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| Routing                | Nested routes, typed path and query params, regex, 404/405, `HEAD` and `OPTIONS`, static files, health checks | [routing](doc/routing.md)                                                                     |
| Filters                | Global and route filters, ordered, that see every error                                                       | [filters](doc/filters.md)                                                                     |
| Requests and responses | Headers, cookies, every kind of body (JSON, forms, uploads, binary), streams                                  | [requests and responses](doc/requests-and-responses.md)                                       |
| JSON                   | `toJson()` without interfaces, your own serializers, generics, `snake_case`, clear errors                     | [object mapper](doc/object-mapper.md)                                                         |
| Validation             | Typed validators, nested objects, async rules, a 422 with a code per field                                    | [validation](doc/validation.md)                                                               |
| Errors                 | Every error is a Problem Details (RFC 9457); a 500 never leaks details                                        | [error handling](doc/error-handling.md)                                                       |
| Security               | Authentication filters, roles and permissions, CORS, security headers, a rate limiter                         | [security](doc/security.md)                                                                   |
| Dependency injection   | Singletons, lazy, factories, one instance per request, async startup, disposal on shutdown                    | [dependency injection](doc/dependency-injection.md)                                           |
| Configuration          | Typed environment variables, `.env` files and profiles                                                        | [configuration](doc/configuration.md)                                                         |
| Logging                | Console and JSON loggers, a request id in every log                                                           | [logging](doc/logging.md)                                                                     |
| i18n                   | Messages in the language of the request                                                                       | [i18n](doc/i18n.md)                                                                           |
| Real time              | WebSockets that go through the filters first, and Server-Sent Events                                          | [routing](doc/routing.md#websockets), [SSE](doc/requests-and-responses.md#server-sent-events) |
| OpenAPI                | The document of the routes and Swagger UI, schemas from an example and its `validate()`                       | [openapi](doc/openapi.md)                                                                     |
| Scheduled tasks        | Intervals and cron expressions, started and stopped with the server                                           | [scheduling](doc/scheduling.md)                                                               |
| Testing                | The whole pipeline in memory, without ports                                                                   | [testing](doc/testing.md)                                                                     |
| Deployment             | Native executables, Docker, graceful shutdown, health checks                                                  | [deployment](doc/deployment.md)                                                               |

How it fits together: [architecture](doc/architecture.md). Every guide: [`doc/`](doc/README.md).

## A real API

Now something closer to what an API does every day: a JSON body turned into an object and
validated, a service from dependency injection, a filter that every request goes through, and
errors that the client can read.

```dart
import 'package:winter/winter.dart';

/// The body of `POST /tasks`: read from JSON, then validated
class NewTask implements Validatable {
  final String title;
  final int priority;

  NewTask(this.title, this.priority);

  factory NewTask.fromJson(Map<String, dynamic> json) =>
      NewTask(json.field<String>('title'), json.field<int?>('priority') ?? 3);

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('title', title).notBlank().size(max: 100)
    ..field('priority', priority).min(1).max(5);
}

/// What the API answers: written as JSON with its toJson()
class Task {
  final int id;
  final String title;
  final int priority;

  Task(this.id, this.title, this.priority);

  Map<String, Object> toJson() => {'id': id, 'title': title, 'priority': priority};
}

class TaskService {
  final Map<int, Task> _tasks = {};

  List<Task> all() => _tasks.values.toList();

  Task find(int id) => _tasks[id] ?? (throw NotFoundException(detail: 'Task $id not found'));

  Task create(NewTask task) {
    final int id = _tasks.length + 1;
    return _tasks[id] = Task(id, task.title, task.priority);
  }
}

/// A filter: every request must say which app sends it
class ClientFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) async {
    if (request.headers['x-client'] == null) {
      throw const BadRequestException(detail: 'Send the X-Client header');
    }
    return chain.doFilter(request);
  }
}

WinterRouter router() => WinterRouter(
  basePath: '/tasks',
  routes: [
    Route.get(
      path: '/',
      handler: (request) => ResponseEntity.ok(body: di.find<TaskService>().all()),
    ),
    Route.get(
      path: '/{id|[0-9]+}',
      handler: (request) => ResponseEntity.ok(
        body: di.find<TaskService>().find(request.pathParam<int>('id')),
      ),
    ),
    Route.post(
      path: '/',
      handler: (request) async {
        final NewTask newTask = await request.body<NewTask>(); // 400 or 422 if it's wrong
        final Task task = di.find<TaskService>().create(newTask);
        return ResponseEntity.created(location: '/tasks/${task.id}', body: task);
      },
    ),
  ],
);

void main() async {
  di.put(TaskService());
  Winter.context.setUp(
    objectMapper: ObjectMapper(deserializers: [Deserializer<NewTask>.json(NewTask.fromJson)]),
  );
  await Winter.start(
    globalFilterConfig: FilterConfig([LoggingFilter(), ClientFilter()]),
    router: router(),
  );
}
```

What a client gets (every error is a Problem Details, `application/problem+json`):

| Request (with `X-Client: web`) | Response |
|--------------------------------|----------|
| `POST /tasks` `{"title": "Write the docs"}` | `201`, `Location: /tasks/1`, `{"id": 1, "title": "Write the docs", "priority": 3}` |
| `POST /tasks` `{"title": " ", "priority": 9}` | `422` with a violation per field: `title` (`notBlank`) and `priority` (`max.inclusive`) |
| `POST /tasks` `{"priority": 2}` | `400`, `"detail": "$.title: missing"` |
| `GET /tasks/7` | `404`, `"detail": "Task 7 not found"` |
| `GET /tasks` without `X-Client` | `400`, `"detail": "Send the X-Client header"` |

And it's tested in memory, with the whole pipeline and without opening a port:

```dart
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(
    globalFilterConfig: FilterConfig([ClientFilter()]),
    router: router(),
  );

  test('an invalid task is a 422', () async {
    final response = await client.post(
      '/tasks',
      headers: {'x-client': 'test'},
      body: {'title': ' '},
    );

    expect(response.statusCode, 422);
  });
}
```

From zero to this, step by step: [getting started](doc/getting-started.md).

## Examples

If you liked it, [`example/`](example) has much more: many small examples by topic, one file per
case with its test, and complete apps.

| Topic                                                                                                            | Cases                                                                                                           |
|------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| [routing](example/routing), [bodies](example/bodies)                                                             | Params, nested routes, a CRUD, static files, health checks; every kind of request body                          |
| [object_mapper](example/object_mapper), [validation](example/validation)                                         | Field naming, adapters, `PATCH`, sealed classes; nested objects, custom and async rules                         |
| [errors](example/errors), [filters](example/filters)                                                             | Exceptions of the domain, a handler of your own; tenants, maintenance mode, a response cache                    |
| [security](example/security), [di](example/di)                                                                   | API keys, Basic auth, webhook signatures, login throttling; scoped services, async startup                      |
| [api_patterns](example/api_patterns)                                                                             | Pagination, ETag and `If-Match`, content negotiation, downloads, `202` jobs, idempotency keys, versioning       |
| [openapi](example/openapi), [realtime](example/realtime), [scheduling](example/scheduling), [i18n](example/i18n) | Swagger UI, Server-Sent Events, a WebSocket chat, cron tasks, translated messages                               |
| [apps](example/apps)                                                                                             | Authentication with JWT, an orders API, a photo gallery with uploads and a chat, a production setup with Docker |

## Powered by Winter

The projects that run on Winter:

| [➕](https://github.com/Root-101/winter/pulls) |
|:---------------------------------------------:|
| [Your project?](https://github.com/Root-101/winter/pulls) |

<!--
A column per project, before the "Your project?" one: its icon in the first row, its name in the
second. The icon by an absolute URL, so it shows on pub.dev too:

| [<img src="https://url-of-the-icon.png" width="64" alt="name">](https://link-of-the-project) | [➕](https://github.com/Root-101/winter/pulls) |
|:---:|:---:|
| [name](https://link-of-the-project) | [Your project?](https://github.com/Root-101/winter/pulls) |
-->

## More

- [`DECISIONS.md`](DECISIONS.md): why Winter works the way it does.
- [Winter and other frameworks](doc/comparison.md): where its ideas come from (Spring, ASP.NET Core,
  Ktor, NestJS...) and how it compares with the Dart frameworks.
- [`CHANGELOG.md`](CHANGELOG.md) and [`ROADMAP.md`](ROADMAP.md).
- [Benchmarks](doc/benchmarks.md): Winter serves ~85 % of the requests per second of raw
  `dart:io`, and the object mapper costs about a tenth more than JSON written by hand.

## Contributing

Issues and pull requests are welcome. [`CONTRIBUTING.md`](CONTRIBUTING.md) explains how to set up
the project (FVM), run the checks and the tests, add a language, and write the commits and the
changelog.

## License

[Apache 2.0](LICENSE).

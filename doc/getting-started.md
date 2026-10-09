# Getting started

From zero to a JSON API with validation and tests.

## Requirements

- The Dart SDK 3.13 or newer (`dart --version`).
- A project: `dart create -t console todo_api` (or any Dart package).

## Installation

```bash
dart pub add winter:^1.0.0-rc.1   # a release candidate: pub only picks it when asked
dart pub add dev:test
```

## The first endpoint

`bin/server.dart`:

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

```bash
dart run bin/server.dart
curl localhost:8080/hello   # Hello Winter!
```

The server listens on `0.0.0.0:8080` (`ServerConfig` changes it) and stops gracefully with Ctrl+C.

## A JSON API

A to-do list: create, list, read and delete, with a validated body. Put the app in
`lib/todo_api.dart`, so the server and the tests share it.

```dart
import 'package:winter/winter.dart';

class Todo {
  final int id;
  final String title;
  final bool done;

  const Todo(this.id, this.title, {this.done = false});

  /// Written by the object mapper: no interface to implement
  Map<String, Object?> toJson() => {'id': id, 'title': title, 'done': done};
}

/// The body of `POST /todos`
class CreateTodo implements Validatable {
  final String title;

  const CreateTodo(this.title);

  factory CreateTodo.fromJson(Map<String, dynamic> json) => CreateTodo(json['title'] as String);

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.field('title', title).notBlank().size(max: 100);
    return cvc;
  }
}

class TodoService {
  final Map<int, Todo> _todos = {};
  int _nextId = 1;

  List<Todo> all() => _todos.values.toList();

  Todo find(int id) =>
      _todos[id] ?? (throw NotFoundException(detail: 'To-do $id not found'));

  Todo create(CreateTodo request) {
    final todo = Todo(_nextId++, request.title);
    return _todos[todo.id] = todo;
  }

  void delete(int id) => _todos.remove(find(id).id);
}

/// How to read a body of `CreateTodo`
void configure() => om.addDeserializer(Deserializer<CreateTodo>.json(CreateTodo.fromJson));

WinterRouter router(TodoService service) => WinterRouter(
  basePath: '/todos',
  routes: [
    Route.get(path: '/', handler: (request) => ResponseEntity.ok(body: service.all())),
    Route.post(
      path: '/',
      handler: (request) async {
        final todo = service.create(await request.body<CreateTodo>()); // validated: 422 if not
        return ResponseEntity.created(location: '/todos/${todo.id}', body: todo);
      },
    ),
    Route.get(
      path: '/{id}',
      handler: (request) => ResponseEntity.ok(body: service.find(request.pathParam<int>('id'))),
    ),
    Route.delete(
      path: '/{id}',
      handler: (request) {
        service.delete(request.pathParam<int>('id'));
        return ResponseEntity.noContent();
      },
    ),
  ],
);
```

`bin/server.dart`:

```dart
import 'package:todo_api/todo_api.dart';
import 'package:winter/winter.dart';

void main() async {
  configure();
  await Winter.start(
    globalFilterConfig: FilterConfig([LoggingFilter()]),
    router: router(TodoService()),
  );
}
```

Try it:

```bash
curl -X POST localhost:8080/todos -H 'content-type: application/json' -d '{"title": "Write docs"}'
# 201 {"id": 1, "title": "Write docs", "done": false}

curl -X POST localhost:8080/todos -H 'content-type: application/json' -d '{"title": ""}'
# 422 {"violations": [{"fieldName": "title", "message": "The field cannot be blank", ...}], ...}

curl localhost:8080/todos/7
# 404 {"type": "about:blank", "title": "Not Found", "status": 404, "detail": "To-do 7 not found"}

curl localhost:8080/todos/abc
# 400 {"detail": "The path param id must be an integer", ...}
```

Every error is a Problem Details (`application/problem+json`), and an unexpected one is a 500
without details, logged with its request id.

## Testing it

`test/todo_api_test.dart`, in memory, without a port:

```dart
import 'package:test/test.dart';
import 'package:todo_api/todo_api.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUpAll(configure);
  setUp(() => client = WinterTestClient.build(router: router(TodoService())));

  test('creates and reads a to-do', () async {
    final created = await client.post('/todos', body: {'title': 'Write docs'});

    expect(created.statusCode, 201);
    expect(created.headers['location'], '/todos/1');
    expect((await client.get('/todos/1')).json, {'id': 1, 'title': 'Write docs', 'done': false});
  });

  test('a blank title is a 422', () async {
    final response = await client.post('/todos', body: {'title': ' '});

    expect(response.statusCode, 422);
    expect((response.json as Map)['violations'][0]['fieldName'], 'title');
  });
}
```

```bash
dart test
```

## Next steps

- [Routing](routing.md): path params, nested routes, 404 and 405.
- [Validation](validation.md) and the [object mapper](object-mapper.md): every validator, nested
  objects, your own types.
- [Security](security.md): authentication, roles, CORS, the rate limiter.
- [Configuration](configuration.md) and [deployment](deployment.md): `.env`, Docker, the shutdown.
- The [examples](../example), from a basic server to a production setup.

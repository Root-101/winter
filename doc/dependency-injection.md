# Dependency injection

`di` is a service locator: you register your services (repositories, clients, configuration) once
at start-up, and find them by their type anywhere.

- Four ways to register: an instance (`put`), a lazy singleton (`putLazy`), a factory
  (`putFactory`) and one instance per request (`putScoped`).
- `onDispose` closes what needs closing (a database connection) when the server shuts down.
- No reflection, no annotations and no code generation: what you register is what you get.

The decisions behind it are in [`DECISIONS.md` §5](../DECISIONS.md#5-dependency-injection).

## Minimal example

```dart
import 'package:winter/winter.dart';

abstract class UserRepository {
  String? findName(int id);
}

class InMemoryUserRepository implements UserRepository {
  final Map<int, String> _names = {1: 'Ann'};

  @override
  String? findName(int id) => _names[id];
}

class UserService {
  final UserRepository repository;

  UserService(this.repository);

  String name(int id) =>
      repository.findName(id) ?? (throw NotFoundException(detail: 'User $id not found'));
}

void main() async {
  di
    ..put<UserRepository>(InMemoryUserRepository())
    ..putLazy<UserService>(() => UserService(di.find()));

  await Winter.start(
    router: WinterRouter(
      routes: [
        Route.get(
          path: '/users/{id}',
          handler: (request) =>
              ResponseEntity.ok(
                body: di.find<UserService>().name(int.parse(request.pathParams['id']!)),
              ),
        ),
      ],
    ),
  );
}
```

## How it works

### Registering

| Method                     | Instance                                           | `onDispose`                   |
|----------------------------|----------------------------------------------------|-------------------------------|
| `put(instance)`            | The one given                                      | Yes                           |
| `putLazy<T>(() => ...)`    | Created by the first `find`, then the same         | Yes, if it was created        |
| `putFactory<T>(() => ...)` | A new one on every `find`                          | No (whoever finds it owns it) |
| `putScoped<T>(() => ...)`  | One per request, created by the first `find` in it | Yes, when the request ends    |

- Every method takes an optional `tag`, to register several instances of the same type:
  `di.put<HttpClient>(paymentsClient, tag: 'payments')`.
- Registering a type (and tag) again replaces it. The old instance is not disposed: it may still be
  in use.
- The functions are synchronous. Initialize what is async before registering it:
  `di.put(await Database.connect(url), onDispose: (db) => db.close())`.

### Finding

| Method                      | Not registered |
|-----------------------------|----------------|
| `di.find<T>({tag})`         | `StateError`   |
| `di.tryFind<T>({tag})`      | `null`         |
| `di.isRegistered<T>({tag})` | `false`        |
| `di.delete<T>({tag})`       | `StateError`   |

`delete` returns the instance if it was created (`null` for a lazy one never found, a factory or a
scoped one), and doesn't dispose it.

A registered `null` is valid (`put<Config?>(null)`): `find` returns it, and `isRegistered` tells
it from a missing one.

### By exact type

A dependency is found by the type it was registered with, never by a supertype or an interface:

```dart
di.put
(
InMemoryUserRepository());
di.find<UserRepository>(); // StateError: registered as InMemoryUserRepository

di.put<UserRepository>(InMemoryUserRepository());
di.find<UserRepository>
(
); // found
```

`T` and `T?` are the same key: a dependency registered from a variable of type `Service?` is found
as `Service`.

### Lazy singletons and their order

`putLazy` creates the instance the first time it's found, so dependencies can be registered in any
order, even if one needs another:

```dart
di..putLazy<OrderService>
(
() => OrderService(di.find(), di.find()))
..putLazy<OrderRepository>(() => SqlOrderRepository(di.find()))
..putLazy<PaymentClient>(() => PaymentClient(paymentsUrl));
```

A cycle (`A` needs `B`, which needs `A`) is a `StateError` with the chain:
`Circular dependency: OrderService -> PaymentClient -> OrderService`.

### One instance per request: `putScoped`

```dart
di.putScoped<UnitOfWork>
(
() => UnitOfWork(di.find<Database>()),
onDispose: (uow) => uow.close(),
);

Route.post(
path: '/orders',
handler: (request) async {
final uow = di.find<UnitOfWork>(); // the same one in this request, even after an await
await di.find<OrderService>().create(await request.body<Order>(), uow);
return ResponseEntity(201);
},
);
```

- Every request gets its own instance, created the first time it's found in it; concurrent
  requests never share it (like `@RequestScope` in Spring). Services find it with `di.find` too,
  without receiving the request.
- Its `onDispose` runs when the request ends: **after the response is built, before it's sent**.
  A response streamed after that (a `Stream` body) must not need it.
- Outside a request it's a `StateError`. In a test, give it one with
  `RequestScope.run(scope, () => ...)` and call `await scope.complete()` to dispose it.

`RequestScope.current?.onComplete(() => ...)` runs any code of your own at the end of the request
the same way.

### Shutting down: `onDispose`

```dart
di.putLazy<Database>
(
() => Database.open(databaseUrl),
onDispose: (db) => db.close(),
);
```

`Winter.shutdown()` (SIGTERM, Ctrl+C) waits for the requests in progress, calls
`ServerConfig.onShutdown`, and then `di.disposeAll()`: every `onDispose` of what was created, in
**reverse order of registration** (so a service is closed before the database it uses), and the
dependencies are removed. An `onDispose` that fails is logged, and the others still run.

`Winter.close()` doesn't dispose anything, so a test can close a server and start another one with
the same dependencies. Call `di.disposeAll()` yourself when you need it.

### What Winter registers

`Winter.start` registers the `ServerConfig`, the router (as `AbstractWinterRouter`) and the
`SecurityConfig` it uses (the ones given, or the ones already registered, or the defaults), and
`Winter.close()` restores what was there before, so nothing leaks to the next server.

## Configuration

`di` is the `DependencyInjection` of `Winter.context`. Every `DependencyInjection` has its own
registrations, so a test can use a fresh one:

```dart
setUp
(
() => Winter.context.setUp(dependencyInjection: DependencyInjection
(
)
)
);
```

Replacing it drops what was registered in the previous one.

## Common cases

### Replacing a dependency in a test

Register the fake with the same type, before the code under test finds it:

```dart
setUp
(
() {
di.put<PaymentClient>(FakePaymentClient());
});
```

Registering it again replaces the registration, even a `putLazy` already created, so the next
`find` returns the fake. What was found before keeps the instance it got.

### Several implementations of the same type

```dart
di..put<Notifier>
(
EmailNotifier(), tag: 'email')
..put<Notifier>(SmsNotifier(), tag: 'sms');

di.find<Notifier>(tag: 'sms');
```

### Configuration values

```dart
di.put
(
AppConfig
.
fromEnv
(
env
)
); // read once at start-up, fail fast if something is missing
```

## Typical mistakes and limitations

- **Registering the implementation and finding the interface**: `put(SqlRepo())` and
  `find<Repo>()` fail. Write `put<Repo>(SqlRepo())`.
- **Finding a dependency in a `static final` or at the top level**: it runs before the
  registrations. Find it when it's used, or in a `putLazy` function.
- **An async initialization in `putLazy`**: the function is synchronous; await it first and `put`
  the result.
- **A scoped dependency outside a request** (a `Timer`, a background job): it's a `StateError`;
  run that code inside `RequestScope.run` or use a lazy or factory dependency.
- **No constructor injection**: dependencies are found by your code (`di.find()` in the
  functions), never injected by Winter. It's a service locator on purpose: AOT has no reflection,
  and the project avoids code generation.

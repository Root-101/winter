# Dependency injection

`di` is a service locator: you register your services (repositories, clients, configuration) once
at start-up, and find them by their type anywhere.

- Four ways to register: an instance (`put`), a lazy singleton (`putLazy`), a factory
  (`putFactory`) and one instance per request (`putScoped`).
- `onDispose` closes what needs closing (a database connection) when the server shuts down.
- No reflection, no annotations and no code generation: what you register is what you get.

The decisions behind it are in [`DECISIONS.md` §5](../DECISIONS.md#5-dependency-injection).

Examples, one file per case: [`example/di`](../example/di) (layered services and fakes, one
instance per request, async startup).

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
                body: di.find<UserService>().name(request.pathParam<int>('id')),
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
| `putLazyAsync<T>(() async => ...)` | Created by `ready()` (or the first `findAsync`), then the same | Yes, if it was created |
| `putFactory<T>(() => ...)` | A new one on every `find`                          | No (whoever finds it owns it) |
| `putScoped<T>(() => ...)`  | One per request, created by the first `find` in it | Yes, when the request ends    |

- Every method takes an optional `tag`, to register several instances of the same type:
  `di.put<HttpClient>(paymentsClient, tag: 'payments')`.
- Registering a type (and tag) again replaces it. The old instance is not disposed: it may still be
  in use.
- The functions are synchronous, except the one of `putLazyAsync` (below).

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
di.put(InMemoryUserRepository());
di.find<UserRepository>(); // StateError: registered as InMemoryUserRepository

di.put<UserRepository>(InMemoryUserRepository());
di.find<UserRepository>(); // found
```

`T` and `T?` are the same key: a dependency registered from a variable of type `Service?` is found
as `Service`.

### Lazy singletons and their order

`putLazy` creates the instance the first time it's found, so dependencies can be registered in any
order, even if one needs another:

```dart
di
  ..putLazy<OrderService>(() => OrderService(di.find(), di.find()))
  ..putLazy<OrderRepository>(() => SqlOrderRepository(di.find()))
  ..putLazy<PaymentClient>(() => PaymentClient(paymentsUrl));
```

A cycle (`A` needs `B`, which needs `A`) is a `StateError` with the chain:
`Circular dependency: OrderService -> PaymentClient -> OrderService`.

### Asynchronous initialization: `putLazyAsync`

A dependency that needs an `await` to exist (a connection opened, a file read) is registered with
`putLazyAsync`, in any order like a `putLazy`:

```dart
di.putLazyAsync<Database>(
  () => Database.connect(env.require<String>('DATABASE_URL')),
  onDispose: (db) => db.close(),
);
di.putLazy<UserRepository>(() => SqlUserRepository(di.find<Database>()));

await Winter.start(); // creates the async ones (di.ready()) before opening the port
```

- `Winter.start` awaits `di.ready()`, which creates every async dependency one after the other, in
  order of registration. If one fails, the server doesn't start: every failure is logged and named
  in one `StateError`.
- From then on `di.find<Database>()` is synchronous, so the rest of the code doesn't change. A
  `find` before `ready()` is a `StateError` that says so.
- `await di.findAsync<T>()` finds it waiting for it (creating it the first time; concurrent calls
  share the creation). An async function uses it to depend on another async one registered before
  it.
- Without a server (a test, a script), call `await di.ready()` yourself.
- A cycle between async dependencies (`A` awaits `B`, which awaits `A`) is a `StateError`, never a
  wait forever.

### What is registered: `registrations`

`di.registrations` lists every registration in order: its type, tag, kind and whether its
instance exists. Log it at start-up, or look at it when a `find` says a dependency is missing:

```dart
logger.info('Dependencies:\n${di.registrations.join('\n')}');
// UserService (instance, created)
// Database [main] (lazy, not created)
// Clock (factory)
// UnitOfWork (scoped)
```

It's a read-only snapshot. Each `DependencyRegistration` has `type` (the type it was registered
with), `tag`, `kind` (`DependencyKind.instance`, `lazy`, `factory` or `scoped`) and `created`.

### Failing at start-up: `createAll`

A lazy singleton that can't be created (a missing dependency, a cycle, a constructor that throws)
fails in the first request that needs it, maybe hours after a deploy. `di.createAll()` creates
every lazy singleton now, so the same mistake stops the start-up instead:

```dart
registerDependencies();   // in any order, as always
di.createAll();           // every putLazy, created now
await Winter.start();
```

- Optional: without it, a lazy singleton is created by its first `find` (a faster start, and
  nothing unused is ever created). The order of registration stays free either way.
- Every lazy singleton is tried: each failure is logged with its stack trace, and then one
  `StateError` names all of them (`2 dependencies could not be created: - <Db>: ...`). One that
  fails stays registered and not created.
- Factories and scoped dependencies are not created: they belong to a `find` or a request. A lazy
  singleton that depends on a scoped one is found here too.

### One instance per request: `putScoped`

```dart
di.putScoped<UnitOfWork>(
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
- Outside a request it's a `StateError`, with `find` and with `tryFind` too: it's registered, but
  there is no request to give it. In a test, give it one with `RequestScope.run(scope, () => ...)`
  and call `await scope.complete()` to dispose it.
- After its request ended (code that keeps running after the response, like an `unawaited` job)
  it's a `StateError` too: its instance is already disposed (`RequestScope.isCompleted`).
- **A lazy singleton can't depend on it.** A `putLazy` is created once, in the first request that
  finds it, and would keep the scoped instance of that request (disposed when it ends) forever.
  It's a `StateError` that says so. The service that needs it is a `putFactory` (a new one in each
  request, which gets the instance of its request) or a `putScoped`, or it finds the dependency
  where it's used:

  ```dart
  di
    ..putScoped<UnitOfWork>(() => UnitOfWork(di.find()))
    ..putFactory<OrderService>(() => OrderService(di.find<UnitOfWork>())); // not putLazy
  ```

`RequestScope.current?.onComplete(() => ...)` runs any code of your own at the end of the request
the same way (registering it after the request ended is a `StateError`: it would never run).

### Shutting down: `onDispose`

```dart
di.putLazy<Database>(
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

`Winter.start` registers the `ServerConfig`, the router (as `BaseRouter`) and the
`SecurityConfig` it uses (the ones given, or the ones already registered, or the defaults), and
`Winter.close()` restores what was there before, so nothing leaks to the next server.

## Configuration

`di` is the `DependencyInjection` of `Winter.context`. Every `DependencyInjection` has its own
registrations, so a test can use a fresh one:

```dart
setUp(() => Winter.context.setUp(dependencyInjection: DependencyInjection()));
```

Replacing it drops what was registered in the previous one.

## Common cases

### Replacing a dependency in a test

Register the fake with the same type, before the code under test finds it:

```dart
setUp(() {
  di.put<PaymentClient>(FakePaymentClient());
});
```

Registering it again replaces the registration, even a `putLazy` already created, so the next
`find` returns the fake. What was found before keeps the instance it got.

To leave the registrations of the app untouched, give each test a **child** container with its
fakes:

```dart
late DependencyInjection appDependencies;

setUpAll(() {
  registerDependencies();                       // the real ones, in the global di
  appDependencies = Winter.context.dependencyInjection;
});

setUp(() => Winter.context.setUp(
  dependencyInjection: appDependencies.child()..put<PaymentClient>(FakePaymentClient()),
));

tearDown(() => di.disposeAll());                // only what this child created
```

- What the child registers wins; the rest comes from its `parent`.
- The child takes the **recipes** of the parent, not its instances (except those given with
  `put`): a `putLazy` of the parent gets its own instance in each child, created when the child
  finds it, so a service of the app uses the fakes of the test. The parent never changes.
- `registrations`, `delete`, `createAll` and `disposeAll` of a child only see what the child
  registered or created.
- The fakes only reach code that finds its dependencies through the global `di` (the container of
  `Winter.context`), which is what a `putLazy(() => Service(di.find()))` of the app does. A
  function that captured a container in a variable keeps using that container.
- A lazy singleton that is expensive to create (a connection pool) is created again in each
  child: register it with `put` in the parent to share it.

### Several implementations of the same type

```dart
di
  ..put<Notifier>(EmailNotifier(), tag: 'email')
  ..put<Notifier>(SmsNotifier(), tag: 'sms');

di.find<Notifier>(tag: 'sms');
```

### Configuration values

See [configuration](configuration.md) for `Env` and the typed configuration of the app.

```dart
di.put(AppConfig.fromEnv(env)); // read once at start-up, fail fast if something is missing
```

## Typical mistakes and limitations

- **Registering the implementation and finding the interface**: `put(SqlRepo())` and
  `find<Repo>()` fail. Write `put<Repo>(SqlRepo())`.
- **Finding a dependency in a `static final` or at the top level**: it runs before the
  registrations. Find it when it's used, or in a `putLazy` function.
- **An async initialization in `putLazy`**: its function is synchronous; use `putLazyAsync`.
- **A test that uses an async dependency without `ready()`**: `WinterTestClient` doesn't call it
  (only `Winter.start` does); `await di.ready()` in `setUp`.
- **A scoped dependency outside a request** (a `Timer`, a background job, or after the response):
  it's a `StateError`; run that code inside `RequestScope.run` or use a lazy or factory dependency.
- **A lazy singleton that depends on a scoped one**: it's a `StateError`. Register the service with
  `putFactory` or `putScoped`.
- **A broken registration found in production**: a lazy singleton fails when it's first found.
  Call `di.createAll()` before `Winter.start` to fail at start-up.
- **No constructor injection**: dependencies are found by your code (`di.find()` in the
  functions), never injected by Winter. It's a service locator on purpose: AOT has no reflection,
  and the project avoids code generation.

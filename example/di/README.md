# Dependency injection examples

One file per case, each a server of its own: `dart run lib/<case>.dart` (port 8080). The tests run
each one in memory: `dart test`.

| Case | File | What it shows |
|------|------|---------------|
| Layered services | [`layered_services.dart`](lib/layered_services.dart) | Repository → service → handler by interfaces with `putLazy`, two implementations told apart by a `tag`, `createAll()` at start, a fake in a `child()` container in the test |
| Request scoped | [`request_scoped.dart`](lib/request_scoped.dart) | `putScoped`: an audit trail per request, created with the user of the request and written by its `onDispose` when the request ends; concurrent requests never mix |
| Async startup | [`async_startup.dart`](lib/async_startup.dart) | `putLazyAsync` for a connection, awaited by `Winter.start` (`di.ready()`), a failure that names the dependency, `onDispose` on shutdown, a readiness check |

Guide: [dependency injection](../../doc/dependency-injection.md).

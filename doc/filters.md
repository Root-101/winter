# Filters

A filter runs code before and after the handler of a request: authentication, logs, metrics,
headers, limits. The filters of a request form a chain, and each one decides whether the request
goes on:

- **Global filters** run for every request (also a 404); **route filters** only for their route.
- They run sorted by `order`, and with the same `order` in the order they are declared: the global
  ones first, then the ones of the route.
- A filter never receives an exception: anything thrown inside the chain becomes a response where
  it's thrown.

## Minimal example

```dart
import 'package:winter/winter.dart';

/// Adds how long the request took
class TimingFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) async {
    final stopwatch = Stopwatch()..start();
    final ResponseEntity response = await chain.doFilter(request);
    return response.change(headers: {'Server-Timing': 'app;dur=${stopwatch.elapsedMilliseconds}'});
  }
}

void main() async {
  await Winter.start(
    globalFilterConfig: FilterConfig([LogsFilter(), TimingFilter()]),
    router: WinterRouter(
      routes: [Route.get(path: '/hello', handler: (request) => ResponseEntity.ok(body: 'hi'))],
    ),
  );
}
```

## How it works

### `doFilter` and the chain

`doFilter(request, chain)` returns the response of the request:

- `chain.doFilter(request)` runs the rest of the chain (the next filters and the handler) and
  returns its response, which the filter can change (`response.change(headers: ...)`).
- Returning a response without calling the chain **short-circuits** it: the handler never runs.
- `request.change(headers: ..., context: ...)` gives the next filters a changed request.

```dart
class MaintenanceFilter extends Filter {
  final bool Function() enabled;

  MaintenanceFilter(this.enabled);

  @override
  Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) async {
    if (enabled()) throw ServiceUnavailableException(detail: 'Back in 5 minutes');
    return chain.doFilter(request);
  }
}
```

### Global and route filters

```dart
await Winter.start(
  globalFilterConfig: FilterConfig([LogsFilter()]),       // every request
  router: WinterRouter(
    routes: [
      Route.parent(
        path: '/admin',
        filterConfig: FilterConfig([AuditFilter()]),     // /admin and its children
        routes: [
          Route.get(
            path: '/stats',
            handler: stats,
            filterConfig: FilterConfig([CacheFilter()]), // only this route, after AuditFilter
          ),
        ],
      ),
    ],
  ),
);
```

The filters of a parent route are inherited by its children, and run before theirs. A
`FilterConfig` is immutable: `merge` gives a new one with the filters of both
(`FilterConfig([a]).merge(FilterConfig([b]))`). A filter or a list of filters becomes one with
`.toFilterConfig()`.

### `order`

`order` (0 by default) sorts the whole chain, lower first: a global filter with `order: 10` runs
after a route filter with the default 0.

```dart
class AuditFilter extends Filter {
  AuditFilter() : super(order: 10);
  ...
}
```

The filters of Winter run first: `CorsFilter` (-100) and `SecurityHeadersFilter` (-99), so their
headers are on every response, the errors included.

### `shouldFilter`

Return `false` to skip the filter for a request (the chain goes on without it):

```dart
@override
bool shouldFilter(RequestEntity request) => !request.requestedUri.path.startsWith('/public');
```

A filter can also recognize a route by its key: `request.routingContext?.key == 'health'` (see
[routing](routing.md#route-keys)).

### Errors become responses where they are thrown

When a filter or the handler throws (an `ApiException`, a `StateError`...), the server's
`ExceptionHandler` turns it into a response right there, and that response goes back through the
outer filters. So:

- `LogsFilter`, CORS and the security headers see every error response.
- A `try`/`catch` around `chain.doFilter` never catches the error of the handler: look at the
  status of the response instead. To change how an error is answered, use the exception handler
  (see [error handling](error-handling.md)).
- A `FilterChain` built by hand without an `exceptionHandler` (in a unit test) rethrows.

### The filters of Winter

| Filter                    | What it does                                                         |
|---------------------------|----------------------------------------------------------------------|
| `LogsFilter`              | Logs `REQUEST`/`RESPONSE` with the status and the time (never the body nor the query) |
| `CorsFilter`              | Added by `SecurityConfig(cors:)` (see [security](security.md#cors))  |
| `SecurityHeadersFilter`   | Added by `SecurityConfig(securityHeaders:)`                          |
| `AuthFilter`              | 401/403 by authentication and rules ([security](security.md))        |
| `RateLimiterFilter`       | 429 beyond a limit per client ([security](security.md#rate-limiter)) |

## Common cases

### Testing a filter

With the whole pipeline:

```dart
final client = WinterTestClient.build(
  globalFilterConfig: FilterConfig([TimingFilter()]),
  router: router,
);

test('every response has Server-Timing', () async {
  expect((await client.get('/hello')).headers['server-timing'], startsWith('app;dur='));
});
```

Or alone, with a chain of its own (without an exception handler, the errors are rethrown):

```dart
final chain = FilterChain([MaintenanceFilter(() => true)], (request) => ResponseEntity.ok());

expect(
  () => chain.doFilter(RequestEntity('GET', Uri.parse('http://localhost/'))),
  throwsA(isA<ServiceUnavailableException>()),
);
```

## Typical mistakes and limitations

- **Catching the error of the handler in a filter**: it never arrives, it's already a response.
- **An authentication filter on a route and `AuthFilter` global**: the global one runs first and
  sees nobody. Keep the authentication global and first.
- **Changing the request and then reading the old one**: `change` returns a new request; pass it to
  `chain.doFilter`.
- **Reading the body in a filter**: `request.body<T>()` caches it, so the handler can read it too,
  but `read()`/`readAsString()` can't be used after it.

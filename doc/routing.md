# Routing

A router decides which handler answers a request. `WinterRouter` holds a list of routes, each with a
method, a path (with params and regex) and its filters:

- A static route wins over one with params (`/users/me` before `/users/{id}`); between the others,
  the first one declared.
- No route for the method is a **405** with `Allow`, no route for the path a **404**, and an
  `OPTIONS` is answered automatically.
- The route table is checked when the router is built: an invalid or duplicated route fails at
  start, not as a 404 in production.

The decisions behind it are in [`DECISIONS.md` §9](../DECISIONS.md#9-router-and-filters).

## Minimal example

```dart
import 'package:winter/winter.dart';

void main() async {
  await Winter.start(
    router: WinterRouter(
      basePath: '/api',
      routes: [
        Route.get(path: '/users', handler: (request) => ResponseEntity.ok(body: ['ann', 'bob'])),
        Route.get(
          path: '/users/{id}',
          handler: (request) => ResponseEntity.ok(body: {'id': request.pathParam<int>('id')}),
        ),
        Route.post(
          path: '/users',
          handler: (request) => ResponseEntity.created(location: '/api/users/3', body: {'id': 3}),
        ),
      ],
    ),
  );
}
```

| Request                | Response                                                |
|------------------------|---------------------------------------------------------|
| `GET /api/users/7`     | 200 `{"id": 7}`                                         |
| `GET /api/users/abc`   | 400 `The path param id must be an integer`              |
| `DELETE /api/users`    | 405, `Allow: GET, POST, HEAD, OPTIONS`                  |
| `OPTIONS /api/users`   | 204, `Allow: GET, POST, HEAD, OPTIONS`                  |
| `GET /api/orders`      | 404                                                     |

## How it works

### Routes

`Route.get`, `query`, `post`, `put`, `patch` and `delete` take a `path`, a `handler` (a function of
the `RequestEntity` that returns a `ResponseEntity`, or a `Future` of one) and optionally a
`filterConfig` and a `key`. `Route(path:, method: HttpMethod('...'), handler:)` takes any other
method.

Nest routes with `Route.parent`: the children join its path and inherit its filters (the ones of the
parent run first).

```dart
WinterRouter(
  routes: [
    Route.parent(
      path: '/admin',
      filterConfig: hasRole('admin').toFilterConfig(),
      routes: [
        Route.get(path: '/stats', handler: stats),                // GET /admin/stats
        Route.delete(path: '/users/{id}', handler: deleteUser),   // DELETE /admin/users/{id}
      ],
    ),
  ],
)
```

A route can have a handler and children at the same time: `Route.get(path: '/orders', handler:
list, routes: [...])` answers `/orders` and its children inherit its filters. A child with
`path: '/'` answers the path of its parent too. An empty path (`''`) is not a route.

`basePath` is added to every route of the router.

### Path params

| Path                       | Matches                    | `pathParams`               |
|----------------------------|----------------------------|----------------------------|
| `/users/{id}`              | `/users/42`                | `{id: 42}`                 |
| `/users/{id}/posts/{post}` | `/users/42/posts/7`        | `{id: 42, post: 7}`        |
| `/numbers/{n\|[0-9]+}`     | `/numbers/12`, not `/numbers/ab` | `{n: 12}`            |
| `/files/{path\|.*}`        | `/files/a/b.txt`           | `{path: a/b.txt}`          |

A param matches one segment (no `/`) unless it has its own regex after `|`. The values are
URL-decoded (`/users/John%20Doe` gives `John Doe`).

Read them with their type:

```dart
final int id = request.pathParam<int>('id');               // 400 if it's not an integer
final int page = request.queryParam<int>('page') ?? 1;      // null if missing or empty
final Status? status = request.queryParam('status', values: Status.values);
```

- Types: `String`, `int`, `double`, `num`, `bool` (`true`/`false`, any case), `DateTime` (ISO 8601),
  and one of `values` (an enum by name, any case; or a list like `['asc', 'desc']`).
- A value of another type is a 400 (Problem Details) that names the param and never the value.
- A name that isn't in the path of the route is a `StateError`, and an unsupported type an
  `ArgumentError`: both are bugs of the app (a 500).
- `pathParams`, `queryParams` and `queryParamsAll` (every value of a repeated param) are the raw
  `Map`s.

### Regex routes

Outside a param, `.*`, `.+`, `.?` and `.{n}` act as regex, and the rest of the characters of a
regex (`(a|b)`, `[a-z]`) too. A lone `.` is a literal dot: `/feed.json` doesn't match `/feedXjson`.

```dart
Route.get(path: '/static/.*', handler: serveFile)
```

### Which route answers

1. A static route (no params, no regex) wins: `/users/me` before `/users/{id}`, in any order.
2. Between the rest, the first one declared.
3. A trailing slash is ignored: `/users/` is `/users` (except the root, `/`).
4. A `HEAD` without its own route uses the `GET` one (the body isn't sent).
5. An `OPTIONS` without its own route is a 204 with `Allow`. The CORS preflights are answered
   before, by `CorsFilter` (see [security](security.md#cors)).
6. No route for the method: a 405 with `Allow` (which always lists `HEAD` with `GET`, and
   `OPTIONS`). No route for the path: a 404. Both are Problem Details.

The paths are compared as they are: `//users/1` and `/users//1` are a 404, never `/users/1` (behind
a proxy, a rule for `/admin` doesn't block `//admin`).

### The route table is checked at start

When the router is built (and on `addRoute`):

- **An invalid path** (`/in valid`, `/ñ`: the literal parts must be a valid URL path; encode them)
  is a `StateError`.
- **A duplicated route** is a `StateError`: the same `key`, or the same method and the same shape.
  The names of the params don't count, so `GET /users/{id}` and `GET /users/{name}` are the same
  route: the second one could never be reached.

`RouterConfig` changes that:

```dart
WinterRouter(
  config: RouterConfig(
    onInvalidUrl: DefaultOnInvalidUrl.ignore(),          // drop it with a warning
    onDuplicatedRoute: DefaultOnDuplicatedRoute.ignore(log: false),
    onLoadedRoutes: DefaultOnLoadedRoutes.log(),         // log the table at start
  ),
  routes: routes,
)
```

Each hook is a function, so it can do anything with the `Route` it receives.

### Route keys

Every route has a `key`: generated from its path and method, or given with `key:`. A filter uses it
to recognize a route without depending on its path:

```dart
class MetricsFilter extends Filter {
  @override
  bool shouldFilter(RequestEntity request) => request.routingContext?.key != 'health';

  @override
  Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) async {
    final response = await chain.doFilter(request);
    // record the metrics of the response...
    return response;
  }
}

Route.get(path: '/health', key: 'health', handler: (r) => ResponseEntity.ok(body: 'up'))
```

### Adding routes later

`router.routes` is read-only; `addRoute` adds a route (and its children) with the same rules as the
constructor: the `basePath`, the validation and the duplicates.

```dart
router.addRoute(Route.get(path: '/version', handler: version));
```

### `MultiRouter` and `ServeRouter`

`MultiRouter([routerA, routerB])` sends a request to the first of its `routers` that can handle it,
with the route filters of that router. Its 405 and its `OPTIONS` merge the methods of all of them.

`ServeRouter((request) => ...)` answers every request with one function, without routes.

### Your own router

Extend `BaseRouter` and implement `canHandle` and `handler`. A router that holds routes, or
wraps other routers, must also override `resolveRoute`: the server uses the `Route` it returns for
the route filters (`AuthFilter` included) and the path params. Without it, those filters are
silently skipped.

## Common cases

### A versioned API

```dart
final router = MultiRouter([
  WinterRouter(basePath: '/v1', routes: v1Routes),
  WinterRouter(basePath: '/v2', routes: v2Routes),
]);
```

### Testing the routes

```dart
final client = WinterTestClient.build(router: router);

test('an unknown user is a 404', () async {
  expect((await client.get('/api/users/999')).statusCode, 404);
});
```

## Typical mistakes and limitations

- **`int.parse(request.pathParams['id']!)`**: `/users/abc` is a 500. Use `pathParam<int>('id')`.
- **The same route with two param names** (`/users/{id}` and `/users/{userId}` for `GET`): it fails
  at start. Use one name.
- **A space or a non-ASCII character in a path**: encode it (`/caf%C3%A9`).
- **A custom router without `resolveRoute`**: its route filters never run.
- The regex of a param can't contain `{` or `}` (`{code|[A-Z]{3}}`): use `[A-Z][A-Z][A-Z]` or `+`.
- Routes are matched one by one: fine for hundreds of routes, not for tens of thousands.

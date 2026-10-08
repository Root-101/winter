# Security

Winter doesn't decide how your users log in: a filter of your app reads the credentials (a JWT, a
session cookie, an API key) and saves who made the request. From there the framework gives you:

- `AuthFilter` and composable rules (`hasRole('admin') | hasPermission('users.read')`) that answer
  a **401** (nobody authenticated) or a **403** (authenticated, but not allowed).
- The user of the request from any code, with its type: `requestPrincipal<User>()`.
- CORS, security headers and a rate limiter.

The decisions behind it are in [`DECISIONS.md` §8](../DECISIONS.md#8-security).

## Minimal example

```dart
import 'package:winter/winter.dart';

void main() async {
  await Winter.start(
    globalFilterConfig: FilterConfig([BearerFilter()]),
    router: WinterRouter(
      routes: [
        Route.get(
          path: '/me',
          handler: (request) => ResponseEntity.ok(body: requestPrincipal<User>().name),
          filterConfig: FilterConfig([AuthFilter()]),
        ),
        Route.delete(
          path: '/users/{id}',
          handler: (request) => ResponseEntity(204),
          filterConfig: hasRole('admin').toFilterConfig(),
        ),
      ],
    ),
  );
}

class User {
  final String name;
  final Set<String> roles;

  const User(this.name, this.roles);
}

/// Reads `Authorization: Bearer <token>` and saves the user of the token
class BearerFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) async {
    final header = request.headers[HttpHeader.authorization];
    if (header != null && header.startsWith('Bearer ')) {
      final User? user = verifyToken(header.substring(7));
      if (user != null) {
        request.securityContext.setAuthentication(
          Authentication<User>(principal: user, roles: user.roles),
        );
      }
    }
    return chain.doFilter(request);
  }
}

/// Your verification (a JWT library, a lookup in the database...)
User? verifyToken(String token) => token == 'secret' ? const User('ann', {'admin'}) : null;
```

| Request                                         | Response                                |
|-------------------------------------------------|-----------------------------------------|
| `GET /me`                                       | 401, `WWW-Authenticate: Bearer`         |
| `GET /me` with `Authorization: Bearer secret`   | 200 `ann`                               |
| `DELETE /users/7` with a user without `admin`   | 403                                     |

The full app, with login, hashed passwords and expiring JWTs, is
[`example/03_auth_security`](../example/03_auth_security).

## How it works

### Authentication: who made the request

`Authentication<T>` is the user of a request:

- `principal` (a `T`: your `User`, its id...), with `name` as its `toString()`.
- `roles` and `permissions`: two unmodifiable `Set<String>`.
- `authenticated`: `true` by default. `Authentication.anonymous()` is the one with `false`.

It's saved in the `RequestSecurityContext` of the request (`request.securityContext`), which the
server creates before the filters, so every filter, the handler and the `change()` copies of the
request share it.

Your filter calls `setAuthentication(...)` when the credentials are valid, and does nothing
otherwise: rejecting the request is the job of `AuthFilter`, so the public routes keep working
without credentials. Declare it as a **global** filter so every route has its user.

### The user of the request, from any code

The request runs in its own `Zone` (the `RequestScope`), so a service reads the user without
receiving the request:

```dart
class OrderService {
  Future<List<Order>> myOrders() => repository.findByOwner(requestPrincipal<User>().name);
}
```

| Function                                       | Nobody authenticated                         |
|------------------------------------------------|----------------------------------------------|
| `requestPrincipal<T>()`, `request.principal<T>()` | A 401 (`UnauthorizedException`, with `WWW-Authenticate: Bearer`) |
| `requestPrincipalOrNull<T>()`, `request.principalOrNull<T>()` | `null` (for a public route that changes for a logged in user) |

A principal of another type than `T` is a `StateError` (a 500): it's a bug of the app, not of the
client. `requestAuthentication` and `requestSecurityContext` give the whole `Authentication` and the
context (roles, permissions). Outside a request all of them are `null` (or a 401).

### `AuthFilter`: 401 or 403

`AuthFilter` lets the request go on only if it's authenticated and passes its `rules`:

| Situation                                              | Response                               |
|--------------------------------------------------------|----------------------------------------|
| Nobody authenticated (and `authenticated: true`, the default) | **401** with `WWW-Authenticate`  |
| Nobody authenticated and the rules fail                | **401**: logging in may give access    |
| Authenticated, but the rules fail                      | **403**: logging in again won't help   |

The `WWW-Authenticate` of the 401 (required by RFC 9110) is `Bearer`; change it with `challenge`:

```dart
AuthFilter(challenge: 'Basic realm="api"')
```

`AuthFilter(authenticated: false, rules: ...)` only checks the rules (an anonymous
`Authentication` evaluates them). A rule turns into a filter with `.toFilter()` or into a whole
`FilterConfig` with `.toFilterConfig()`.

### Rules

`hasRole` and `hasPermission` combine with `&` (and) and `|` (or), with the precedence of Dart (`&`
before `|`; use parentheses to be clear):

```dart
AuthFilter(rules: hasRole('admin') | (hasRole('editor') & hasPermission('posts.publish')))
```

A rule receives the `Authentication` **and the request**, so a rule of your app can look at the
path, the query or the headers. With `rule(...)`:

```dart
final isOwner = rule(
  (auth, request) => request.pathParams['id'] == (auth.principal as User).name,
  describe: 'isOwner',
);

Route.put(
  path: '/users/{id}',
  handler: updateUser,
  filterConfig: (hasRole('admin') | isOwner).toFilterConfig(),
);
```

Or with a class, when it has its own state:

```dart
class HasPlanRule extends AuthorizationRule {
  final String plan;

  const HasPlanRule(this.plan);

  @override
  bool evaluate(Authentication authentication, RequestEntity request) =>
      (authentication.principal as User).plan == plan;

  @override
  String describe() => 'hasPlan($plan)';
}

AuthFilter(rules: hasRole('admin') | const HasPlanRule('pro'))
```

`describe()` (the name of the class by default) is how the rule is shown in `toString()` and in the
logs: `hasRole(admin) || hasPlan(pro)`.

A rule is synchronous. A check that needs the database (is this user a member of this project?)
belongs in the handler or the service, which throws a `ForbiddenException`.

### A global `AuthFilter`

To protect everything but a few routes, add `AuthFilter` to the global filters, **after** your
authentication filter, with `shouldFilter`:

```dart
await Winter.start(
  globalFilterConfig: FilterConfig([
    BearerFilter(),
    AuthFilter(shouldFilter: (request) => !request.requestedUri.path.startsWith('/public')),
  ]),
  router: router,
);
```

The filters run sorted by `order` (0 by default) and, with the same `order`, in the order they are
declared: the global ones first, then the ones of the route.

### CORS

`SecurityConfig(cors: ...)` adds a `CorsFilter` before every other filter, which answers the
preflights (`OPTIONS`) and adds the CORS headers to every response, error ones included:

```dart
await Winter.start(
  securityConfig: SecurityConfig(
    cors: const CorsConfig(
      allowedOrigins: ['https://app.example.com'],
      allowCredentials: true,
      exposedHeaders: ['X-Total-Count'],
      maxAge: 600,
    ),
  ),
  router: router,
);
```

- `allowedOrigins: ['*']` (the default) lets any website read the API **without** cookies.
- With `allowCredentials: true`, list the origins. With `'*'` Winter has to echo the origin of the
  request (a browser rejects `*` with credentials), so any website could read the API with the
  cookies of its user: Winter logs a warning when the server is built like that.
- `X-Request-Id` is always exposed, so a web client can show it when it reports an error.
- When the answer depends on the origin (a list of origins, or credentials), every response has
  `Vary: Origin`, even the ones for an origin that isn't allowed, so a cache never serves the
  answer of one origin to another.

### Security headers

Every response has `X-Content-Type-Options: nosniff` and `X-Frame-Options: DENY`, unless the
response already sets them. For an API that's all a browser needs; add the rest with
`SecurityHeaders`:

```dart
SecurityConfig(securityHeaders: const SecurityHeaders(hsts: true))
```

| Header                      | Default                                       |
|-----------------------------|-----------------------------------------------|
| `Referrer-Policy`           | `no-referrer` (`referrerPolicy`, null to leave it out) |
| `Content-Security-Policy`   | `default-src 'none'; frame-ancestors 'none'` (`contentSecurityPolicy`) |
| `Strict-Transport-Security` | Only with `hsts: true`: `max-age=31536000` (`hstsMaxAge`, `hstsIncludeSubDomains`) |

A header the response already has is kept, so a route that serves a page can set its own
`Content-Security-Policy`. Turn on HSTS only when the API is served over HTTPS (directly or by its
proxy): a browser that received it refuses HTTP for `hstsMaxAge`.

### Rate limiter

`RateLimiterFilter` allows `maxRequests` per client in any rolling `window` (a sliding window), and
answers a **429** with `Retry-After` beyond that:

```dart
globalFilterConfig: FilterConfig([
  RateLimiterFilter(maxRequests: 100, window: const Duration(minutes: 1)),
]),
```

Every response has `X-RateLimit-Limit`, `X-RateLimit-Remaining` and `X-RateLimit-Reset` (seconds
until a slot is free).

- The client is its IP, the address of the connection. Behind a proxy (a load balancer, nginx),
  that's the proxy: trust its `X-Forwarded-For` with
  `clientId: (request) => request.clientIp(trustedProxies: 1) ?? 'unknown'` (the number of proxies
  in front of the app). Never trust it without a proxy: a client can send any value.
- `clientId` can return any id: the user (`requestPrincipalOrNull<User>()?.name`), an API key...
- A `maxRequests` under 1 or a `window` that isn't positive is an `ArgumentError` when it's created.
- Inactive clients are forgotten once per window, so the memory doesn't grow with every new IP.

The requests are kept **in memory, per isolate and per process**: four instances of the app (or
four isolates with `shared: true`) allow four times the limit. A shared limit needs a store of its
own (Redis, a database), see [below](#a-shared-rate-limit).

`RateLimiter` can be used without the filter, for example to limit the logins of an account:

```dart
final loginLimiter = RateLimiter(5, const Duration(minutes: 15));

final RateLimitResult result = await loginLimiter.check(email);
if (!result.allowed) {
  throw TooManyRequestsException(retryAfter: result.retryAfter.inSeconds + 1);
}
```

`peek(id)` gives the state without recording a request, `reset(id)` forgets an id (after a correct
login) and `clear()` forgets all of them.

## Configuration

| Option                                  | Default        | What it does                                   |
|-----------------------------------------|----------------|------------------------------------------------|
| `SecurityConfig(cors:)`                 | `null`         | Adds a `CorsFilter` (order -100)               |
| `SecurityConfig(securityHeaders:)`      | `null`         | Adds a `SecurityHeadersFilter` (order -99)     |
| `AuthFilter(authenticated:)`            | `true`         | Requires an authenticated user                 |
| `AuthFilter(rules:)`                    | `null`         | The rules the user must pass                   |
| `AuthFilter(challenge:)`                | `'Bearer'`     | The `WWW-Authenticate` of a 401                |
| `AuthFilter(shouldFilter:)`             | every request  | Which requests it checks                       |
| `RateLimiterFilter(clientId:)`          | the client IP  | The id that is limited                         |
| `RateLimiterFilter(onLimited:)`         | a debug log    | Called for every rejected request              |

`SecurityConfig` is resolved like the router and `ServerConfig`: the argument of `Winter.start`,
then `di.tryFind<SecurityConfig>()`, then the default (no CORS, no extra headers). Extend it to
compute the CORS configuration (`cors()` is a method).

## Common cases

### Testing a protected route

`WinterTestClient` runs the whole pipeline, your authentication filter included:

```dart
final client = WinterTestClient.build(
  globalFilterConfig: FilterConfig([BearerFilter()]),
  router: router,
);

test('a user without admin gets a 403', () async {
  final response = await client.delete('/users/7', headers: {'authorization': 'Bearer user-token'});

  expect(response.statusCode, 403);
});
```

To test a service that reads the user, without a server, give it a `RequestScope`:

```dart
final context = RequestSecurityContext<User>.empty()
  ..setAuthentication(Authentication<User>(principal: const User('ann', {})));

await RequestScope.run(RequestScope(securityContext: context), () async {
  expect(await OrderService().myOrders(), hasLength(2));
});
```

### A shared rate limit

Implement `RateLimiterStore` and give it to a `RateLimiter`. `hit` must be atomic for an id (in
Redis, a Lua script or a `MULTI` over a sorted set):

```dart
class RedisRateLimiterStore implements RateLimiterStore {
  @override
  Future<RateLimitResult> hit(
    String id, {
    required int limit,
    required Duration window,
    required DateTime now,
    bool record = true,
  }) async {
    // Remove the requests older than now - window, count the rest and add `now` when
    // there are fewer than limit (and record is true)...
    throw UnimplementedError();
  }

  @override
  Future<void> reset(String id) async {/* DEL the key of id */}

  @override
  Future<void> clear() async {/* DEL every key */}
}

RateLimiterFilter.fromRateLimiter(
  rateLimiter: RateLimiter(100, const Duration(minutes: 1), store: RedisRateLimiterStore()),
)
```

## Production checklist

- **HTTPS**, in the app or in its proxy, and then `SecurityHeaders(hsts: true)`.
- CORS with the list of your origins, never `'*'` with credentials.
- `trustedProxies` in the rate limiter (and in `clientIp`) equal to the proxies in front of the app.
- A rate limit on the login, per account, besides the one per IP.
- `ServerConfig.maxBodySize` (10 MB by default) as small as your biggest request.
- Secrets (the key of the JWTs) from the environment: `env.require<String>('JWT_SECRET')`.
- Never log tokens, passwords nor bodies (`LoggingFilter` doesn't), and `sensitive: true` on the
  validation of secret fields, so their value never ends in a violation.
- A reverse proxy in front of the app (nginx, a load balancer) for what `dart:io` doesn't limit:
  slow clients that send their headers byte by byte, the size of the headers (`dart:io` accepts
  tens of KB), and the number of connections per client.
- `ServerConfig.requestTimeout` so a slow upload or a stuck handler can't hold a request forever.

## Typical mistakes and limitations

- **`AuthFilter` before the authentication filter.** It sees nobody and answers 401 to everyone.
  Keep your filter global and first, or give it a lower `order`.
- **The authentication filter answers the 401 itself.** Then a public route can't be called
  without credentials. Leave the rejection to `AuthFilter`.
- **Catching the 401 of `requestPrincipal`.** It's an `UnauthorizedException` on purpose: a handler
  behind `AuthFilter` never sees it, and one without it answers 401 like `AuthFilter` would.
- **Rules that need `await`.** A rule is synchronous; do that check in the service.
- **One rate limit for several instances.** The default store is per process; use a shared store.
- There are no sessions, CSRF protection nor OAuth flows: they belong to your app or a package.
- Only roles and permissions: an "authority" is `hasRole(x) | hasPermission(x)`.
- **A response header with a line break or a character that isn't ASCII** (a `Location` or a
  `Content-Disposition` built from the request) is a 500: `dart:io` can't send it, and a line break
  would be a header injection. Validate the value, and encode a file name that isn't ASCII
  (`filename*=UTF-8''${Uri.encodeComponent(name)}`).

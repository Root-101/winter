* Unreleased:
    * The fixes of a security audit (every finding reproduced in a sandbox and checked by two independent verifiers) and a quality audit (roadmap 10).
    * **Security** :lock: : `body<T>()` reads only a JSON `Content-Type` (`application/json` or `+json`): `text/plain` or none on a body that isn't empty is a 415, because a page of another site can send them without a CORS preflight (CSRF on a cookie session). WebSockets don't negotiate permessage-deflate unless the route asks for it (`Route.websocket(compression:)`): `dart:io` inflates whole messages with no limit. A `Forwarded` line with a quoted string never closed is ignored, so a client can't swallow the element of its proxy. A singleton (`putLazy`, `putLazyAsync`) is created outside the request that finds it first, so its listeners never see that user.
    * **Limits** :shield: : Trailing slashes are removed in one pass (they cost quadratic time per route, before any filter). `InMemoryIdempotencyStore(maxBytes:)` bounds the responses it keeps in bytes (64 MB by default), not only in keys. A JSON number too big for a `double` (`1e400`) is a 400, never `Infinity`.
    * **Hardening** :shield: : `ServerConfig.requestTimeout` is 30 seconds by default (`null` for none), so a slow client or a stuck handler can't hold a request forever; the package no longer carries the tests; `IdempotencyFilter` without `partition` keeps the keys of each user apart when the principal is an id (a `String` or a number), and warns once otherwise; `ConsoleLogger` escapes control characters, so a value can't forge a log line; a `Route.websocket` without `allowedOrigins` accepts only a page of the same host; a response behind `AuthFilter` gets `Cache-Control: private` unless it has one; Swagger UI loads its files with Subresource Integrity under a CSP that allows only them.
    * **Performance** :zap: : static routes are found by their path, without trying the regex of every route; the idempotency fingerprint hashes the body in place; one keep-alive timer per Server-Sent Events stream; random ids take 4 bytes per call.
    * **Fixes** :wrench: : the 422 of `body<T>(objectMapper:)` names the fields once, with that mapper (`ValidationException(objectMapper:)`); with `autoCompress`, a stream keeps its `Content-Length`; the guide and the example of `checkPreconditions` read the body before the check, so two edits of the same version can't both pass.

* 1.0.0-rc.3:
    * **DATE** :date: : 2026-10-20.
    * The same code as `1.0.0-rc.2`, which is retracted: its package carried the executables of the benchmarks by mistake (12 MB instead of 0.5 MB).

* 1.0.0-rc.2:
    * **DATE** :date: : 2026-10-20 (retracted, see `1.0.0-rc.3`).
    * The second release candidate: the standards that clients, gateways and tracing tools read (phase 8 of the roadmap), and the fixes of a full review of the code and a security probe of the real server (phase 9).
    * **Errors** :rotating_light: : Problem Details (RFC 9457) complete: `instance` (the path of the request by default, never its query string, or your own with `ApiException(instance:)`), `ProblemDetails.fromJson` (registered in the object mapper, so `as<ProblemDetails>()` works; a member of the wrong type is ignored, as the RFC asks), and `application/problem+json` only for a `ProblemDetails` body (any other JSON is `application/json`).
    * **Security** :lock: : `RateLimiterFilter` announces its limits with the headers of the IETF draft *RateLimit header fields for HTTP*: `RateLimit-Policy` (`"default";q=100;w=60`) and `RateLimit` (`"default";r=42;t=17`), on every response it lets through and on its 429; a `policy:` name per filter, so a burst and a daily limit on a route add one item each. Behind proxies, `ServerConfig.trustedProxies` (`TrustedProxies(count, headers:)`) reads `X-Forwarded-For`/`-Proto`/`-Host` or `Forwarded` (RFC 7239), one kind only and every value checked, so `clientIp` is the client and `requestedUri` the public URL (`Location`, `instance`, OpenAPI).
    * **Logging** :scroll: : W3C Trace Context: a request with a `traceparent` continues its trace with a span of its own, `requestTrace` gives it to any code (`requestTrace!.headers` to call another service), `JsonLogger` writes `traceId` and `spanId`, and without a valid `X-Request-Id` the request id is the trace id.
    * **HTTP** :globe_with_meridians: : Conditional requests (RFC 9110 §13): a `GET` whose `ETag` or `Last-Modified` the client already has is a 304 by itself, and `request.checkPreconditions(etag:, lastModified:, required:)` guards a change with a 412 (`PreconditionFailedException`) or a 428 (`PreconditionRequiredException`). `WebLink` (RFC 8288) and `WebLink.pages` for the `Link` of a paginated list, keeping the other params. `request.preferences` reads `Prefer` (RFC 7240: `return=minimal`, `respond-async`, `wait`, `handling`) and adds `Vary: Prefer` by itself.
    * **Filters** :link: : `DeprecationFilter` (`Deprecation`, RFC 9745, and `Sunset`, RFC 8594, with their links, inherited by the children of a parent and `deprecated` in OpenAPI) and `IdempotencyFilter` (`Idempotency-Key`, IETF draft: the first answer of a retried `POST` replayed, 422 for another body, 409 while it runs, over a pluggable `IdempotencyStore`).
    * **Routing** :health_worker: : `Route.health` answers `application/health+json` (`pass`/`fail` and a list per check), the format of the monitors and gateways.
    * **Hardening** :shield: : The URI of a request comes from its target, the scheme of the server and a valid `Host`, never from an `X-Forwarded-*` the client sent; static files check the real names (Windows short names such as `ENV~1`); CORS echoes only header names and origins; a `Prefer` over 4 KB is ignored; objects nested more than 128 levels are a 400; integers beyond 64 bits are a 400, never clamped; a date without offset is read as UTC; typed params are decimal and finite (no `NaN`, `Infinity` nor hex); an IPv6 client counts by its /64 in the rate limiter; a WebSocket handshake `dart:io` would refuse is a 426.
    * **Fixes** :wrench: : cron `*/2` in the day of the month keeps its step; a request that timed out keeps its scoped dependencies until its handler ends (`RequestScope.holdUntil`); Server-Sent Events leave the close of the server when their client leaves; the 422 names the fields with the mapper given to `body<T>(objectMapper:)`; a hidden parent hides its children in OpenAPI; `IdempotencyFilter` takes the query into account, can't be confused by spaces in a key or a partition, works with typed responses without body, and its in-memory store keeps at most `maxKeys`.
    * **RFC 9110** :books: : `StatusCode` and its exceptions follow the names and reason phrases of RFC 9110 (`ContentTooLargeException` for 413 `Content Too Large`, `UnprocessableContentException` for 422 `Unprocessable Content`, `misdirectedRequest` for 421); `Scheduler.cron` takes `runOnStart` like `every`.


* 1.0.0-rc.1:
    * **DATE** :date: : 2026-10-09.
    * The first version of Winter as a complete framework, built directly on `dart:io`. The guides are in `doc/`, and the reasons behind every design choice in `DECISIONS.md`.
    * **Server** :rocket: : `Winter.start` with `ServerConfig` (`host`, `port`, `shared` isolates, `maxBodySize`, `autoCompress`, `idleTimeout`, HTTPS with `securityContext`, a 503 after `requestTimeout`, `ServerConfig.fromEnv`). Graceful shutdown on SIGINT/SIGTERM (`shutdownTimeout`, `onShutdown`, the `onDispose` of the dependencies). Every response has an `X-Request-Id`, a `Date`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` and the reason phrase of its status.
    * **Requests and responses** :inbox_tray: : `RequestEntity` (case insensitive `headers` and `headersAll`, `cookies`, `body<T>()` decoded with the object mapper and validated, typed `pathParam<T>`/`queryParam<T>`, every kind of body (none, JSON, any text with `body<String>()`, binary with `bytes()`/`body<Uint8List>()`), forms and file uploads with `formData()` (`application/x-www-form-urlencoded` and `multipart/form-data`) or streamed with `multipart()`, `clientIp()`) and `ResponseEntity` (a value written as JSON, text, bytes or a stream for Server-Sent Events, automatic `Content-Type` and `Content-Length`, `cookies`, shortcuts like `ok`, `created(location:)`, `noContent`, the redirects (`redirect`, `seeOther`, `temporaryRedirect`, `permanentRedirect`) and the errors (`conflict`, `serviceUnavailable(retryAfter:)`...)), changed with `copyWith`. The resolved route travels in the request (`request.route`), and a request or a response is extended with typed keys (`ContextKey<T>` in its `context`) and an extension, like the security context.
    * **OpenAPI** :page_with_curl: : `Route.openApi` serves the OpenAPI 3.1 document of the routes and `Route.swaggerUi` shows it. Paths, params, security (from the `AuthFilter`s) and Problem Details errors come by themselves; the bodies from an example (its schema inferred, the rules of its `validate()` as constraints), a `JsonSchema` written by hand, or both (`RouteDocs`, `BodyDocs`).
    * **Scheduled tasks** :alarm_clock: : `Scheduler` with `every(interval)` and `cron('0 3 * * *')` (5 fields, ranges, steps, names, macros, local or UTC) or a `Schedule` of your own. Each run in a request scope of its own (an id in its logs, scoped dependencies), errors logged, no overlapping runs, `lastRun`/`lastSucceeded`/`nextRun` for a health check. `Winter.start(scheduler:)` starts it with the server, and the graceful shutdown waits for the runs in progress.
    * **WebSockets** :electric_plug: : `Route.websocket(path:, handler:)`: the handshake goes through the filters (auth, rate limit), the handler gets the `WebSocket` of `dart:io` (plus `sendJson`) in a request scope of its own, with `allowedOrigins`, subprotocols, a ping and a 426 for a request that isn't a handshake; the server closes the sockets when it shuts down.
    * **Server-Sent Events** :satellite: : `ResponseEntity.sse(stream)` with `ServerSentEvent` (`data`, `event`, `id`, `retry`, `json`, comments): the headers at once, a keep-alive, the stream cancelled when the client leaves and ended when the server shuts down.
    * **HTTP** :globe_with_meridians: : `HttpHeader` constants, `StatusCode` (one enum with `value`, `series`, `reasonPhrase`, `resolve`/`valueOf`), `HttpMethod` and `MediaType`.
    * **Router** :twisted_rightwards_arrows: : `WinterRouter` with nested routes, path params with regex, static routes first, 404/405 with `Allow`, automatic `HEAD` and `OPTIONS`, the `QUERY` method (`Route.query`), route keys, and a route table checked at start (invalid and duplicated routes). `MultiRouter`, `ServeRouter` and `BaseRouter` for your own. Static files with `Route.static`, or `StaticFiles(directory).serve(request, path)` from any handler (no path traversal, `ETag`, 304, `Range` requests, streamed), and health checks with `Route.health` (named checks with a timeout, a 503 when one is down).
    * **Filters** :link: : Global and route filters sorted by `order`, `shouldFilter`, `LoggingFilter`; an error becomes a response where it's thrown, so every filter sees it.
    * **Errors** :rotating_light: : Every error is a Problem Details (RFC 9457): `ApiException` and its shortcuts (`NotFoundException`...), `SimpleExceptionHandler..on<T>()` for the exceptions of the app, and a 500 that never exposes its cause.
    * **Object mapper** :card_file_box: : JSON ↔ objects with `toJson()` (no interface: `json_serializable` and `freezed` work as they are), `Serializer<T>`/`Deserializer<T>` and `JsonAdapter<T>` (both in one, for a type you don't own), generic types (`List<T>`, `Map<String, T>`, `T?`, and maps with other keys with `mapWithKeys<K>()`), enums, strict primitives, `fieldNaming`, `includeNulls`, `durationFormat`, `prettyPrint`, `rejectUnknownFields` (a key the `fromJson` never read is a 400), errors with the path of the value (`$.items[1]: expected a string, got an integer`) down to each field of a hand-written `fromJson` with `json.field<T>()`, `PatchValue<T>` (`json.patch<T>()`) to tell a missing field from a `null` one in a PATCH, and bodies written and read in UTF-8 directly (`encodeBytes`, `decodeBytes`).
    * **Validation** :white_check_mark: : `Validatable` with `cvc.field(name, value)` and typed validators (strings, numbers, iterables, maps, dates), nested objects, lists and maps (`valid()`, `validEach()`), `sensitive` fields, asynchronous rules (`AsyncValidatable`, `cvc.check`) run after the synchronous ones, and a 422 with a `code` and `params` per violation.
    * **Security** :lock: : `AuthFilter` (401 with `WWW-Authenticate`, 403) with composable rules (`hasRole`, `hasPermission`, `rule`, `&`, `|`), the typed principal of the request (`requestPrincipal<T>()`), CORS, `SecurityHeaders` (CSP, Referrer-Policy, HSTS) a sliding-window rate limiter with a pluggable `RateLimiterStore`, and response headers checked before they're sent (a line break taken from the request is a 500, never a header injection).
    * **Dependency injection** :syringe: : `put`, `putLazy`, `putLazyAsync` (created by `ready()`, before the server opens its port), `putFactory`, `putScoped` (one per request), tags, `onDispose`, `createAll()` to create every lazy singleton at start-up, `registrations` to list what is registered, and child containers (`di.child()`) for the fakes of a test.
    * **Configuration** :gear: : `Env` with typed values (`find`, `require`, `requireAll`, lists, `Duration`, enums), `.env` files and profiles (`WINTER_PROFILE`).
    * **Logging** :memo: : `ConsoleLogger` and `JsonLogger`, levels, structured `fields`, and the request id in every log.
    * **i18n** :globe_with_meridians: : The validation messages in the language of the request (`Accept-Language`, English and Spanish), `requestLocale` from any code, and `Vary: Accept-Language` added by itself.
    * **Request scope** :link: : Every request runs in its own `Zone`: `requestId`, `requestPrincipal`, `requestLocale` from any code, and `onComplete`.
    * **Testing** :test_tube: : `WinterTestClient` runs the whole pipeline in memory, without ports (`bodyBytes` for a binary response, `as<T>()` to read a body with the object mapper).
    * **Examples** :books: : Many small examples by topic, one file per case with its test (routing, request bodies, validation, object mapper, errors, filters, security (API keys, Basic auth, webhook signatures, login throttling), dependency injection, patterns of real APIs (pagination, ETag and `If-Match`, content negotiation, streamed downloads, `202` jobs, idempotency keys, versioning), OpenAPI, Server-Sent Events and WebSockets, scheduled tasks, i18n), and complete apps: authentication with JWT, an orders API, a photo gallery with uploads and a chat, and a production setup with Docker (`example/`).

* 0.0.7:
    * **DATE** :date: : 2024-10-29.
    * **General** :hammer_and_wrench: : Update min sdk version to ^3.4.0
  
* 0.0.6:
    * **DATE** :date: : 2024-10-26.
    * **Router** :twisted_rightwards_arrows: : Move `RouterConfig` inside `WinterRouter` (This way we can validate path
      and send response if it fails).
    * **Router** :twisted_rightwards_arrows: : `WinterRouter`: Check if route have a valid path before it's used (if
      path is NOT valid, it will not be used as a route and the function `RouterConfig.onInvalidUrl` will be called).
    * **Tests** :test_tube: : Add/Fix test for having `RouterConfig` inside `WinterRouter`.
    * **Router** :twisted_rightwards_arrows: : `MultiRouter`: Created a multi router class, It is a router that instead
      of containing a list of routes contains a list of other routers.
    * **Tests** :test_tube: : Add tests for `MultiRouter`.
    * **Docs** :scroll: : Fix details in general docs.

* 0.0.5:
    * **DATE** :date: : 2024-10-24.
    * **General** :hammer_and_wrench: : Fix example to pass in `pub points`

* 0.0.4:
    * **DATE** :date: : 2024-10-24.
    * **General** :hammer_and_wrench: : Fix code analyzer

* 0.0.3:
    * **DATE** :date: : 2024-10-24.
    * **General** :hammer_and_wrench: : Move code to `/lib` folder, update everything else.
    * **Docs** :scroll: : Add installing library to docs.

* 0.0.2:
    * **DATE** :date: : 2024-10-24.
    * **General** :hammer_and_wrench: : Clean up project, remove warnings, add example...

* 0.0.1:
    * **DATE** :date: : 2024-10-24.
    * **General** :hammer_and_wrench: : Initial version/deploy of lib.
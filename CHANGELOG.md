* 0.1.0:
    * **DATE** :date: : Unreleased.
    * The first version of Winter as a complete framework, built directly on `dart:io`. The guides are in `doc/`, and the reasons behind every design choice in `DECISIONS.md`.
    * **Server** :rocket: : `Winter.start` with `ServerConfig` (`host`, `port`, `shared` isolates, `maxBodySize`, `autoCompress`, `idleTimeout`, HTTPS with `securityContext`, a 503 after `requestTimeout`, `ServerConfig.fromEnv`). Graceful shutdown on SIGINT/SIGTERM (`shutdownTimeout`, `onShutdown`, the `onDispose` of the dependencies). Every response has an `X-Request-Id`, a `Date`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` and the reason phrase of its status.
    * **Requests and responses** :inbox_tray: : `RequestEntity` (case insensitive `headers` and `headersAll`, `cookies`, `body<T>()` decoded with the object mapper and validated, typed `pathParam<T>`/`queryParam<T>`, forms and file uploads with `formData()` (`application/x-www-form-urlencoded` and `multipart/form-data`) or streamed with `multipart()`, `clientIp()`) and `ResponseEntity` (a value written as JSON, text, bytes or a stream for Server-Sent Events, automatic `Content-Type` and `Content-Length`, `cookies`, shortcuts like `ok`, `created(location:)`, `noContent`, the redirects (`redirect`, `seeOther`, `temporaryRedirect`, `permanentRedirect`) and the errors (`conflict`, `serviceUnavailable(retryAfter:)`...)), changed with `copyWith`. The resolved route travels in the request (`request.route`), and a request or a response is extended with typed keys (`ContextKey<T>` in its `context`) and an extension, like the security context.
    * **Router** :twisted_rightwards_arrows: : `WinterRouter` with nested routes, path params with regex, static routes first, 404/405 with `Allow`, automatic `HEAD` and `OPTIONS`, route keys, and a route table checked at start (invalid and duplicated routes). `MultiRouter`, `ServeRouter` and `BaseRouter` for your own. Static files with `Route.static` (no path traversal, `ETag`, 304, `Range` requests, streamed), and health checks with `Route.health` (named checks with a timeout, a 503 when one is down).
    * **Filters** :link: : Global and route filters sorted by `order`, `shouldFilter`, `LoggingFilter`; an error becomes a response where it's thrown, so every filter sees it.
    * **Errors** :rotating_light: : Every error is a Problem Details (RFC 9457): `ApiException` and its shortcuts (`NotFoundException`...), `SimpleExceptionHandler..on<T>()` for the exceptions of the app, and a 500 that never exposes its cause.
    * **Object mapper** :card_file_box: : JSON ↔ objects with `toJson()` (no interface: `json_serializable` and `freezed` work as they are), `Serializer<T>`/`Deserializer<T>`, generic types (`List<T>`, `Map<String, T>`, `T?`), enums, strict primitives, `fieldNaming`, `includeNulls`, `durationFormat`, `prettyPrint`, and errors with the path of the value (`$.items[1]: expected a string, got an integer`).
    * **Validation** :white_check_mark: : `Validatable` with `cvc.field(name, value)` and typed validators (strings, numbers, iterables, maps, dates), nested objects (`valid()`, `validEach()`), `sensitive` fields, and a 422 with a `code` and `params` per violation.
    * **Security** :lock: : `AuthFilter` (401 with `WWW-Authenticate`, 403) with composable rules (`hasRole`, `hasPermission`, `rule`, `&`, `|`), the typed principal of the request (`requestPrincipal<T>()`), CORS, `SecurityHeaders` (CSP, Referrer-Policy, HSTS) and a sliding-window rate limiter with a pluggable `RateLimiterStore`.
    * **Dependency injection** :syringe: : `put`, `putLazy`, `putFactory`, `putScoped` (one per request), tags and `onDispose`.
    * **Configuration** :gear: : `Env` with typed values (`find`, `require`, `requireAll`, lists, `Duration`, enums), `.env` files and profiles (`WINTER_PROFILE`).
    * **Logging** :memo: : `ConsoleLogger` and `JsonLogger`, levels, structured `fields`, and the request id in every log.
    * **i18n** :globe_with_meridians: : The validation messages in the language of the request (`Accept-Language`, English and Spanish), `requestLocale` from any code, and `Vary: Accept-Language` added by itself.
    * **Request scope** :link: : Every request runs in its own `Zone`: `requestId`, `requestPrincipal`, `requestLocale` from any code, and `onComplete`.
    * **Testing** :test_tube: : `WinterTestClient` runs the whole pipeline in memory, without ports.
    * **Examples** :books: : From a basic server to authentication with JWT, i18n, nested DTOs and a production setup with Docker (`example/`).

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
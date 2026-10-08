# Architecture

How Winter is put together: the path of a request through the pipeline, the context that holds the
shared pieces (object mapper, DI, logger...), the scope of a request, and the model of one server
per isolate. Read it to know where to plug your code, or before contributing.

## The path of a request

```
 HttpRequest (dart:io)                       WinterTestClient (in memory)
        │                                              │
        └──────────────► RequestEntity ◄───────────────┘
                              │  the body limit (ServerConfig.maxBodySize → 413 when read)
                              ▼
               RequestScope (a Zone): request id, security context, language
                              │
                              ▼
               router.resolveRoute(request) → Route: its filters and path params
                              │
                              ▼
               FilterChain, sorted by `order`:
                 CorsFilter (-100) → SecurityHeadersFilter (-99)
                   → global filters → route filters (parents first) → handler
                              │
     anything thrown on the way ──► ExceptionHandler ──► a Problem Details response,
                              │                          where it was thrown
                              ▼
               ResponseEntity + X-Request-Id + nosniff/DENY (+ Vary: Accept-Language)
                              │
               scope.complete(): onComplete callbacks, scoped dependencies disposed
                              │
                              ▼
               writeResponse → HttpResponse (Date, Content-Length or chunked, no body for HEAD)
```

1. **The request.** The server turns each `HttpRequest` of `dart:io` into a `RequestEntity` (its
   headers are read as a view, not copied). `WinterTestClient` builds the same `RequestEntity` in
   memory and calls the same function, `Winter.buildHandler`: tests run the real pipeline.
2. **The scope.** Each request runs in its own `Zone` with a `RequestScope`: its id (the
   `X-Request-Id` sent, if valid, or a new UUID), its security context and its language. Any code
   reads them (`requestId`, `requestPrincipal<T>()`, `requestLocale`) without receiving the request,
   and concurrent requests never mix.
3. **The route.** The router resolves the `Route` before the filters run, so the route filters
   (`AuthFilter`) know the route, and the path params are ready. A 404, 405 or automatic `OPTIONS`
   is answered later, by the router's handler, so the global filters see it too.
4. **The chain.** The filters run sorted by `order` (stable: the global ones first, then the ones
   of the route), and the handler is the last link. A filter continues with `chain.doFilter` or
   answers by itself.
5. **The errors.** The `ExceptionHandler` turns anything thrown (an `ApiException`, an `Error`)
   into a response at the point where it was thrown, so every outer filter (CORS, logs, the rate
   limiter) receives a response, never the exception. Every error is a Problem Details, and a 500
   never shows its cause.
6. **The response.** The server adds the request id and the basic security headers, and
   `Vary: Accept-Language` if something read the language. Then the scope completes (scoped
   dependencies are disposed) and the response is written.

## The context: `WinterContext`

The pieces that the whole app shares live in `Winter.context`, a `WinterContext`, which exists
before the server starts:

| Piece                 | Shortcut   | Default                                      |
|-----------------------|------------|----------------------------------------------|
| `objectMapper`        | `om`       | `ObjectMapper()`                             |
| `exceptionHandler`    | `eh`       | `SimpleExceptionHandler()`                   |
| `dependencyInjection` | `di`       | `DependencyInjection()`                      |
| `env`                 | `env`      | `Env()` (the variables of the process)       |
| `logger`              | `logger`   | `ConsoleLogger()`                            |
| `localeConfig`        |            | `LocaleConfig()` (English only)              |

Replace any of them with `Winter.context.setUp(objectMapper: ..., logger: ...)`, or the whole
context with `Winter.start(context: WinterContext(...))`.

`Winter.start` resolves the `ServerConfig`, the router and the `SecurityConfig` from its argument,
then from `di`, then a default, and registers them in `di` until the server closes.

## One server per isolate

`Winter.context` and the running server are static: there is one of each **per isolate**. A Dart
isolate has its own memory, so:

- An app is one isolate with one server, the usual case.
- To use several cores, start one server per isolate on the same port with
  `ServerConfig(shared: true)` (see [deployment](deployment.md#several-isolates)). Each one has its
  own context, dependencies and in-memory state (the rate limiter, caches).
- Test files run in different isolates, so each one can change the context without affecting the
  others.

## The modules

| Module            | Files                         | Guide                                         |
|-------------------|-------------------------------|-----------------------------------------------|
| Server, lifecycle | `winter_server.dart`, `server_config.dart` | [configuration](configuration.md), [deployment](deployment.md) |
| Request, response | `request_entity.dart`, `response_entity.dart` | [requests and responses](requests-and-responses.md) |
| Router            | `router/`                     | [routing](routing.md)                         |
| Filters           | `filter_chain/`               | [filters](filters.md)                         |
| Object mapper     | `context/object_mapper/`      | [object mapper](object-mapper.md)             |
| Validation        | `context/validation/`         | [validation](validation.md)                   |
| Errors            | `context/exception/`          | [error handling](error-handling.md)           |
| DI                | `context/dependency_injection/` | [dependency injection](dependency-injection.md) |
| Configuration     | `env/`, `winter_context.dart` | [configuration](configuration.md)             |
| Logging           | `logging/`                    | [logging](logging.md)                         |
| Security          | `security/`                   | [security](security.md)                       |
| i18n              | `i18n/`, `request_scope.dart` | [i18n](i18n.md)                               |
| Testing           | `testing/`                    | [testing](testing.md)                         |

Everything is in `lib/src`, and `package:winter/winter.dart` is the only public library. Why each
piece is the way it is: [`DECISIONS.md`](../DECISIONS.md).

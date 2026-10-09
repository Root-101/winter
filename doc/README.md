# Winter documentation

Guides for each part of the framework. Each one explains what the module does, a minimal example,
how it works inside, its configuration, common cases, and typical mistakes and limitations. The
examples are runnable: one file per case, with its test.

## Guides

| Document                                             | Content                                                                      | Examples |
|------------------------------------------------------|------------------------------------------------------------------------------|----------|
| [Getting started](getting-started.md)               | Installation, first endpoint, a CRUD with JSON and validation, tests         | [routing](../example/routing) |
| [Architecture](architecture.md)                     | The path of a request, `WinterContext`, global state, request scope, isolates | |
| [Routing](routing.md)                                | Routes, typed path and query params, priority, 404/405/OPTIONS, static files, health, WebSockets, `MultiRouter`, your own router | [routing](../example/routing), [realtime](../example/realtime) |
| [Filters](filters.md)                                | `Filter`, the chain, `order`, `shouldFilter`, global and route filters, errors as responses | [filters](../example/filters) |
| [Requests and responses](requests-and-responses.md) | `RequestEntity`, `ResponseEntity`, every kind of body, forms and uploads, cookies, `copyWith`, Server-Sent Events, patterns of real APIs (pagination, ETag, 202, idempotency) | [bodies](../example/bodies), [api_patterns](../example/api_patterns), [realtime](../example/realtime) |
| [Object mapper](object-mapper.md)                    | JSON ↔ objects: `toJson()`, serializers, deserializers, generics, errors, options | [object_mapper](../example/object_mapper) |
| [Validation](validation.md)                          | `Validatable`, `cvc.field(...)`, the validators, nested objects, async rules, the 422 | [validation](../example/validation) |
| [Error handling](error-handling.md)                  | Problem Details, `ApiException` and its shortcuts, `on<T>()`, the 500        | [errors](../example/errors) |
| [i18n](i18n.md)                                     | The language of the request, Winter's messages, translating an app with slang | [i18n](../example/i18n) |
| [Security](security.md)                              | Your authentication filter, `AuthFilter` (401/403), rules, the principal, CORS, headers, rate limiter | [security](../example/security), [apps/auth_jwt](../example/apps/auth_jwt) |
| [Dependency injection](dependency-injection.md)      | `put`, `putLazy`, `putFactory`, `putScoped`, `putLazyAsync`, `child()`, `onDispose`, tests | [di](../example/di) |
| [Configuration](configuration.md)                    | `Env` (`find`, `require`, types, `.env` and profiles), `ServerConfig`, `WinterContext` | [apps/production](../example/apps/production) |
| [Logging](logging.md)                                | `ConsoleLogger`, `JsonLogger`, fields, the request id, what Winter logs      | [apps/production](../example/apps/production) |
| [Testing](testing.md)                               | `WinterTestClient`, tests without ports, `RequestScope.run`, fake clocks     | every `test/` of `example/` |
| [OpenAPI](openapi.md)                               | The document of the routes, Swagger UI, schemas from examples and `validate()` | [openapi](../example/openapi) |
| [Scheduled tasks](scheduling.md)                    | `Scheduler`, `every` and cron expressions, each run in a scope, with the server's shutdown | [scheduling](../example/scheduling) |
| [Deployment](deployment.md)                         | `dart compile exe`, Docker, graceful shutdown, isolates, reverse proxy       | [apps/production](../example/apps/production) |
| [Benchmarks](benchmarks.md)                         | The results of [`benchmark/`](../benchmark) against `dart:io`, and how to run them | |
| [Winter and other frameworks](comparison.md)      | Where each idea comes from (Spring, ASP.NET Core, Ktor...), the closest frameworks, the Dart ones, what Winter does its own way | |

## Other references

- [`DECISIONS.md`](../DECISIONS.md): **why** the framework behaves the way it does (the guides
  explain **how**): i18n (§1), the object mapper (§2), validation (§3), errors (§4), dependency
  injection (§5), configuration (§6), logging (§7), security (§8), the router and filters (§9),
  the HTTP layer (§10), the public API (§11), OpenAPI (§12) and scheduled tasks (§13).
- [`example/`](../example): every example, by topic, and four complete apps.
- [`CHANGELOG.md`](../CHANGELOG.md): what each version contains.
- [`ROADMAP.md`](../ROADMAP.md): what is left for 1.0, and the review before every release.

# Winter documentation

Guides for each part of the framework. Each one explains what the module does, a minimal example,
how it works inside, its configuration, common cases, and typical mistakes and limitations.

The documents are written once the review of their module (phase 2 of the
[roadmap](../ROADMAP.md)) is done, so they describe the API that will be stable in 1.0. Until
then, this index says which ones exist.

**State:** ✅ written · 🕓 planned

## Guides

| Document                                             | State | Content                                                                      |
|------------------------------------------------------|-------|------------------------------------------------------------------------------|
| [Getting started](getting-started.md)               | ✅    | Installation, first endpoint, a CRUD with JSON and validation, tests         |
| [Architecture](architecture.md)                     | ✅    | The path of a request, `WinterContext`, global state, request scope, isolates |
| [Routing](routing.md)                                | ✅    | Routes, typed path and query params, priority, 404/405/OPTIONS, the route table checks, `MultiRouter`, your own router |
| [Filters](filters.md)                                | ✅    | `Filter`, the chain, `order`, `shouldFilter`, global and route filters, errors as responses |
| [Requests and responses](requests-and-responses.md) | ✅    | `RequestEntity`, `ResponseEntity`, headers, cookies, the body, `copyWith`, streams |
| [Object mapper](object-mapper.md)                    | ✅    | JSON ↔ objects: `toJson()`, serializers, deserializers, generics, errors, options |
| [Validation](validation.md)                          | ✅    | `Validatable`, `cvc.field(...)`, the validators, nested objects, the 422     |
| [Error handling](error-handling.md)                  | ✅    | Problem Details, `ApiException` and its shortcuts, `on<T>()`, the 500        |
| [i18n](i18n.md)                                     | ✅    | The language of the request, Winter's messages, translating an app with slang |
| [Security](security.md)                              | ✅    | Your authentication filter, `AuthFilter` (401/403), rules, the principal, CORS, headers, rate limiter |
| [Dependency injection](dependency-injection.md)      | ✅    | `put`, `putLazy`, `putFactory`, `putScoped`, `onDispose`, tests              |
| [Configuration](configuration.md)                    | ✅    | `Env` (`find`, `require`, types, `.env` and profiles), `ServerConfig`, `WinterContext` |
| [Logging](logging.md)                                | ✅    | `ConsoleLogger`, `JsonLogger`, fields, the request id, what Winter logs      |
| [Testing](testing.md)                               | ✅    | `WinterTestClient`, tests without ports, `RequestScope.run`, fake clocks     |
| [OpenAPI](openapi.md)                               | ✅    | The document of the routes, Swagger UI, schemas from examples and `validate()` |
| [Scheduled tasks](scheduling.md)                    | ✅    | `Scheduler`, `every` and cron expressions, each run in a scope, with the server's shutdown |
| [Deployment](deployment.md)                         | ✅    | `dart compile exe`, Docker, graceful shutdown, isolates, reverse proxy       |

## Other references

- [`DECISIONS.md`](../DECISIONS.md): **why** the framework behaves the way it does (the guides
  explain **how**): i18n (§1), the object mapper (§2), validation (§3), errors (§4), dependency
  injection (§5), configuration (§6), logging (§7), security (§8), the router and filters (§9),
  the HTTP layer (§10), the public API (§11), OpenAPI (§12) and scheduled tasks (§13).
- [`CHANGELOG.md`](../CHANGELOG.md): what each version contains.
- [`ROADMAP.md`](../ROADMAP.md): what is left for 1.0.
- [`example/`](../example): standalone apps, from a basic server to authentication and i18n.
- [Benchmarks](benchmarks.md): the results of [`benchmark/`](../benchmark) (HTTP against `dart:io`,
  the pipeline in memory, the object mapper) and how to run them.

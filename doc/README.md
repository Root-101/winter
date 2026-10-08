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
| Getting started                                      | 🕓    | Installation, first endpoint, a CRUD with JSON and validation, tests         |
| Architecture                                         | 🕓    | The path of a request, `BuildContext`, global state, request scope, isolates |
| [Routing](routing.md)                                | ✅    | Routes, typed path and query params, priority, 404/405/OPTIONS, the route table checks, `MultiRouter`, your own router |
| [Filters](filters.md)                                | ✅    | `Filter`, the chain, `order`, `shouldFilter`, global and route filters, errors as responses |
| Requests and responses                               | 🕓    | `RequestEntity`, `ResponseEntity`, body limit, cookies, forms, files (after phase 3.1) |
| [Object mapper](object-mapper.md)                    | ✅    | JSON ↔ objects: `toJson()`, serializers, deserializers, generics, errors, options |
| [Validation](validation.md)                          | ✅    | `Validatable`, `cvc.field(...)`, the validators, nested objects, the 422     |
| [Error handling](error-handling.md)                  | ✅    | Problem Details, `ApiException` and its shortcuts, `on<T>()`, the 500        |
| i18n                                                 | 🕓    | The language of the request, Winter's messages, translating an app with slang |
| [Security](security.md)                              | ✅    | Your authentication filter, `AuthFilter` (401/403), rules, the principal, CORS, headers, rate limiter |
| [Dependency injection](dependency-injection.md)      | ✅    | `put`, `putLazy`, `putFactory`, `putScoped`, `onDispose`, tests              |
| [Configuration](configuration.md)                    | ✅    | `Env` (`find`, `require`, types, `.env` and profiles), `ServerConfig`, `BuildContext` |
| [Logging](logging.md)                                | ✅    | `ConsoleLogger`, `JsonLogger`, fields, the request id, what Winter logs      |
| Testing                                              | 🕓    | `WinterTestClient`, tests without ports, `RequestScope.run`, fake clocks     |
| Deployment                                           | 🕓    | `dart compile exe`, Docker, graceful shutdown, isolates, reverse proxy       |
| Migration from 0.x to 1.0                            | 🕓    | Every breaking change with a before and after (today in the [CHANGELOG](../CHANGELOG.md)) |

## Other references

- [`DECISIONS.md`](../DECISIONS.md): **why** the framework behaves the way it does (the guides
  explain **how**). Today: i18n (§1), the object mapper (§2), validation (§3), error handling
  (§4), dependency injection (§5), configuration (§6), logging (§7), security (§8), the
  router, filters and entities (§9) and the systems together (§10).
- [`CHANGELOG.md`](../CHANGELOG.md): what changed in each version, breaking changes included.
- [`ROADMAP.md`](../ROADMAP.md): what is left for 1.0.
- [`example/`](../example): standalone apps, from a basic server to authentication and i18n.
- [`benchmark/`](../benchmark): routing, server and object mapper benchmarks.

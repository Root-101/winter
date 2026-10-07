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
| Routing                                              | 🕓    | Routes, path params, priority, 404/405, `MultiRouter`, your own router       |
| Filters                                              | 🕓    | `Filter`, the chain, `order`, global and route filters, the default filters  |
| Requests and responses                               | 🕓    | `RequestEntity`, `ResponseEntity`, body limit, cookies, forms, files         |
| [Object mapper](object-mapper.md)                    | ✅    | JSON ↔ objects: `toJson()`, serializers, deserializers, generics, errors, options |
| [Validation](validation.md)                          | ✅    | `Validatable`, `cvc.field(...)`, the validators, nested objects, the 422     |
| [Error handling](error-handling.md)                  | ✅    | Problem Details, `ApiException` and its shortcuts, `on<T>()`, the 500        |
| i18n                                                 | 🕓    | The language of the request, Winter's messages, translating an app with slang |
| Security                                             | 🕓    | Authentication, `AuthFilter`, rules, CORS, rate limiter (2.7)                |
| Dependency injection                                 | 🕓    | `di`, tags, what `Winter.start` registers, tests (2.4)                       |
| Configuration                                        | 🕓    | `ServerConfig`, `Env`, `.env`, `BuildContext` (2.5)                          |
| Logging                                              | 🕓    | `WinterLogger`, levels, what the framework logs (2.6)                        |
| Testing                                              | 🕓    | `WinterTestClient`, tests without ports, `RequestScope.run`, fake clocks     |
| Deployment                                           | 🕓    | `dart compile exe`, Docker, graceful shutdown, isolates, reverse proxy       |
| Migration from 0.x to 1.0                            | 🕓    | Every breaking change with a before and after (today in the [CHANGELOG](../CHANGELOG.md)) |

## Other references

- [`DECISIONS.md`](../DECISIONS.md): **why** the framework behaves the way it does (the guides
  explain **how**). Today: i18n (§1), the object mapper (§2), validation (§3) and error handling
  (§4).
- [`CHANGELOG.md`](../CHANGELOG.md): what changed in each version, breaking changes included.
- [`ROADMAP.md`](../ROADMAP.md): what is left for 1.0.
- [`example/`](../example): standalone apps, from a basic server to authentication and i18n.
- [`benchmark/`](../benchmark): routing, server and object mapper benchmarks.

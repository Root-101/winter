# Winter documentation

Guides for each part of the framework. Each one explains what the module does, a minimal example,
how it works inside, its configuration, common cases, and typical mistakes and limitations.

The documents are written once the review of their module (phase 2 of the
[roadmap](../ROADMAP.md)) is done, so they describe the API that will be stable in 1.0. Until
then, this index says which ones exist.

**State:** ✅ written · 🕓 planned · ⚠️ exists but outdated

## Guides

| Document                                             | State | Content                                                                      |
|------------------------------------------------------|-------|------------------------------------------------------------------------------|
| Getting started                                      | 🕓    | Installation, first endpoint, a CRUD with JSON and validation, tests         |
| Architecture                                         | 🕓    | The path of a request, `BuildContext`, global state, request scope, isolates |
| Routing                                              | ⚠️    | Routes, path params, priority, 404/405, `MultiRouter` — today in [`routing/winter_router.md`](routing/winter_router.md), outdated |
| Filters                                              | 🕓    | `Filter`, the chain, `order`, global and route filters, the default filters  |
| Requests and responses                               | 🕓    | `RequestEntity`, `ResponseEntity`, body limit, cookies, forms, files         |
| [Object mapper](object-mapper.md)                    | ✅    | JSON ↔ objects: `toJson()`, serializers, deserializers, generics, errors, options |
| Validation                                           | ⚠️    | Validators and the 422 response, after the review 2.2 — [`vs/vs.md`](vs/vs.md) is obsolete |
| Error handling                                       | 🕓    | Exceptions, their status, the `ExceptionHandler`, the error format (2.3)     |
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
  explain **how**). Today: i18n (§1) and the object mapper (§2).
- [`CHANGELOG.md`](../CHANGELOG.md): what changed in each version, breaking changes included.
- [`ROADMAP.md`](../ROADMAP.md): what is left for 1.0.
- [`example/`](../example): standalone apps, from a basic server to authentication and i18n.
- [`benchmark/`](../benchmark): routing, server and object mapper benchmarks.

# Roadmap to 1.0.0

What it took to publish `winter` 1.0.0: an HTTP framework that covers the main use cases of a
REST API. Not at the level of Spring, but with the basics complete, stable and documented.

> **Now: `1.0.0` is on pub.dev (2026-10-31)**, the first stable version. From here on a breaking
> change needs a 2.0; what may come next is under *Possible improvements after release*.

The decisions behind each point are in `DECISIONS.md` (§ numbers below), the behavior in the
tests, the usage in `doc/`, and what each version has in `CHANGELOG.md`.

---

## What "1.0" means

1.0 is a promise of **API stability**: from then on, a breaking change requires a 2.0. Exit
criteria:

1. The public API is reviewed: no misspelled names, deprecated code or internal helpers exported by
   mistake.
2. It covers the typical use cases of an API: CRUD with JSON, validation, consistent errors,
   authentication and authorization, CORS, forms and file uploads, static files, configuration per
   environment, logs, tests and deployment.
3. Every module has its own guide in `doc/`, and the whole public API has dartdoc. 1.0 is a first
   version: no migration guide from 0.x.
4. Before each release the checks pass locally (format, analyze, tests, examples, publish dry run)
   with a good pana score, and the CI runs them on `develop` and `main`.
5. At least one release candidate was published and used in a real project (done: `1.0.0-rc.1` in
   feather-io).

---

## Current state

What `develop` has, module by module (the guide in `doc/`, the decisions in `DECISIONS.md`, and a
case per feature in `example/`):

| Module                            | What it covers                                                                                                                                                                                                                                                       | Guide                                     | Decisions |
|-----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------|-----------|
| HTTP engine                       | `dart:io` directly (~79 % of it on an empty endpoint), HTTPS, gzip, `idleTimeout`, `maxBodySize`, an optional `requestTimeout` (503), graceful shutdown                                                                                                              | `configuration.md`, `deployment.md`       | §10       |
| Requests and responses            | Winter's own `RequestEntity`/`ResponseEntity`: multi-value headers, cookies, `copyWith`, every kind of body (JSON, text, bytes, forms, multipart streamed or whole), `clientIp`, `Prefer`, `Link`                                                                    | `requests-and-responses.md`               | §10       |
| Pipeline                          | Global and route filters by `order`, the request scope (`Zone`: user, locale, id and trace from any code), an exception handler inside the chain                                                                                                                     | `architecture.md`, `filters.md`           | §9, §10   |
| Router                            | Nested routes, regex params, static routes by a map, 404/405 with `Allow`, automatic HEAD/OPTIONS, `QUERY`, a route table checked at start, `MultiRouter`, `ServeRouter`                                                                                             | `routing.md`                              | §9        |
| Static files and health           | `Route.static` (ETag, 304, `Range`, no traversal, Windows short names), `Route.health` (`application/health+json`)                                                                                                                                                   | `routing.md`                              | §9        |
| Object mapper                     | JSON ↔ objects without codegen (`toJson()`, `Serializer`/`Deserializer`, `JsonAdapter`), generic types, enums, strict primitives, `fieldNaming`, `rejectUnknownFields`, `PatchValue`, errors with the path of the value, UTF-8 bytes directly                        | `object-mapper.md`                        | §2        |
| Validation                        | Typed validators chained per field, nested objects/lists/maps, async rules, `sensitive` fields, a 422 with `code` and `params` per violation                                                                                                                         | `validation.md`                           | §3        |
| Errors                            | Problem Details (RFC 9457) for every error, `ApiException` and its shortcuts, `SimpleExceptionHandler.on<T>()`, a 500 that never shows its cause                                                                                                                     | `error-handling.md`                       | §4        |
| Dependency injection              | `put`, `putLazy`, `putLazyAsync` (+ `ready()`), `putFactory`, `putScoped` (per request), tags, `onDispose`, child containers for tests                                                                                                                               | `dependency-injection.md`                 | §5        |
| Configuration                     | `Env` (typed values, `.env` files and profiles, errors without values), `ServerConfig` (`const`, validated, `fromEnv`)                                                                                                                                               | `configuration.md`                        | §6        |
| Logging and tracing               | `ConsoleLogger`/`JsonLogger`, structured fields, a request id in every log and response, W3C Trace Context, never a value of the client                                                                                                                              | `logging.md`                              | §7        |
| Security                          | `AuthFilter` with composable rules, typed principal, CORS, security headers (+ `nosniff`, `DENY` on every response), `Cache-Control: private` behind auth, rate limiter with RateLimit headers, trusted proxies, response headers checked before sending             | `security.md`                             | §8        |
| API patterns                      | Conditional requests (304, 412/428), idempotency keys (per user), deprecation (`Deprecation`/`Sunset`), pagination (`WebLink.pages`), `Prefer`                                                                                                                       | `requests-and-responses.md`, `filters.md` | §9, §10   |
| WebSockets and Server-Sent Events | `Route.websocket` (filters on the handshake, same-host origin by default, compression opt-in), `ResponseEntity.sse` (keep-alive, ends on shutdown)                                                                                                                   | `routing.md`, `requests-and-responses.md` | §10       |
| OpenAPI                           | `Route.openApi` (3.1, from the routes, the filters and the validation rules), `Route.swaggerUi` (pinned, SRI)                                                                                                                                                        | `openapi.md`                              | §12       |
| Scheduled tasks                   | `Scheduler` with `every`/`cron`, each run in a request scope, waited on shutdown                                                                                                                                                                                     | `scheduling.md`                           | §13       |
| i18n                              | The validation messages in the language of the request (English, Spanish), `requestLocale`, `Vary` by itself                                                                                                                                                         | `i18n.md`                                 | §1        |
| Testing                           | `WinterTestClient`: the whole pipeline in memory, no ports, in parallel                                                                                                                                                                                              | `testing.md`                              | §10       |
| Quality                           | ~1208 tests, coverage ~99.7 %, two security audits (the last one with every finding closed), benchmarks                                                                                                                                                              | `benchmarks.md`                           |           |
| Examples                          | 13 topics with one case and its test each (`routing`, `bodies`, `validation`, `object_mapper`, `errors`, `filters`, `security`, `di`, `api_patterns`, `openapi`, `realtime`, `scheduling`, `i18n`), and the apps `auth_jwt`, `orders`, `files_gallery`, `production` | `example/README.md`                       |           |
| CI and package                    | GitHub Actions on Linux and Windows (format, analyze, tests, examples, slang, doc snippets, an obfuscated build, the dry run, pana), actions pinned, a package of 320 KB                                                                                             | `CONTRIBUTING.md`                         |           |

---

## Pending

### Release `1.0.1`

Documentation only (the README with the logo and *Why Winter*, the memory in `doc/benchmarks.md`),
the code of `1.0.0`.

1. [x] The [release review](#release-review-before-every-release) (2026-10-31), on
   `release/1.0.1`, on what changed since `1.0.0` (whose review was the same day): the README and
   the guide match the code, the claim of memory measured and recorded; format, analyze, tests,
   the examples, `dart doc`, the doc snippets, `dart pub outdated` and the dry run checked again.
2. [ ] Merge into `main`, tag `v1.0.1`, merge back into `develop`, publish.

### Release `1.0.0`

feather-io (an S3 server) runs on the last rc and dumpling (backups of PostgreSQL) on Winter, so
the rc period ends here; both move to `1.0.0` once it's published.

1. [x] The [release review](#release-review-before-every-release) (2026-10-31), on
   `release/1.0.0`. Found and fixed:
   - **API** (the last chance before 2.0): `Env.find<T>` throws for a missing variable and
     `tryFind<T>` returns null, as `di.find`/`di.tryFind` (it was `find`/`require`; also
     `tryFindEnum`/`findEnum`); `AuthFilter(rule:)` takes any `AuthorizationRule`, with `&`/`|`
     on the base class, so a rule of the app needs no wrapper (`RuleBuilder` gone, the combining
     rules private); `HttpHeader` and the `DefaultOn*` of `RouterConfig` are `abstract final`;
     `TraceContext.tryParse` (it returns null); `Authentication.anonymous` a shared
     `Authentication<String>`; new `Winter.server.port` (the one chosen for `port: 0`).
   - **Tests**: two server tests shared ports 9111/9112 with the SSE and WebSocket tests (random
     failures in parallel), moved to 9113/9114; 17 overlapping tests merged or deleted, 4
     renamed, a real-clock assertion removed, `duplicated_route_test` moved in memory: 1208 tests.
     Coverage 99.68 % (the 14 uncovered lines are the known kinds of `CLAUDE.md`).
   - **Docs**: the README without "experimental" (used in production by feather-io and dumpling,
     both in *Powered by Winter*), install with `dart pub add winter`; stale numbers (~85 % in
     `DECISIONS.md`), the `.and()` of `auth_jwt`, the static routes found by a map, the timeout
     filter in the order of `filters.md`; every example case linked from its guide; a note that
     `logResponse` sees the response before the header check.
   - **Security** (the real server probed on Windows): no medium or high finding. Logs and errors
     without client values, static files (encoded `..`, hidden, 8.3 names, device names,
     junctions), header injection, every body limit, malformed multipart, CORS, the WebSocket
     origin and the forwarded headers all as designed. Low: `LoggingFilter` logs the 200 of a
     response whose headers become a 500 after the pipeline (documented). Info: a 404 echoes a
     long path in `instance` (1:1, not amplified). `dart pub get`: no advisories.
   - Checked: format, analyze, the tests of the 17 example packages, `dart doc` without warnings,
     the 160 doc snippets, the dry run (325 KB). `pana` in the CI (no Docker here).
2. [x] The version in `pubspec.yaml` and the CHANGELOG entry with its date (2026-10-31, the last
   commit of the branch), merge into `main`, tag `v1.0.0`, merge back into `develop`.
3. [x] **Published on pub.dev on 2026-10-31** (327 KB, 0 warnings in the dry run; the CI green
   on `main` and `develop`, `pana` **160/160**).
4. [ ] A GitHub release from the tag `v1.0.0`, the announcement (r/dartlang, Dart Discord, X), and
   feather-io and dumpling moved to `1.0.0`.

### Possible improvements after release 🟢

Only if a real use asks for them; none breaks the API.

- [ ] `Content-Digest` (RFC 9530) and HTTP Message Signatures (RFC 9421): they need cryptographic
  hashes and signatures (a `crypto` dependency the project doesn't have), and RFC 9421 is large.
- [ ] A Redis `RateLimiterStore` in its own package (`winter_redis`), so several instances share
  the limit.
- [ ] More languages for Winter's messages (fr, pt, de…): the `*.i18n.yaml` of `lib/src/i18n/`.
- [ ] A trie router, only if a benchmark of a real app shows the lookup of the dynamic routes as a
  cost (the static ones are already a map).
- [ ] A `maxMessageSize` for WebSockets (`dart:io` keeps each whole message with no limit).
- [ ] Notes of the audits that no real use has asked for yet: the health checks run per request
  (no cache, a timeout doesn't cancel them); `checkPreconditions(required: true)` is satisfied by
  an `If-Unmodified-Since` when the app gives no `lastModified`; `ConsoleLogger` doesn't escape the
  C1 controls nor U+2028/U+2029; the WebSocket "same host" check ignores the port; the example
  apps (`auth_jwt` without `iss`/`aud`, sessions without expiry in `files_gallery`).

---

## Done (summary)

The details of each step are in `CHANGELOG.md`, `DECISIONS.md` and the git history.

- **Phase 1, bugs in the core:** `copyWith` of the response, repeated query params, the router in
  DI, tests moved to `WinterTestClient`.
- **Phase 2, system-by-system review (§2–§10):** object mapper, validation, errors (Problem
  Details), DI, configuration, logging, security, router and filters, and everything together in
  `test/integration/`.
- **Phase 3, off shelf and the API frozen (§10, §11):** `dart:io` directly with Winter's own
  `RequestEntity`/`ResponseEntity` (from ~63 % to ~85 % of `dart:io`), deprecated code removed,
  internal helpers hidden.
- **Phase 4, features:** forms, multipart, cookies, static files, HTTPS, `requestTimeout`, gzip,
  health checks, WebSockets, Server-Sent Events, scheduled tasks, OpenAPI, async validation, DI and
  object mapper extras.
- **Phase 5, documentation:** a guide per module in `doc/`, the README, dartdoc with categories,
  `example/` by topic with a test per case.
- **Phase 6, package and CI:** `pubspec.yaml` and `.pubignore`; the CI on Linux and Windows
  (format, analyze, tests, examples, slang, snippets, an obfuscated build, the dry run, pana).
- **Phases 7 and 9, full reviews:** the release review twice (API, a real server probed, tests
  without overlaps, coverage 99.7 %, docs, pana 160/160), with every finding fixed.
- **Phase 8, standards:** RFC 9457, RateLimit headers, W3C Trace Context, trusted proxies,
  conditional requests, `Deprecation`/`Sunset`, `Link`, idempotency keys, `Prefer`, health format.
- **Releases:** `1.0.0-rc.1` (2026-10-09, used in feather-io), `1.0.0-rc.2` (2026-10-20,
  retracted: it carried `build/`), `1.0.0-rc.3` (2026-10-20), `1.0.0-rc.4` (2026-10-22, the
  audits, on pub.dev), `1.0.0-rc.5` (2026-10-22, `AuthFilter(cacheControl:)`, on pub.dev),
  `1.0.0-rc.6` (2026-10-25, the route table of the logs, feather-io), `1.0.0-rc.7` (2026-10-28,
  the git history cleaned of a test credential, rewritten with `git filter-repo`).
- **Audits (2026-10-21/22, in `develop`):** a security audit (8 findings: a quadratic route
  lookup, WebSocket compression, CSRF through `text/plain`, `Forwarded` parsing, singletons in a
  request scope, idempotency memory, `Infinity`, a lost update in the docs) and a quality audit
  (the 422 names, a router 2–3× faster, memory, `Content-Length`), all fixed; hardening (WebSocket
  origin, SRI, `Cache-Control: private`, idempotency per user, log escapes, CI pinned, no tests in
  the package); a confirmation audit that closed the 8 and one variant; benchmarks again.

---

## Release review (before every release)

A review of the whole project from zero, run before each release. Each step is done on the code as
it is, not from memory: read it, run it, fix what fails, and write down here what was found.

1. **Roadmap.** Short and current: what is done in one line each, what is pending at the top.
   Nothing in it that nobody plans to do.
2. **Code and API.** Read the public API (`dart doc` output): no misspelled or inconsistent names,
   no deprecated code, no internal helper exported by mistake (`lib/winter.dart`). Every public
   member has dartdoc and a `{@category}`.
3. **Security.** Probe the real server, not only the tests:
    - Nothing of the client in a log or an error (bodies, query strings, tokens, values of a
      failed deserialization or validation), and a 500 never has details.
    - Static files: `..` (also encoded), hidden files, `\`, device names, links out of the folder.
    - Headers: a response header with CR/LF or non-ASCII is a 500; nothing long echoed back.
    - Limits: `maxBodySize`, multipart part headers, malformed bodies are a 400.
    - CORS (`'*'` with credentials), `allowedOrigins` of the WebSockets, `trustedProxies`.
    - The dependencies: `dart pub outdated` and the advisories of pub.dev.
4. **Tests.** Every use case covered, with no two tests checking the same thing: merge or delete
   the overlapping ones, rename the ones whose name no longer says what they check. No real
   clock, a free port per server test. Coverage at the current level (~99.7 %): look at every
   uncovered line.
5. **Examples.** Every case and app runs (`dart run`) and its tests pass. Add cases for the uses
   that are uncommon but frequent in real APIs; every feature has one, linked from its guide.
6. **Documentation.** Every guide of `doc/`, the README, `CONTRIBUTING.md`, `DECISIONS.md` and
   `CLAUDE.md` match the code: no outdated sentences ("not supported yet"), every snippet compiles
   and runs, every feature has a usage example and a link to its example case. The CHANGELOG lists
   everything.
7. **Checks** (the ones of the CI, by hand): `dart format --set-exit-if-changed .`, `dart analyze`,
   `dart test`, the tests of every example, `dart doc --dry-run` without warnings,
   `dart pub publish --dry-run` (check the size and the file list: rc.2 carried `build/`), `pana`
   (on Linux: in Docker, `dart:stable`, from a clone of the repository; Windows fails), the
   generated `messages*.g.dart` up to date, the benchmarks without a regression
   (`doc/benchmarks.md`).

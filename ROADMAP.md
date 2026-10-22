# Roadmap to 1.0.0

What is missing to publish `winter` 1.0.0: an HTTP framework that covers the main use cases of a
REST API. Not at the level of Spring, but with the basics complete, stable and documented.

**Legend:** 🔴 blocks 1.0 · 🟡 should be in 1.0 · 🟢 after 1.0 (1.x) · ✅ done · ⏸️ on hold

> **Now: `1.0.0-rc.3` is on pub.dev (2026-10-20)**, after `1.0.0-rc.1` (2026-10-09) was used in a
> real project and `1.0.0-rc.2` was retracted. Phases 1 to 9 are done (8: the standards, after the
> rc; 9: the review after them), and so is the CI (6.1). Next: `1.0.0` (6.5).

The decisions behind each point are in `DECISIONS.md` (§ numbers below), the behavior in the
tests, and the usage in `doc/`.

---

## 0. What "1.0" means

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
   with a good pana score, and the CI (6.1) runs them on `develop` and `main`.
5. At least one release candidate (`1.0.0-rc.1`, then `1.0.0-rc.3`) was published and used in a
   real project.

---

## 1. Current state

| Module                                                         | Guide                            | Decisions |
|----------------------------------------------------------------|----------------------------------|-----------|
| HTTP engine on `dart:io`, own `RequestEntity`/`ResponseEntity` | `requests-and-responses.md`      | §10       |
| Pipeline, filters, request scope (`Zone`)                      | `architecture.md`, `filters.md`  | §9, §10   |
| Router (nested, regex, 404/405, HEAD, static files, health)    | `routing.md`                     | §9        |
| Object mapper                                                  | `object-mapper.md`               | §2        |
| Validation (sync and async)                                    | `validation.md`                  | §3        |
| Errors (Problem Details)                                       | `error-handling.md`              | §4        |
| Dependency injection                                           | `dependency-injection.md`        | §5        |
| Configuration (`Env`, `ServerConfig`)                          | `configuration.md`               | §6        |
| Logging (request id, JSON logger)                              | `logging.md`                     | §7        |
| Security (auth, CORS, rate limit, headers)                     | `security.md`                    | §8        |
| i18n (slang + YAML, `Accept-Language`)                         | `i18n.md`                        | §1        |
| WebSockets and Server-Sent Events                              | `requests-and-responses.md`      | §10       |
| OpenAPI and Swagger UI                                         | `openapi.md`                     | §12       |
| Scheduled tasks                                                | `scheduling.md`                  | §13       |
| Testing in memory (`WinterTestClient`)                         | `testing.md`                     |           |
| Deployment, benchmarks                                         | `deployment.md`, `benchmarks.md` |           |
| CI / publishing                                                | `.github/workflows/ci.yml`, `CONTRIBUTING.md` |  |

---

## Done

### Phase 1: bugs in the core ✅

- `ResponseEntity.copyWith` lost or re-serialized the body when a filter added headers.
- Repeated query params were lost (`?tag=a&tag=b`) → `queryParamsAll`.
- `Winter.start` looked for the router in DI with the wrong type.
- The tests on a real server were moved to `WinterTestClient`, except those of the server itself.

### Phase 2: system-by-system review ✅

Each system was read, its problems written as tests first, decided in `DECISIONS.md`, fixed and
documented. The behavior of each one is in its `*_behavior_test.dart`.

- **2.1 Object mapper (§2):** types found by `Type`, never by name (it broke with obfuscation and
  with two classes of the same name); `T?`/`List<T>`/`Set<T>`/`Map<String, T>` derived from `T`;
  duck-typed `toJson()` (`Serializable` removed, so `json_serializable`/`freezed` work); a
  serializer applies to subtypes; `DateTime` always UTC; strict primitives; errors as
  `$.path: reason` without Dart internals; 415 for a body that isn't JSON; options `includeNulls`,
  `fieldNaming`, `durationFormat`, `prettyPrint`; `encode` in a single pass (×3.5 → ×1.1).
- **2.2 Validation (§3):** `pattern(RegExp)` never matched; `ConstraintViolation` renamed; typed
  validators (`cvc.field(name, value)`) that run as they are chained; `code` and `params` in each
  violation, never the value; `body<T>()` validates; `valid()`/`validEach()` for nested objects;
  `url`, `uuid`, `positive`, `past`/`future`, `notEmpty`, `oneOf`.
- **2.3 Errors (§4):** Problem Details (RFC 9457) for every error; the exceptions become a response
  where they are thrown, so every filter sees it; `SimpleExceptionHandler.on<T>()`;
  `ApiException(status)` plus shortcuts.
- **2.4 Dependency injection (§5):** a service locator by exact type, `T` and `T?` the same key,
  `isRegistered`, `putLazy`/`putFactory`/`putScoped`, `onDispose` on shutdown, cycles detected.
- **2.5 Configuration (§6):** `Env.load()` with profiles, `require`/`requireAll`, nullable types,
  errors without values; `ServerConfig` is `const` and validated, `ServerConfig.fromEnv`.
- **2.6 Logging (§7):** `JsonLogger`, request id in every log and response, `fields` and errors at
  every level, `isEnabled`, UTC, never a value of the client in a log.
- **2.7 Security (§8):** CORS warns about `'*'` with credentials, varies by origin and exposes
  `X-Request-Id`; `WWW-Authenticate` on 401; typed principal; roles and permissions only; rules
  that see the request; `SecurityHeaders`; async rate limiter over a `RateLimiterStore`.
- **2.8 Router and filters (§9):** read-only routes, immutable `FilterConfig`, a broken route
  table fails at start, duplicates by method and shape, typed `pathParam<T>`/`queryParam<T>`
  (400), automatic `OPTIONS`; `GET //users` and regex params fixed.
- **2.9 Everything together (§10):** `test/integration/` runs a whole app in memory and the real
  server against `WinterTestClient`; fixed the charset of text bodies, the names of Problem
  Details following `fieldNaming`, and `X-Powered-By`.

### Phase 3: remove shelf and freeze the API ✅

- **3.1 `dart:io` (§10):** `HttpServer` directly, own `RequestEntity`/`ResponseEntity`
  (multi-value headers, cookies, one `copyWith`), HTTPS, `autoCompress`, `idleTimeout`, errors of
  the HTTP layer, in-memory testing with the same pipeline. From ~63 % to ~85 % of `dart:io`.
- **3.2 Public API (§11):** deprecated code removed, `StatusCode` a single enum, internal helpers
  hidden (`export ... hide`), names reviewed, no `dart doc` warnings.

### Phase 4: features ✅

- **4.1 HTTP:** response shortcuts (`created`, `noContent`, redirects…), forms (`formData()`),
  multipart with its own parser (`multipart()`, §10), cookies, `Route.static` (ETag, Range, no
  traversal, §9), every kind of body (`bytes()`), HTTPS.
- **4.2 Operations:** `requestTimeout` (503), gzip, `Route.health`, `di.createAll()`.
- **4.3 More features:** WebSockets (`Route.websocket`, `allowedOrigins`, §10), Server-Sent Events
  (`ResponseEntity.sse`, §10), scheduled tasks (`Scheduler`, `every`/`cron`, §13), OpenAPI
  (`Route.openApi`, `Route.swaggerUi`, `RouteDocs`, `JsonSchema`, §12), `AsyncValidatable` (§3).
    - DI: `putLazyAsync` + `ready()`/`findAsync`, `di.child()` for tests, `di.registrations`.
    - Validation: `Map<String, Validatable>`, LRU for `pattern()`, `copyWith(code: () => null)`.
    - Object mapper: `JsonAdapter<T>`, typed fields for a hand-written `fromJson`
      (`json.field<T>()`, `json.object()`), `TestResponse.as<T>()`, a warning when replacing the
      mapper loses registrations, `encodeBytes`/`decodeBytes` (16–46 % faster), `PatchValue<T>`,
      `rejectUnknownFields`, `mapWithKeys<K>()`.
    - Not possible on purpose: reading an unregistered class or serializing records; both need
      reflection or codegen (§11).

### Phase 5: documentation ✅

- A guide per module in `doc/` (index in `doc/README.md`), each with runnable snippets, plus
  `getting-started.md`, `architecture.md`, `testing.md`, `deployment.md` and `benchmarks.md`.
- README and `CONTRIBUTING.md` rewritten. No migration guide (first version).
- Dartdoc on the whole public API, one `{@category}` per module, no warnings.
- `example/` reorganized by topic, one file per case with its test (`routing`, `bodies`,
  `validation`, `object_mapper`, `openapi`, `realtime`, `scheduling`, `i18n`), and the apps
  `auth_jwt`, `orders`, `files_gallery` and `production`.

### Phase 6: package and final review ✅ (except 6.1 and 6.4)

- **6.2 Package:** `pubspec.yaml` metadata and topics, `.pubignore`, `crypto` removed, tests pass
  with the minimum versions of the runtime dependencies.
- **6.3 Final review:** security review against the real server (header injection now a 500, a
  415 no longer echoes a long `Content-Type`; slow clients and header sizes are a proxy's job,
  `doc/security.md`); benchmarks published (`doc/benchmarks.md`); coverage 99.6 %.

### Phase 7: second full review ✅

The [release review](#release-review-before-every-release), the first time (2026-10-09).

- **Roadmap:** condensed, the pending points at the end.
- **Code and API:** the 971 public elements of `dart doc` read by class. `RateLimiter` takes
  `maxRequests:` and `window:` like its filter; `Winter.timestamp` → `startedAt`;
  `WinterContext.timestamp` removed.
- **Security:** a real server probed with raw requests. Fixed: a body rejected half read (a
  chunked body over `maxBodySize`, a part header over its limit) closed the connection without
  the 413/400; now the rest is read and discarded. Documented: open redirects, `%2F` in a path
  param, `Content-Length` with `Transfer-Encoding`.
- **Tests:** from 1325 tests in 94 files to 1155 in 76, without overlaps; coverage from 98.4 % to
  99.7 %. Fixed: OpenAPI wrote an `ApiKey` challenge as an HTTP scheme that doesn't exist, and
  `WinterTestClient` sent a `List<int>` body as bytes (only a `Uint8List` is bytes now).
- **Examples:** five new topics, 23 cases (`api_patterns`, `security`, `filters`, `errors`, `di`).
- **Documentation:** every snippet analyzed against the API, outdated sentences fixed, each guide
  linked to its examples, `doc/comparison.md`, the README rewritten as a walk-through.
- **Checks:** format, analyze, tests, examples, `dart doc`, the publish dry run, and `pana`
  **160/160** on Linux (Docker). The benchmarks showed no regression; refreshing
  `doc/benchmarks.md` needs a quiet machine.

### Phase 8: standards ✅

The behaviors of the framework moved to the RFCs and drafts that clients, gateways and tracing
tools already read, by priority (impact against effort). Each one with its guide, decision,
example case and tests.

- **RFC 9457 complete (§4):** `instance` (the path, never the query), `ProblemDetails.fromJson`
  (lenient, §3.1), `application/problem+json` only for a `ProblemDetails` body.
- **RateLimit headers (§8):** `RateLimit-Policy`/`RateLimit` of the IETF draft instead of
  `X-RateLimit-*`, a `policy` per filter.
- **W3C Trace Context (§7):** `traceparent`/`tracestate`, `requestTrace`, a span per request,
  `traceId`/`spanId` in `JsonLogger`, the trace id as the request id.
- **Trusted proxies (§8):** `ServerConfig.trustedProxies` (`Forwarded` of RFC 7239 or
  `X-Forwarded-*`, one kind only) for `clientIp()` and `requestedUri`.
- **Conditional requests (§10):** the 304 of the server for any `GET`, `checkPreconditions`
  (412, 428), static files on the same code.
- **Deprecation (§9):** `DeprecationFilter` (`Deprecation` RFC 9745, `Sunset` RFC 8594, links,
  `deprecated` in OpenAPI).
- **`Link` (§10):** `WebLink` and `WebLink.pages` for pagination (RFC 8288).
- **Idempotency keys (§9):** `IdempotencyFilter` over an `IdempotencyStore` (IETF draft).
- **`Prefer` (§10):** `request.preferences` (RFC 7240), `Vary: Prefer` by itself.
- **Health (§9):** `Route.health` answers `application/health+json` (`pass`/`fail`).

### Phase 9: third full review ✅

The [release review](#release-review-before-every-release) after phase 8 (2026-10-19), with a
quality audit of the whole code: five reviews at once (the server, the context modules, security
against a real server, the tests, the docs and the API), then every finding fixed with its test.

- **Security (real server):** the URI of a request came from `dart:io`'s `requestedUri`, which
  takes `X-Forwarded-Host`/`-Proto` from any client and glues them before the path: a client chose
  the host, the scheme and even the routed path (`X-Forwarded-Host: h/static/ENV~1?` read a
  `.env`). Now it's the request target, the scheme of the server and a valid `Host`. Static files
  on Windows served hidden files by their 8.3 short name (`ENV~1`): the real names are checked
  too. Two idempotency partitions could share an id through a space; CORS echoed any
  `Access-Control-Request-Headers` (a 500 on demand); `Prefer` had no size limit.
- **Bugs:** cron `*/2` in the day of the month ran every day; a typed response without body broke
  `IdempotencyFilter` and locked its key; the query string wasn't part of an idempotent request;
  a request that timed out disposed its scoped dependencies under the handler still running; every
  SSE connection left a listener until shutdown; typed params took `NaN`, `Infinity` and hex; the
  422 named the fields with the global mapper when `body<T>()` had its own; integers beyond 64 bits
  were clamped; a date without offset was read in the server's time zone; a hidden parent didn't
  hide its children in OpenAPI.
- **Limits:** objects nested more than 128 levels are a 400 (they cost seconds), the cache of
  renamed keys is bounded, `InMemoryIdempotencyStore` keeps at most `maxKeys`, an IPv6 client
  counts by its /64 in the rate limiter.
- **API:** `clientIp` is a getter, `RequestPreconditionsX`, the reason phrases of RFC 9110
  (`ContentTooLargeException`, `UnprocessableContentException`, 421), no `Set-Cookie2`, `Warning`
  nor 509, the categories of the request getters, `Scheduler.cron(runOnStart:)`.
- **Tests:** from 1237 to 1215, without overlaps, without the real clock, coverage 99.7 % (the
  rest: other platforms, races and unreachable code, listed in `CLAUDE.md`).
- **Docs:** 21 outdated sentences (Problem Details without `instance`, hand-written health checks,
  `change()`, the pipeline of `architecture.md`...), every snippet analyzed against the API (none
  broken), no broken link.
- **Checks:** format, analyze, tests, every example, `dart doc`, the publish dry run, `pana`
  **160/160** on Linux (Docker), `messages*.g.dart` up to date, `dart pub outdated` only minor
  updates. Benchmarks without a regression: 81–85 % of `dart:io` (noisy machine), the router
  ~225 000 req/s, the mapper as before.
- **Not done, on purpose:** `fieldNaming` renames the whole object given to `Deserializer.json`
  (map fields included) but writes only the top of a `toJson()`, a known limitation (§2). A cycle
  of async dependencies found concurrently waits forever (`ready()` is safe; documented).

---

## Release review (before every release)

A review of the whole project from zero, run before each release (the first time as phase 7).
Each step is done on the code as it is, not from memory: read it, run it, fix what fails, and
write down here what was found.

1. **Roadmap.** Short and current: what is done in one line each, what is pending at the end.
   Move anything finished out of *Pending*; nothing in it that nobody plans to do.
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
   every feature.
7. **Checks** (the ones of 6.1, by hand): `dart format --set-exit-if-changed .`, `dart analyze`,
   `dart test`, the tests of every example, `dart doc --dry-run` without warnings,
   `dart pub publish --dry-run`, `pana` (on Linux: in Docker, `dart:stable`, from a clone of the
   repository; Windows fails), the generated `messages*.g.dart` up to date,
   the benchmarks without a regression (`doc/benchmarks.md`).

---

## Pending

### 6.4 Release

Every release (the rc included) goes through the
[release review](#release-review-before-every-release) first. The package `winter` already
exists on pub.dev (0.0.7, the same repository), so each release is a new version of it.

1. [x] **`1.0.0-rc.1` published on pub.dev on 2026-10-09**: `pana` 160/160, merged into `main`
   (`release/1.0.0-rc.1`), tag `v1.0.0-rc.1`. pub.dev keeps 0.0.7 as the latest stable until
   1.0.0, and the installation commands name the version (pub only picks a prerelease when asked).
2. [x] Use it in a real project for a few weeks (feather-io). Already in *Powered by Winter* in
   the README, with a teaser of Almond.
3. [x] **`1.0.0-rc.2` published on 2026-10-20 and retracted**: phases 8 and 9 (the
   [release review](#release-review-before-every-release) ran as phase 9, 2026-10-19), tag
   `v1.0.0-rc.2`. Its package carried the executables of the benchmarks (`build/`, added to the
   release commit by mistake): 12 MB instead of 0.5 MB. `build/` is ignored by git and pub now.
4. [x] **`1.0.0-rc.3` published on pub.dev on 2026-10-20**: the same code without them (489 KB),
   `release/1.0.0-rc.3` merged into `main`, tag `v1.0.0-rc.3`. Check the size of the archive in
   the dry run before every release.

### 6.1 CI ✅

`.github/workflows/ci.yml`, on a push to `develop` or `main` and on the pull requests to them, not
on every push of a feature branch (`CONTRIBUTING.md`):

- [x] GitHub Actions: `dart format --set-exit-if-changed`, `dart analyze`, `dart test` with
  coverage (Codecov when the repository has `CODECOV_TOKEN`), and the analysis and tests of every
  example, on Linux and Windows (SDK 3.13.1, the lowest supported).
- [x] `messages*.g.dart` up to date: `dart run slang` with the lowest slang of `pubspec.yaml`
  (`dart pub downgrade slang`) + `git diff --exit-code`. It found the messages of `example/i18n`
  generated by a newer slang.
- [x] `pana` on Linux, red below 150 of 160 (a new major version of a dependency is 10 points).
- [x] The snippets of the docs: `tool/check_doc_snippets.dart` analyzes the 157 Dart blocks of
  `README.md` and `doc/` (136 analyzed; 21 fragments like `routes: [...]` don't parse alone). Only
  an error about Winter counts, not a name of the app the fragment doesn't define.
- [x] An obfuscated AOT build (`tool/obfuscation/main.dart`, `--expect-obfuscated`): generic
  types, two classes with the same name and a failing `fromJson` work, and the errors have no
  obfuscated names.
- [x] The publish dry run without warnings and an archive under 1 MB (after `1.0.0-rc.2`).

### 10. Security and quality audits (2026-10-21)

A security audit (`security-audit`: 31 coverage units, every finding reproduced in a sandbox with
no network and checked by two independent verifiers) and a quality audit (`ponytail-audit`) of
`develop` @ `e8707db`. One commit per item in `feature/audit-fixes`, each with its regression test;
the public API keeps working (only new optional parameters).

Security, by severity:

1. [x] **High.** `normalizePath` removed trailing slashes with one `substring` per slash, once
   per route, before any filter: `GET /x` + 40 000 `/` blocked the isolate ~3 s with 5 routes,
   unauthenticated. Now a single pass.
2. [x] **Medium.** WebSockets negotiated permessage-deflate by default, and `dart:io` keeps each
   whole message with no limit: 8 KB on the wire became 8 MiB in the handler, past `maxBodySize`.
   Now off unless the route asks for it (`Route.websocket(compression:)`). `dart:io` has no
   message limit to set; documented.
3. [x] `body<T>()` read JSON from `text/plain` or without `Content-Type`, what a cross-site page
   sends without a CORS preflight (CSRF on cookie sessions). Now a 415 for a typed body (an empty
   one without type is still `null`); clients send `Content-Type: application/json`.
4. [x] An unterminated quoted string in a client's `Forwarded` swallowed the element the proxy
   appends on the same line: the client chose `clientIp`, host and scheme. Now such a line makes
   the whole header ignored (the connection address).
5. [x] A `putLazy`/`putLazyAsync` singleton was created inside the zone of the first request that
   finds it: its listeners and timers saw that request's authentication and id forever. Now it is
   created outside any `RequestScope`.
6. [x] `InMemoryIdempotencyStore` bounded the keys, not the bytes: 16-byte requests kept 512 KiB
   responses (up to tens of GiB at 100 000 keys). Now `maxBytes` too (64 MB by default).
7. [x] A `double`/`num` took `1e400` as `Infinity`: it passed the validators and every later
   response that serialized it was a 500. Now a 400 (`got a number too big`), as for `int`.
8. [x] The guide and the `api_patterns` example awaited the body between `checkPreconditions`
   and the save: two writers with the same `If-Match` both passed (lost update). Now the body first.

Quality:

9. [x] `body<T>(objectMapper:)` renamed the fields of a 422 twice (its mapper, then the global
   `om`). Now `ValidationException(objectMapper:)` carries the mapper that names them, once.
10. [x] The router matched the regex of every route on each request, up to three times on a 404.
    Now the static routes are found by their path (router benchmark ~62 000 → 165 000+ req/s).
11. [x] The fingerprint of `IdempotencyFilter` copied the whole body into a `List<int>` (~80 MB
    for 10 MB). Now it hashes the bytes in place (same hash).
12. [x] With `autoCompress`, a stream response (static files, 206) lost its `Content-Length`
    although `dart:io` never compresses it. Now only a body of bytes leaves it out.
13. [x] Small ones: request/trace ids from one helper, 4 random bytes per call (they took one per
    byte); one SSE `Timer` per stream, not per event; one `typeOf`, not three. Not done: sorting
    the filters of each request (3-6 of them, a stable sort; caching it costs more code than it
    saves).

Hardening (no finding), in `feature/hardening`:

14. [x] `Route.websocket` without `allowedOrigins` accepted any `Origin`: now only a page of the
    same host (the host only, as behind a proxy the scheme and port differ).
15. [x] Swagger UI loaded its two files from unpkg without Subresource Integrity, under a CSP that
    allowed all of unpkg: now `integrity` (SHA-384) and a CSP with only those two files.
16. [x] The CI ran with the default token and actions by tag: now `permissions: contents: read` and
    every action pinned by commit.
17. [x] A response behind `AuthFilter` had no `Cache-Control`: now `private` unless it has one.
18. [x] `IdempotencyFilter` without `partition` shared the keys of every user (a response, its
    `Set-Cookie` included, replayed to another with the same key and body): now a principal that
    is a `String` or a number is the partition, and another kind logs a warning once.
19. [x] `ConsoleLogger` wrote control characters as they came: now escaped (`\n`, `\x1b`), so a
    value of the client can't forge a log line nor send terminal codes.
20. [x] `ServerConfig.requestTimeout` had no limit by default: now 30 seconds (`null` for none).
21. [x] The package carried `test/` (with the TLS key of the tests as a "false secret"): now left
    out (483 KB to 320 KB).
22. [x] The CI installed the latest `pana`, so a new release could change the score by itself: now
    a fixed version.

Already decided, not redone: `fieldNaming` renames the map fields of an object given to
`Deserializer.json` (phase 9, §2).

### 6.5 Release `1.0.0`

1. [ ] Fix what comes up in 6.4 and publish `1.0.0`: tag `v1.0.0`, the version in `pubspec.yaml`,
   CHANGELOG with the date, announcement (r/dartlang, Dart Discord, X).

### Possible improvements after release 🟢

Only if a real use asks for them; none breaks the API.

- [ ] `Content-Digest` (RFC 9530) and HTTP Message Signatures (RFC 9421), the last standard of
  phase 8: they need cryptographic hashes and signatures (a `crypto` dependency the project
  doesn't have), and RFC 9421 is a large spec.
- [ ] A Redis `RateLimiterStore` in its own package (`winter_redis`), so several instances share
  the limit.
- [ ] More languages for Winter's messages (fr, pt, de…): the `*.i18n.yaml` of `lib/src/i18n/`.
- [ ] A trie router, only if a benchmark of a real app shows the linear lookup as a cost.
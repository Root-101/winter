# Roadmap to 1.0.0

What is missing to publish `winter` 1.0.0: an HTTP framework that covers the main use cases of a
REST API. Not at the level of Spring, but with the basics complete, stable and documented.

**Legend:** 🔴 blocks 1.0 · 🟡 should be in 1.0 · 🟢 after 1.0 (1.x) · ✅ done · ⏸️ on hold

> **Decision (2026-10-08): no release for now.** Everything still pending is finished first (4.3
> and the reorganization of `example/`, both done), then a second full review (phase 7), and only
> then the release (6.4). The CI (6.1) stays postponed.

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
   with a good pana score. The CI comes after 1.0 (6.1).
5. At least one release candidate (`1.0.0-rc.1`) was published and used in a real project.

---

## 1. Current state

| Module                                                             | Guide                          | Decisions |
|--------------------------------------------------------------------|--------------------------------|-----------|
| HTTP engine on `dart:io`, own `RequestEntity`/`ResponseEntity`     | `requests-and-responses.md`    | §10       |
| Pipeline, filters, request scope (`Zone`)                          | `architecture.md`, `filters.md`| §9, §10   |
| Router (nested, regex, 404/405, HEAD, static files, health)        | `routing.md`                   | §9        |
| Object mapper                                                      | `object-mapper.md`             | §2        |
| Validation (sync and async)                                        | `validation.md`                | §3        |
| Errors (Problem Details)                                           | `error-handling.md`            | §4        |
| Dependency injection                                               | `dependency-injection.md`      | §5        |
| Configuration (`Env`, `ServerConfig`)                              | `configuration.md`             | §6        |
| Logging (request id, JSON logger)                                  | `logging.md`                   | §7        |
| Security (auth, CORS, rate limit, headers)                         | `security.md`                  | §8        |
| i18n (slang + YAML, `Accept-Language`)                             | `i18n.md`                      | §1        |
| WebSockets and Server-Sent Events                                  | `requests-and-responses.md`    | §10       |
| OpenAPI and Swagger UI                                             | `openapi.md`                   | §12       |
| Scheduled tasks                                                    | `scheduling.md`                | §13       |
| Testing in memory (`WinterTestClient`)                             | `testing.md`                   |           |
| Deployment, benchmarks                                             | `deployment.md`, `benchmarks.md`|          |
| CI / publishing                                                    | ❌ Postponed (6.1, 6.4)         |           |

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

---

## Release review (before every release)

A review of the whole project from zero, run before each release (and as phase 7 before the
first one). Each step is done on the code as it is, not from memory: read it, run it, fix what
fails, and write down here what was found.

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
   `dart pub publish --dry-run`, `pana` (on Linux), the generated `messages*.g.dart` up to date,
   the benchmarks without a regression (`doc/benchmarks.md`).

---

## Pending

### Phase 7: second full review 🔴

The [release review](#release-review-before-every-release), the first time.

- [x] Roadmap: condensed, the pending points at the end.
- [x] **Code and API:** the 971 public elements of the `dart doc` output read by class. Everything
  exported is meant to be (`internalServerErrorResponse` and `QueryParam` on purpose). Changed:
  `RateLimiter(5, window)` → `RateLimiter(maxRequests: 5, window: ...)`, like its filter;
  `Winter.timestamp` → `Winter.startedAt`; `WinterContext.timestamp` removed (unused). Kept: the
  seconds of a header as an `int` everywhere (`maxAge`, `retryAfter`, `hstsMaxAge`), and
  `Scheduler.isStarted` vs `ScheduledTask.isRunning` (two different things).
- [ ] Security.
- [x] **Tests:** from 1325 tests in 94 files to 1154 in 76, and the coverage from 98.4 % to
  99.7 % (it had dropped with OpenAPI). Merged or removed the overlapping ones: the old
  `object_mapper_test` (stale names: `Serializable`, `StateError`), five validation files, three
  of `AuthFilter`, six of the filter chain into `filters_pipeline_test`, `copy_with`, `body_cache`,
  `bad_path` (a real server for what `router_config` checks in memory), `params`, `route_key`,
  the two identical basic routing files, `authorization_rules` (stale "authority", `andd()`),
  `env`, and the CORS cases of the behavior tests. New tests for every option of `JsonSchema`
  and `withRules`, `json.object()` with the global mapper, `PatchValue` equality, a `fromJson`
  that changes its map, `ResponseEntity.sse(headers:)`. Found and fixed:
  - OpenAPI wrote `AuthFilter(challenge: 'ApiKey header="X-API-Key"')` as an HTTP scheme
    `apikey` (it doesn't exist); now `{type: apiKey, in: header, name: X-API-Key}`.
  - `WinterTestClient` sent a `List<int>` body as raw bytes, while `ResponseEntity` writes it as
    JSON; now only a `Uint8List` is bytes, in both.
  - Not covered on purpose: defensive code, races, other platforms, the `onPause` of an SSE
    stream and a local time skipped by daylight saving.
- [x] **Examples:** five new topics with 23 cases: `api_patterns` (pagination, ETag/`If-Match`,
  content negotiation, streamed downloads, `202` jobs, idempotency keys, versioning), `security`
  (API keys, Basic auth, webhook signatures, CORS with cookies, login throttling, ownership),
  `filters`, `errors` and `di`. Every example package passes.
- [x] **Documentation:** every Dart snippet of `doc/` and the README extracted and analyzed
  against the API (no wrong name; one snippet with a broken string fixed in
  `dependency-injection.md`); outdated sentences fixed (forms "not supported yet", the 401
  without `WWW-Authenticate`, `X-Request-Id` "planned"); `doc/README.md` without the "planned"
  column and with the examples of each guide; each guide links its new example topic, and
  `requests-and-responses.md` has the patterns of `api_patterns` with snippets.
- [ ] Checks: format, analyze, tests, every example, `dart doc` and the publish dry run pass;
  `pana` (on Linux) and the benchmarks are left for the release.

### 6.4 Release ⏸️

After phase 7. Decide the version (`0.1.0` today, or the plan below); every release (the rc
included) goes through the [release review](#release-review-before-every-release) first.

1. [ ] `1.0.0-rc.1`, used in a real project for a few weeks.
2. [ ] Fix what comes up and publish `1.0.0`: tag `v1.0.0`, CHANGELOG with the date, announcement
   (r/dartlang, Dart Discord, X).

### 6.1 CI 🟢 (after 1.0)

Until then the same checks run by hand. Notes: run on a push to any branch and on pull requests;
`pana` fails on Windows (start it report-only on Linux); Codecov needs `CODECOV_TOKEN`.

- [ ] GitHub Actions: `dart format --set-exit-if-changed`, `dart analyze`, `dart test` with
  coverage, and the tests of every example, on Linux and Windows.
- [ ] `messages*.g.dart` up to date (`dart run slang` + `git diff --exit-code`).
- [ ] `pana` with a score threshold.
- [ ] The snippets of the docs compile (`doc/snippets/*.dart` or `code_excerpter`).
- [ ] An obfuscated AOT build (`--extra-gen-snapshot-options=--obfuscate`) that serializes generic
  types, two classes with the same name and a failing `fromJson`: the mapper works and its errors
  have no obfuscated names.

### Possible improvements 🟢

Only if a real use asks for them; none breaks the API.

- [ ] A Redis `RateLimiterStore` in its own package (`winter_redis`), so several instances share
  the limit.
- [ ] More languages for Winter's messages (fr, pt, de…): the `*.i18n.yaml` of `lib/src/i18n/`.
- [ ] A trie router, only if a benchmark of a real app shows the linear lookup as a cost.

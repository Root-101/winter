# Roadmap to 1.0.0

What is missing to publish `winter` 1.0.0: an HTTP framework that covers the main use cases of a
REST API. Not at the level of Spring, but with the basics complete, stable and documented.

It comes from a full review of the code (`lib/src`, tests, examples and docs) at version `0.1.0`
(branch `feature/retake_project`). It replaces `todo.md` and the *Future Roadmap* section of the
README: once adopted, delete `todo.md` and link this file from the README.

**Legend:** 🔴 blocks 1.0 · 🟡 should be in 1.0 · 🟢 after 1.0 (1.x) · ✔️ confirmed with a script

---

## 0. What "1.0" means

1.0 is a promise of **API stability**: from then on, a breaking change requires a 2.0. That's why
the most important work before publishing is not adding features, but **leaving the public API the
way we want to maintain it**. Exit criteria:

1. The public API is reviewed: no misspelled names, deprecated code or internal helpers exported by
   mistake.
2. It covers the typical use cases of an API: CRUD with JSON, validation, consistent errors,
   authentication and authorization, CORS, forms and file uploads, static files, configuration per
   environment, logs, tests and deployment.
3. Every module has its own document in `doc/`, the whole public API has dartdoc, and there is a
   migration guide from 0.x.
4. There is CI (analyze, format, tests, coverage, examples) and a good pana score (pub points).
5. At least one release candidate (`1.0.0-rc.1`) was published and used in a real project.

---

## 1. Current state

| Module                                                                                  | State                                      |
|-----------------------------------------------------------------------------------------|--------------------------------------------|
| Pipeline (`buildHandler`, filters, exception handler inside the chain)                  | ✅ Solid                                    |
| Router (nested, regex, static routes first, 404/405 + `Allow`, HEAD→GET, `MultiRouter`) | ✅ Solid, with benchmark                    |
| Lifecycle (graceful shutdown, signals, body limit with 413)                             | ✅                                          |
| Request scope (`Zone`): `requestAuthentication`, `requestLocale`                        | ✅                                          |
| i18n (slang + YAML, `Accept-Language`, automatic `Vary`)                                | ✅ Documented in `DECISIONS.md`             |
| Testing (in-memory `WinterTestClient`)                                                  | ✅                                          |
| HTTP engine (`shelf` + `shelf_io`)                                                      | ⚠️ To be replaced by `dart:io` → phase 3.1 |
| Object mapper                                                                           | ✅ Reviewed (2.1), `doc/object-mapper.md`   |
| Validation                                                                              | ✅ Reviewed (2.2), `doc/validation.md`      |
| Exceptions, DI, Env, logging, security                                                  | ⚠️ Work, to be reviewed → phase 2          |
| Documentation                                                                           | ❌ The biggest gap                          |
| CI / publishing                                                                         | ❌ No CI                                    |

---

## Phase 1: bugs in the core 🔴

Bugs of the pipeline and the entities. The bugs of a specific system (object mapper, validation…)
are in its section of phase 2, so each system is reviewed as a whole.

- [x] ✔️ **`ResponseEntity.copyWith` loses or corrupts the body.** `CorsFilter` and
  `RateLimiterFilter` add headers with `copyWith`, which rebuilds the response from the original
  value of the body (`_bodyValue`):
    - After `change(body: bytes)` on a `ResponseEntity<String>`, the body is **lost** (it's empty).
    - On a `ResponseEntity<dynamic>`, the bytes are **serialized as JSON** (`[104,105]` instead of
      `hi`).
    - With an object, every filter that adds headers **runs `jsonEncode` on the body again**: no
      error, but repeated work on every response.
    - Fix: the filters use `change(headers: ...)` (it doesn't touch the already resolved body), and
      `copyWith` only re-serializes when it receives a new `body`.
- [x] ✔️ **Repeated query params are lost:** `?tag=a&tag=b` gives `{tag: b}`. Add `queryParamsAll`
  (`Map<String, List<String>>`, with `Uri.queryParametersAll`).
- [x] **`Winter.start` looks for the router in DI as `WinterRouter`, but registers it as
  `AbstractWinterRouter`.** A `MultiRouter` registered with `di.put<AbstractWinterRouter>` is
  ignored. Look it up as `AbstractWinterRouter`.
- [ ] Tests: many still start a real server on a fixed port, which makes them slow and fragile in
  parallel. Move them to `WinterTestClient` little by little (🟡, not blocking).

---

## Phase 2: system-by-system review 🔴

Each system is reviewed on its own: its API, its behavior, its errors and how it fits with the
rest. The result of each review is a list of decisions; the breaking ones are applied before
freezing the API (phase 3), and each one goes to `DECISIONS.md` like i18n did.

The **object mapper** gets the most time: it's the system with the deepest design limits, and the
others (validation, exceptions, `ResponseEntity`) depend on it.

Steps for every system:

1. Read the code and its tests, and write down how it is used in the examples.
2. Write a test for each problem listed below before touching anything.
3. Decide (and record in `DECISIONS.md`): keep, change or remove.
4. Implement, update the CHANGELOG and the migration guide.
5. Write its document in `doc/` (phase 5), now that it won't change.

### 2.1 Object mapper (dedicated review) ✅

**Done** (2026-10-06, commits `716b572` and `0add5e1`, then `Deserializer.enumByName`, the typed
constructors `string`/`integer`/`number`/`boolean` and `body<T>(objectMapper:)`, §2.10): every
decision is in `DECISIONS.md` §2,
the behavior in `test/object_mapper/object_mapper_behavior_test.dart` (100% line coverage of the
mapper), the guide in `doc/object-mapper.md` and the numbers in
`benchmark/object_mapper_benchmark.dart`. What is left of the object mapper is in other phases:
the format of the error body (2.3), `validBody<T>()` (2.2), the migration guide and
`requests-and-responses.md` (5.2), example `05` (5.4) and the obfuscation check in CI (6.1).

**Before the review:** a registry of `Serializer<T>`/`Deserializer<T>` by exact `Type`, the `Serializable`
interface, recursive serialization, and `List<T>` / `Map<String, T>` found by the **name** of the
type.

**Problems found:**

- [x] **Generic types are found by name** (`k.toString() == typeName` in
  `_extractListElementType` / `_extractMapValueType`):
    - Two `User` classes from different libraries collide (the 400 even sent the paths of the
      server's files to the client).
    - With `dart compile exe --extra-gen-snapshot-options=--obfuscate` the names change and it
      stops working.
    - `List<List<T>>`, `Set<T>` and nullable types (`body<User?>()`) are not supported, or fail with
      a 500 (`StateError`) instead of a 400.
    - → Found by `Type`; `T?`, `List<T>`, `Set<T>`, `Map<String, T>` derived from `T`, deeper types
      with `deserializerOf<T>().list()` (§2.1). Checked with an obfuscated AOT build.
- [x] ✔️ **A class with `toJson()` that doesn't implement `Serializable` gives a 500**
  (`Bad state: Generated need to implement the Serializable interface`). That's exactly what
  `json_serializable` and `freezed` generate, so the most common way of writing models in Dart
  doesn't work without adding `implements Serializable` to each one. → `toJson()` is called
  dynamically and `Serializable` was removed (§2.2).
- [x] **Serializers are found by the exact `runtimeType`:** a serializer for `Animal` doesn't apply
  to `Dog`. The default `Serializer<num>` and `Serializer<Object>` are never used (no value has
  those runtime types). → A serializer applies to subtypes; the dead defaults were removed (§2.3).
- [x] ✔️ **A local `DateTime` is serialized without an offset** (`2026-01-01T00:00:00.000`): the
  client can't know its time zone. Decide: always UTC (`toUtc()`), or keep the offset. → Always UTC
  (§2.6).
- [x] **The errors expose Dart internals to the client** (400): a failing `fromJson` sends
  `type 'Null' is not a subtype of type 'String' in type cast`, and a wrong number sends the parser
  message (`Invalid radix-10 number (at character 1)`). They don't say which field failed either.
  → `path: reason` (`$.items[1]: expected a string, got an integer`), never a Dart type (§2.5).
- [x] **Leniency is inconsistent:** `int`/`double`/`bool` are parsed from `v.toString()`, so `"12"`
  (a string) is accepted as `12` and `"true"` as `true`, but `12.0` is not accepted as an `int`.
  → Strict types, `12.0` is an `int` (§2.4).
- [x] `body<String>()` returns the raw body without decoding the JSON (`_isPrimitive`): a JSON body
  `"hello"` comes back with its quotes. Document it, or decode it when the `Content-Type` is JSON.
  → Decoded when the `Content-Type` is JSON; `deserialize` (values) and `decode` (text) are
  separate methods (§2.0, §2.7).
- [x] `body<T>()` ignores the `Content-Type` of the request: a form or XML body tries to parse as
  JSON. Decide whether a non-JSON body is a **415**. → 415 (`UnsupportedMediaTypeException`),
  except `text/plain` and no `Content-Type`, which `package:http` and `fetch()` send (§2.7).
- [x] `ListTypeExtension` adds `isList`/`isMap` to **every** `Type` of the user (public extension).
  → Removed.

**Questions to decide:**

- [x] **How generics are registered.** Options: (a) explicit
  (`om.addDeserializer<List<User>>(...)` generated by a helper, `Deserializer<User>.list()`),
  (b) the deserializer of `T` creates the ones of `List<T>`/`Map<String, T>`/`T?` itself when it's
  registered, (c) optional codegen. Option (b) removes the lookup by name without new API.
  → (b), plus (a) for deeper types.
- [x] **Duck-typed `toJson()`:** call `(object as dynamic).toJson()` when the object has one
  (dynamic calls work in AOT), so `json_serializable`/`freezed` models work without
  `Serializable`. Then, is `Serializable` still needed? → No: `Serializable` was removed.
- [x] **Strict or lenient types** (`"12"` as an `int`), and whether it's configurable. → Strict,
  not configurable.
- [x] **Error format:** a field path (`$.address.zip: expected a String, got a number`) and a 400
  without Dart details, consistent with the error format of phase 2.3. → Done for the message; the
  body format goes with 2.3.
- [x] **Subtypes:** fall back to the serializer of a supertype, or keep exact types (faster and
  predictable) and document it. → Fall back, cached per type (needed by `freezed`).
- [x] **Options:** omit `null` fields, naming strategy (`snake_case`), `Duration` as milliseconds
  vs ISO-8601. Possibly none of them (the model's `toJson` decides), but say so in the docs.
  → `includeNulls`, `fieldNaming`, `durationFormat` and `prettyPrint` (on by default) (§2.8).
- [x] **Performance:** benchmark `serialize` + `jsonEncode` of a big list (it's done in two passes
  and fully in memory) and compare it with a direct `jsonEncode` of the `toJson()`. → It was
  ×3.5–4.2 in AOT; `encode` is now a single pass, ×1.1–1.2 (§2.9).

### 2.2 Validation ✅

**Done** (2026-10-06): every decision is in `DECISIONS.md` §3, the behavior in
`test/validation/validation_behavior_test.dart` (100% line coverage of the validation), and the
guide in `doc/validation.md`. A second review from zero fixed the chaining of types, `url()`,
`fieldName` with `fieldNaming` and the `params` that could give a 500 (§3.9). Left for other
phases: the format of `fieldName` vs the `$` path of the 400 (2.3), async validations and the
improvements below in 4.3, and example `05` (5.4).

**Before the review:** `Validatable`, `ConstraintValidatorContext`, a fluent `ConstraintValidator` with
validators as extensions, `throwOnFailure()` → 422, messages in the language of the request.

**Problems found:**

- [x] ✔️ **`pattern()` with a `RegExp` never matches.** It does `RegExp(pattern.toString())`, and
  `RegExp.toString()` returns `RegExp: pattern=^abc$ flags=i`, so the regex it builds is that text.
  It only works with a `String`. It also builds a new `RegExp` on every validation; use the `RegExp`
  received as is (flags included) and compile a `String` once. → Fixed (§3.7).
- [x] `ConstrainViolation` → **`ConstraintViolation`** (misspelled public API: it appears in the
  JSON of the 422s and in `ValidationException.violations`). → Renamed (§3.6).
- [x] `ConstrainViolation.==` compares `value.toString()` and says "needed for tests": decide
  whether it's real value equality or remove it. → Real equality; `1` and `'1'` were equal with
  different hash codes (§3.6).
- [x] `Validatable` is an abstract class with a `validate()` that returns an empty context: it
  should be an interface (`abstract interface class`), and returning a valid context by default
  hides a forgotten implementation. → Interface (§3.6).
- [x] Validators receive `dynamic`: a typo like `.min(3)` on a `String` is only seen at runtime
  (`The value must be a number`). → Typed by the value (§3.1).
- [x] ✔️ **A forgotten `.validate(value)` validated nothing**, silently
  (`cvc.buildValidator('name').notNull();`). → The rules run as they are chained (§3.1).
- [x] ✔️ **A 422 became a 500** when the `value` of a violation was an object without `toJson()`.
  → The 422 never has the value (§3.5).
- [x] `notBlank()` of a value that isn't a String said "cannot be blank", and `size()` didn't accept
  a `Map`. → Typed validators; `size()`/`notEmpty()` accept a `Map` (§3.7).

**Questions to decide:**

- [x] **A machine-readable code in each violation** (`"code": "size.min", "params": {"value": 3}`)
  besides the message, so a client (a Flutter app) can show its own text. → Yes (§3.4).
- [x] **`validBody<T>()`**: deserializes and validates in one step (every POST/PUT repeats it by
  hand). It depends on 2.1. → `body<T>()` validates by default, `validate: false` to skip it (§3.2).
- [x] **Typed validators** (`buildValidator<String>('name')`) so the compiler rejects `.min()` on a
  String, or keep `dynamic` for simplicity. → `cvc.field(name, value)`, typed by the value (§3.1).
- [x] **Nested validation** without calling `merge(prefix:)` by hand (`.valid()` on a `Validatable`
  field). → `valid()` and `validEach()` (§3.3).
- [x] **More validators:** `url`, `uuid`, `positive`/`negative`, `past`/`future` (dates), `notEmpty`
  (collections), `oneOf` (literal values), `size` on `Map`. → All of them (§3.7).
- [x] **Async validations** (`FutureOr`, "the email already exists"): decide now whether the API
  allows them later without a breaking change, even if they arrive in 1.x 🟢. → A separate
  `AsyncValidatable` interface in 1.x, without breaking changes (§3.8, and 4.3).

### 2.3 Exceptions and error handling

**Today:** the `ApiException` hierarchy (400, 401, 402, 403, 404, 409, 413, 422, 500),
`ResponseException`, `SimpleExceptionHandler`, a generic 500 that never exposes the error.

**Problems found:**

- [ ] **Errors come in different formats:** an `ApiException` answers `text/plain` with the reason
  phrase, a 404/405 of the router has no body, a validation returns a JSON array and a
  `DeserializationException` a string.
- [ ] `_runPipeline` checks `eh is SimpleExceptionHandler` to find `logUnhandledError`: a custom
  `ExceptionHandler` can't log the `Error`s its own way. Move it to the `ExceptionHandler`
  interface.
- [ ] The `ExcHandler` typedef in `handler.dart` is unused and its parameter is named `stackTrac`.
- [ ] `ResponseException.responseEntity` is not `final`; the exceptions can't be `const`.
- [ ] A chain without a response returns a 500 with the body `Filter chain ended without a
  response` (an internal message sent to the client).

**Questions to decide:**

- [ ] **Problem Details (RFC 9457)** as the default format of every error. Winter already sends
  `application/problem+json` when the status is >= 400 and the body is an object, but the body
  doesn't follow the format:
  ```json
  { "type": "about:blank", "title": "Not Found", "status": 404, "detail": "User 42 not found" }
  ```
  Validation would extend it with `"violations": [...]`. Configurable by replacing the
  `ExceptionHandler`, but consistent by default (router, `ApiException`, deserialization, 413, 429,
  500).
- [ ] **`ExceptionHandler` by type:** today you have to extend `SimpleExceptionHandler` and chain
  `if (e is X)`. A registry `handler.on<MyException>((req, e) => ...)` (Spring's
  `@ControllerAdvice`, without annotations).
- [ ] **More exceptions:** `MethodNotAllowedException` (405), `NotAcceptableException` (406),
  `UnsupportedMediaTypeException` (415, already added in 2.1), `TooManyRequestsException` (429),
  `ServiceUnavailableException` (503). Or a single `ApiException(StatusCode.x)` and fewer classes.

### 2.4 Dependency injection

**Today:** `put`/`find`/`tryFind`/`delete` by `(Type, tag)`, singletons only.

- [ ] `find` checks `!= null`, so a `null` value can't be registered and `tryFind` can't tell "not
  registered" from "registered as null". Add `isRegistered<T>()`.
- [ ] `notFound` is a public method of `DependencyInjection` (it should be private), and the map is
  named `_singl`.
- [ ] **Lazy singletons** (`putLazy`, created on the first `find`) and **factories** (a new
  instance per `find`).
- [ ] **`dispose`/`onClose`** called on the graceful shutdown (to close database connections), in
  reverse order of registration.
- [ ] A clear error on circular dependencies between lazy ones.
- [ ] Decide the scope: stay a minimal service locator (and document it as such), or grow towards a
  container. A service locator is enough for 1.0.

### 2.5 Configuration (`Env` and `ServerConfig`)

- [ ] **Load a `.env` file** (`Env.load('.env')`) and **profiles** (`WINTER_PROFILE=prod`), with a
  documented precedence (process variables > `.env` > defaults).
- [ ] The "unsupported type" message of `Env.find` doesn't mention `List<bool>`, even though it is
  supported.
- [ ] `Env.put` returns the value read again with `find` (it fails for an unsupported type even if
  it was stored); `caseSensitive: false` scans every variable.
- [ ] `ServerConfig` uses `late final` fields assigned in the constructor body: move them to
  initializers so it can be `const`, and move `shared` there too (today it's a separate parameter of
  `Winter.start`). Add `securityContext` (HTTPS) and `requestTimeout` (phase 4).
- [ ] Typed configuration of the app: a pattern (or helper) to read a config class from `Env` once
  at start-up and fail fast if a required variable is missing.

### 2.6 Logging

- [ ] A **JSON logger** (`JsonLogger`) for production (Cloud Logging, Datadog…).
- [ ] **Request ID** in the logs: a filter that reads or generates `X-Request-Id`, saves it in the
  `RequestScope` (`requestId`), adds it to the response, and the loggers include it.
- [ ] `debug`/`info` don't accept `error`/`stackTrace` (only `warning`/`error` do).
- [ ] Lazy messages (`logger.debug(() => '...')`) so a disabled level doesn't build the string.
- [ ] `ConsoleLogger` uses the local time; decide UTC.

### 2.7 Security

- [ ] **CORS with `'*'` and `allowCredentials: true` echoes any origin**: that gives every website
  credentialed access to the API, which is what the browser rule is meant to prevent. Require
  explicit origins with credentials (fail on start), or at least log a warning.
- [ ] **A 401 without `WWW-Authenticate`:** RFC 9110 requires it. Let `AuthFilter` set it (for
  example `Bearer`).
- [ ] **Typed principal:** `RequestSecurityContext<T>` is generic, but `request.securityContext`
  returns `RequestSecurityContext<dynamic>` and `Authentication.anonymous()` is an
  `Authentication<dynamic>` with the principal `'Anonymous'`. Add typed access
  (`request.principal<User>()`) so handlers don't need a cast.
- [ ] Roles vs permissions vs authorities: three concepts, where `authorities` is the union of the
  other two. Decide whether all three are needed.
- [ ] Rate limiter: document that it's in memory, per isolate and per process; leave an abstract
  `RateLimiterStore` so a Redis store can be added in 1.x without a breaking change.
- [ ] A `SecurityHeadersFilter`: `Strict-Transport-Security`, `X-Content-Type-Options`,
  `Referrer-Policy`, a basic `Content-Security-Policy`.

### 2.8 Router, filters and entities (light review)

They're the most solid part (phase 1 covers their bugs), so this is only an API review. The
entities (`RequestEntity`, `ResponseEntity`) are redesigned in phase 3.1, without shelf.

- [ ] `WinterRouter.routes` is a public, mutable `List`: expose it read-only and leave `addRoute` as
  the only way to add routes.
- [ ] `FilterConfig.add` mutates a list that may be `const` (it throws then).
- [ ] i18n was reviewed recently (`DECISIONS.md` §1): only check that it fits with the decisions of
  2.2 (violation codes) and 2.3 (error format).

---

## Phase 3: remove shelf and freeze the public API 🔴

With the decisions of phase 2 applied, the last pass before the API becomes stable. Every change
goes to the CHANGELOG and to the migration guide.

### 3.1 Move from shelf to `dart:io`

**Decision:** 1.0 doesn't depend on `shelf`. Winter serves the requests with `dart:io` directly and
has its own request/response model, so its public API never depends on another package's, and
the features that shelf packages provide (WebSockets, static files, multipart) are implemented by
Winter.

**Why:** today `RequestEntity`/`ResponseEntity` extend the classes of shelf and `winter.dart`
re-exports all of shelf, so every method of shelf is public API of Winter, and a breaking change in
shelf is a breaking change in Winter. It also costs performance: on an empty endpoint (AOT,
loopback, 64 concurrent connections) `dart:io` serves ~17 000 req/s, shelf ~14 500 (−15 %) and
Winter ~12 500. Record the decision in `DECISIONS.md` when it's done.

**Where shelf is used today** (everything else, router, filters, security, DI, object mapper, i18n,
is already independent):

| Where                                                                 | What it uses                                                                                |
|-----------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| `winter_server.dart`                                                  | `shelf_io.serve(...)`: bind, connections, writing the response                              |
| `RequestEntity extends Request`, `ResponseEntity<T> extends Response` | Headers, body and its encoding, `context`, `change()`                                       |
| `Winter.buildHandler` → `Handler`                                     | `WinterTestClient` calls the pipeline in memory                                             |
| `context['shelf.io.connection_info']`                                 | The IP of the client (`clientIp`)                                                           |
| `export 'package:shelf/shelf.dart'`                                   | All of shelf re-exported (tests use `Response.ok` with `addVary`, `shelf_change_test.dart`) |

**Tasks:**

- [ ] **Baseline:** save the numbers of `benchmark/` (handler, sequential and concurrent server)
  before starting, to compare at the end. Add a `dart:io` "hello world" to the benchmark as the
  ceiling.
- [ ] **Server:** `HttpServer.bind` / `bindSecure` (HTTPS) with `shared`, a loop that runs the
  pipeline for every `HttpRequest`, and the settings shelf hid: `autoCompress`, `idleTimeout`,
  `defaultResponseHeaders` (today Content-Type is removed by hand), `X-Powered-By`. The graceful
  shutdown and `_InFlightRequests` are already Winter's.
- [ ] **Own request model:** `RequestEntity` no longer extends anything. One implementation reads
  an `HttpRequest` and another one is built in memory (tests). It keeps the names the users know
  (`method`, `headers`, `requestedUri`, `body<T>()`, `pathParams`, `queryParams`, `context`…)
  and adds what shelf didn't have:
    - Headers that are case-insensitive and multi-value (`header('x')`, `headerAll('x')`).
    - `cookies` (`HttpRequest.cookies` of `dart:io`).
    - `clientIp` from `HttpRequest.connectionInfo`, without context keys.
    - A body read once (single subscription), with the charset of the `Content-Type` and the
      `maxBodySize` limit.
    - Decide `copyWith` (async) vs `change` (sync): today they do almost the same, keep one.
    - Drop what only shelf needed: `handlerPath`, `url` relative to the handler, the unmodifiable
      `context` that Winter had to override.
- [ ] **Own response model:** `ResponseEntity<T>` with status, multi-value headers (several
  `Set-Cookie`), a body as a value, String, bytes or Stream, the encoding, and automatic
  `Content-Type`/`Content-Length` (the logic of phase 1 is already Winter's).
- [ ] **Writing the response** to `HttpResponse`: status, headers, `Content-Length` or chunked, no
  body for HEAD/204/304, streaming with `bufferOutput: false` (for Server-Sent Events), and a client
  that disconnects in the middle must not crash the server (log at debug).
- [ ] **Errors of the HTTP layer** that shelf_io handled: a malformed request (`HttpException` of
  `dart:io`) → 400; a handler that fails after the headers were sent → log and close the
  connection; a response that can't be written → log.
- [ ] **Testing in memory:** `Winter.buildHandler` returns a Winter handler
  (`Future<ResponseEntity> Function(RequestEntity)`) and `WinterTestClient` builds in-memory
  requests. The same pipeline as the real server, without ports, as today.
- [ ] **Leave room for WebSockets (1.x):** the pipeline must be able to hand an `HttpRequest` over
  to `WebSocketTransformer.upgrade` of `dart:io` after the filters (auth, CORS) run, without a
  breaking change. Design it now (ex: a response type that takes the connection), implement it in
  4.3.
- [ ] **Remove the dependency:** `shelf` out of `pubspec.yaml`, no `export` of shelf, `addVary` and
  the helpers on Winter's types, rewrite `test/shelf_change_test.dart` and `client_ip_test.dart`.
- [ ] **Shelf middlewares:** they stop working. Filters are the replacement; document how to turn a
  shelf middleware into a filter in the migration guide.
- [ ] **Compare with the baseline:** Winter must be at least as fast as with shelf (goal: close to
  the `dart:io` ceiling), and publish the numbers.
- [ ] Update `CLAUDE.md`, `DECISIONS.md` and the CHANGELOG.

### 3.2 Freeze the public API

- [ ] Delete the deprecated `onAlreadyStarted` parameter of `Winter.close` and the `@Deprecated`
  values of `StatusCode`.
- [ ] **Exported surface:** `winter.dart` exports everything. Decide what is really public API and
  what is an internal detail (once in 1.0, changing it is breaking):
    - Loose helpers: `addVary`, `limitBodySize`, `isValidUri`, `normalizePath`,
      `methodNotAllowedOrNotFound`, `internalServerErrorResponse`,
      `warnLocalesWithoutWinterMessages` and `console_style` (`stylize` on `String`).
- [ ] Read the whole public API once more (`dart doc` output) looking for inconsistent names and
  parameters.

---

## Phase 4: missing features

### 4.1 Basic HTTP 🔴

- [ ] **More `ResponseEntity` constructors:** `created` (201, with `Location`), `accepted` (202),
  `noContent` (204), `conflict` (409), `unprocessableEntity` (422), `serviceUnavailable` (503) and
  redirects (`redirect`/`seeOther`/`permanentRedirect` with `Location`).
- [ ] **Typed access to params:** `request.pathParam<int>('id')` and
  `request.queryParam<int>('page', defaultValue: 1)`. If the value can't be converted, a **400**
  (today every handler runs `int.parse`, and an error there ends in a 500).
- [ ] **`application/x-www-form-urlencoded` forms:** `request.formData()`.
- [ ] **Multipart / file uploads:** `request.multipart()` with fields and files as streams,
  respecting `maxBodySize` (possible base: `MimeMultipartTransformer` of `package:mime`, from
  the Dart team, or an own parser). It was in `todo.md`.
- [ ] **Cookies:** read (`request.cookies`, from 3.1) and write (`ResponseEntity` with
  `setCookie(...)`, with `HttpOnly`, `Secure`, `SameSite`, `Max-Age`; `Cookie` of `dart:io`).
- [ ] **Static files:** a `StaticRouter`/`Route.static('/assets', directory)` with
  `ETag`/`Last-Modified`, `304`, `Range` requests and no path traversal (`..`), streaming the
  `File` of `dart:io`.
- [ ] **HTTPS:** `ServerConfig(securityContext: ...)` with `HttpServer.bindSecure` (the server of
  3.1).

### 4.2 Operations 🟡

- [ ] **Timeout per request** (`ServerConfig.requestTimeout`): a stuck handler returns a 503 and
  doesn't hold the graceful shutdown until its timeout.
- [ ] Optional **gzip compression** (`HttpServer.autoCompress`, exposed by the server of 3.1).
- [ ] **Health check:** `Route.health('/health')` or a documented example (needed for Docker and
  Kubernetes).

### 4.3 After 1.0 🟢

They don't block 1.0 and shouldn't delay it (they can be added in 1.x without breaking changes):

- [ ] **WebSockets**, implemented by Winter on `WebSocketTransformer` of `dart:io` (no shelf):
  routes for WebSockets that go through the filters (auth, CORS) before the upgrade, as designed
  in 3.1.
- [ ] **Server-Sent Events** on the streaming responses of 3.1.
- [ ] Scheduled tasks (cron), it was in `todo.md`.
- [ ] OpenAPI generation from the routes.
- [ ] Async validations: an `AsyncValidatable` interface with a `Future` `validate()`, also run by
  `body<T>()` (`DECISIONS.md` §3.8).
- [ ] A Redis `RateLimiterStore`.
- [ ] More languages for Winter's messages (fr, pt, de…).
- [ ] Configuration with annotations / package scanning (with codegen).
- [ ] A tree-based (trie) router if benchmarks with hundreds of routes justify it (today the lookup
  is linear).

**Validation** (proposed in the second review of 2.2, none of them is breaking):

- [ ] **Validate a `Map<String, Validatable>`**: `body<T>()` validates a `Validatable` or a list of
  them, not a map of them; and a `validEach()` for the values of a map (`prices["eur"].amount`).
- [ ] **Limit the cache of `pattern()`**: a regular expression given as a String is compiled once
  and kept forever. It only grows with dynamic patterns (built from data), which are rare; an LRU
  or no cache for them.
- [ ] **`ConstraintViolation.copyWith` can't clear a field**: `copyWith(code: null)` keeps the old
  code (`??`). Use sentinels or explicit `clearCode`/`clearValue` flags if it's ever needed.

**Object mapper** (proposed after the review 2.1, none of them is breaking):

- [ ] **`JsonConverter<T>`**: register the serializer and the deserializer of a type you don't
  own in one call (`om.addConverter(JsonConverter<Uri>.string(toJson: ..., fromJson: Uri.parse))`).
- [ ] **Typed field access for hand-written `fromJson`** (`json.field<String>('name')`,
  `json.object('address', Address.fromJson)`): the 400 says which field failed
  (`$.address.zip: ...`) instead of `$: invalid value`, without tracking the keys behind the
  scenes.
- [ ] **`TestResponse.as<T>()`**: deserialize a response of `WinterTestClient` with the mapper,
  instead of `json` (`dynamic`) and a manual `fromJson`.
- [ ] **Warn when the mapper is replaced after registering**: `Winter.context.setUp(objectMapper:
  ...)` drops what was registered in the previous `om`, and the missing deserializer is only seen
  as a 500 at runtime.
- [ ] **Encode straight to bytes** with `JsonUtf8Encoder` (today `encode` makes a String that is
  encoded to UTF-8 again), on the response model of 3.1. Measure it with
  `benchmark/object_mapper_benchmark.dart` first.
- [ ] **Decode without the intermediate String** (`utf8.decoder.fuse(json.decoder)` on the body
  stream), keeping the cache of the raw body that `body<T>()` needs.
- [ ] **Absent vs `null`** for partial updates (PATCH): today a missing field and a `null` one are
  the same; `body<Map<String, dynamic>>()` is the workaround.
- [ ] **Reject unknown fields** (optional, against mass assignment): needs to know which keys the
  `fromJson` read (see the typed field access above).
- [ ] **Map keys that are not `String`** (`Map<int, T>`, `Map<Status, T>`): convert the key from
  its text.
- Not possible, on purpose: reading a class without registering it, or serializing records
  (`(id: 1, name: 'a')`); both need reflection, which AOT doesn't have, or codegen, which the
  project avoids.

---

## Phase 5: documentation 🔴

The part with the most pending work. Today there is `README.md` (very general), `DECISIONS.md`,
the index `doc/README.md` and `doc/object-mapper.md`. The old `doc/routing/winter_router.md`
(outdated: `ParentRoute`, the first declared route winning, empty sections) and `doc/vs/vs.md`
(obsolete: a `ValidationService` with `@Valid` annotations that no longer exists) were deleted;
`routing.md` and `validation.md` replace them.

The docs are written in English, like the code, the comments and `DECISIONS.md` (pub.dev is
international).

### 5.1 Proposed structure

```
README.md                    ← front page: what it is, installation, hello world, links to doc/
doc/
  README.md                  ← index of the documentation
  getting-started.md
  architecture.md            ← pipeline of a request, BuildContext, global state, request scope
  routing.md
  filters.md
  requests-and-responses.md
  object-mapper.md
  validation.md
  error-handling.md
  i18n.md
  security.md
  dependency-injection.md
  configuration.md
  logging.md
  testing.md
  deployment.md
  migration-0.x-to-1.0.md
DECISIONS.md                 ← stays: the "why" (the docs explain the "how")
CONTRIBUTING.md
CHANGELOG.md
```

- [x] `doc/README.md`: the index, with the state of each planned document (written or
  planned). Update it every time a document is added.

### 5.2 Content of each document

Every document follows the same outline: **what it is → minimal example → how it works inside →
configuration → common cases → typical mistakes and limitations**. Every code example must compile
(see phase 6, checking the snippets).

The documents of the systems of phase 2 are written **when their review is done**, so they aren't
written twice. The rest can be written now.

- [ ] **`getting-started.md`:** requirements (SDK), installation, first endpoint, a CRUD with JSON
  and validation, how to run it and test it. From zero to a working API in 10 minutes.
- [ ] **`architecture.md`:**
    - The path of a request: `Request` → `RequestEntity` → `RequestScope` (Zone) → `resolveRoute` →
      `FilterChain` (CORS, global and route filters, sorted by `order`) → handler →
      `ExceptionHandler` → `Vary`.
    - Include a diagram.
    - What lives in `BuildContext` (`om`, `eh`, `di`, `env`, `logger`, `localeConfig`) and the model
      of one server per isolate.
    - How to scale with several isolates (`shared: true`, see
      `benchmark/server_shared_benchmark.dart`).
- [ ] **`routing.md`:** `Route.get/post/...`, nested routes and `Route.parent`, path params (`{id}`,
  `{id|regex}`, decoding), regex routes, priority (static routes first, then declaration order),
  trailing slash, HEAD→GET, 404 vs 405 + `Allow`, `basePath`, `addRoute`, route keys and duplicates,
  the `RouterConfig` hooks (`ignore`/`fail`/`log`), `MultiRouter`, `ServeRouter`, and how to write
  your own router (override `resolveRoute`, or the route filters are skipped).
- [ ] **`filters.md`:** `Filter`, `doFilter`/`chain.doFilter`, short-circuiting the chain, `order`,
  `shouldFilter`, global vs route filters (inherited in nested routes), why a filter never receives
  an exception (it becomes a response where it's thrown), `LogsFilter`, `CorsFilter`,
  `RateLimiterFilter`.
- [ ] **`requests-and-responses.md`:** `RequestEntity` (`body<T>()` and its cache, `pathParams`,
  `queryParams`, `clientIp`, `change`) and `ResponseEntity` (constructors, automatic `Content-Type`
  and `Content-Length`, streams), body limit (413), cookies, forms, multipart and static files
  (once they exist).
- [x] **`object-mapper.md`** (after 2.1), its snippets checked by running them:
    - `toJson()`, `Serializer<T>`, `Deserializer<T>` and `Deserializer<T>.json(fromJson)`.
    - Registration in `ObjectMapper(...)` and in `Winter.context.setUp(objectMapper: ...)`.
    - Default types (`DateTime`, `Duration`) and the rules of serialization (recursion, enums,
      iterables, map keys).
    - Deserialization of lists, maps and generics, as decided in 2.1.
    - Which error each failure gives and its format.
    - How to use it with `json_serializable`/`freezed`.
- [x] **`validation.md`** (after 2.2), its snippets checked by running them:
    - `Validatable`, `ConstraintValidatorContext`, `field(name, value)`.
    - Every validator with its semantics: `null` passes except with `notNull`, `stopOnFailure`,
      `inclusive`.
    - Sensitive fields (`sensitive: true`).
    - Nested objects and lists (`valid()`, `validEach()` → `items[0].name`).
    - `body<T>()` and `throwOnFailure()` → 422 and the format of the response.
    - Custom and translated messages (link to `i18n.md`).
    - Writing your own validators as an extension of `FieldValidator` with `addRule`.
    - **Pitfall:** build the validators inside `validate()`, never in a `static final`.
- [ ] **`error-handling.md`** (after 2.3): the exception hierarchy, which status each one gives,
  why a 500 never exposes details, how to customize the `ExceptionHandler`, the error format and
  the difference between `Exception` and `Error`.
- [ ] **`i18n.md`**, with this outline:
    1. **What it solves:** answering in the language of the client, both Winter's validation
       messages
       and the texts of the app.
    2. **Enabling it:** `Winter.context.setUp(localeConfig: LocaleConfig(supported: [english,
     spanish], fallback: english))`. By default there is only English, so an existing app doesn't
       change its responses by surprise.
    3. **How the language is chosen:** `Accept-Language` per RFC 9110 (sorted by `q`, `q=0` = not
       acceptable, `es-MX` → `es` → any `es-*`, `fallback`), with a table of examples of header →
       chosen language.
    4. **Reading the language:** `request.locale` vs `requestLocale` (from any code thanks to the
       `RequestScope`), and what it returns outside a request.
    5. **Winter's messages:** which validators are translated, the included languages (en, es), the
       warning on start about languages without translations, and how to contribute a new language
       (`*.i18n.yaml` + `dart run slang`).
    6. **Translating the texts of your app with slang**, step by step as in `example/04_i18n`:
       `slang.yaml` with the same options as Winter (`locale_handling: false`,
       `string_interpolation: braces`, `fallback_strategy: none`), nested YAML, typed parameters,
       generating the code and the getter `t => appMessages(requestLocale)` (**a getter, never a
       `final`**). Using it in validators (`message: t.x`), exceptions and responses.
    7. **Automatic `Vary: Accept-Language`:** when it's added (when the language is read and more
       than one language is supported), how it's merged with the `Vary: Origin` of CORS, and why it
       matters for caches.
    8. **Tests:** `WinterTestClient` with the `Accept-Language` header, and
       `RequestScope.run(RequestScope(locale: ...))` to test a service without a server.
    9. **Limitations and decisions:** what is not translated on purpose (HTTP reason phrases,
       technical deserialization errors), the mix of languages when the app supports a language that
       Winter doesn't have, and a link to `DECISIONS.md` §1 for why slang and YAML.
- [ ] **`security.md`** (after 2.7): how to authenticate with your own filter (Bearer/JWT, as in
  `example/03_auth_security`), `Authentication` and `RequestSecurityContext`,
  `requestAuthentication` from services, `AuthFilter` (401 vs 403), rules (`hasRole`,
  `hasPermission`, `hasAuthority`, `&`, `|`), route vs global filters with `shouldFilter`, CORS
  (`SecurityConfig.cors()`, credentials, preflight), rate limiter (sliding window, `X-RateLimit-*`
  headers, per IP, `trustedProxies`, its limits with several isolates), and a production checklist
  (HTTPS, security headers, body limit, never log secrets, `sensitive: true`).
- [ ] **`dependency-injection.md`** (after 2.4): the API, tags, the global `di` instance, what
  `Winter.start` registers and how it's restored, common patterns (repository → service →
  controller), and how to replace dependencies in tests.
- [ ] **`configuration.md`** (after 2.5): every option of `ServerConfig`, `Env` (supported types,
  `required`, lists, `.env`), `BuildContext` and `setUp`, and the order in which `Winter.start`
  resolves the configuration (argument → DI → default).
- [ ] **`logging.md`** (after 2.6): `WinterLogger`, levels, `ConsoleLogger(minLevel:)`, writing
  your own logger, what the framework logs and at which level, and why `LogsFilter` never logs
  bodies nor query strings.
- [ ] **`testing.md`:** `WinterTestClient` (all its methods, `TestResponse.json`), parallel tests
  without ports, `RequestScope.run` for services, injecting fake clocks (as in `RateLimiter`), and
  when a test with a real server is worth it (`Winter.close(force: true)` in `tearDownAll`).
- [ ] **`deployment.md`:** compiling with `dart compile exe`, an example multi-stage Dockerfile,
  graceful shutdown in Docker/Kubernetes (SIGTERM, `shutdownTimeout` vs
  `terminationGracePeriodSeconds`), health checks, several isolates with `shared: true`, and running
  behind a reverse proxy (`trustedProxies`, HTTPS terminated at the proxy).
- [ ] **`migration-0.x-to-1.0.md`:** every breaking change of phases 1 to 3 with a before and after,
  including the move away from shelf (the shelf types that are gone, and how to turn a shelf
  middleware into a filter).
- [ ] **Rewritten `README.md`:**
    - Badges (pub, CI, coverage, license), the value proposition in 3 lines, installation with the
      real version (today it says `^latest_version`) and hello world.
    - A feature table with a link to each doc, a link to the examples, and removing the "not
      production-ready" warning in 1.0.
    - Fix the SDK: the README says `>= 3.12`, `pubspec.yaml` `^3.13.0` and `CLAUDE.md` `^3.12.0`.
    - Tone down the "protect from DDoS" of the rate limiter, it promises more than it does.
- [ ] **`CONTRIBUTING.md`:** FVM, commands, style (lints), how to add a language, commit convention
  (`[module] ...`), and how to update the CHANGELOG and `DECISIONS.md`.

### 5.3 Dartdoc (API reference on pub.dev)

- [ ] Enable the `public_member_api_docs` lint and document the whole public API, with an example
  in the main classes (`Winter`, `WinterRouter`, `Route`, `Filter`, `ResponseEntity`,
  `ObjectMapper`, `FieldValidator`, `AuthFilter`). The object mapper already passes the lint.
- [ ] Clean up the comments copied from Spring with Javadoc syntax (`{@link ...}`, `{@code ...}`,
  `@see <a href=...>` with broken URLs) in `http_status_code.dart` and `status_code.dart`.
- [ ] Use dartdoc categories (`{@category Routing}`) to group the reference by module.

### 5.4 Examples

The current 4 are fine. Missing:

- [ ] `05_validation_object_mapper`: nested DTOs, lists, `Map<String, T>`, custom serializers and a
  422 response (after 2.1 and 2.2).
- [ ] `06_files`: multipart, static files and cookies (once they exist).
- [ ] `07_production`: `.env`, JSON logger, request id, health check, Dockerfile and graceful
  shutdown with `onShutdown` closing a "database".

---

## Phase 6: quality, tooling and publishing

### 6.1 CI 🔴

- [ ] GitHub Actions (there is no `.github/`): `dart format --set-exit-if-changed`, `dart analyze`,
  `dart test` with coverage (uploaded to Codecov), and `dart pub get && dart test` in every example,
  on Linux and Windows (SIGTERM only runs on Linux).
- [ ] Check that `messages*.g.dart` is up to date (`dart run slang` + `git diff --exit-code`).
- [ ] `pana` in CI with a score threshold (goal: the maximum pub points).
- [ ] Check that the snippets of the docs compile (extract them to `doc/snippets/*.dart` and analyze
  them, or use a tool like `code_excerpter`).
- [ ] Build an obfuscated AOT executable (`dart compile exe
  --extra-gen-snapshot-options=--obfuscate`) that serializes and deserializes generic types, two
  classes with the same name and a failing `fromJson`: the object mapper must work and its errors
  must not contain obfuscated names (checked by hand in 2.1).

### 6.2 Package 🔴

- [ ] `pubspec.yaml`: `homepage`, `documentation`, `issue_tracker`, `topics` (`server`, `http`,
  `backend`, `rest`, `api`) and a `description` that says clearly in one line what it is.
- [ ] `.pubignore`: leave out `todo.md`, `benchmark/`, `slang.yaml`, `CLAUDE.md`,
  `winter_framework.iml` and `brag-output/` (today `dart pub publish --dry-run` includes the whole
  `test/`, which is fine, but the rest is not needed).
- [ ] Review the runtime dependencies: `slang` + `intl` (range `>=0.18.1 <2.0.0`), `crypto` (only
  for the route keys; a simpler hash would remove the dependency), `collection` and `http_parser`.
  `shelf` is already gone (3.1).
  Check that they work with the minimum versions (`dart pub downgrade && dart test`).

### 6.3 Final review 🟡

- [ ] A full security review (path traversal in static files, multipart limits, headers, errors
  never leaking internal data).
- [ ] Publish the benchmarks (routing, server and object mapper) and compare them with `dart:io`
  (the ceiling) and with the last version on shelf, in the README or in `doc/`.
- [ ] Keep the coverage of the new modules at the current level (~99%).

### 6.4 Release

1. [ ] `0.2.0` (or `1.0.0-dev.x`) with phases 1 to 3: all the breaking changes together.
2. [ ] `1.0.0-rc.1` with phase 4 🔴 and the documentation. Use it in a real project for a few weeks.
3. [ ] Fix what comes up and publish `1.0.0`: git tag `v1.0.0`, CHANGELOG with the date, and an
   announcement (Reddit r/dartlang, Dart Discord, X).

---

## 7. Recommended order

```
Phase 1      Phase 2 (system by system)             Phase 3       Phase 4       rc.1 ──► 1.0.0
(core bugs)  2.1 object mapper ──► 2.2 validation   3.1 dart:io   (features)
                                                    3.2 freeze
             ──► 2.3 exceptions ──► 2.4-2.8                │             │
                    │                                      │             │
                    └── each system's doc, once reviewed ──┴── docs of the new features
                                                               + examples 05-07

Can start now: CI and pubspec/.pubignore (phase 6.1, 6.2), and the docs of the modules that
won't change (i18n, routing, filters, testing, architecture, deployment).
```

Phase 3.1 goes before the features of phase 4 because cookies, static files, multipart, HTTPS and
compression are built on its server and its request/response model. It can also start in parallel
with phase 2: it only touches the HTTP layer, and the systems of phase 2 don't depend on shelf.

2.1 → 2.2 → 2.3 go in that order because each one depends on the previous: `validBody` needs the
deserialization of 2.1, and the error format of 2.3 has to include the violations of 2.2 and the
deserialization errors of 2.1. The rest of phase 2 (2.4 to 2.8) is independent and can go in any
order.

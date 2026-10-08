# Roadmap to 1.0.0

What is missing to publish `winter` 1.0.0: an HTTP framework that covers the main use cases of a
REST API. Not at the level of Spring, but with the basics complete, stable and documented.

It comes from a full review of the code (`lib/src`, tests, examples and docs) at version `0.1.0`
(branch `feature/retake_project`). It replaces `todo.md` and the *Future Roadmap* section of the
README: once adopted, delete `todo.md` and link this file from the README.

**Legend:** 🔴 blocks 1.0 · 🟡 should be in 1.0 · 🟢 after 1.0 (1.x) · ✔️ confirmed with a script

> **Decision (2026-10-08): no release for now.** Phases 1 to 6.3 are done, but instead of
> publishing a release candidate, everything still pending is finished first, starting with
> **4.3** (in the order given there). The release (6.4) comes after that; the CI (6.1) stays
> postponed.

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
3. Every module has its own document in `doc/`, and the whole public API has dartdoc. 1.0 is a
   first version: there is no migration guide from 0.x.
4. Before each release the checks pass locally (format, analyze, tests, examples, a publish dry
   run) with a good pana score (pub points). The CI that runs them on every push comes after 1.0
   (6.1).
5. At least one release candidate (`1.0.0-rc.1`) was published and used in a real project.

---

## 1. Current state

| Module                                                                                  | State                                           |
|-----------------------------------------------------------------------------------------|-------------------------------------------------|
| Pipeline (`buildHandler`, filters, exception handler inside the chain)                  | ✅ Solid                                         |
| Router (nested, regex, static routes first, 404/405 + `Allow`, HEAD→GET, `MultiRouter`) | ✅ Reviewed (2.8), `doc/routing.md`              |
| Lifecycle (graceful shutdown, signals, body limit with 413)                             | ✅                                               |
| Request scope (`Zone`): `requestAuthentication`, `requestLocale`                        | ✅                                               |
| i18n (slang + YAML, `Accept-Language`, automatic `Vary`)                                | ✅ Documented in `DECISIONS.md`                  |
| Testing (in-memory `WinterTestClient`)                                                  | ✅                                               |
| HTTP engine (`dart:io`, own request/response)                                           | ✅ Replaced shelf (3.1), `doc/requests-and-responses.md` |
| Object mapper                                                                           | ✅ Reviewed (2.1), `doc/object-mapper.md`        |
| Validation                                                                              | ✅ Reviewed (2.2), `doc/validation.md`           |
| Exceptions and error handling                                                           | ✅ Reviewed (2.3), `doc/error-handling.md`       |
| Dependency injection                                                                    | ✅ Reviewed (2.4), `doc/dependency-injection.md` |
| Configuration (`Env`, `ServerConfig`)                                                   | ✅ Reviewed (2.5), `doc/configuration.md`        |
| Logging                                                                                 | ✅ Reviewed (2.6), `doc/logging.md`              |
| Security                                                                                | ✅ Reviewed (2.7), `doc/security.md`             |
| Documentation                                                                           | ✅ A guide per module, `doc/README.md`           |
| CI / publishing                                                                         | ❌ No CI                                         |

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
- [x] Tests: many still start a real server on a fixed port, which makes them slow and fragile in
  parallel. Move them to `WinterTestClient` little by little (🟡, not blocking). → Done in 3.2: the
  ones on a real server test the server itself (lifecycle, shutdown, `dart:io`, start failures).

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
4. Implement and update the CHANGELOG.
5. Write its document in `doc/` (phase 5), now that it won't change.

### 2.1 Object mapper (dedicated review) ✅

**Done** (2026-10-06, commits `716b572` and `0add5e1`, then `Deserializer.enumByName`, the typed
constructors `string`/`integer`/`number`/`boolean` and `body<T>(objectMapper:)`, §2): every
decision is in `DECISIONS.md` §2,
the behavior in `test/object_mapper/object_mapper_behavior_test.dart` (100% line coverage of the
mapper), the guide in `doc/object-mapper.md` and the numbers in
`benchmark/object_mapper_benchmark.dart`. What is left of the object mapper is in other phases:
the format of the error body (2.3), `validBody<T>()` (2.2), the migration guide and
`requests-and-responses.md` (5.2), example `05` (5.4) and the obfuscation check in CI (6.1).

**Before the review:** a registry of `Serializer<T>`/`Deserializer<T>` by exact `Type`, the
`Serializable`
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
      with `deserializerOf<T>().list()` (§2). Checked with an obfuscated AOT build.
- [x] ✔️ **A class with `toJson()` that doesn't implement `Serializable` gives a 500**
  (`Bad state: Generated need to implement the Serializable interface`). That's exactly what
  `json_serializable` and `freezed` generate, so the most common way of writing models in Dart
  doesn't work without adding `implements Serializable` to each one. → `toJson()` is called
  dynamically and `Serializable` was removed (§2).
- [x] **Serializers are found by the exact `runtimeType`:** a serializer for `Animal` doesn't apply
  to `Dog`. The default `Serializer<num>` and `Serializer<Object>` are never used (no value has
  those runtime types). → A serializer applies to subtypes; the dead defaults were removed (§2).
- [x] ✔️ **A local `DateTime` is serialized without an offset** (`2026-01-01T00:00:00.000`): the
  client can't know its time zone. Decide: always UTC (`toUtc()`), or keep the offset. → Always UTC
  (§2).
- [x] **The errors expose Dart internals to the client** (400): a failing `fromJson` sends
  `type 'Null' is not a subtype of type 'String' in type cast`, and a wrong number sends the parser
  message (`Invalid radix-10 number (at character 1)`). They don't say which field failed either.
  → `path: reason` (`$.items[1]: expected a string, got an integer`), never a Dart type (§2).
- [x] **Leniency is inconsistent:** `int`/`double`/`bool` are parsed from `v.toString()`, so `"12"`
  (a string) is accepted as `12` and `"true"` as `true`, but `12.0` is not accepted as an `int`.
  → Strict types, `12.0` is an `int` (§2).
- [x] `body<String>()` returns the raw body without decoding the JSON (`_isPrimitive`): a JSON body
  `"hello"` comes back with its quotes. Document it, or decode it when the `Content-Type` is JSON.
  → Decoded when the `Content-Type` is JSON; `deserialize` (values) and `decode` (text) are
  separate methods (§2, §2).
- [x] `body<T>()` ignores the `Content-Type` of the request: a form or XML body tries to parse as
  JSON. Decide whether a non-JSON body is a **415**. → 415 (`UnsupportedMediaTypeException`),
  except `text/plain` and no `Content-Type`, which `package:http` and `fetch()` send (§2).
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
  → `includeNulls`, `fieldNaming`, `durationFormat` and `prettyPrint` (on by default) (§2).
- [x] **Performance:** benchmark `serialize` + `jsonEncode` of a big list (it's done in two passes
  and fully in memory) and compare it with a direct `jsonEncode` of the `toJson()`. → It was
  ×3.5–4.2 in AOT; `encode` is now a single pass, ×1.1–1.2 (§2).

### 2.2 Validation ✅

**Done** (2026-10-06): every decision is in `DECISIONS.md` §3, the behavior in
`test/validation/validation_behavior_test.dart` (100% line coverage of the validation), and the
guide in `doc/validation.md`. A second review from zero fixed the chaining of types, `url()`,
`fieldName` with `fieldNaming` and the `params` that could give a 500 (§3). Left for other
phases: the format of `fieldName` vs the `$` path of the 400 (2.3), async validations and the
improvements below in 4.3, and example `05` (5.4).

**Before the review:** `Validatable`, `ConstraintValidatorContext`, a fluent `ConstraintValidator`
with
validators as extensions, `throwOnFailure()` → 422, messages in the language of the request.

**Problems found:**

- [x] ✔️ **`pattern()` with a `RegExp` never matches.** It does `RegExp(pattern.toString())`, and
  `RegExp.toString()` returns `RegExp: pattern=^abc$ flags=i`, so the regex it builds is that text.
  It only works with a `String`. It also builds a new `RegExp` on every validation; use the `RegExp`
  received as is (flags included) and compile a `String` once. → Fixed (§3).
- [x] `ConstrainViolation` → **`ConstraintViolation`** (misspelled public API: it appears in the
  JSON of the 422s and in `ValidationException.violations`). → Renamed (§3).
- [x] `ConstrainViolation.==` compares `value.toString()` and says "needed for tests": decide
  whether it's real value equality or remove it. → Real equality; `1` and `'1'` were equal with
  different hash codes (§3).
- [x] `Validatable` is an abstract class with a `validate()` that returns an empty context: it
  should be an interface (`abstract interface class`), and returning a valid context by default
  hides a forgotten implementation. → Interface (§3).
- [x] Validators receive `dynamic`: a typo like `.min(3)` on a `String` is only seen at runtime
  (`The value must be a number`). → Typed by the value (§3).
- [x] ✔️ **A forgotten `.validate(value)` validated nothing**, silently
  (`cvc.buildValidator('name').notNull();`). → The rules run as they are chained (§3).
- [x] ✔️ **A 422 became a 500** when the `value` of a violation was an object without `toJson()`.
  → The 422 never has the value (§3).
- [x] `notBlank()` of a value that isn't a String said "cannot be blank", and `size()` didn't accept
  a `Map`. → Typed validators; `size()`/`notEmpty()` accept a `Map` (§3).

**Questions to decide:**

- [x] **A machine-readable code in each violation** (`"code": "size.min", "params": {"value": 3}`)
  besides the message, so a client (a Flutter app) can show its own text. → Yes (§3).
- [x] **`validBody<T>()`**: deserializes and validates in one step (every POST/PUT repeats it by
  hand). It depends on 2.1. → `body<T>()` validates by default, `validate: false` to skip it (§3).
- [x] **Typed validators** (`buildValidator<String>('name')`) so the compiler rejects `.min()` on a
  String, or keep `dynamic` for simplicity. → `cvc.field(name, value)`, typed by the value (§3).
- [x] **Nested validation** without calling `merge(prefix:)` by hand (`.valid()` on a `Validatable`
  field). → `valid()` and `validEach()` (§3).
- [x] **More validators:** `url`, `uuid`, `positive`/`negative`, `past`/`future` (dates), `notEmpty`
  (collections), `oneOf` (literal values), `size` on `Map`. → All of them (§3).
- [x] **Async validations** (`FutureOr`, "the email already exists"): decide now whether the API
  allows them later without a breaking change, even if they arrive in 1.x 🟢. → A separate
  `AsyncValidatable` interface in 1.x, without breaking changes (§3, and 4.3).

### 2.3 Exceptions and error handling ✅

**Done** (2026-10-07): every decision is in `DECISIONS.md` §4, the behavior in
`test/server/exception_handler/error_handling_behavior_test.dart` (100% line coverage of the
exceptions and the handler), and the guide in `doc/error-handling.md`. Left for other phases: the
`WWW-Authenticate` of the 401 (2.7) and a request id in the 500 (2.6).

**Before the review:** the `ApiException` hierarchy (400, 401, 402, 403, 404, 409, 413, 422, 500),
`ResponseException`, `SimpleExceptionHandler`, a generic 500 that never exposes the error.

**Problems found:**

- [x] **Errors come in different formats:** an `ApiException` answers `text/plain` with the reason
  phrase, a 404/405 of the router has no body, a validation returns a JSON array and a
  `DeserializationException` a string. → Problem Details for every error (§4).
- [x] `_runPipeline` checks `eh is SimpleExceptionHandler` to find `logUnhandledError`: a custom
  `ExceptionHandler` can't log the `Error`s its own way. Move it to the `ExceptionHandler`
  interface. → The handler receives `Error`s too (§4).
- [x] ✔️ **An `Error` gave a 500 without the CORS headers**, and no filter saw it (`LogsFilter`
  didn't log it): it went through the chain up to the pipeline. → The chain turns it into a
  response where it's thrown (§4).
- [x] The `ExcHandler` typedef in `handler.dart` is unused and its parameter is named `stackTrac`.
  → Removed.
- [x] `ResponseException.responseEntity` is not `final`; the exceptions can't be `const`. → `final`,
  and most exceptions are `const`.
- [x] A chain without a response returns a 500 with the body `Filter chain ended without a
  response` (an internal message sent to the client). → It can't happen: a `StateError`.

**Questions to decide:**

- [x] **Problem Details (RFC 9457)** as the default format of every error. Winter already sends
  `application/problem+json` when the status is >= 400 and the body is an object, but the body
  doesn't follow the format:
  ```json
  { "type": "about:blank", "title": "Not Found", "status": 404, "detail": "User 42 not found" }
  ```
  Validation would extend it with `"violations": [...]`. Configurable by replacing the
  `ExceptionHandler`, but consistent by default (router, `ApiException`, deserialization, 413, 429,
  500). → Yes, and the errors of Winter are exceptions, so the handler formats all of them (§4).
- [x] **`ExceptionHandler` by type:** today you have to extend `SimpleExceptionHandler` and chain
  `if (e is X)`. A registry `handler.on<MyException>((req, e) => ...)` (Spring's
  `@ControllerAdvice`, without annotations). → `on<T>()`, and inheritance still works (§4).
- [x] **More exceptions:** `MethodNotAllowedException` (405), `NotAcceptableException` (406),
  `UnsupportedMediaTypeException` (415, already added in 2.1), `TooManyRequestsException` (429),
  `ServiceUnavailableException` (503). Or a single `ApiException(StatusCode.x)` and fewer classes.
  → `ApiException(status)` for any status, shortcuts for the common ones with 405, 429 and 503;
  `PaymentRequiredException` removed (§4).

### 2.4 Dependency injection ✅

**Done** (2026-10-07): every decision is in `DECISIONS.md` §5, the behavior in
`test/dependency_injection/di_behavior_test.dart` (100% line coverage of the DI and the request
scope), and the guide in `doc/dependency-injection.md`. A second review fixed two silent bugs of
`putScoped` (§5): a lazy singleton that kept the disposed instance of the first request, and a
`find` after the request ended.

**Before the review:** `put`/`find`/`tryFind`/`delete` by `(Type, tag)`, singletons only.

- [x] `find` checks `!= null`, so a `null` value can't be registered and `tryFind` can't tell "not
  registered" from "registered as null". Add `isRegistered<T>()`. → Done (§5).
- [x] ✔️ **A dependency registered from a nullable variable wasn't found**: `di.put(maybeService)`
  registered it as `<Service?>`, and `find<Service>()` failed. → `T` and `T?` are the same key
  (§5).
- [x] `notFound` is a public method of `DependencyInjection` (it should be private), and the map is
  named `_singl`. → Fixed.
- [x] **Lazy singletons** (`putLazy`, created on the first `find`) and **factories** (a new
  instance per `find`). → Both, and `putScoped` (one per request) (§5).
- [x] **`dispose`/`onClose`** called on the graceful shutdown (to close database connections), in
  reverse order of registration. → `onDispose`, run by `Winter.shutdown()` (§5).
- [x] A clear error on circular dependencies between lazy ones. →
  `Circular dependency: A -> B -> A`.
- [x] Decide the scope: stay a minimal service locator (and document it as such), or grow towards a
  container. A service locator is enough for 1.0. → A service locator, by exact type (§5).

### 2.5 Configuration (`Env` and `ServerConfig`) ✅

**Done** (2026-10-07): every decision is in `DECISIONS.md` §6, the behavior in
`test/env/config_behavior_test.dart` (100% line coverage of `Env` and `ServerConfig`), and the
guide in `doc/configuration.md`. Left for phase 3.1 and 4: `securityContext` (HTTPS) and
`requestTimeout`.

- [x] **Load a `.env` file** (`Env.load('.env')`) and **profiles** (`WINTER_PROFILE=prod`), with a
  documented precedence (process variables > `.env` > defaults). → `Env.load()`: process >
  `.env.<profile>` > `.env`, missing files ignored (§6).
- [x] The "unsupported type" message of `Env.find` doesn't mention `List<bool>`, even though it is
  supported. → It lists every type (§6).
- [x] `Env.put` returns the value read again with `find` (it fails for an unsupported type even if
  it was stored); `caseSensitive: false` scans every variable. → `put` returns the value given.
- [x] ✔️ **The error of a wrong type showed the value** (`found with value 'hunter2'`): a secret
  could end in the logs. → Errors never show a value (§6).
- [x] ✔️ `find(required: true)` returned a `T?`, `find<int?>` was unsupported, a `String` secret was
  trimmed and `List<bool>` didn't accept `TRUE`. → `require<T>`, nullable types, no trim of
  `String`, any case (§6, §6).
- [x] `ServerConfig` uses `late final` fields assigned in the constructor body: move them to
  initializers so it can be `const`, and move `shared` there too (today it's a separate parameter of
  `Winter.start`). Add `securityContext` (HTTPS) and `requestTimeout` (phase 4). → `const`, `host`,
  `shared`, validated by `Winter.start`, and `ServerConfig.fromEnv` (§6).
- [x] Typed configuration of the app: a pattern (or helper) to read a config class from `Env` once
  at start-up and fail fast if a required variable is missing. → The `AppConfig.fromEnv` pattern
  and `requireAll` (§6).

### 2.6 Logging ✅

**Done** (2026-10-07): every decision is in `DECISIONS.md` §7, the behavior in
`test/logging_behavior_test.dart` (100% line coverage of the loggers and the request scope), and
the guide in `doc/logging.md`.

- [x] A **JSON logger** (`JsonLogger`) for production (Cloud Logging, Datadog…). → One JSON per
  line, with `fields` (§7).
- [x] **Request ID** in the logs: a filter that reads or generates `X-Request-Id`, saves it in the
  `RequestScope` (`requestId`), adds it to the response, and the loggers include it. → Always on,
  no filter to add, and in the body of a 500 (§7).
- [x] `debug`/`info` don't accept `error`/`stackTrace` (only `warning`/`error` do). → Every level
  takes them, and `fields` (§7).
- [x] Lazy messages (`logger.debug(() => '...')`) so a disabled level doesn't build the string.
  → `isEnabled(level)`, used by the debug logs of the framework (§7).
- [x] `ConsoleLogger` uses the local time; decide UTC. → UTC (§7).
- [x] ✔️ **The debug log of a failed deserialization included the value sent** (a card number in
  the test), in several lines. → The type of the error only (§7).

### 2.7 Security

**Done** (`DECISIONS.md` §8, guide in `doc/security.md`): CORS warns about `'*'` with credentials,
varies by origin and exposes `X-Request-Id`; the 401 has `WWW-Authenticate`; a typed principal from
any code; rules that see the request; security headers; an asynchronous rate limiter with a
`RateLimiterStore`.

- [x] **Expose `X-Request-Id` to browsers**: CORS must list it in `Access-Control-Expose-Headers`,
  or
  a web client can't read the id of a response (found in the review 2.6). → Always exposed (§8).
- [x] **CORS with `'*'` and `allowCredentials: true` echoes any origin**: that gives every website
  credentialed access to the API, which is what the browser rule is meant to prevent. Require
  explicit origins with credentials (fail on start), or at least log a warning. → A warning, and
  `Vary: Origin` on every response that depends on the origin (§8).
- [x] **A 401 without `WWW-Authenticate`:** RFC 9110 requires it. Let `AuthFilter` set it (for
  example `Bearer`). → `Bearer`, configurable with `challenge` (§8).
- [x] **Typed principal:** `RequestSecurityContext<T>` is generic, but `request.securityContext`
  returns `RequestSecurityContext<dynamic>` and `Authentication.anonymous()` is an
  `Authentication<dynamic>` with the principal `'Anonymous'`. Add typed access
  (`request.principal<User>()`) so handlers don't need a cast. → `requestPrincipal<T>()` from any
  code (the request scope) and `request.principal<T>()`, a 401 for nobody (§8).
- [x] Roles vs permissions vs authorities: three concepts, where `authorities` is the union of the
  other two. Decide whether all three are needed. → Roles and permissions only (§8). Rules also
  receive the request, and `describe()` prints them (§8).
- [x] `RateLimiter(0, window)` answers every request with a 500: with no logs, `getWaitDuration`
  reads `logs.first` of an empty list (`StateError`). Reject `maxRequests < 1` when it's created
  (found in the review 2.3). → An `ArgumentError`, also for a window that isn't positive (§8).
- [x] Rate limiter: document that it's in memory, per isolate and per process; leave an abstract
  `RateLimiterStore` so a Redis store can be added in 1.x without a breaking change. → An
  asynchronous `RateLimiterStore` (§8).
- [x] A `SecurityHeadersFilter`: `Strict-Transport-Security`, `X-Content-Type-Options`,
  `Referrer-Policy`, a basic `Content-Security-Policy`. → `nosniff` and `DENY` always,
  `SecurityHeaders` opt-in in `SecurityConfig`, HSTS only with `hsts: true` (§8).

### 2.8 Router, filters and entities (light review)

They're the most solid part (phase 1 covers their bugs), so this is only an API review. The
entities (`RequestEntity`, `ResponseEntity`) are redesigned in phase 3.1, without shelf.

**Done** (`DECISIONS.md` §9, guides in `doc/routing.md` and `doc/filters.md`): a broken route
table fails at start, duplicates by method and shape, typed path and query params, automatic
`OPTIONS`, an immutable `FilterConfig`, read-only routes, and two fixes (`GET //...` was a 500
outside the pipeline, a param with a regex was dropped).

- [x] `WinterRouter.routes` is a public, mutable `List`: expose it read-only and leave `addRoute` as
  the only way to add routes. → Read-only; `MultiRouter.routes` => `routers` (§9).
- [x] `FilterConfig.add` mutates a list that may be `const` (it throws then). → Immutable, `add`
  removed (§9).
- [x] i18n was reviewed recently (`DECISIONS.md` §1): only check that it fits with the decisions of
  2.2 (violation codes) and 2.3 (error format). → It fits: the codes of the violations are the keys
  of the YAML, and the `title` of a Problem Details is not translated.
- [x] ✔️ **`GET //users` was a 500 outside the pipeline** (shelf rejected its url): no request id,
  no security headers, logged without the `logger`. → A 404 like `/users//1` (§9).
- [x] ✔️ **A param with a regex (`{id|[0-9]+}`) was dropped as an invalid URL**, with a warning.
  → Only the literal parts are validated, and a broken route table fails at start (§9, §9).
- [x] Duplicated routes with another key or param name (`/users/{id}` and `/users/{name}`) were not
  detected. → The same method and shape is a duplicate; the keys stay (§9).
- [x] `int.parse(request.pathParams['id']!)` is a 500 for `/users/abc`. → `pathParam<T>` and
  `queryParam<T>`, a 400 (§9).
- [x] `OPTIONS` without CORS was a 405. → A 204 with `Allow` (§9).
- [x] `ResponseEntity.created(location:)`, `accepted()`, `noContent()` (§9).

### 2.9 Review all of the above

**Done** (`DECISIONS.md` §10): two integration tests run every system at once (in memory and on a
real server configured from `.env` files). They fitted, except for four details: the charset of a
text body depended on its language, the names of the errors followed `fieldNaming`, the real server
sent `X-Powered-By`, and an empty child path.

- [x] check all the systems in this phase to ensure they work well together. → A whole app in
  `test/integration/app_integration_test.dart`; the real server against `WinterTestClient` in
  `test/integration/server_integration_test.dart`.
- [x] Review the tests of all these systems to test most use cases, including those that involve
  multiple systems, such as an object mapper that validates and that validation depends on an
  environment. → Validation that reads `env`, snake_case + i18n in a 422, a scoped service that
  reads the user, the rate limit per user, concurrent requests, the shutdown with a request in
  progress.
- [x] ✔️ **The `Content-Type` of a text body changed with its content** (`; charset=utf-8` only with
  non-ASCII characters). → Always `; charset=utf-8` (§10).
- [x] **The members of a Problem Details followed `fieldNaming`** (`request_id`, `field_name`).
  → Fixed names (§4).
- [x] **`X-Powered-By: Winter-Server`** on the real server only. → Removed (§8).

---

## Phase 3: remove shelf and freeze the public API 🔴

With the decisions of phase 2 applied, the last pass before the API becomes stable. Every change
goes to the CHANGELOG.

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

**Done** (`DECISIONS.md` §10, guide in `doc/requests-and-responses.md`): Winter serves with
`HttpServer` of `dart:io`, `RequestEntity`/`ResponseEntity` are its own types (`headersAll`,
cookies, one `copyWith`), `ServerConfig` has `autoCompress`, `idleTimeout` and `securityContext`
(HTTPS), and shelf is out of `pubspec.yaml`. An empty endpoint went from 3984 to ~5100 req/s
(−17 % from the `dart:io` ceiling, it was −37 %).

**Tasks:**

- [x] **Baseline:** save the numbers of `benchmark/` (handler, sequential and concurrent server)
  before starting, to compare at the end. Add a `dart:io` "hello world" to the benchmark as the
  ceiling.
- [x] **Server:** `HttpServer.bind` / `bindSecure` (HTTPS) with `shared`, a loop that runs the
  pipeline for every `HttpRequest`, and the settings shelf hid: `autoCompress`, `idleTimeout`,
  `defaultResponseHeaders` (today Content-Type is removed by hand), `X-Powered-By`. The graceful
  shutdown and `_InFlightRequests` are already Winter's.
- [x] **Own request model:** `RequestEntity` no longer extends anything. One implementation reads
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
- [x] **Own response model:** `ResponseEntity<T>` with status, multi-value headers (several
  `Set-Cookie`), a body as a value, String, bytes or Stream, the encoding, and automatic
  `Content-Type`/`Content-Length` (the logic of phase 1 is already Winter's).
- [x] **Writing the response** to `HttpResponse`: status, headers, `Content-Length` or chunked, no
  body for HEAD/204/304, streaming with `bufferOutput: false` (for Server-Sent Events), and a client
  that disconnects in the middle must not crash the server (log at debug).
- [x] **Errors of the HTTP layer** that shelf_io handled: a malformed request (`HttpException` of
  `dart:io`) → 400; a handler that fails after the headers were sent → log and close the
  connection; a response that can't be written → log.
- [x] **Testing in memory:** `Winter.buildHandler` returns a Winter handler
  (`Future<ResponseEntity> Function(RequestEntity)`) and `WinterTestClient` builds in-memory
  requests. The same pipeline as the real server, without ports, as today.
- [x] **Leave room for WebSockets (1.x):** the pipeline must be able to hand an `HttpRequest` over
  to `WebSocketTransformer.upgrade` of `dart:io` after the filters (auth, CORS) run, without a
  breaking change. Design it now (ex: a response type that takes the connection), implement it in
  4.3.
- [x] **Remove the dependency:** `shelf` out of `pubspec.yaml`, no `export` of shelf, `addVary` and
  the helpers on Winter's types, rewrite `test/shelf_change_test.dart` and `client_ip_test.dart`.
- [x] **Shelf middlewares:** they stop working. Filters are the replacement; document how to turn a
  shelf middleware into a filter in the migration guide. → Dropped: 1.0 is a first version, without
  a migration guide.
- [x] **Compare with the baseline:** Winter must be at least as fast as with shelf (goal: close to
  the `dart:io` ceiling), and publish the numbers.
- [x] Update `CLAUDE.md`, `DECISIONS.md` and the CHANGELOG.

### 3.2 Freeze the public API

- [x] Delete the deprecated `onAlreadyStarted` parameter of `Winter.close` and the `@Deprecated`
  values of `StatusCode`. → And `StatusCode` is a single enum (`DECISIONS.md` §11).
- [x] **Exported surface:** `winter.dart` exports everything. Decide what is really public API and
  what is an internal detail (once in 1.0, changing it is breaking):
    - Loose helpers: `addVary`, `limitBodySize`, `isValidUri`, `normalizePath`,
      `methodNotAllowedOrNotFound`, `internalServerErrorResponse`,
      `warnLocalesWithoutWinterMessages` and `console_style` (`stylize` on `String`).
    - → All internal (`export ... hide`), with `writeResponse` and `RequestEntity.fromHttpRequest`
      (§11).
- [x] Read the whole public API once more (`dart doc` output) looking for inconsistent names and
  parameters. → `WinterContext`, `BaseRouter`, `LoggingFilter`, `clear()`, `clientId`/`onLimited`;
  no `dart doc` warnings (§11, §11).
- [x] Add examples for more use cases, check the coverage of test, check that there is no
  overlapping tests, check for missing flow without tests. → Examples `05` and `07`; 29 test files
  moved from a real server to `WinterTestClient` (the ones left test the server itself); the
  overlapping CORS, exception handler, logging and rate limiter tests merged; the uncovered
  branches tested in `test/edge_cases_test.dart`.
- [x] Check all the docs, add the missing ones and improve the existing ones → Every guide of
  `doc/` is written (getting started, architecture, i18n, testing and deployment were missing), the
  README and `CONTRIBUTING.md` rewritten, and `DECISIONS.md` condensed to the current decisions.

---

## Phase 4: missing features

### 4.1 Basic HTTP 🔴

- [x] **More `ResponseEntity` constructors:** `created` (201, with `Location`), `accepted` (202),
  `noContent` (204), `conflict` (409), `unprocessableEntity` (422), `serviceUnavailable` (503) and
  redirects (`redirect`/`seeOther`/`permanentRedirect` with `Location`). → `created`, `accepted`
  and `noContent` in 2.8; the rest, plus `temporaryRedirect` (307), here. `redirect` is a 302.
- [x] **Typed access to params:** `request.pathParam<int>('id')` and
  `request.queryParam<int>('page', defaultValue: 1)`. If the value can't be converted, a **400**
  (today every handler runs `int.parse`, and an error there ends in a 500). → Done in 2.8
  (`pathParam<T>`/`queryParam<T>`, §9).
- [x] **`application/x-www-form-urlencoded` forms:** `request.formData()`. → A `FormData` with
  `fields`/`fieldsAll` and `field<T>()` typed like `queryParam<T>`; 415 for another
  `Content-Type`, 400 for a bad encoding, cached like `body<T>()`.
- [x] **Multipart / file uploads:** `request.multipart()` with fields and files as streams,
  respecting `maxBodySize` (possible base: `MimeMultipartTransformer` of `package:mime`, from
  the Dart team, or an own parser). It was in `todo.md`. → An own parser (`mime` leaves a reader
  waiting forever and throws uncaught errors on malformed bodies, `DECISIONS.md` §10):
  `multipart()` streams `MultipartPart`s, and `formData()` also reads `multipart/form-data` with
  its `files` (`UploadedFile`) in memory.
- [x] **Cookies:** read (`request.cookies`, from 3.1) and write (`ResponseEntity` with
  `setCookie(...)`, with `HttpOnly`, `Secure`, `SameSite`, `Max-Age`; `Cookie` of `dart:io`).
  → Done in 3.1: `request.cookies`/`cookie(name)` and `cookies:` in `ResponseEntity`.
- [x] **Static files:** a `StaticRouter`/`Route.static('/assets', directory)` with
  `ETag`/`Last-Modified`, `304`, `Range` requests and no path traversal (`..`), streaming the
  `File` of `dart:io`. → `Route.static` and `StaticFiles` (`DECISIONS.md` §9). It found a bug: a
  `?` in the regex of a route cut its path there, and the route matched any url.
- [x] **HTTPS:** `ServerConfig(securityContext: ...)` with `HttpServer.bindSecure` (the server of
  3.1). → Done in 3.1.

### 4.2 Operations 🟡

- [x] **Timeout per request** (`ServerConfig.requestTimeout`): a stuck handler returns a 503 and
  doesn't hold the graceful shutdown until its timeout. → Off by default, a filter at order -98
  (`DECISIONS.md` §10); also in `buildHandler` and `WinterTestClient.build`.
- [x] Optional **gzip compression** (`HttpServer.autoCompress`, exposed by the server of 3.1).
  → Done in 3.1: `ServerConfig.autoCompress`.
- [x] **Health check:** `Route.health('/health')` or a documented example (needed for Docker and
  Kubernetes). → `Route.health(path:, checks:, timeout:)` (`DECISIONS.md` §9), used by
  `example/07_production`.
- [x] **`di.createAll()`**: create every lazy dependency at start-up (opt-in), so a broken
  registration (a missing dependency, a cycle, a constructor that throws) fails when the server
  starts instead of in the first request that needs it. Proposed in the second review of 2.4.
  → Opt-in, every failure named in one `StateError` (`DECISIONS.md` §5).

### 4.3 More features 🟢 (next, before the release)

They were planned for 1.x (none of them breaks the API), but they are done before the first
release (see the decision at the top). Order of work: what makes the existing modules complete
first, small and independent; then the new features, from the most used to the least:

1. **Dependency injection, validation and object mapper** (the three lists below): small
   improvements of reviewed modules, each one on its own.
2. **Server-Sent Events**: the streaming responses already exist (3.1).
3. **Async validations**.
4. **WebSockets**: the biggest one, already designed in 3.1.
5. **OpenAPI** generation from the routes.
6. **Scheduled tasks**, a **Redis `RateLimiterStore`**, **more languages**.
7. A **trie router**, only if a benchmark with hundreds of routes justifies it.
8. **Annotations / package scanning** needs code generation, which the project avoids
   (`DECISIONS.md`): decide whether it's done at all before starting it.

- [ ] **WebSockets**, implemented by Winter on `WebSocketTransformer` of `dart:io` (no shelf):
  routes for WebSockets that go through the filters (auth, CORS) before the upgrade, as designed
  in 3.1.
- [x] **Server-Sent Events** on the streaming responses of 3.1. → `ResponseEntity.sse` and
  `ServerSentEvent`; the streams end when the server starts closing (`DECISIONS.md` §10).
  `example/06_files` sends the new photos.
- [ ] Scheduled tasks (cron), it was in `todo.md`.
- [ ] OpenAPI generation from the routes.
- [ ] Async validations: an `AsyncValidatable` interface with a `Future` `validate()`, also run by
  `body<T>()` (`DECISIONS.md` §3).
- [ ] A Redis `RateLimiterStore`.
- [ ] More languages for Winter's messages (fr, pt, de…).
- [ ] Configuration with annotations / package scanning (with codegen).
- [ ] A tree-based (trie) router if benchmarks with hundreds of routes justify it (today the lookup
  is linear).

**Dependency injection** (proposed in the second review of 2.4, none of them is breaking):

- [x] **Async initialization**: `putLazyAsync<T>(() async => ...)` and `await di.ready()`, for a
  dependency that needs a connection opened; today it's awaited before `put`. → Plus `findAsync`;
  `Winter.start` awaits `ready()` before opening the port, and a cycle is a `StateError`
  (`DECISIONS.md` §5).
- [x] **Child containers for tests**: `di.child()` falls back to its parent, so a test registers
  its fakes in a child without touching the global `di`. → It takes the recipes of the parent,
  not its instances (except those of `put`), so a lazy service of the app uses the fakes
  (`DECISIONS.md` §5).
- [x] **A listing of the registrations** (`di.registrations`: type, tag, kind, created or not), to
  log them at start-up or debug a missing one. → `DependencyRegistration` and the public
  `DependencyKind`, with a `toString` for the logs.

**Validation** (proposed in the second review of 2.2, none of them is breaking):

- [x] **Validate a `Map<String, Validatable>`**: `body<T>()` validates a `Validatable` or a list of
  them, not a map of them; and a `validEach()` for the values of a map (`prices["eur"].amount`).
  → The key quoted as in JSON, and never renamed by `fieldNaming`.
- [x] **Limit the cache of `pattern()`**: a regular expression given as a String is compiled once
  and kept forever. It only grows with dynamic patterns (built from data), which are rare; an LRU
  or no cache for them. → An LRU of 256.
- [x] **`ConstraintViolation.copyWith` can't clear a field**: `copyWith(code: null)` keeps the old
  code (`??`). Use sentinels or explicit `clearCode`/`clearValue` flags if it's ever needed.
  → The nullable fields take a function, typed: `copyWith(code: () => null)`.

**Object mapper** (proposed after the review 2.1, none of them is breaking):

- [x] **`JsonConverter<T>`**: register the serializer and the deserializer of a type you don't
  own in one call (`om.addConverter(JsonConverter<Uri>.string(toJson: ..., fromJson: Uri.parse))`).
  → Named `JsonAdapter<T>` (`JsonConverter` is a class of `json_annotation`: importing both would
  clash), with `adapters:` and `addAdapter`.
- [x] **Typed field access for hand-written `fromJson`** (`json.field<String>('name')`,
  `json.object('address', Address.fromJson)`): the 400 says which field failed
  (`$.address.zip: ...`) instead of `$: invalid value`, without tracking the keys behind the
  scenes. → `JsonObjectFields`: `json.field<T>()` (with the mapper that is
  deserializing) and `json.object(name, fromJson)`; example 05 uses it.
- [x] **`TestResponse.as<T>()`**: deserialize a response of `WinterTestClient` with the mapper,
  instead of `json` (`dynamic`) and a manual `fromJson`.
- [x] **Warn when the mapper is replaced after registering**: `Winter.context.setUp(objectMapper:
  ...)` drops what was registered in the previous `om`, and the missing deserializer is only seen
  as a 500 at runtime. → A warning with the types of the app (not the defaults)
  that the new mapper has not.
- [x] **Encode straight to bytes** with `JsonUtf8Encoder` (today `encode` makes a String that is
  encoded to UTF-8 again), on the response model of 3.1. Measure it with
  `benchmark/object_mapper_benchmark.dart` first. → `om.encodeBytes`, used by `ResponseEntity`
  for UTF-8: 16 % to 46 % faster.
- [x] **Decode without the intermediate String** (`utf8.decoder.fuse(json.decoder)` on the body
  stream), keeping the cache of the raw body that `body<T>()` needs. → `om.decodeBytes` on the
  cached bytes, used by `body<T>()` for UTF-8: 20 % to 25 % faster. The 415 is now checked before
  reading the body.
- [x] **Absent vs `null`** for partial updates (PATCH): today a missing field and a `null` one are
  the same; `body<Map<String, dynamic>>()` is the workaround. → `PatchValue<T>` from
  `json.patch<T>()` (`isPresent`, `value`, `orElse`, `valueOrNull`); example 02 has a PATCH.
- [x] **Reject unknown fields** (optional, against mass assignment): needs to know which keys the
  `fromJson` read (see the typed field access above). → `ObjectMapper(rejectUnknownFields: true)`, and
  per type in `Deserializer.json`: the map given to the `fromJson` records the keys read, so it
  works with any `fromJson` (also the generated ones). Example 05 turns it on.
- [x] **Map keys that are not `String`** (`Map<int, T>`, `Map<Status, T>`): convert the key from
  its text. → `deserializer.mapWithKeys<K>()`: `int`, `double`, `num` and `bool`
  parsed, any other key through its own deserializer. Writing them already worked.
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

- [x] **`getting-started.md`** (its code run as a test): requirements (SDK), installation, first endpoint, a CRUD with JSON
  and validation, how to run it and test it. From zero to a working API in 10 minutes.
- [x] **`architecture.md`:**
    - The path of a request: `Request` → `RequestEntity` → `RequestScope` (Zone) → `resolveRoute` →
      `FilterChain` (CORS, global and route filters, sorted by `order`) → handler →
      `ExceptionHandler` → `Vary`.
    - Include a diagram.
    - What lives in `BuildContext` (`om`, `eh`, `di`, `env`, `logger`, `localeConfig`) and the model
      of one server per isolate.
    - How to scale with several isolates (`shared: true`, see
      `benchmark/server_shared_benchmark.dart`).
- [x] **`routing.md`** (after 2.8), its snippets checked by running them: `Route.get/post/...`,
  nested routes and `Route.parent`, path params (`{id}`,
  `{id|regex}`, decoding), regex routes, priority (static routes first, then declaration order),
  trailing slash, HEAD→GET, 404 vs 405 + `Allow`, `basePath`, `addRoute`, route keys and duplicates,
  the `RouterConfig` hooks (`ignore`/`fail`/`log`), `MultiRouter`, `ServeRouter`, and how to write
  your own router (override `resolveRoute`, or the route filters are skipped).
- [x] **`filters.md`** (after 2.8), its snippets checked by running them: `Filter`, `doFilter`/
  `chain.doFilter`, short-circuiting the chain, `order`,
  `shouldFilter`, global vs route filters (inherited in nested routes), why a filter never receives
  an exception (it becomes a response where it's thrown), `LogsFilter`, `CorsFilter`,
  `RateLimiterFilter`.
- [x] **`requests-and-responses.md`** (after 3.1), its snippets checked by running them: `RequestEntity` (`body<T>()` and its cache, `pathParams`,
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
- [x] **`error-handling.md`** (after 2.3), its snippets checked by running them: the exception
  hierarchy, which status each one gives,
  why a 500 never exposes details, how to customize the `ExceptionHandler`, the error format and
  the difference between `Exception` and `Error`.
- [x] **`i18n.md`** (its snippets checked by running them), with this outline:
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
- [x] **`security.md`** (after 2.7), its snippets checked by running them: how to authenticate with
  your own filter (Bearer/JWT, as in
  `example/03_auth_security`), `Authentication` and `RequestSecurityContext`,
  `requestAuthentication` from services, `AuthFilter` (401 vs 403), rules (`hasRole`,
  `hasPermission`, `rule`, `&`, `|`), route vs global filters with `shouldFilter`, CORS
  (`SecurityConfig.cors()`, credentials, preflight), rate limiter (sliding window, `X-RateLimit-*`
  headers, per IP, `trustedProxies`, its limits with several isolates), and a production checklist
  (HTTPS, security headers, body limit, never log secrets, `sensitive: true`).
- [x] **`dependency-injection.md`** (after 2.4), its snippets checked by running them: the API,
  tags, the global `di` instance, what
  `Winter.start` registers and how it's restored, common patterns (repository → service →
  controller), and how to replace dependencies in tests.
- [x] **`configuration.md`** (after 2.5), its snippets checked by running them: every option of
  `ServerConfig`, `Env` (supported types,
  `required`, lists, `.env`), `BuildContext` and `setUp`, and the order in which `Winter.start`
  resolves the configuration (argument → DI → default).
- [x] **`logging.md`** (after 2.6), its snippets checked by running them: `WinterLogger`, levels,
  `ConsoleLogger(minLevel:)`, writing
  your own logger, what the framework logs and at which level, and why `LogsFilter` never logs
  bodies nor query strings.
- [x] **`testing.md`** (its snippets checked by running them): `WinterTestClient` (all its methods, `TestResponse.json`), parallel tests
  without ports, `RequestScope.run` for services, injecting fake clocks (as in `RateLimiter`), and
  when a test with a real server is worth it (`Winter.close(force: true)` in `tearDownAll`).
- [x] **`deployment.md`** (its snippets checked by running them): compiling with `dart compile exe`, an example multi-stage Dockerfile,
  graceful shutdown in Docker/Kubernetes (SIGTERM, `shutdownTimeout` vs
  `terminationGracePeriodSeconds`), health checks, several isolates with `shared: true`, and running
  behind a reverse proxy (`trustedProxies`, HTTPS terminated at the proxy).
- [x] ~~**`migration-0.x-to-1.0.md`**~~ → Dropped: 1.0 is a first version (no migration guide, no
  list of breaking changes).
- [x] **Rewritten `README.md`:** (without badges until there is CI and a published version)
    - Badges (pub, CI, coverage, license), the value proposition in 3 lines, installation with the
      real version (today it says `^latest_version`) and hello world.
    - A feature table with a link to each doc, a link to the examples, and removing the "not
      production-ready" warning in 1.0.
    - Fix the SDK: the README says `>= 3.12`, `pubspec.yaml` `^3.13.0` and `CLAUDE.md` `^3.12.0`.
    - Tone down the "protect from DDoS" of the rate limiter, it promises more than it does.
- [x] **`CONTRIBUTING.md`:** FVM, commands, style (lints), how to add a language, commit convention
  (`[module] ...`), and how to update the CHANGELOG and `DECISIONS.md`.

### 5.3 Dartdoc (API reference on pub.dev)

- [x] Enable the `public_member_api_docs` lint and document the whole public API, with an example
  in the main classes (`Winter`, `WinterRouter`, `Route`, `Filter`, `ResponseEntity`,
  `ObjectMapper`, `FieldValidator`, `AuthFilter`). The object mapper already passes the lint.
  → 229 members documented; `example/analysis_options.yaml` turns the lint off for the examples
  (apps, not an API).
- [x] Clean up the comments copied from Spring with Javadoc syntax (`{@link ...}`, `{@code ...}`,
  `@see <a href=...>` with broken URLs) in `http_status_code.dart` and `status_code.dart`.
  → They were left in `http_header.dart`, now markdown links.
- [x] Use dartdoc categories (`{@category Routing}`) to group the reference by module. → 14
  categories in `dartdoc_options.yaml`, one per module; every exported declaration has one, and
  `dart doc` has no warnings.

### 5.4 Examples

The current 4 are fine. Missing:

- [x] `05_validation_object_mapper`: nested DTOs, lists, `Map<String, T>`, custom serializers and a
  422 response (after 2.1 and 2.2). → Done in 3.2 (it found that `enumByName` inside a list was a
  `Deserializer<Enum>`, `DECISIONS.md` §2).
- [x] `06_files`: multipart, static files and cookies (once they exist). → A photo gallery; it
  found that `TestResponse` could not read a binary body (now `bodyBytes`).
- [x] `07_production`: `.env`, JSON logger, request id, health check, Dockerfile and graceful
  shutdown with `onShutdown` closing a "database". → Done in 3.2.

---

## Phase 6: quality, tooling and publishing

### 6.1 CI 🟢 (after 1.0)

Postponed to a later version: until then, the same checks are run by hand before each release
(the commands of `CONTRIBUTING.md`). Notes from a first draft of the workflow:

- Run it on a push to any branch (not only `main`) and on pull requests: a feature branch is
  checked before its pull request exists, and `workflow_dispatch` only shows up once the workflow
  is on the default branch.
- `pana` fails on Windows (its sandbox rejects paths with `:`), so its first score comes from a
  Linux runner: start it as report-only and add the threshold after 5.3.
- Coverage to Codecov needs the `CODECOV_TOKEN` secret.

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

- [x] `pubspec.yaml`: `homepage`, `documentation`, `issue_tracker`, `topics` (`server`, `http`,
  `backend`, `rest`, `api`) and a `description` that says clearly in one line what it is. → Without
  `homepage` (the same as `repository`), and `false_secrets` for the test certificate.
- [x] `.pubignore`: leave out `todo.md`, `benchmark/`, `slang.yaml`, `CLAUDE.md`,
  `winter_framework.iml` and `brag-output/` (today `dart pub publish --dry-run` includes the whole
  `test/`, which is fine, but the rest is not needed). → It repeats the entries of
  `.gitignore` (pub stops reading it), and leaves out `ROADMAP.md`, `.fvmrc`, `.dockerignore`,
  `doc/api/` and what the examples generate. `dart pub publish --dry-run` passes.
- [x] Review the runtime dependencies: `slang` + `intl` (range `>=0.18.1 <2.0.0`), `crypto` (only
  for the route keys; a simpler hash would remove the dependency), `collection` and `http_parser`.
  `shelf` is already gone (3.1).
  Check that they work with the minimum versions (`dart pub downgrade && dart test`).
  → `crypto` removed: a route key is its method and path (`GET /users/{id}`), readable and without
  a hash. The tests pass with the minimum versions of the runtime dependencies
  (`dart pub downgrade collection http_parser slang intl`); a full downgrade also lowers the dev
  dependencies, and that `test` doesn't run on Dart 3.13.

### 6.3 Final review 🟡

- [x] A full security review (path traversal in static files, multipart limits, headers, errors
  never leaking internal data). → Probed against the real server:
  - Fixed: a response header with a line break, a control character or a character that isn't
    ASCII left a broken response (a 303 without `Location`, a 200 without body) logged only at
    debug; a line break from the request was a header injection attempt. Now a 500, logged.
  - Fixed: a 415 echoed the whole `Content-Type` of the client (5 KB in the probe); cut to 100.
  - Checked, fine: invalid JSON gives no excerpt of the body; `X-Request-Id` only takes
    `[A-Za-z0-9._:-]{1,128}`; static files refuse `..` (also encoded, also `\`), hidden files,
    Windows device names (`CON`, `NUL`) and links out of the folder; multipart has a limit per
    part header and malformed bodies are a 400; cookies that don't parse are skipped; a JSON body
    100.000 levels deep is decoded; `dart:io` refuses headers of about 1 MB.
  - Documented, not fixed (a proxy's job, `doc/security.md`): slow clients (no timeout to read the
    headers), the size of the headers, and connections per client. A response that is a JSON
    nested thousands of levels (echoed from the client) overflows the stack of the encoder: a 500.
- [x] Publish the benchmarks (routing, server and object mapper) and compare them with `dart:io`
  (the ceiling) and with the last version on shelf, in the README or in `doc/`. → `doc/benchmarks.md`:
  Winter at ~85 % of `dart:io` (63 % on shelf). The check of the response headers of the security
  review cost ~2 % with regular expressions; as a loop it's within the noise.
- [x] Keep the coverage of the new modules at the current level (~99%). → 99.64 % of the lines
  (2737 of 2747, without the generated code). Not covered: the end of a filter chain without a
  handler, the race between `stat` and resolving the links of a static file, a folder at the root
  of a drive, the branches of other platforms (Linux paths, SIGTERM on Windows), a connection that
  fails before its request, and a logger that throws outside the pipeline.

### 6.4 Release ⏸️ (on hold)

On hold until 4.3 is done (see the decision at the top). Then the version is decided (`0.1.0`
today in `pubspec.yaml` and the CHANGELOG, or the plan below), and the checks of 6.1 run by hand.

1. [ ] `1.0.0-dev.x` with phases 1 to 3, a first preview.
2. [ ] `1.0.0-rc.1` with phase 4 🔴 and the documentation. Use it in a real project for a few weeks.
3. [ ] Fix what comes up and publish `1.0.0`: git tag `v1.0.0`, CHANGELOG with the date, and an
   announcement (Reddit r/dartlang, Dart Discord, X).

---

## 7. Recommended order

```
Phase 1      Phase 2 (system by system)             Phase 3       Phase 4.1-4.2   Phases 5, 6.2, 6.3
(core bugs)  2.1 object mapper ──► 2.2 validation   3.1 dart:io   (features)      (docs, package,
                                                    3.2 freeze                     final review)
             ──► 2.3 exceptions ──► 2.4-2.8                │             │                │
                    │                                      │             │                │
                    └── each system's doc, once reviewed ──┴── docs of the new features   │
                                                               + examples 05-07           │
                                                                                          ▼
                                     done up to here ──► 4.3 (now) ──► 6.4 release (on hold)

CI (phase 6.1) stays postponed; until then its checks run by hand before each release.
```

Phase 3.1 goes before the features of phase 4 because cookies, static files, multipart, HTTPS and
compression are built on its server and its request/response model. It can also start in parallel
with phase 2: it only touches the HTTP layer, and the systems of phase 2 don't depend on shelf.

2.1 → 2.2 → 2.3 go in that order because each one depends on the previous: `validBody` needs the
deserialization of 2.1, and the error format of 2.3 has to include the violations of 2.2 and the
deserialization errors of 2.1. The rest of phase 2 (2.4 to 2.8) is independent and can go in any
order.

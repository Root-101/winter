# Design decisions

Why Winter works the way it does, where the code alone doesn't tell. Each section states the
decision and its reason; how to use it is in the guides of [`doc/`](doc/README.md). When a decision
changes, rewrite its section: this file describes the current design, not its history.

## 1. Translated messages (i18n)

Guide: [`doc/i18n.md`](doc/i18n.md).

- **The language of a request** comes from `Accept-Language` (RFC 9110: highest `q` first, `q=0`
  is not acceptable, `es-MX` falls back to `es`) among `localeConfig.supported`, or the `fallback`.
  `LocaleConfig` lives in `WinterContext`, so `WinterTestClient` sees it without a server. By
  default only English is supported: an app doesn't change its responses until it opts in.
- **Texts are resolved when they are created**, with `requestLocale`, the language of the request
  in progress, read from its `RequestScope` (a `Zone`). Any code (a validator, a service) builds
  the final text without receiving the request, and concurrent requests never mix. So a `message:`
  is a plain `String`, and the `t` of an app is a **getter** over `requestLocale`; validators are
  built inside `validate()`, never in a `static final` (it would keep the first language). Outside
  a request `requestLocale` is the `fallback`.
- **`Vary: Accept-Language` is automatic**: reading the language during a request marks its scope,
  and the server adds the header (merged with any other `Vary`) when the app supports more than one
  language. A response that never reads the language stays cacheable for every language. A
  validator only reads it when it fails.
- **slang + YAML**: typed access (`m.errors.validations.size.max(value: 5)`; a wrong key or
  parameter doesn't compile), pure Dart without `build_runner`, and no global state
  (`locale_handling: false`: one instance per language, built once). YAML because it nests keys by
  module and allows comments; ARB has no nesting and JSON no comments. `string_interpolation:
  braces` (`{value}`, like ARB/ICU), types declared only in the base language, texts quoted (the
  `: ` of `{value: int}`), and `fallback_strategy: none` (a missing key fails to compile instead of
  answering half in English).
- **Not translated**, on purpose: the `title` of a Problem Details and the reason phrase of the
  status line (standard texts), and the `detail` of a 400 of the object mapper (technical, for the
  developer of the client). The texts of Winter don't include the field name: it's in `fieldName`.
- A supported language that Winter doesn't translate (`fr`) answers Winter's messages in English;
  `Winter.start` logs a warning listing those languages.

## 2. Object mapper

Guide: [`doc/object-mapper.md`](doc/object-mapper.md).

- **Values and text are two APIs**: `serialize`/`deserialize` work with JSON values, `encode`/
  `decode` with JSON text, so a `String` is never ambiguous. `decode` of an empty text is `null`
  for a nullable type, else a 400.
- **Types are found by `Type`, never by name**: the name mixes two classes with the same name and
  breaks with `--obfuscate`. Registering `Deserializer<T>` derives `T?`, `List<T>`, `Set<T>`,
  `Map<String, T>` and their nullable forms (built as real types inside `Deserializer<T>`); deeper
  types are composed (`deserializerOf<T>().list()`). An explicit registration wins over a derived
  one.
- **The type of a (de)serializer is always written** (`Deserializer<User>.json(...)`,
  `Deserializer<Status>.enumByName(...)`): inside a `List<Deserializer>` Dart infers the type from
  the list, not from the arguments, so it would be registered as `dynamic` or `Enum`. One created
  with those types is an `ArgumentError`, so the mistake shows at start, not as a 500.
- **`toJson()` is called dynamically**, without an interface, so `json_serializable` and `freezed`
  models work as they are. It's read as a tear-off first: only a missing method means "no
  `toJson()`"; an error inside it is a `SerializationException`.
- **A serializer applies to subtypes** (`freezed` and sealed classes generate private subclasses):
  exact type → the first serializer of a supertype → `toJson()` → enum `name`, decided once per
  `runtimeType` and cached. Deserializers stay exact: the target type is the one asked for.
- **Absent vs `null`** (a PATCH) is a value of its own, `PatchValue<T>` read with
  `json.patch<T>()`, not a mode of the mapper: only the models of a partial update need it, and
  the rest keep plain fields. Its value is read like `json.field<T>()`.
- **Unknown fields are ignored by default, rejected on request** (`rejectUnknownFields`): a known
  field is one the `fromJson` *reads*, tracked by the map it receives, so it works with any
  `fromJson` (casts, `json.field`, generated code) without declaring the fields twice. Off by
  default: a client that sends more than the model knows (a newer version) keeps working.
- **Strict primitives**: JSON has one number type, so `12.0` is an `int`; a string is never a
  number nor a bool (`"12"` is a 400).
- **Errors say where, never what Dart said**: `$.items[1]: expected a string, got an integer`.
  The message never contains a Dart type (an internal, maybe obfuscated, name), a cast, a file path
  nor the value sent. Inside a `fromJson` the path is unknown: `$: invalid value`, with the original
  error in `cause` and its type logged at debug. A `fromJson` that deserializes its children loses
  their path; known limitation for 1.0.
- **`DateTime` is written in UTC**: a local time without offset can't be read correctly in another
  time zone.
- **Options apply to objects only**: `includeNulls` and `fieldNaming` touch the maps of `toJson()`,
  of a serializer and of `Deserializer.json`, never a `Map` used as data. `fieldNaming` renames the
  whole object given to `Deserializer.json` (a parent reads its children with Dart names), and is
  not reversible for acronyms (`userID` → `user_id` → `userId`). `prettyPrint` is on: responses are
  readable in a browser or curl; turn it off when size matters.
- **`encode` is one pass** (`JsonEncoder` with `toEncodable`), always equal to
  `jsonEncode(serialize(x))`: about 3x faster than building a copy of the tree first
  (`benchmark/object_mapper_benchmark.dart`).
- **Enums** are written by `name` and read with `Deserializer<E>.enumByName(E.values)` (Dart can't
  list an enum from its type); the 400 lists the valid names. `.string`, `.integer`, `.number` and
  `.boolean` check the JSON type before converting, so the 400 says what was expected.
- **`body<T>()`** reads JSON when the `Content-Type` is JSON (`*/*+json` included), `text/plain`
  (what `package:http` and `fetch()` send for a String) or none; any other is a 415 that names the
  expected type. `body<String>()` decodes a JSON string only when the body is JSON.

## 3. Validation

Guide: [`doc/validation.md`](doc/validation.md).

- **The value first, typed**: `cvc.field(name, value)` returns a `FieldValidator<T>` whose rules
  run as they are chained, so there is no final call to forget. The validators are generic
  extensions bounded by the type of the value (`StringValidators<T extends String?>`...) that
  return `FieldValidator<T>`: `.min()` on a String doesn't compile, and chaining keeps the type.
- Every validator but `notNull` passes on `null`; `stopOnFailure` (default in `notNull`) skips the
  rest of the field. A validator of the app is an extension that calls `addRule`; its message is a
  function, called only on failure, so a valid request never reads the language.
- **`body<T>()` validates** a `Validatable` (or a list of them) by default: a model implements it to
  be validated. A PATCH opts out (`validate: false`) or uses a model of its own.
- **Nested objects**: `valid()` and `validEach()` prefix the violations (`address.zip`,
  `items[0].quantity`, `prices["eur"].amount`) and run the nested `validate()` with the clock of the
  parent. A key of a map is quoted as in JSON and never renamed by `fieldNaming` (it's data).
- **Each violation has a `code`** (the key of its text in `*.i18n.yaml`) and `params` (JSON values
  only), so a client can show its own text. The 422 **never includes the value**: the client knows
  what it sent, and repeating it leaks personal data; a `sensitive` field never even stores it.
- `fieldName` follows the `fieldNaming` of the mapper: it's the name the client sent.
- `Validatable` is an interface without a default `validate()`: a default valid result would hide a
  forgotten implementation.
- `validate()` is synchronous; a rule that needs an `await` ("the email exists") goes in
  `AsyncValidatable.validateAsync()`, which `body<T>()` runs only after `validate()` passed: a
  value with a wrong format never reaches a query, and both failures are the same 422. A separate
  interface, so the synchronous models (and `valid()`/`validEach()`) didn't change.

## 4. Errors

Guide: [`doc/error-handling.md`](doc/error-handling.md).

- **Every error is a Problem Details** (RFC 9457, `application/problem+json`): one format any
  client reads, the standard Spring uses too. `type` (`about:blank` by default), `title` (the
  reason phrase, never translated), `status`, `detail` (what the user reads, never in a 500) and
  extensions; the 422 adds `violations`, a 500 its `requestId`.
- **The names of the format are fixed** (`requestId`, `fieldName`...) whatever the `fieldNaming` of
  the app, so every Winter app answers errors the same way (and kebab-case would break the member
  names RFC 9457 recommends). The extensions of the app keep the names it gives.
- **`ApiException(status, detail:, type:, title:, extensions:, headers:)`** with shortcuts for the
  common statuses; they are `const`. A response that is not a Problem Details (or a status that
  `StatusCode` doesn't have) is a `ResponseException`.
- **The `ExceptionHandler` receives everything** (`Object`: Exceptions and Errors), and the chain
  turns it into a response where it's thrown, so every outer filter (CORS, logs) sees a response.
  Anything unexpected is logged and answered as a generic 500 without details. If the handler
  itself throws, both errors are logged and the answer is a generic 500.
- **`SimpleExceptionHandler..on<T>()`** maps an exception of the app to an `ApiException` or a
  response; the most specific type wins whatever the order, and a mapping that throws goes to the
  default rules (never loops). Extending it and overriding `handle` also works.
- **Winter's own errors are exceptions** (the 404/405 of the router, the 401/403 of `AuthFilter`,
  the 429 of the rate limiter), so the handler is the only place that formats errors.
- The 400 of the mapper has a JSON path (`$.items[1].price`), the 422 a field name
  (`items[1].price`): a 400 is a bug of the client's code, a 422 points at an input of a form.

## 5. Dependency injection

Guide: [`doc/dependency-injection.md`](doc/dependency-injection.md).

- **A service locator, by exact type**: registered and found by `(Type, tag)`, never by reflection
  (AOT has none) or code generation. An implementation is found by the type it was registered with;
  looking up subtypes would be slower and ambiguous. `T` and `T?` are the same key.
- **Lifetimes**: `put` (an instance), `putLazy` (created by the first `find`; a cycle is a
  `StateError` with the chain), `putFactory` (one per `find`) and `putScoped` (one per request, in
  its `RequestScope`). The functions are synchronous, except `putLazyAsync`: created by
  `ready()`, which `Winter.start` awaits before opening the port, so `find` stays synchronous
  everywhere (an async `find` would turn every handler and constructor into a `Future`). A cycle
  between async ones is detected through a `Zone`: with `await` it would wait forever.
- **Child containers** (`di.child()`) take the recipes of their parent, not its instances (only
  the instances given with `put` are shared): a lazy singleton of the parent gets its own instance
  in the child, so it's built with the fakes of a test and the parent never changes (sharing the
  instance would leak a fake to the next test, or ignore it if it was already created).
- **`createAll()`, optional**: lazy keeps the order of registration free and the start fast, but a
  broken registration only fails when it's first found. Without reflection the graph can't be
  checked without creating it, so `createAll()` creates every lazy singleton (not factories nor
  scoped ones) and reports every failure in one `StateError`, as `Env.requireAll` does.
- **A scoped dependency can't be captured**: finding one while a lazy singleton is being created,
  or after its request ended, is a `StateError` (it would keep a disposed instance).
- **`onDispose`** runs on `Winter.shutdown()` (after the requests and `onShutdown`) or
  `disposeAll()`, in reverse order of registration, only for created instances; a failing one is
  logged and the others run. A scoped instance is disposed at the end of its request
  (`RequestScope.onComplete`).
- A registered `null` is valid: `isRegistered` tells it from a missing one. `put` of a registered
  key replaces it, so a test can register a fake at any time.

## 6. Configuration

Guide: [`doc/configuration.md`](doc/configuration.md).

- **`find<T>` returns `T?`, `require<T>` a `T`**, and `requireAll` names every missing variable in
  one error (in a container, one restart per missing variable is slow). An empty value counts as
  missing.
- **An error never shows the value**: a configuration error ends in the logs, and the value may be
  a secret.
- Types: `String`, `bool`, `int`, `double`, `num`, `Duration` (`30s`), absolute `Uri`, lists (comma
  separated) and enums (`findEnum`). A `String` is never trimmed (a secret may have spaces); the
  other types are.
- **`Env.load()`**: process variables > `.env.<WINTER_PROFILE>` > `.env`, missing files ignored.
  In production the platform gives the variables, the files are for local development, so the same
  code runs in both. No interpolation (`${OTHER}`): it hides where a value comes from.
- **`ServerConfig` is `const`** (a `host` String, not an `InternetAddress`), validated by
  `Winter.start` before opening the port. `ServerConfig.fromEnv(env)` reads `PORT` and `HOST`, the
  variables of Cloud Run, Heroku and Kubernetes.
- The configuration of an app is a class read once at start and registered in `di`, so a missing
  variable fails before the port opens.

## 7. Logging

Guide: [`doc/logging.md`](doc/logging.md).

- **The logs never contain the data of a request**: no bodies, query strings, tokens, nor the
  message of a deserialization error (it may contain the value sent); only the type of the error.
- **Every request has an id**, always: its `X-Request-Id` when it's valid (1–128 safe characters,
  so a header can't inject lines into the logs), or a new UUID. It's in `requestId`, the response,
  every log of the request and a 500. It turns "it failed at 10:31" into the logs of that request.
- Every level takes `error`, `stackTrace` and `fields`; `isEnabled(level)` skips building an
  expensive message (the framework's debug logs use it, so an attack doesn't cost a string per
  rejected request).
- `ConsoleLogger` for development (UTC time, the request id, `key=value` fields; warning and error
  to stderr) and `JsonLogger` for production (one object per line with the keys Cloud Logging
  reads; fields never replace them).

## 8. Security

Guide: [`doc/security.md`](doc/security.md).

- **Authentication is the app's filter**: it sets the `Authentication` of the request; `AuthFilter`
  answers **401** with a `WWW-Authenticate` challenge (RFC 9110; `Bearer` by default) when nobody is
  authenticated, and **403** when the rules fail.
- **Roles and permissions**, nothing else: an "authority" is `hasRole(x) | hasPermission(x)`.
- **Rules see the request** (`evaluate(authentication, request)`, `rule((auth, request) => ...)`),
  so "only the owner" lives in the rule. `describe()` gives the readable form of any rule.
- **A typed principal from any code**: `requestPrincipal<T>()` (the scope) and
  `request.principal<T>()`; nobody is a 401, another type a `StateError` (a bug of the app).
- **CORS**: `'*'` with credentials echoes the origin and logs a warning (any site could use the
  user's cookies); `Vary: Origin` on every response that depends on the origin; `X-Request-Id` is
  always exposed.
- **Security headers**: `X-Content-Type-Options: nosniff` and `X-Frame-Options: DENY` on every
  response (an API is never framed); `SecurityHeaders` adds `Referrer-Policy`, a CSP for an API and
  HSTS (only with `hsts: true`: it must only be sent over HTTPS). No `Server` nor `X-Powered-By`: an
  API doesn't announce its framework.
- **Rate limiter**: a sliding window over an asynchronous `RateLimiterStore` (in memory by default,
  so per isolate and per process; a shared store like Redis implements the same interface).
  `maxRequests < 1` or a non positive window is an `ArgumentError`. The client is its IP; behind a
  proxy `trustedProxies` reads `X-Forwarded-For`, never trusted without it.
- **Response headers are checked before they're sent**: a value with a line break, another control
  character or a character that isn't ASCII, or a name that isn't a token, is a 500 with the error
  logged (never the value). `dart:io` refuses those headers, so the response would leave broken and
  silent; and a line break taken from the request (a `Location` built from a query) is a header
  injection. The check is in the pipeline, so `WinterTestClient` answers the same.
- **What the client sent is never echoed whole**: an error names a param or a field, not its value,
  and the `Content-Type` of a 415 is cut to 100 characters.

## 9. Router and filters

Guides: [`doc/routing.md`](doc/routing.md), [`doc/filters.md`](doc/filters.md).

- **The route table is checked at start**: an invalid path or a duplicated route is a `StateError`
  (`RouterConfig.fail()`), found at start instead of as a 404. A duplicate is the same key, or the
  same method and shape (`/users/{id}` and `/users/{name}`: the second could never be reached).
  Only the literal parts of a path are validated; params and regex can have any character.
- **The resolved `Route` travels in the request** (`request.route`), not as text: the server
  resolves it before the filters (so the route filters run and the path params are ready) and the
  chain ends in its handler; the router only answers when there is no route (404, 405, `OPTIONS`)
  or it has no routes (`ServeRouter`). **Route keys** are the method and path (`GET /users/{id}`:
  readable in the logs, unique like them, no hash) or given by the app, so a filter recognizes a
  route (`request.route?.key`) without depending on its path.
- A static route wins over a dynamic one; between the rest, the first declared. A trailing slash is
  ignored; repeated slashes are a 404 (a proxy rule for `/admin` doesn't block `//admin`, so the
  path is never rewritten). An empty child path is not a route: the parent takes the handler.
- **`HEAD` and `OPTIONS` are automatic**: `HEAD` uses the `GET` route, an `OPTIONS` without its own
  route is a 204 with `Allow` (RFC 9110), and `Allow` always lists `OPTIONS`.
- **Typed params**: `pathParam<T>`/`queryParam<T>` (`String`, numbers, `bool`, `DateTime`, one of
  `values`); an invalid value is a 400 that names the param, never the value. A name that isn't in
  the route, or an unsupported type, is a bug of the app (500).
- **Static files** (`Route.static`, `StaticFiles`): a `GET` route with a regex param, so `HEAD`,
  filters and route keys work as in any route. Only files inside the folder, checked twice: no
  `..`, hidden, `\` or `:` segment (`.env`, `.git/`, a Windows separator, drive or stream), and the
  canonical path (links resolved) inside the canonical folder. `ETag` from size and modification
  time (strong, so `If-Range` can use it), 304, one `Range` (several are rare and need
  `multipart/byteranges`: the whole file is sent instead), the file streamed with its
  `Content-Length`. A folder redirects to its `/` before serving its index, with a relative
  `Location` that works behind a proxy prefix. MIME types are a short table of the web formats,
  extended by `mimeTypes:`, without a dependency.
- **Health checks** (`Route.health`): a route, not a server feature, so the app decides its paths
  (liveness and readiness are two of them) and its filters. Named checks (`FutureOr<bool>`) run at
  once, each with a timeout (a hung database must not hang the probe); a false, an error or a
  timeout is a 503 `DOWN` with the state of each check, never the reason (it's logged). Its own
  JSON (`status`/`checks`, as Spring Actuator), not a Problem Details, also for the 503.
- **A route path has no query**: a `?` in it belongs to a regex (`{id|\d?}`, `(/.*)?`).
- **Immutable configuration**: `FilterConfig` (combined with `merge`) and the routes of a router
  (added with `addRoute`, validated like the constructor).
- **Filters run sorted by `order`**, stable (global first, then the route's, parents before
  children); CORS (-100) and the security headers (-99) first, so every response has them. An
  error becomes a response where it's thrown, so a filter never receives an exception.

## 10. The HTTP layer

Guide: [`doc/requests-and-responses.md`](doc/requests-and-responses.md).

- **Winter serves with `dart:io` directly**, with its own request and response, without shelf: its
  public API doesn't depend on another package (nor on its breaking changes), and an empty endpoint
  is close to the `dart:io` ceiling (~83 %, `benchmark/http_benchmark.dart`).
- **The request is read-only** (headers, query and path params): a filter passes a copy to the
  chain. `headers` (one value, case insensitive) and `headersAll` (every value); the headers of
  `dart:io` are read as a view, not copied. The body is read once and shared by the copies;
  `body<T>()` caches it. The size limit (`maxBodySize`) wraps that body, without a copy. A body
  that stops being read before its end (a 413, a malformed multipart body) is read to the end and
  discarded instead of cancelled: cancelling the body of `dart:io` closes the connection, and the
  client would never get the answer.
- **The context is extensible and typed**: data attached to a request (or a response) is found by
  a `ContextKey<T>`, an object, not a name, so two packages never overwrite each other and a value
  has its type without casts. An extension turns it into a property (`request.securityContext`
  and `request.locale` of Winter, and the same pattern in an app: `request.tenant`). Data of the
  core (the route) are fields. A copy starts with the same values.
- **One `copyWith`**, synchronous, in both types: `headers` are added (`null` removes one), and a
  new body is resolved again with its own `Content-Type` and `Content-Length`.
- **A response body is a value**: a `String` is text, a `Uint8List` bytes (a `List<int>` is data,
  written as JSON), a `Stream<List<int>>` a stream, anything else JSON. Text and bytes can be read
  any number of times (a filter can look at the body); only a stream is read once. A text body always says its
  charset (shelf only did it for non-ASCII bodies, so a response changed with its language).
- **Writing a response**: the reason phrase of `StatusCode` (`dart:io` alone sends
  `422 Status 422`), a `Date` (RFC 9110; formatted once per second), a `Content-Length` for bytes
  or chunked for a stream (sent as it's produced, for Server-Sent Events; `dart:io` sends the
  headers with the first chunk), no body for `HEAD`/204/304, and the length left out when gzipping
  (`dart:io` only compresses chunked responses). A client that leaves, or a stream that fails, is
  logged at debug: the server goes on.
- **The server**: `bind` or `bindSecure` (HTTPS with `securityContext`), `shared` isolates,
  `autoCompress` (off: usually the proxy compresses) and `idleTimeout`. The default headers of
  `dart:io` are cleared so the real server and `WinterTestClient` answer the same.
- **Request timeout** (`ServerConfig.requestTimeout`, off by default: a limit that fits every app
  doesn't exist, and a slow upload would fail): a filter right after CORS and the security headers
  (order -98), so the 503 is a Problem Details with their headers and every other filter is timed.
  A `Future` can't be cancelled: the handler is abandoned, its late result ignored and a late error
  logged; the response is sent, so the request stops holding the graceful shutdown. Only building
  the response is timed, not sending it (streams).
- **`Winter.buildHandler`** returns the pipeline as a `RequestHandler`; `WinterTestClient` calls it
  in memory, so tests run the real pipeline.
- **Forms and uploads**: `formData()` reads a whole form (`application/x-www-form-urlencoded` or
  `multipart/form-data`) into memory, with the files as bytes, from the cached body: the simple
  case, and `maxBodySize` bounds it. `multipart()` streams the parts so a big file goes to disk
  without being held; its parts come in order and a part left unread is discarded, never buffered.
  The multipart parser is Winter's own, not `package:mime`: `mime` throws a malformed header
  inside its own `listen` (an uncaught error) and leaves the reader of a part waiting forever when
  the body ends early or fails (a 413), and a client controls both. Winter's parser pulls the body
  (`StreamIterator`), so every error is thrown by the read that waits for it, as a 400 (or the 413).
  A file name is given as the browser sent it (WHATWG: no backslash escapes) and never cleaned:
  it's not a path.
- **Server-Sent Events** (`ResponseEntity.sse`, `ServerSentEvent`): a stream response, not a
  route of its own, so the filters (auth, CORS) and the request scope apply as to any request. A
  comment first (the headers leave at once) and every `keepAlive` (proxies close idle
  connections), `X-Accel-Buffering: no` for nginx, and the stream ends when the server starts
  closing: an endless stream would otherwise hold every graceful shutdown until its timeout, and
  the browser reconnects anyway. `event` and `id` with a line break are an `ArgumentError`: they
  would inject another event.
- **WebSockets** (`Route.websocket`): the handshake is a `GET` route, so the filters (auth, rate
  limit, logs) and the request scope apply before the upgrade. Its handler answers a 101 that
  carries the upgrade in its context; the server recognizes it before writing and hands the
  `HttpRequest` to `WebSocketTransformer.upgrade`. The socket is the `WebSocket` of `dart:io`
  (no wrapper to learn), plus `sendJson`. `allowedOrigins` is explicit because CORS doesn't cover
  WebSockets and a browser sends the cookies to any of them (cross-site WebSocket hijacking). The
  handler runs in a request scope of its own, completed when the socket closes; it isn't awaited
  as a request in progress, so the server closes the sockets itself (1001) when it shuts down,
  also the ones that finish their upgrade while it's closing.

## 11. The public API

- **One library**, `package:winter/winter.dart`. Internal helpers stay in `lib/src` and are hidden
  with `export ... hide`: `addVary`, `limitBodySize`, `isValidUri`, the router helpers,
  `writeResponse`, the construction from an `HttpRequest`, the multipart parser, Winter's own
  translations and the console styles. Public on purpose: `internalServerErrorResponse` and `defaultLogUnhandledError`
  (for an `ExceptionHandler` of the app), the defaults of the filters (`defaultLog*`,
  `defaultClientId`), and the shortcuts `di`, `om`, `eh`, `env`, `logger` (short on purpose; the
  long form is `Winter.context`).
- **Names that don't clash**: `WinterContext` (not `BuildContext`, a class of Flutter), `BaseRouter`
  (not `Router`, a widget of Flutter), `HttpHeader`/`StatusCode` (not the `HttpHeaders`/
  `HttpStatus` of `dart:io`). Filters are named in singular (`LoggingFilter`).
- **`StatusCode` is one enum**: `value`, `series`, `reasonPhrase`, Dart getters (`isSuccessful`,
  `isError`...), `resolve` (null for a code it doesn't know) and `valueOf` (`ArgumentError`). One
  constant per code.
- `HttpHeader` names are `const`, so they work in `const` maps and in a `switch`.
- **No code generation**, except the translations (slang, `DECISIONS.md` §1): no annotations, no
  package scanning, no `build_runner` for routes, injection or JSON. What an app declares is plain
  Dart that is read as it is written (routes in a list, `di.put`, a `fromJson`), and an app that
  wants `json_serializable` or `freezed` uses them on its own.

## 12. OpenAPI

Guide: [`doc/openapi.md`](doc/openapi.md).

- **What Winter knows, it writes by itself**: the paths and methods, the path params (an integer
  from `[0-9]+`/`\d+`, a `pattern` from another regex), the security of the `AuthFilter`s that run
  for each route (found by running their `shouldFilter` with a request to it, the way the server
  does), and the errors as Problem Details (400, 401/403, 404, 415, 422, 429).
- **The bodies come from examples**, not from annotations nor code generation (the project avoids
  both): an example is written by the object mapper, so its schema is what the API really sends,
  and the rules of its `validate()` become the constraints. Those rules are recorded without being
  evaluated (a `Zone` flag in `addRule`), so describing has no side effects and the async rules
  never run. Nothing is written twice.
- **A schema by hand wins** where an example isn't enough (`JsonSchema`, or both in `BodyDocs`):
  the four ways (example, schema, both, nothing) share one field per body.
- **OpenAPI 3.1** (JSON Schema 2020-12: `nullable` is a type list). `Route.static` and
  `Route.websocket` are hidden by default (not operations of an API), `Route.health` documents
  itself. Swagger UI comes from a CDN at a pinned version (`swagger-ui-dist` 5.17.14, written in
  `doc/openapi.md`), allowed by the CSP of its page: not configurable, so the page never changes
  by itself.

## 13. Scheduled tasks

Guide: [`doc/scheduling.md`](doc/scheduling.md).

- **Its own cron parser, no dependency**: 5 fields with ranges, steps, lists, names and macros,
  the day of the month and of the week matched as in cron (either one when both are restricted).
  No seconds and no `L`/`W`/`#`: they cover rare cases, and a `Schedule` of your own (`next`)
  covers anything else. An invalid expression fails when the task is added, naming the field.
- **Local time by default**, as cron, and `utc: true`. The calendar is walked in UTC fields and
  the result built in the zone of the schedule, so a daylight saving change never loops.
- **A timer per task that waits one minute at most**, then checks the time: a change of the clock
  or a suspended machine delays a run a minute, not hours. Missed runs are not repeated (one run,
  and a warning with how many were missed): the scheduler is not a persistent job queue.
- **`every` counts from the time it was due**, not from the end of the run, so it doesn't drift.
- **A run never overlaps the previous one** by default (it's skipped with a warning):
  `allowOverlap` opts in. A task that piles up runs is a bug that would get worse under load.
- **Each run in a `RequestScope`**, like a request and a WebSocket: an id for its logs, and
  `di.putScoped` dependencies that live for the run. An error is logged, never thrown: one task
  never stops the server or the others.
- **With the server, not inside it**: `Winter.start(scheduler:)` (or `di`) starts it after the
  port is open and stops it when the server closes; a graceful close waits for the runs in
  progress within the same timeout as the requests. A `Scheduler` also works without a server.
- Every instance runs its tasks: a task that must run once in a cluster is chosen by
  configuration or a lock of the app, not by Winter.

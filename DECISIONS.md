# Design decisions

Why the framework behaves the way it does where that is not obvious from reading the code. When a
decision changes, update it here.

## 1. Translated messages (i18n)

**What it does.** Winter answers the messages of its validators (`notNull`, `notBlank`, `size`,
`min`, `max`, `email`, `pattern`, `isEnum`) in the language of the request:

- `request.locale` picks the language from `Accept-Language` (highest `q` first, `es-MX` falls back
  to `es`) among `Winter.context.localeConfig.supported`, or `fallback` (English) when nothing
  matches or there is no header. It is computed once and cached in `request.context`
  (`'winter.context.locale'`), the same pattern as `request.securityContext`.
- The texts live in `lib/src/i18n/en.i18n.yaml` and `es.i18n.yaml`; `fvm dart run slang` generates
  `messages*.g.dart` (config in `slang.yaml`), which is versioned.
- A validator builds its text with `requestLocale` (the locale of the request in progress, see
  below), and `SimpleExceptionHandler` only serializes it.
- **`Vary: Accept-Language` is automatic**: reading `requestLocale` or `request.locale` during a
  request marks its `RequestScope` (`localeRead`), and the server adds the header to that response
  when the app answers in more than one language. It is merged with any other `Vary` (`Origin` of
  CORS) and never duplicated. The app doesn't have to remember it, and a response that never reads
  the language (a fixed text, a 200 without texts) stays cacheable for every language.

**Why `slang`.**

- *Typed access*: `m.errors.validations.size.max(value: 5)` instead of
  `messages.get('key', locale, args)`. A typo in a key or a missing parameter is a compile error,
  not a runtime surprise.
- *Pure Dart, no `build_runner`*: it works with `flutter_integration: false` and generates with
  `dart run slang`. The project avoids `build_runner`.
- *No global state*: with `locale_handling: false` there is no `LocaleSettings`; each locale is an
  instance (`WinterMessagesLocale.es.buildSync()`), so two concurrent requests in different
  languages never interfere. They are built once and cached (`winter_messages.dart`).

**Why YAML and not ARB or JSON.**

- *Nested keys*: the messages are grouped by module (`errors.validations.size.min`), and slang turns
  every level into a generated class. **ARB does not support nesting** (every key is flat, so it
  needed prefixes like `sizeMinLength`), which is why it was dropped even though it is Flutter's
  format.
- *Comments*: JSON supports the same nesting but **no comments**. YAML does, so each block can say
  which validator uses it and why a text is the way it is.

**Details of the format.**

- `string_interpolation: braces`: parameters are written `{value}`, like ARB/ICU, instead of slang's
  default `$value`.
- The parameter types are declared only in the base locale (`{value: int}` in `en.i18n.yaml`); the
  other locales only need the text.
- The texts must be **quoted**: the `: ` inside `{value: int}` would otherwise be read by YAML as a
  map.
- `fallback_strategy: none`: a key missing in a locale makes the generated code fail to compile.
  With few messages it is better to fail early than to answer half in English.
- slang always generates **named** parameters (`max(value: 5)`, never `max(5)`).

**Why messages are resolved when they are created, with the locale of the request.** Every request
runs in its own `Zone` with a `RequestScope` (`lib/src/request_scope.dart`), so any code reads the
language with `requestLocale` without receiving the request, and concurrent requests never mix. A
validator (or a service) builds the final text right away, in the language of the request, and the
exception handler only serializes it. An app uses its own slang-generated classes the same way:

```dart
AppMessages get t => appMessages(requestLocale); // a getter, never a `final`

cvc.field('prefix', prefix).notNull(message: t.errors.validations.prefixRequired);
throw UnauthorizedException(body: t.errors.signature.invalid);
```

- *Before*: a validator stored a `LocalizedText` (`String Function(WinterLocale)`) and the exception
  handler resolved it with `request.locale`, because whoever threw the error did not know the
  request. It forced every custom text to be a function (`message: (_) => 'text'`,
  `localized((m) => ...)`) and the violations to carry `localizedMessage`. With the scope the
  language is known everywhere, so the functions are gone: `message` is a plain `String?`.
- *Why not generic over the app's messages class*: Winter cannot know the class slang generates in
  the app. The app writes a one-line getter over `requestLocale` instead.
- It was a breaking change (`LocalizedText`, `addLocalizedRule`, `localizedMessage`, `messageFor`
  and `localize` were removed), accepted because the i18n API had no external users yet.

**Caveats.**

- The text is resolved when it is **evaluated**: `message: t.x` while building the validator. Build
  validators inside `validate()` (once per call, as usual), not in a `static final`, or the text
  stays in the language of whoever built it first. For the same reason the app's `t` is a getter.
- Outside a request (start-up, a global `Timer`, a unit test) `requestLocale` is
  `localeConfig.fallback`. Tests give a language with `RequestScope.run(RequestScope(locale: ...))`.

**Compatibility.**

- `ConstraintViolation.message` is in the **language of the request**, also in logs and `toString`
  (before it was always English).
- `addRule` and `custom()` receive whatever text the rule returns; translate it with
  `requestLocale`.
- `LocaleConfig` lives in the `BuildContext` (not in `ServerConfig`) so `WinterTestClient` and
  `buildHandler` see it without starting a server. By default it only supports English, so an
  existing app does not start answering in Spanish until it opts in.

**Known limitations.**

- `size` uses the same text for Strings (length) and Iterables (items): "The minimum is 3", the
  same as `min()`.
- The texts do not include the field name; it is already in `fieldName` of the response.
- `Vary` is added by the server after the whole chain, so the filters don't see it in the response.
  Reading the language only to log it also adds it (harmless, it only lowers the cache hit rate).
- An app can support a language that Winter doesn't translate (ex: `fr`): its own texts come in
  French but the validation messages of Winter fall back to English, so a 422 can mix both.
  `Winter.start` logs a warning listing those languages (`localesWithoutWinterMessages`, a region
  counts as its language). The fix is a custom `message:` or a new `*.i18n.yaml` in Winter.
- What is **not** translated, on purpose: the default bodies of the HTTP errors (`Bad Request`,
  `Not Found`...) are the standard reason phrases, like the error codes; the messages of
  `DeserializationException` (400) and similar are technical, for the developer of the client.
- `custom()` and `addRule` validators are not translated by Winter: their rule returns the text.

## 2. Object mapper

**Status:** decided and implemented on 2026-10-06 in the review of phase 2.1 of `ROADMAP.md`.
`test/object_mapper/object_mapper_behavior_test.dart` covers every section below.

### 2.0 Values and text: `deserialize` vs `decode`

`serialize`/`deserialize` work with JSON values (`Map`, `List`, `String`, `num`, `bool`, `null`)
and `encode`/`decode` with JSON text.

- *Why*: `deserialize` used to take both, and a `String` was JSON text or a value depending on the
  target type (`_isPrimitive`). That's why `body<String>()` returned the quotes of a JSON string and
  `int` was parsed from `"12"`. With two methods a string is never ambiguous.
- `decode` of an empty text is `null` for a nullable type, else `The body is empty` (400).

### 2.1 Types are found by `Type`, never by name

Registering `Deserializer<T>` also registers, derived from it, the deserializers of `T?`,
`List<T>`, `Set<T>`, `Map<String, T>` and the nullable form of each collection. The defaults
(`int`, `String`, `DateTime`...) get them too, so `body<List<int>>()` needs nothing.

- *Why*: the lookup by name (`k.toString() == typeName`) mixes two classes with the same name from
  different libraries (the 400 even sent the client the paths of the server's files), breaks with
  `dart compile exe --obfuscate`, and only understood one level of `List<...>`/`Map<...>`. Inside
  `Deserializer<T>` the types `List<T>`, `T?`... can be built as real `Type`s (checked in JIT and
  AOT), so every lookup is an exact `Type` comparison and needs no new API.
- Deeper nesting is explicit and composable: registering
  `Deserializer<User>.json(User.fromJson).list()` derives `List<List<User>>`,
  `Map<String, List<User>>`... For the default types, `om.deserializerOf<int>().list()` gives the
  registered deserializer to build from.
- An explicit registration wins over a derived one, and removing a deserializer removes its
  derived types.
- A type without a deserializer is still a `StateError` (500): it's a bug of the server, not of the
  client.
- `ListTypeExtension` (`isList`/`isMap` on every `Type`) is removed.

### 2.2 `toJson()` is called dynamically; `Serializable` is removed

An object without a registered serializer is serialized with `(object as dynamic).toJson()`, so
the models of `json_serializable` and `freezed` work as they are.

- *Why*: `Serializable` only existed so the mapper could call `toJson()`. A dynamic call does the
  same (it works in AOT), and asking every generated model for `implements Serializable` was the
  most common reason for a 500.
- `toJson` is read as a tear-off before calling it: only a missing member means "no `toJson()`"
  (a `MissingSerializerError`, a `StateError` that names the type and how to fix it). An error
  thrown **inside** an existing `toJson()` is a `SerializationException`, never confused with a
  missing method. A `toJson` getter that isn't a method doesn't count.
- An enum with a `toJson()` uses it; without one, its `name`.
- Breaking: `Serializable` is gone (the examples and `ConstrainViolation` drop the `implements`).

### 2.3 A serializer applies to subtypes

The lookup is: the exact `runtimeType` → the first registered serializer whose type matches
(`object is T`) → `toJson()` → enum `name`. The result is cached per `runtimeType`, so the scan
happens once per class.

- *Why*: `freezed` generates private subclasses (`_$UserImpl`), so with exact types a
  `Serializer<User>` never applied to them; the same for `sealed` hierarchies.
- The default `Serializer<num>` and `Serializer<Object>` are removed: they were never used, and
  `Serializer<Object>` would now match everything.
- Deserializers stay exact: the target type is the one asked for (`body<User>()`).

### 2.4 Strict primitive types

| JSON          | `int` | `double` | `num` | `bool` | `String` |
|---------------|-------|----------|-------|--------|----------|
| `12`          | 12    | 12.0     | 12    | 400    | 400      |
| `12.0`        | 12    | 12.0     | 12.0  | 400    | 400      |
| `12.5`        | 400   | 12.5     | 12.5  | 400    | 400      |
| `"12"`        | 400   | 400      | 400   | 400    | `"12"`   |
| `true`        | 400   | 400      | 400   | true   | 400      |
| `"true"`      | 400   | 400      | 400   | 400    | `"true"` |

- *Why*: accepting `"12"` but rejecting `12.0` was neither strict nor lenient. JSON has a single
  number type, so `12.0` is a valid `int`; a string is never a number.
- It applies to what the mapper deserializes itself (`body<int>()`, `List<int>`, `Map<String, int>`,
  `Duration`). Inside a `fromJson` the model's code decides.

### 2.5 Errors: a path and a clean message

A failed deserialization is a 400 whose message never contains Dart details (type casts, parser
positions, file paths):

| Input                                         | Message                                     |
|-----------------------------------------------|---------------------------------------------|
| `{"a":1,"b":"x"}` as `Map<String, int>`       | `$.b: expected an integer, got a string`    |
| `[{"name":"A"}, 1]` as `List<User>`           | `$[1]: expected an object, got a number`    |
| `{}` as `User` (its `fromJson` fails)         | `$: invalid value`                          |
| `{"name": ` (malformed)                       | `The body is not valid JSON`                |

- The path is known where the mapper walks the data itself (lists, maps, primitives). Inside a
  `fromJson` it is not: the message is `invalid value` at the path of the object, and the type and
  the original error are logged at `debug` (the error is also in `cause`).
- The message never names a Dart type: it's an internal name of the server, and with
  `--obfuscate` it's a meaningless one (`invalid value for ej`, found by compiling with
  `dart compile exe --extra-gen-snapshot-options=--obfuscate`).
- The format of the response body (Problem Details) is decided in phase 2.3; this only fixes the
  message.

### 2.6 `DateTime` is always UTC

`DateTime` is serialized as `toUtc().toIso8601String()` (`2026-01-01T16:30:00.000Z`).

- *Why*: a local date without an offset (`2026-01-01T10:30:00.000`) can't be read correctly by a
  client in another time zone. UTC is the usual format of an API, and Dart can't write the offset
  without formatting it by hand.
- Deserialization accepts whatever `DateTime.parse` accepts (with `Z`, an offset, or none).

### 2.7 `body<T>()` and the `Content-Type`

- A request whose `Content-Type` is not JSON (`application/json` or any `*/*+json`), `text/plain`
  or missing is a **415** for `body<T>()`. Without a `Content-Type` the body is read as JSON (shelf
  doesn't add one).
- `text/plain` is read as JSON too: `package:http` (every Flutter app) and the browser's `fetch()`
  send it for a String body when no header is given. Found while implementing it: the strict 415
  broke the tests that use `package:http`.
- `body<String>()` decodes a JSON string only when the `Content-Type` is JSON (`"hello"` →
  `hello`), and returns the text as it is otherwise. It never answers 415.
- *Caveat*: `curl -d '{...}'` sends `application/x-www-form-urlencoded` unless `-H 'Content-Type:
  application/json'` is given, so the 415 message must say which `Content-Type` is expected.
- Forms (`formData()`) and multipart come in phase 4.1 with their own methods.

### 2.8 Options of the `ObjectMapper`

`ObjectMapper(...)` gets four options. The defaults keep the previous behavior, except
`prettyPrint`:

| Option           | Default        | Values                                         |
|------------------|----------------|------------------------------------------------|
| `includeNulls`   | `true`         | `false` drops the keys with a `null` value     |
| `fieldNaming`    | `none`         | `snakeCase`, `kebabCase`                       |
| `durationFormat` | `milliseconds` | `iso8601` (`PT1H30M`)                          |
| `prettyPrint`    | `true`         | `false` writes compact JSON                    |

- `includeNulls` and `fieldNaming` apply **only to objects** (the maps returned by `toJson()` or by
  a serializer, and the map given to `Deserializer.json`), never to a `Map` the app serializes or
  asks for directly (`Map<String, T>` holds data, its keys are not field names).
- *Limitation*: a parent `fromJson` calls the `fromJson` of its children itself, so `fieldNaming`
  renames the keys of the whole object given to `Deserializer.json`, including a `Map` field
  inside it. A model generated by `json_serializable` should use its own `fieldRename` instead.
- Renaming is not reversible for acronyms: `userID` becomes `user_id` (the readable form), which
  comes back as `userId`. The docs recommend camelCase names without acronyms (`userId`), and the
  tests cover the round trip.
- `prettyPrint` is **on by default**, so the responses are readable when they are inspected
  (browser, curl, logs). It makes every JSON response bigger (two spaces per level and a new line
  per value; `{"message":"hello"}` goes from 19 to 24 bytes); turn it off
  (`ObjectMapper(prettyPrint: false)`) when the size matters. Tests should compare decoded JSON,
  not the text.

### 2.9 Performance: `encode` in a single pass

`encode` gives the `JsonEncoder` a `toEncodable` callback: the encoder writes maps, lists and
primitives itself and only asks the mapper to convert the objects, one level at a time. How each
`runtimeType` is converted (exact serializer, supertype serializer, `toJson()`, enum) is decided
the first time and cached.

- *Why*: `jsonEncode(serialize(object))` built a whole copy of the tree before encoding it, and
  every enum (no `toJson()`) threw and caught a `NoSuchMethodError` per value, which is slow in
  AOT. Measured with `benchmark/object_mapper_benchmark.dart` (AOT, 1000 orders, 291 KB):

  | Operation (vs by hand)                 | Before  | After        |
  |----------------------------------------|---------|--------------|
  | `encode`, `toJson()`                   | x3.5–3.8 | x1.15–1.2   |
  | `encode`, `Serializer<Order>`          | x3.6–4.2 | x1.1–1.15   |
  | `encode`, serializer of a supertype    | x1.8–2.0 | x1.15–1.2   |
  | `decode<List<Order>>`                  | x1.0–1.1 | x1.0–1.1    |

- `serialize` follows the same rules (and the same cache), so `encode(x)` is always
  `jsonEncode(serialize(x))`; a test checks it.
- Primitives, lists and maps are written as they are, before looking for a serializer: a
  `Serializer<String>` (or `num`, `bool`, `List`, `Map`) is never used.
- *Benchmark caveat*: measured one after the other in the same process, the later cases were up
  to 3x slower, even the same code (the state of the GC). The benchmark interleaves the cases in
  rounds so they all run in the same conditions.

### 2.10 Enums, typed deserializers and `objectMapper:`

Added after the review, from a list of improvements (the rest are in `ROADMAP.md` §4.3, after 1.0):

- **`Deserializer.enumByName(Status.values)`**. Enums were serialized by `name` with nothing to
  register, but reading one needed a hand-written deserializer, and without it `body<Status>()`
  was a 500. Dart can't list the values of an enum from its type, so the values are passed once.
  The 400 lists the valid names (`expected one of pending, paid, got another string`) and never
  echoes the value sent. It's a static method, not a constructor, so the type is checked to be an
  `Enum` and inferred from the values.
- **`Deserializer<T>.string`, `.integer`, `.number`, `.boolean`**. With `Deserializer<Uri>((data)
  => Uri.parse(data as String))` a number was `invalid value`; the typed constructors check the
  JSON type first, so the 400 says what was expected, and only a failure of the function is
  `invalid value`.
- **`body<T>(objectMapper: ...)`** instead of `body<T>(om: ...)`: `ResponseEntity` and
  `BuildContext` already called it `objectMapper`. Breaking, done before freezing the API.

## 3. Validation

**Status:** decided and implemented on 2026-10-06 in the review of phase 2.2 of `ROADMAP.md`.
`test/validation/validation_behavior_test.dart` covers every section below, and
`doc/validation.md` is the guide.

### 3.1 The value first, typed: `cvc.field(name, value)`

```dart
@override
ConstraintValidatorContext validate() {
  final cvc = ConstraintValidatorContext();
  cvc.field('email', email).notNull().email();
  cvc.field('password', password, sensitive: true).notNull().size(min: 8);
  cvc.field('age', age).min(18);
  cvc.field('address', address).notNull().valid();
  cvc.field('items', items).notEmpty().validEach();
  return cvc;
}
```

`field<T>(name, value)` returns a `FieldValidator<T>`, and every rule runs **as it's chained**.

- *Why*: with `buildValidator(name)...validate(value)`, forgetting the final `.validate(value)` was a
  silent success (nothing was validated), and every validator received `dynamic`, so `.min(3)` on
  a String was only seen at runtime (`The value must be a number`). With the value first there is
  nothing to forget, and `T` comes from the value: the validators are extensions on
  `FieldValidator<String?>`, `<num?>`, `<Iterable<Object?>?>`, `<Map<Object?, Object?>?>`,
  `<DateTime?>` and `<Validatable?>`, so `.min(3)` on a String doesn't compile.
- Every validator except `notNull()` passes on `null`. A rule with `stopOnFailure` (the default of
  `notNull()`) skips the rest of the rules of that field.
- Writing your own validator: an extension on `FieldValidator<T>` that calls
  `addRule(isValid, message: ..., code: ..., params: ...)`; `custom((value) => message?)` for a
  one-off rule. `message` is a function, called only when the rule fails: a valid request never
  reads the language, so it doesn't get a `Vary: Accept-Language`.
- The messages of a wrong type (`type.string`, `type.number`, `size.invalidType`) were removed:
  that mistake is now a compile error.
- Breaking: `buildValidator`, `ConstraintValidator` and the `List<Validatable>.validate()`
  extension are removed.

### 3.2 `body<T>()` validates by default

`body<T>({ObjectMapper? objectMapper, bool validate = true})`: when the body is a `Validatable`
(or a list of them, prefixed `[0].email`), it's validated and a failure throws the 422.

- *Why*: a model implements `Validatable` because it must be validated, so the safe default is to
  do it; every POST/PUT repeated `body<T>()` + `.validate().throwOnFailure()`. A partial update
  (PATCH) opts out with `body<T>(validate: false)`.
- A handler that still calls `.validate().throwOnFailure()` validates twice: harmless.

### 3.3 Nested objects: `valid()` and `validEach()`

`cvc.field('address', address).valid()` validates a `Validatable` and prefixes its violations
(`address.zip`); `validEach()` does it for every element of a list (`items[0].quantity`).
`merge(other, prefix:)` stays for manual cases.

- The nested `validate()` creates its own context, so it couldn't see the `clock` of the parent.
  `valid()`/`validEach()` run it in a `Zone` with that clock, and a context created without one
  takes it: a test fixes the time once for the whole tree.

### 3.4 Each violation has a `code` and `params`

```json
{ "fieldName": "password", "message": "The minimum is 8", "code": "size.min", "params": { "value": 8 } }
```

- *Why*: a client (a Flutter app) can show its own text instead of depending on the message.
- The `code` is the key of the message in `*.i18n.yaml` (`notNull`, `size.min`, `min.exclusive`...)
  and `params` its parameters. A `custom` rule has no code unless it gives one.

### 3.5 The value is never in the JSON of a 422

The violation keeps the `value` in Dart (for logs), except for a `sensitive` field, whose value is
never stored. Its JSON has only `fieldName`, `message`, `code` and `params`.

- *Why*: the client knows what it sent, and repeating it puts personal data and long texts back in
  the response, the same reason the 400 of the object mapper never echoes a value. It also fixes
  a 422 that became a 500 when the value was an object without `toJson()`.

### 3.6 `ConstraintViolation`, equality and `Validatable`

- `ConstrainViolation` is renamed `ConstraintViolation` (misspelled public API).
- Its `==` compares the `value` with `==` (it compared `value.toString()`, so `1` and `'1'` were
  equal with different hash codes, which breaks a `Set` or a `Map`).
- `Validatable` is an `abstract interface class` without a default `validate()`: the default
  returned an empty (valid) context, which hid a forgotten implementation.

### 3.7 Validators

Kept: `notNull`, `notBlank`, `size` (now also for a `Map`), `min`, `max`, `email`, `pattern`,
`isEnum`, `custom`. New: `url`, `uuid`, `positive`, `negative`, `positiveOrZero`,
`negativeOrZero`, `past`, `future`, `pastOrPresent`, `futureOrPresent` (with a clock that tests
can replace), `notEmpty` (collections) and `oneOf` (literal values).

- `pattern()` uses a `RegExp` as it is (flags included) and compiles a `String` once: it built
  `RegExp(pattern.toString())`, so a `RegExp` never matched.

### 3.8 Left for later

- **Async validations** ("the email already exists"): `validate()` stays synchronous. 1.x will add
  a separate interface (an `AsyncValidatable` with a `Future` `validate()`) that `body<T>()` will
  also run, without breaking anything. Until then, check it in the service and throw a
  `ConflictException` or a `ValidationException`.
- **The format of `fieldName`** (`items[0].name`) vs the path of the 400 of the object mapper
  (`$.items[0].name`): decided in 2.3 with the error format (Problem Details).

### 3.9 Second review

A review of the new API, from zero, found:

- **Chaining lost the type of the field**: every validator returned the type of its extension
  (`notEmpty()` gave a `FieldValidator<Iterable<Object?>?>`), so
  `field('items', items).notEmpty().validEach()` didn't compile, nor an `int` validator after
  `min()`, and `custom()` after `min()` received a `num?`. The extensions are now generic with a
  bound (`NumberValidators<T extends num?> on FieldValidator<T>`) and return `FieldValidator<T>`.
- **`url()` accepted `http://exa mple.com`**: `Uri.tryParse` takes a space in the host. Whitespace
  is now rejected.
- **`fieldName` didn't follow `fieldNaming`**: with `snakeCase` the client sent `first_name` and
  the 422 said `firstName` (while its keys were renamed: `field_name`). The exception handler now
  converts every name of the path with `ObjectMapper.jsonFieldName` (`items[0].first_name`).
- **`params` could turn the 422 into a 500**, like the value did: the allowed values of `oneOf()`
  and `isEnum()` were sent as they were. Now only JSON values: an enum as its name, anything else
  as its text.
- `email()` checks the lengths of RFC 5321 (254 in total, 64 before the `@`).
- `violationsOf(fieldName)` for tests. A `Matcher` (`hasViolation(...)`) was considered, but it
  would make `package:matcher` a dependency of every app at runtime.
- The docs recommend `validate()` with cascades (`=> ConstraintValidatorContext()..field(...)`),
  and a model of its own for a PATCH (optional fields are only validated when they come) instead of
  `validate: false`.

## 4. Exceptions and error handling

**Status:** decided and implemented on 2026-10-07 in the review of phase 2.3 of `ROADMAP.md`.
`test/server/exception_handler/error_handling_behavior_test.dart` covers every section below, and
`doc/error-handling.md` is the guide.

### 4.1 Every error is a Problem Details (RFC 9457)

Every error response is `application/problem+json`:

```json
{ "type": "about:blank", "title": "Not Found", "status": 404, "detail": "User 42 not found" }
```

- `type` is `about:blank` unless the app gives one, `title` is the reason phrase of the status,
  `status` its code, and `detail` is only there when there is one (never in a 500).
- The 422 adds `"violations": [...]` (the `ConstraintViolation`s of §3).
- *Why*: there were five formats (no body for 404/405/401/429, `text/plain` for the 400s, 413, 415
  and 500, a JSON array for the 422 and any map for an `ApiException` with a map body), and the 422
  used `application/problem+json` for a body that wasn't one. Problem Details is the standard
  (Spring 6 uses it by default), so any client can read every error the same way.
- The `title` is never translated: it's the standard reason phrase, like the i18n section (§1)
  decided. What the user reads is the `detail`, written by the app with its own translations.

### 4.2 `ApiException`: `detail`, `type`, `title` and extensions

```dart
throw NotFoundException(detail: 'User 42 not found');

throw ApiException(
  StatusCode.conflict,
  detail: 'The email is already registered',
  type: 'https://api.example.com/errors/email-taken',
  extensions: {'email': email},
);

throw ResponseException(ResponseEntity(402, body: myBody)); // a response of its own
```

- `ApiException(status, {detail, type, title, extensions, headers})` works for any status; the
  subclasses are shortcuts for the common ones: 400, 401, 403, 404, 405 (`MethodNotAllowedException`,
  with the `Allow` header), 409, 413, 415, 422, 429 (`TooManyRequestsException`), 500 and 503
  (`ServiceUnavailableException`). `PaymentRequiredException` (402) is removed.
- `type` is a `String` (a URI reference), so the exceptions can be `const`.
- Breaking: `body:` is removed. It meant "the body of the response", which no longer fits a
  Problem Details; a response of its own is a `ResponseException`.
- The status is a `StatusCode`, so a code that isn't in the enum (`700`) needs a
  `ResponseException`. `ProblemDetails` is public, to build one by hand (`toResponse()`).

### 4.3 The `ExceptionHandler` receives everything, `Error`s included

`ExceptionHandler.call(RequestEntity request, Object error, StackTrace stackTrace)`, and the filter
chain turns any `Exception` **or `Error`** into a response where it's thrown.

- *Why*: an `Error` (a `StateError`, a `TypeError`...) went through every filter up to the
  pipeline, which answered its own 500: **without the CORS headers** (a browser showed a CORS error
  instead of the 500), without the filters seeing it (`LogsFilter` didn't log it), and without the
  `ExceptionHandler` (a custom one couldn't log or format it; the pipeline checked
  `eh is SimpleExceptionHandler` to find `logUnhandledError`).
- Breaking for a custom `ExceptionHandler`: the parameter is `Object` instead of `Exception`.
- If the `ExceptionHandler` itself throws, the pipeline logs both errors and answers a generic
  500, so a broken handler never leaves a request without a response.

### 4.4 Handling an exception of the app: `on<T>()` or inheritance

```dart
Winter.context.setUp(
  exceptionHandler: SimpleExceptionHandler()
    ..on<EmailTakenException>((request, e) => ConflictException(detail: e.message))
    ..on<PaymentFailed>((request, e) => ResponseEntity(402, body: {...})),
);
```

- The function returns an `ApiException` (formatted as a Problem Details) or a `ResponseEntity`
  (used as it is). The most specific registered type wins, whatever the order of registration.
- Inheritance keeps working: extend `SimpleExceptionHandler` and override `handle` (its default
  rules; the mappings of `on()` still run first), or implement `ExceptionHandler` to replace it all.
- If a mapping throws, what it throws is answered by the default rules, never by the mappings
  again, so two mappings can't loop.

### 4.5 The errors of Winter go through the handler too

The router throws `NotFoundException` / `MethodNotAllowedException`, `AuthFilter` throws
`UnauthorizedException` / `ForbiddenException` and the rate limiter `TooManyRequestsException`
(with its `X-RateLimit-*` and `Retry-After` headers), instead of returning a response.

- *Why*: the `ExceptionHandler` is then the only place that formats every error, and
  `on<NotFoundException>` can change the 404 of the router.
- Breaking: `AuthFilter.build401`/`build403` are removed (use `on<UnauthorizedException>`).

### 4.6 The path of the 400 and the `fieldName` of the 422 stay different

The 400 of the object mapper has a JSON path in its `detail` (`$.items[1].price: expected a
number, got a string`), and the 422 a field name (`items[1].price`).

- *Why*: a 400 means the JSON doesn't have the shape of the type, a bug of the client that its
  developer reads; a 422 means the user typed an invalid value, and the client links `fieldName`
  to an input of a form.

### 4.7 Small fixes

- The `ExcHandler` typedef (unused, with a parameter named `stackTrac`) is removed.
- `ResponseException.responseEntity` is `final`.
- `Filter chain ended without a response` can't happen (the last link is always the handler, which
  never calls the chain): it becomes a `StateError` instead of a 500 with an internal message.

## 5. Dependency injection

**Status:** decided and implemented on 2026-10-07 in the review of phase 2.4 of `ROADMAP.md`.
`test/dependency_injection/di_behavior_test.dart` covers every section below, and
`doc/dependency-injection.md` is the guide.

### 5.1 A service locator, by exact type

`di` stays a service locator: dependencies are registered and found by `(Type, tag)`, never built
by reflection or code generation (AOT has no reflection, and the project avoids `build_runner`).

- An implementation is found by the type it was registered with: `di.put<UserRepository>(SqlRepo())`
  to find it as a `UserRepository`. Looking up subtypes would be slower, ambiguous with two
  implementations, and magic. The error of a missing dependency says so.
- **Nullable and non nullable types are the same key**: a dependency registered from a `Service?`
  variable was registered as `<Service?>`, and `find<Service>()` didn't find it. Keys are now the
  nullable form of the type, so both find it.
- `put` of a registered key replaces it (the old one isn't disposed: it may still be in use), even
  a lazy one already created: a test can register a fake at any time.

### 5.2 Singletons, lazy singletons, factories and scoped

```dart
di.put(UserService());                                      // the instance given
di.putLazy<Database>(() => Database.connect(url));          // created by the first find
di.putFactory<Clock>(() => SystemClock());                  // a new one by every find
di.putScoped<UnitOfWork>(() => UnitOfWork(di.find()));      // one per request
```

- `putLazy` lets dependencies be registered in any order even if one needs another, and only
  creates what is used. A cycle between lazy ones (`A → B → A`) is a `StateError` that shows the
  chain.
- `putScoped` keeps one instance per request in its `RequestScope` (like `@RequestScope` of
  Spring): a transaction or a unit of work. Outside a request, `find` of it is a `StateError`.
- The functions are synchronous: an async initialization (opening a connection) is awaited before
  registering the result.

### 5.3 Disposing: `onDispose`

`put`, `putLazy` and `putScoped` take `onDispose: (db) => db.close()`.

- `Winter.shutdown()` (SIGTERM, Ctrl+C) calls them after waiting for the requests and after
  `ServerConfig.onShutdown`, in reverse order of registration, and removes the dependencies.
  `di.disposeAll()` does the same by hand.
- `Winter.close()` doesn't: tests start and close servers with the same dependencies.
- A lazy singleton never created is never disposed. A scoped instance is disposed when its request
  ends (after its response is built), in reverse order of creation.
- For that, `RequestScope` got `onComplete(callback)` (public: an app can run its own code at the
  end of every request) and `complete()`, which the server calls in a `finally` after the pipeline,
  still inside the zone of the request. A test that uses `RequestScope.run` calls it itself.
- An `onDispose` that fails is logged, and the others still run.

### 5.4 `null` values and `isRegistered`

`put<Config?>(null)` is a valid registration, and `find` returns `null`. `tryFind` can't tell it
from a missing one, so `isRegistered<T>({tag})` says whether something is registered.

- *Why*: `find` checked `value != null`, so a registered `null` was "not found".

### 5.5 Small fixes

- `notFound` is private, and the map of registrations is no longer named `_singl`.
- `delete` returns the instance if it was created (`null` for a lazy one never used).

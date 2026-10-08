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
  instead of the 500), without the filters seeing it (`LoggingFilter` didn't log it), and without the
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

### 5.6 Second review: the lifetime of a scoped dependency

A review of the new DI, from zero, found two silent bugs of `putScoped`:

- **A lazy singleton that depends on a scoped one** was created in the first request that found it
  and kept that request's instance forever: the next requests used an instance already disposed
  (a *captive dependency*). Finding a scoped dependency while a lazy one is being created is now a
  `StateError` that says to use `putFactory` or `putScoped`; a factory is created in each request,
  so it gets the instance of its request.
- **A `find` after the request ended** (code that keeps running after the response) returned the
  disposed instance. It's a `StateError` now, and `RequestScope.isCompleted` tells it; an
  `onComplete` registered after the end is a `StateError` too (it would never run).
- `tryFind` of a scoped dependency outside a request stays a `StateError`: it's registered, there
  is just no request to give it, and `null` would hide the mistake.

Proposed for later (`ROADMAP.md`): `di.createAll()` to create every lazy one at start-up and fail
there instead of in the first request (before 1.0), and after 1.0 async initialization, child
containers for tests and a listing of the registrations.

## 6. Configuration

**Status:** decided and implemented on 2026-10-07 in the review of phase 2.5 of `ROADMAP.md`.
`test/env/config_behavior_test.dart` covers every section below, and `doc/configuration.md` is
the guide.

### 6.1 `find` and `require`

```dart
final port = env.find<int>('PORT') ?? 8080;     // int
final dbUrl = env.require<String>('DB_URL');     // String, or a StateError that names it
final debug = env.find<bool>('DEBUG') ?? false;
```

- `find<T>` returns `T?` and supports nullable types (`find<int?>` was an "unsupported type");
  defaults are written with `??`. `require<T>` returns a `T`: `find(required: true)` returned a
  `T?` that always needed a `!`. Breaking: `required:` is removed.
- `requireAll(['DB_URL', 'JWT_SECRET'])` checks every variable at once and names **all** the
  missing ones in a single error: in a container, finding them one restart at a time is slow.
- **An error never shows the value**: a wrong type said `found with value 'hunter2'`, and a
  configuration error ends in the logs. It names the variable and the expected type only.
- An empty value counts as missing.

### 6.2 Types

`String`, `bool`, `int`, `double`, `num`, `Duration` (`250ms`, `30s`, `5m`, `1h`, `2d`), `Uri`
(absolute), a `List` of any of them (comma separated), and enums with
`findEnum(key, values)` / `requireEnum(key, values)` (by name, any case; the error lists the valid
names).

- A `String` is returned as it is; numbers, bools, durations, URIs and every item of a list are
  trimmed (`' 8080 '` is a typo, not a value). Trimming a `String` altered secrets and passwords
  with spaces.
- `bool` and `List<bool>` accept any case (`List<bool>` used `bool.parse`, which only takes
  lowercase, while `bool` accepted `TRUE`).
- The "unsupported type" error lists every supported type (it forgot `List<bool>`).
- `put` returns the value given (it read it back with `find`, which failed for a type `find`
  doesn't read).

### 6.3 `.env` files and profiles

`Env.load()` reads `.env` and `.env.<profile>`, the profile coming from `WINTER_PROFILE`
(`WINTER_PROFILE=prod` → `.env.prod`).

- Precedence: **process variables > `.env.<profile>` > `.env`**. A file that doesn't exist is
  ignored.
- *Why*: in production the variables come from the platform (`docker run -e`, the configuration of
  the cloud service), not from files. The files are for local development. Since the process wins
  and missing files are ignored, the same code runs on a laptop (with a `.env`) and in a container
  (without files).
- Format: `KEY=VALUE`, `#` comments, empty lines, an optional `export `, and quoted values
  (`"..."` with `\n` escapes, `'...'` literal). No interpolation (`${OTHER}`): it hides where a
  value comes from.
- `env.profile` is the active profile (`null` without one).
- `Env.parseDotEnv(lines)` is public, to read a file of another place. A line that is not a
  variable, or an unclosed quote, is a `FormatException` with the file and the line number, never
  its content.

### 6.4 A typed configuration of the app

The documented pattern: a class read once at start-up, registered in `di`, so a missing variable
fails before the server opens its port:

```dart
class AppConfig {
  final String dbUrl;
  final Duration timeout;

  AppConfig({required this.dbUrl, required this.timeout});

  factory AppConfig.fromEnv(Env env) {
    env.requireAll(['DB_URL']);
    return AppConfig(
      dbUrl: env.require<String>('DB_URL'),
      timeout: env.find<Duration>('TIMEOUT') ?? const Duration(seconds: 30),
    );
  }
}

di.put(AppConfig.fromEnv(env));
```

### 6.5 `ServerConfig`

- `const ServerConfig(...)`: the fields are set in the initializer list, and the address is a
  `host` `String` (`'0.0.0.0'` by default, `'localhost'`, `'127.0.0.1'`) instead of an
  `InternetAddress`, which can't be `const`. Breaking: `ip:` → `host:`.
- `shared` (several isolates on the same port) moves from `Winter.start(shared:)` to
  `ServerConfig(shared: true)`, with the rest of the server's configuration. Breaking.
- `Winter.start` validates it before opening the port: a port out of `0-65535`, or a negative
  `maxBodySize` or `shutdownTimeout`, is an `ArgumentError` (a `const` constructor can't throw).
- `ServerConfig.fromEnv(env)` reads `PORT` and `HOST`, the variables that Cloud Run, Heroku,
  Render and Kubernetes set, with the given values as defaults.
- `validate()` is public (an empty `host` is rejected too), so a test or a custom start can check
  a configuration without starting a server.
- `securityContext` (HTTPS) and `requestTimeout` come with the server of phase 3.1 and phase 4.

## 7. Logging

**Status:** decided and implemented on 2026-10-07 in the review of phase 2.6 of `ROADMAP.md`.
`test/logging_behavior_test.dart` covers every section below, and `doc/logging.md` is the guide.

### 7.1 The logs never contain the data of a request

The debug log of a failed deserialization was `Invalid value for <T>: $e`, and the message of the
original error can include the value sent (`FormatException: ... card-4111111111111111`), in
several lines. It's now `Invalid value for <T> (FormatException)`: the type of the error, never its
message (the error is still in `DeserializationException.cause`). The same rule as `LoggingFilter`,
which never logs bodies nor query strings.

### 7.2 `WinterLogger`

- Every level takes `error`, `stackTrace` and `fields` (structured data:
  `logger.info('Order created', fields: {'orderId': 42})`); `debug` and `info` didn't take an error.
- `isEnabled(level)` tells whether a level is written, to skip building an expensive message. The
  framework uses it for its own debug logs: the rate limiter built a message for every rejected
  request (a lot of them under an attack) even when debug was off.
- Breaking for a custom logger: `log` takes `fields`.

### 7.3 `ConsoleLogger` and `JsonLogger`

- `ConsoleLogger` (development): `2026-10-07T16:11:07.171Z [INFO] [8f1c...] message`, the time in
  **UTC** (it was the local time without an offset), the request id inside a request, and the
  fields as `key=value`. Debug and info to stdout, warning and error to stderr.
- `JsonLogger` (production): one JSON object per line on stdout, with the keys that Cloud Logging
  reads by itself and that Datadog or Loki map easily:

  ```json
  {"time":"2026-10-07T16:11:07.171Z","severity":"INFO","message":"Order created","requestId":"8f1c...","orderId":42}
  ```

  `error` and `stackTrace` are strings; the `fields` are members of their own and never replace
  `time`, `severity`, `message`, `requestId`, `error` nor `stackTrace`.

### 7.4 The request id

Every request has an id, always (no filter to add):

- It's the `X-Request-Id` of the request when it's valid (1 to 128 letters, digits and `.`, `_`,
  `:`, `-`: a header with anything else could inject lines into the logs), or a new random UUID.
- It's in the `RequestScope` (`requestId`, `null` outside a request), in the `X-Request-Id` header
  of the response, in every log written during the request, and in the body of a 500
  (`"requestId": "..."`), so a client can report it and the logs of that request can be found.
- `RequestScope` generates it (`newRequestId()`, a UUID v4 from `Random.secure`) unless one is
  given, and `isValidRequestId` checks the one of the header; the server adds the header to every
  response. The top-level `requestId` reads it from any code, like `requestLocale`.
- *Why always*: a request id costs almost nothing, and it's what turns a support ticket ("it
  failed at 10:31") into the logs of that request.

### 7.5 `LoggingFilter`

It keeps two lines per request, `REQUEST: GET /users/1` and `RESPONSE: GET /users/1 => 200
(12 ms)`, both in info; both carry the request id now, so they can be matched.

## 8. Security

**Status:** decided and implemented on 2026-10-07 in the review of phase 2.7 of `ROADMAP.md`.
The behavior is tested in `test/security/security_behavior_test.dart`, and the guide is
`doc/security.md`.

### 8.1 CORS

- **`'*'` with `allowCredentials: true` logs a warning** when the server is built, and keeps
  echoing the origin. With credentials, a browser rejects `'*'`, so the origin of the request is
  echoed: every website can then read the API with the cookies of the user. The warning says to
  list the origins.
- **`Vary: Origin` whenever the response depends on the origin**: with a list of origins, for the
  allowed ones but also for the others and for requests without `Origin` (it was only added to an
  allowed one, so a cache could give a response prepared for one origin to another).
- **`X-Request-Id` is always exposed** (`Access-Control-Expose-Headers`), with the
  `exposedHeaders` of the config: a web client can read the id of a response to report it.

### 8.2 `AuthFilter`

- **A 401 has a `WWW-Authenticate` challenge**, as RFC 9110 requires: `Bearer` by default,
  `AuthFilter(challenge: 'Basic realm="api"')` for another scheme.
- **Roles and permissions, no authorities**: `authorities` was only the union of the two, and
  `hasAuthority('x')` is `hasRole('x') | hasPermission('x')`. Breaking: `authorities`,
  `hasAuthority` and `AuthorityRule` are removed.

### 8.3 A typed principal

`requestPrincipal<User>()` reads the principal of the request in progress from the
`RequestScope` (from any code, like `requestLocale`), and `request.principal<User>()` does the same
with the request at hand; both are the same object.

- They return the `User`, or throw an `UnauthorizedException` (401) when nobody is authenticated:
  a handler behind an `AuthFilter` needs no cast and no `!`.
- `requestPrincipalOrNull<User>()` / `request.principalOrNull<User>()` for a public route.
- A principal of another type is a `StateError` (a bug of the app, not of the client).

### 8.4 Rules that see the request

`AuthorizationRule.evaluate(Authentication authentication, RequestEntity request)`, and a rule in
one line with `rule((auth, request) => ...)`:

```dart
AuthFilter(
  rules: hasRole('admin') |
      rule((auth, request) => request.pathParams['id'] == auth.name),
)
```

- *Why*: "only the owner sees `/users/{id}`" needed the request, so it was checked in every
  handler.
- `toString` of a rule is public and overridable (`describe()`): a rule of the app broke the
  `toString` of every rule combined with it, and of its `AuthFilter`, because `_toExpression` was
  private. Breaking for a custom rule: `evaluate` takes the request.

### 8.5 Security headers

- `dart:io` added three headers to every response of the real server, but not to the ones of
  `WinterTestClient`. They are replaced by Winter's own, the same in both:
  `X-Content-Type-Options: nosniff` and `X-Frame-Options: DENY` stay on by default (an API is
  never meant to be framed), and `X-XSS-Protection` is dropped (obsolete, and it opened XSS in old
  browsers).
- `SecurityConfig(securityHeaders: const SecurityHeaders())` adds the rest, like the CORS filter:
  `Referrer-Policy: no-referrer`, a `Content-Security-Policy` for an API
  (`default-src 'none'; frame-ancestors 'none'`), and `Strict-Transport-Security` only with
  `hsts: true` (it must only be sent when the API is served over HTTPS).

### 8.6 Rate limiter

- `RateLimiter(maxRequests, window)` rejects a `maxRequests` below 1 or a `window` that is not
  positive with an `ArgumentError`: with `0`, every request was a 500 (`logs.first` of an empty
  list).
- The algorithm stores its logs through a `RateLimiterStore` interface; the in-memory one comes
  with Winter, and a shared one (Redis) can be added in 1.x without a breaking change. For that the
  store is **asynchronous** (a Redis call is), and so are the methods of `RateLimiter`
  (`Future<RateLimitResult> check(id)`, one call that records the request and gives the remaining,
  reset and wait). Breaking: the synchronous `allowRequest`/`getRemaining`/... are replaced.
- *Documented*: the in-memory limit is per isolate and per process (four instances allow four times
  the limit), and by IP it needs `trustedProxies` behind a proxy (or every client shares the IP of
  the proxy).

## 9. Router, filters and entities

**Status:** decided and implemented on 2026-10-07 in the review of phase 2.8 of `ROADMAP.md`.
The behavior is tested in `test/server/router/router_behavior_test.dart`. It's a light review: the
entities (`RequestEntity`, `ResponseEntity`) are redesigned without shelf in phase 3.1.

### 9.1 Repeated slashes are a 404

`GET //users/1` was a 500 outside the pipeline: shelf rejected the url when the `RequestEntity` was
built, so the answer had no `X-Request-Id`, no security headers, and was written to the console
without the `logger`. Now it goes through the pipeline like `/users//1`, and no route matches it: a
404 (Problem Details).

- *Why not join the slashes*: behind a proxy, a rule that blocks `/admin` doesn't block `//admin`;
  if the app joined them, `//admin` would reach `/admin`. Not rewriting the path is the safe choice.
- *Why not a 400*: a 404 is what `/users//1` already answered; one rule for both.

### 9.2 A broken route table fails at start

`RouterConfig` uses `DefaultOnInvalidUrl.fail()` and `DefaultOnDuplicatedRoute.fail()` by default:
an invalid or duplicated route is a `StateError` when the router is built. They were dropped with a
warning, so the app started without them and the bug was found as a 404 in production (a route with
a regex param, `/n/{id|[0-9]+}`, was dropped that way: see 9.3). `ignore()` is still available.

### 9.3 Validation of the paths and duplicates

- **Only the literal parts of a path are validated**: the regex of a param (`{id|[0-9]+}`) and the
  regex parts (`.*`) can have any character. Before, `[`, `]` or `+` made the route invalid.
- **The `key` stays**, generated from the path and the method or given by the app, so a filter can
  recognize a route (`request.routingContext?.key`) without depending on its path.
- **A duplicated route is also one with the same method and the same shape**: the names of the
  params don't count, so `GET /users/{id}` and `GET /users/{name}` are the same route, and so are
  two `GET /x` with different keys. The second one could never be reached.

### 9.4 `OPTIONS` is answered automatically

An `OPTIONS` to a path without an `OPTIONS` route is a `204` with `Allow` (RFC 9110), and `Allow`
always lists `OPTIONS` (in a 405 too). A path that doesn't exist is still a 404. A route of the app
for `OPTIONS` wins, and the CORS preflights are still answered by `CorsFilter`.

### 9.5 `FilterConfig` is immutable

`FilterConfig.add` mutated the list, which failed when it was `const` (and changed every route
sharing it). `FilterConfig` holds an unmodifiable list, `add` is removed (use `merge`), and a `Route`
without filters has a `const FilterConfig([])`. Breaking.

### 9.6 Routers expose their routes read-only

`WinterRouter.routes` is an unmodifiable list: `routes.add(...)` skipped the `basePath`, the
validation and the duplicates. `addRoute` is the way to add routes. `MultiRouter.routes` is renamed
`MultiRouter.routers` (it holds routers). Breaking.

### 9.7 Typed path and query params

`int.parse(request.pathParams['id']!)` with `/users/abc` was a 500 (`FormatException`). Now:

```dart
final int id = request.pathParam<int>('id');               // 400 if it's not an integer
final int page = request.queryParam<int>('page') ?? 1;      // null if missing or empty
final Status? status = request.queryParam('status', values: Status.values);
```

- Types: `String`, `int`, `double`, `num`, `bool` (`true`/`false`), `DateTime` (ISO 8601) and
  enums by name with `values:`. A value of another type is a `BadRequestException` (400) whose
  detail names the param and the expected type, never the value.
- A path param that isn't in the route is a `StateError` (a bug of the app); an unsupported `T` is
  an `ArgumentError`.
- The raw maps (`pathParams`, `queryParams`, `queryParamsAll`) stay.

### 9.8 Responses

- The shortcuts of `ResponseEntity` stay, error ones included (`notFound`, `badRequest`...), and
  without a body they send none. Throwing an `ApiException` is the way to answer a Problem Details.
- New success shortcuts: `ResponseEntity.created(location:, body:)` (201 with `Location`),
  `accepted()` (202) and `noContent()` (204).
- `Route.toString()` no longer prints the closure of the handler.

## 10. The systems together

**Status:** decided and implemented on 2026-10-07 in the review of phase 2.9 of `ROADMAP.md`.
`test/integration/app_integration_test.dart` runs a whole app with every system at once
(configuration from the environment, a scoped service, authentication and rules, CORS, security
headers, the rate limiter per user, snake_case, validation that depends on the configuration, two
languages, logs and concurrent requests), and `test/integration/server_integration_test.dart` the
real server configured from `.env` files, compared with `WinterTestClient`, and its shutdown.

Almost everything fitted: the user, the language and the scope of a request never mixed, every
error kept the CORS and security headers, and every log had the request id. These are the
exceptions.

### 10.1 A text body always says its charset

The same 422 was `application/problem+json` in English and
`application/problem+json; charset=utf-8` in Spanish: shelf adds the charset only to a body with
non-ASCII characters. Now every text body of Winter says it: `application/json; charset=utf-8`,
`application/problem+json; charset=utf-8` and `text/plain; charset=utf-8` (without it, a client may
read `text/plain` as ISO-8859-1). An `encoding` given to the response is its charset; a binary body
has none. Breaking for a test that compares the `Content-Type` exactly.

### 10.2 The names of the errors are fixed

With `fieldNaming: snakeCase`, the members of a Problem Details were renamed: `requestId` became
`request_id`, `fieldName` became `field_name` (and with `kebabCase` `request-id`, which RFC 9457
advises against: member names should be letters, digits and `_`). The error format of Winter is
now the same in every app: `ProblemDetails` and `ConstraintViolation` are written with their own
names. The **value** of `fieldName` still follows `fieldNaming`, since it names a field of the
client's JSON; the `extensions` of the app keep the names it gives. A `Serializer` of the app for
those types still wins.

### 10.3 No `X-Powered-By`

The real server sent `X-Powered-By: Winter-Server` and `WinterTestClient` didn't. It's removed: an
API doesn't announce its framework (OWASP), and both send the same headers now (tested). The header
came from `shelf_io`, which is replaced in phase 3.1.

### 10.4 A handler at the path of a parent route

A child can't have an empty path (`''`). To answer the path of a parent, the parent itself has the
handler (`Route.get(path: '/orders', handler: list, routes: [...])`), or the child uses `'/'`.

### 10.5 Known limitation: the path of an error inside `fromJson`

A `fromJson` that deserializes its children (`om.deserialize<List<Item>>(json['items'])`) loses the
path: an invalid item is `$: invalid value`, not `$.items[0]...` (see §2.5). It stays for 1.0.

## 11. From shelf to `dart:io`

**Status:** decided and implemented on 2026-10-07 in phase 3.1 of `ROADMAP.md`. The behavior is
tested in `test/server/http_server_behavior_test.dart` (the real server) and
`test/entities_behavior_test.dart` (the entities), and the guide is `doc/requests-and-responses.md`.

Winter no longer depends on shelf. It serves the requests with `HttpServer` of `dart:io`, and
`RequestEntity`/`ResponseEntity` are its own types: the public API of Winter doesn't depend on the
API (nor the breaking changes) of another package, and shelf cost performance.

### 11.1 The request

- **The names users know stay**: `method`, `requestedUri`, `headers`, `context`, `body<T>()`,
  `read()`, `readAsString()`, `pathParams`, `queryParams`, `clientIp()`.
- **Headers**: `headers` (one value, case insensitive, several joined with `, `) and `headersAll`
  (every value). *Why not a `Headers` class*: every `headers['x']` of today keeps working.
- **New**: `cookies` and `cookie(name)` (the `Cookie` of `dart:io`), `connectionInfo` (the IP no
  longer comes from a shelf context key), `mimeType`/`encoding` (the body is decoded with the
  charset of the `Content-Type`).
- **Read-only**: headers, query and path params can't be changed (a filter cleared
  `queryParams`); a filter passes a copy to the chain.
- **The body is read once**, shared by the copies of a request: `body<T>()` caches it for all of
  them, and `read()`/`readAsString()` fail after it.
- **Removed**: `handlerPath` and `url` (relative to a mounted handler: Winter is never mounted; the
  router uses `requestedUri.path`), the context override, and `RequestEntity.change`.
- `RequestEntity.fromHttpRequest` builds one from the `HttpRequest` of the server, reading its
  headers without copying them.

### 11.2 The response

- A `body` value is written by its type: a `String` as text, a `Uint8List` as bytes, a
  `Stream<List<int>>` as a stream, anything else as JSON. *Why `Uint8List` and not `List<int>`*: a
  `List<int>` of the app is data (`[1, 2]` in JSON).
- `headersAll` with several values (`Link`), and `cookies:` (one `Set-Cookie` each) in the
  constructor, the success shortcuts and `copyWith`.
- A text body's charset is the one of its `encoding` (UTF-8 by default).

### 11.3 One `copyWith`

`copyWith` is the only way to change a request or a response (`change` came from shelf and did
almost the same; the `copyWith` of the request was async). It's synchronous in both, adds `headers`
(`null` removes one) and `context`, and a new `body` is resolved again with its own `Content-Type`
and `Content-Length`. Breaking: `change` is removed, and the `headers` of `ResponseEntity.copyWith`
are added instead of replacing all of them.

### 11.4 The server

- `HttpServer.bind`, or `bindSecure` with `ServerConfig.securityContext` (HTTPS), with `shared`.
- New settings of `dart:io` in `ServerConfig`: `autoCompress` (false: usually the proxy compresses)
  and `idleTimeout` (120 s, the one of `dart:io`; validated).
- No `Server` nor `X-Powered-By`, and the default headers of `dart:io` are cleared.
- Every response has a `Date` (RFC 9110; `dart:io` doesn't add it), formatted once per second.
- `Winter.buildHandler` returns a `RequestHandler` (`RequestEntity → ResponseEntity`), the same
  pipeline that `WinterTestClient` calls in memory.

### 11.5 Writing a response

`writeResponse` (public, for a server of the app):

- The status line has the reason phrase of `StatusCode` (`422 Unprocessable Entity`). `dart:io`
  alone only knows some codes and sent `422 Status 422` (the problem of shelf issue #449). A code
  that `StatusCode` doesn't know keeps the one of `dart:io`. Clients should ignore it (RFC 9110),
  and the `title` of a Problem Details has the same text, but Postman, curl and proxy logs show it.

- A `Content-Length` for bytes, chunked for a stream, which is sent as it's produced
  (`bufferOutput: false`, for Server-Sent Events). `dart:io` sends the headers with the first
  chunk.
- No body for `HEAD` (it keeps the `Content-Length` of `GET`), `204` and `304`.
- With `autoCompress` and a client that accepts gzip, the length is left out: `dart:io` only
  compresses a chunked response.
- A client that leaves in the middle, or a stream that fails, is logged at debug and the connection
  is closed: the server goes on.
- A malformed request is answered (or closed) by `dart:io` before it reaches Winter.

### 11.6 WebSockets (design for phase 4.3)

The pipeline must be able to hand the connection over to `WebSocketTransformer.upgrade` after the
filters (authentication, CORS) ran, without a breaking change. The design: a response of its own
kind (`ResponseEntity.upgrade((WebSocket socket) {...})`, a subclass or a marker in its context)
that the server recognizes before `writeResponse`; it has the `HttpRequest` (`_serve`), so it can
upgrade it. In memory (`WinterTestClient`) it's a 101 without a socket. Nothing in today's API
blocks it.

### 11.7 Shelf middlewares

They no longer plug in: the same code is a filter (before and after `chain.doFilter`), shown in
`doc/filters.md`. `Response.ok(...)` is `ResponseEntity.ok(body: ...)`, `change` is `copyWith`,
`request.url` is `request.requestedUri`.

### 11.8 Performance

On the same machine (Windows, AOT, 64 connections, `benchmark/http_benchmark.dart`), an empty
endpoint:

| Server                 | req/s | vs `dart:io` |
|------------------------|-------|--------------|
| `dart:io` alone        | ~6200 | ceiling      |
| shelf alone            | 5561  | −13 %        |
| Winter on shelf        | 3984  | −37 %        |
| Winter on `dart:io`    | ~5100 | −17 %        |

The pipeline in memory went from 21 µs to 12.5 µs per request: the headers are views (no copies of
the headers of `dart:io`, no joined map per access), the request id is built with a table, and a
body of bytes is written with `add` instead of a stream.

## 12. The public API of 1.0

**Status:** decided and implemented on 2026-10-07 in phase 3.2 of `ROADMAP.md`. Once 1.0 is out,
changing any of this is a breaking change.

### 12.1 What is exported

`winter.dart` exports the modules, minus the internal helpers, with `export ... hide` (they stay
in `lib/src`, where the framework and its tests import them by path):

| Internal now                                                     | Why                                          |
|------------------------------------------------------------------|----------------------------------------------|
| `addVary`, `limitBodySize`                                       | Details of the pipeline                      |
| `isValidUri`, `normalizePath`, `methodNotAllowedOrNotFound`, `noRouteResponse`, `allowHeader` | Details of the router (a custom router throws `NotFoundException`) |
| `writeResponse`, `requestFromHttpRequest` (was `RequestEntity.fromHttpRequest`) | Only the server writes and reads `dart:io` |
| `winterMessages`, `localesWithoutWinterMessages`, `warnLocalesWithoutWinterMessages` | The translations of Winter itself |
| `console_style` (`stylize`, `ConsoleColor`), the constants `bearer`/`basic` | Not part of a web framework; `bearer`/`basic` were global names |

Public on purpose: `internalServerErrorResponse` and `defaultLogUnhandledError` (for an
`ExceptionHandler` of the app), the `defaultLog*` functions and `defaultClientId` (the defaults of
the filters, to wrap them), and `di`, `om`, `eh`, `env`, `logger` (short on purpose, and
documented; `Winter.context.objectMapper` is the long form).

### 12.2 Renamed

| Before                                  | After                                  | Why                                     |
|-----------------------------------------|----------------------------------------|-----------------------------------------|
| `BuildContext`                          | `WinterContext`                        | The `BuildContext` of Flutter: a full-stack Dart project imports both |
| `AbstractWinterRouter`                  | `BaseRouter`                           | A Java name; `Router` is a widget of Flutter |
| `LogsFilter`                            | `LoggingFilter`                        | The only filter named in plural         |
| `RequestSecurityContext.clearContext()` | `clear()`                              | It repeated the name of the class       |
| `RateLimiterFilter(onRequest:, log:)`   | `RateLimiterFilter(clientId:, onLimited:)` | `onRequest` was the id of the client, not a callback |
| `clientIpRequestId`                     | `defaultClientId`                      | The default of `clientId`               |
| `WinterRouter.handlerRoute`             | private (`resolveRoute` is the public one) | Two public methods did the same      |

### 12.3 Status codes

The model ported from Spring (`StatusCode`, the mixin `HttpStatusCode`, `DefaultHttpStatusCode`,
methods `is2xxSuccessful()`, javadoc) is now one enum: `StatusCode` with `value`, `series`,
`reasonPhrase`, Dart getters (`isSuccessful`, `isClientError`, `isError`...), `resolve(int)`
(null for a code it doesn't know, from a map) and `valueOf(int)` (an `ArgumentError`). The
deprecated values (`movedTemporarily`, `useProxy`, `requestEntityTooLarge`, `requestURITooLong` and
three WebDAV drafts) are removed: one constant per code.

### 12.4 Small fixes

- `HttpHeader` names are `const` (they were `static final`, so they couldn't be used in a `const`
  map nor a `switch`).
- `Winter.close` returns `Future<void>`, without the deprecated `onAlreadyStarted`.
- No `dart doc` warnings in the library (the doc of `RequestHandler` still talked about shelf).

### 12.5 The type of a serializer is always written

Writing example `05`, `Deserializer.enumByName(Status.values)` inside
`ObjectMapper(deserializers: [...])` was registered as `Deserializer<Enum>`: inside a
`List<Deserializer>` Dart infers a generic type from the list, not from the arguments, so the enum
was a 500 on the first request (§2.10 said the static method inferred it from the values; it only
does outside a list). And a `Deserializer.json(User.fromJson)` in the same list was registered as
`dynamic` with only a warning.

- `enumByName` is a constructor: `Deserializer<Status>.enumByName(Status.values)`, like `.json`,
  `.string` or `.integer`. One rule: the type is always written. Its values must be the values of
  an enum. Breaking.
- A `Serializer` or `Deserializer` created as `dynamic` or `Enum` is an `ArgumentError` with the
  way to write it, instead of a warning: it shows when the app starts, not as a 500.

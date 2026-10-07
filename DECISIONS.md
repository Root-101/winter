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

cvc.buildValidator('prefix')
    .notNull(message: t.errors.validations.prefixRequired)
    .validate(prefix);
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

- `ConstrainViolation.message` is in the **language of the request**, also in logs and `toString`
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

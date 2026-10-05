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

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
- A validator stores a `LocalizedText` (`String Function(WinterLocale)`), and `SimpleExceptionHandler`
  resolves it with `request.locale` when it builds the 422, adding `Vary: Accept-Language`.

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

**Why messages are resolved when responding, not when throwing.** Whoever throws the error (a
validator, a service) does not know the request. Storing a function from locale to text lets the
exception handler, which does know it, pick the language. It also lets an app (e.g. feather-io)
use its own slang-generated classes in `addLocalizedRule` without Winter knowing them.

**The custom message of a validator is a `LocalizedText`.** `notNull(message: ...)`, `size(...)` and
the other built-in validators take `LocalizedText? message`, not `String? message`:

```dart
cvc.buildValidator('prefix')
    .notNull(message: localized((m) => m.errors.validations.prefixRequired))
    .validate(prefix);
```

- *Why not a `String`*: a plain String is the same in every language, so an app that wants its own
  translated text had to rewrite the whole rule with `addLocalizedRule`. With a `LocalizedText` it
  keeps the built-in rule and only changes the text, resolved with `request.locale` like Winter's.
- A fixed text is still possible: `message: (_) => 'text'`.
- `ConstrainViolation.message` keeps the English text (the function called with `en`).
- *Why not generic over the app's messages class* (e.g. `notNull<AppMessages>(message: (m) => ...)`):
  Winter cannot know the class slang generates in the app, and a type parameter for it would spread
  through `ConstraintValidator`, the violations and the exception handler. Instead each app writes a
  small adapter from its own messages to a `LocalizedText`, like feather-io's
  `localized((m) => ...)`, which builds the app's slang instance for the `WinterLocale`.
- It was a breaking change (`message: 'x'` no longer compiles), accepted because the i18n API had no
  external users yet.

**Compatibility.**

- `ConstrainViolation.message` is still always in **English**: it is what logs and `toString` show.
  The translation is in the extra field `localizedMessage`.
- `addRule` and `custom()` keep a fixed text, the same in every language.
- `LocaleConfig` lives in the `BuildContext` (not in `ServerConfig`) so `WinterTestClient` and
  `buildHandler` see it without starting a server. By default it only supports English, so an
  existing app does not start answering in Spanish until it opts in.

**Known limitations.**

- `size` uses the same text for Strings (length) and Iterables (items): "The minimum is 3", the
  same as `min()`.
- The texts do not include the field name; it is already in `fieldName` of the response.
- A custom `message:` in `notNull`/`size` also adds `Vary: Accept-Language` although the text does
  not change (harmless, it only lowers the cache hit rate).
- What is **not** translated, on purpose: the default bodies of the HTTP errors (`Bad Request`,
  `Not Found`...) are the standard reason phrases, like the error codes; the messages of
  `DeserializationException` (400) and similar are technical, for the developer of the client.
- `custom()` and `addRule` validators keep their fixed text: use `addLocalizedRule` to translate them.

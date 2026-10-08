# Contributing to Winter

## Setup

Winter needs Dart 3.13 or newer. The repository pins the SDK with [FVM](https://fvm.app)
(`.fvmrc`), so run every command through it:

```bash
fvm install
fvm dart pub get
```

## Commands

```bash
fvm dart format .                     # the format is checked
fvm dart analyze                      # no issues allowed (strict casts and inference)
fvm dart test                         # every test, in parallel
fvm dart test test/security/cors_test.dart -N "preflight"   # one file, one test
fvm dart test --coverage-path=coverage/lcov.info --branch-coverage
fvm dart run benchmark/http_benchmark.dart                   # compile it with `dart compile exe` to measure
```

Every example in `example/` is a package of its own: run `fvm dart pub get` and `fvm dart test`
inside it.

## How the code is written

- Everything lives in `lib/src/`; `lib/winter.dart` is the only public library. A new public file
  goes to the barrel of its module; an internal helper stays out of it (or is hidden with
  `export ... hide`).
- The lints of `analysis_options.yaml`: single quotes, trailing commas, `const`, explicit casts of
  `dynamic`, explicit type arguments, no `print` (use `logger`).
- Framework code never writes to stdout or stderr: it logs through `logger`, and never logs bodies,
  query strings or tokens.

## Tests

- New tests use `WinterTestClient` (in memory, no port). Only the tests of the server itself start
  a real one, on a port no other test file uses.
- Never wait on the real clock: inject one (`clock:`).
- Keep the coverage: every behavior has a test, and every bug a test that failed before the fix.

## Translations

Winter's validation messages live in `lib/src/i18n/*.i18n.yaml`. To add a language, copy
`en.i18n.yaml` to `<language>.i18n.yaml`, translate the texts (keep the `{params}`), and run
`fvm dart run slang` to regenerate `messages*.g.dart` (versioned).

## Commits and documentation

- Commit messages start with the module: `[router] ...`, `[security] ...`, `[docs] ...`.
- Update the entry of the next version in `CHANGELOG.md` (what the version contains).
- A design choice goes to `DECISIONS.md` (the decision and why), and the guide of its module in
  `doc/` explains how to use it; check its snippets by running them.

## Publishing

`.pubignore` decides what goes into the package; pub ignores `.gitignore` when it exists, so a new
entry of `.gitignore` goes there too. Check it with `fvm dart pub publish --dry-run`.

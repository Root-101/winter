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
fvm dart run tool/check_doc_snippets.dart                    # the snippets of the docs use the API right
```

Every topic of `example/` (and every app of `example/apps/`) is a package of its own: run
`fvm dart pub get` and `fvm dart test` inside it.

## CI

`.github/workflows/ci.yml` runs on a push to `develop` or `main` and on a pull request to them (not
on every push of a `feature/*` branch: run the checks of above by hand there):

- **Tests**, on Linux and Windows: the format, the analysis, the tests (with coverage, sent to
  Codecov when the repository has the `CODECOV_TOKEN` secret) and the analysis and tests of every
  example.
- **Generated code**: `messages*.g.dart` equal to what `dart run slang` writes with the lowest
  slang of `pubspec.yaml` (`dart pub downgrade slang` first), in the package and in `example/i18n`.
- **Docs**: `tool/check_doc_snippets.dart` analyzes every Dart snippet of `README.md` and `doc/`
  against the API (a fragment's own names, like `User`, don't count; a parameter or a method of
  Winter that doesn't exist does).
- **Obfuscation**: `tool/obfuscation/main.dart` built with `--obfuscate`: generic types, two
  classes with the same name and a failing `fromJson` work, and the errors have no obfuscated
  names.
- **Package**: `dart pub publish --dry-run` without warnings, and an archive under 1 MB.
- **pana**: on Linux (it fails on Windows), at a fixed version, red below 150 of its 160 points.

## How the code is written

- Everything lives in `lib/src/`; `lib/winter.dart` is the only public library. A new public file
  goes to the barrel of its module; an internal helper stays out of it (or is hidden with
  `export ... hide`).
- The lints of `analysis_options.yaml`: single quotes, trailing commas, `const`, explicit casts of
  `dynamic`, explicit type arguments, no `print` (use `logger`).
- Every public member has a dartdoc (the `public_member_api_docs` lint), and every public
  top-level declaration ends its doc with `{@category <module>}` (the categories are listed in
  `dartdoc_options.yaml`). Check the reference with `fvm dart doc --dry-run`: no warnings.
- Framework code never writes to stdout or stderr: it logs through `logger`, and never logs bodies,
  query strings or tokens.

## Tests

- New tests use `WinterTestClient` (in memory, no port). Only the tests of the server itself start
  a real one, on a port no other test file uses.
- Never wait on the real clock: inject one (`clock:`).
- Keep the coverage: every behavior has a test, and every bug a test that failed before the fix.
- One behavior, one test: before adding a test, look for one that already checks it, and name
  the test after what it checks (never `Test #1`).

## Translations

Winter's validation messages live in `lib/src/i18n/*.i18n.yaml`. To add a language, copy
`en.i18n.yaml` to `<language>.i18n.yaml`, translate the texts (keep the `{params}`), and run
`fvm dart run slang` to regenerate `messages*.g.dart` (versioned). Generate them with the lowest
slang of `pubspec.yaml` (`fvm dart pub downgrade slang`): a newer one writes them a little
differently, and the CI compares them with that one.

## Branches

- Every feature or change gets its own branch from `develop` (`feature/<name>`), and all its work
  goes there. When it's done and the checks pass, it's merged into `develop` and the branch is
  deleted.
- The `CHANGELOG.md` entry, the version and the rest of the release notes go in a commit of the
  branch itself, preferably its last one, right before merging into `develop`.

## Commits and documentation

- Commit messages start with the module: `[router] ...`, `[security] ...`, `[docs] ...`.
- Update the entry of the next version in `CHANGELOG.md` (what the version contains) in the last
  commit of the branch, before merging into `develop`.
- A design choice goes to `DECISIONS.md` (the decision and why), and the guide of its module in
  `doc/` explains how to use it; check its snippets by running them.

## Publishing

`.pubignore` decides what goes into the package; pub ignores `.gitignore` when it exists, so a new
entry of `.gitignore` goes there too. Check it with `fvm dart pub publish --dry-run`.

Before every release, run the whole
[release review of the roadmap](ROADMAP.md#release-review-before-every-release): the roadmap,
the API, security, the tests, the examples, the docs and the checks.

# Configuration

A Winter app is configured in two places:

- **`Env`** (the global `env`) reads the environment variables with their type: the database URL,
  the secrets, the timeouts. In production they come from the platform (`docker run -e`, the
  settings of the cloud service); for local development, from a `.env` file.
- **`ServerConfig`** says how the server runs: host and port, the body limit, the graceful
  shutdown.

The decisions behind them are in [`DECISIONS.md` §6](../DECISIONS.md#6-configuration).

## Minimal example

```dart
import 'package:winter/winter.dart';

class AppConfig {
  final String databaseUrl;
  final Duration requestTimeout;

  AppConfig({required this.databaseUrl, required this.requestTimeout});

  factory AppConfig.fromEnv(Env env) {
    env.requireAll(['DATABASE_URL']); // every missing variable in one error
    return AppConfig(
      databaseUrl: env.require<String>('DATABASE_URL'),
      requestTimeout: env.find<Duration>('REQUEST_TIMEOUT') ?? const Duration(seconds: 30),
    );
  }
}

void main() async {
  final env = Env.load(); // .env (and .env.<profile>) under the variables of the process
  Winter.context.setUp(env: env);
  di.put(AppConfig.fromEnv(env)); // fails here, before the server opens its port

  await Winter.start(
    config: ServerConfig.fromEnv(env), // PORT and HOST of the platform, or 8080 on 0.0.0.0
    router: WinterRouter(routes: []),
  );
}
```

## How it works

### Reading a variable

| Method                            | Missing or empty            | Not a valid `T`  |
|-----------------------------------|-----------------------------|------------------|
| `env.find<T>(key)`                | `null` (`?? default`)       | `StateError`     |
| `env.require<T>(key)`             | `StateError` that names it  | `StateError`     |
| `env.findEnum(key, values)`       | `null`                      | `StateError` that lists the names |
| `env.requireEnum(key, values)`    | `StateError`                | `StateError`     |
| `env.requireAll([keys])`          | `StateError` that names **all** the missing ones | — |

```dart
final port = env.find<int>('PORT') ?? 8080;
final dbUrl = env.require<String>('DATABASE_URL');
final level = env.findEnum('LOG_LEVEL', LogLevel.values) ?? LogLevel.info;
```

- An empty value (`KEY=` or only spaces) counts as missing.
- Every method takes `caseSensitive: false` to find the key in any case.
- **The errors never show the value**: they name the variable and what it should be
  (`The env variable DB_PORT is not an integer`). A configuration error ends in the logs, and the
  value may be a secret.

### Types

| Type        | Example value                        | Notes                                        |
|-------------|--------------------------------------|----------------------------------------------|
| `String`    | `postgres://localhost/app`           | As it is: **never trimmed** (a secret may have spaces) |
| `bool`      | `true`, `False`                      | Only `true` or `false`, any case             |
| `int`       | `8080`                               | `8.5` is an error, never truncated           |
| `double`, `num` | `0.5`, `3`                       |                                              |
| `Duration`  | `250ms`, `30s`, `5m`, `1h`, `2d`     | A number and a unit                          |
| `Uri`       | `https://api.example.com/v1`         | Must be absolute (with a scheme)             |
| `List<T>`   | `admin, editor`, `1,2,3`             | Comma separated, of any type above; empty items are skipped |
| enums       | `warning` for `LogLevel.warning`     | With `findEnum`/`requireEnum`, by name, any case |

Every type except `String` is trimmed (`' 8080 '` is `8080`), and the nullable forms work too
(`find<int?>`). Another type (`Set<int>`, `DateTime`...) is a `StateError` that lists the
supported ones.

`env.put(key, value)` sets a variable so `find` reads it back (a list comma separated, a
`Duration` in milliseconds, an enum by name), and returns the value. `env.all` is a copy of every
variable.

### `.env` files and profiles

`Env.load()` reads the variables of the process on top of two optional files of the current
directory:

| Precedence | Source                      | Typical use                                    |
|------------|-----------------------------|------------------------------------------------|
| 1 (wins)   | The variables of the process | Production: `docker run -e`, Kubernetes, the cloud service |
| 2          | `.env.<profile>`            | A profile on a laptop (`.env.test`, `.env.staging`) |
| 3          | `.env`                      | The local defaults of the team                  |

The profile is `WINTER_PROFILE` (or `Env.load(profile: 'test')`), and `env.profile` tells which
one is active. A file that doesn't exist is ignored, so the same code runs on a laptop, with a
`.env`, and in a container, without files.

```properties
# .env
PORT=8080
DATABASE_URL=postgres://localhost/app   # a comment after a space and #
export LOG_LEVEL=debug
GREETING="Hello\nWorld"                  # double quotes: \n, \t, \" and \\ escapes
PATTERN='^\d+$'                          # single quotes: literal
```

- One `KEY=VALUE` per line; `#` starts a comment (inside an unquoted value, only after a space:
  `a#b` is a value); an `export ` prefix is ignored.
- No interpolation (`${OTHER}` is literal): it would hide where a value comes from.
- A line that is not a variable, or an unclosed quote, is a `FormatException` with the file and
  the line number (never its content).
- Keep secrets out of the repository: commit a `.env` with development values, and ignore
  `.env.*` files with real ones.

`Env()` (the default of `Winter.context`) only has the variables of the process; `Env(env: {...})`
adds yours on top of them (handy in tests).

### `ServerConfig`

| Option            | Default        | What it does                                                      |
|-------------------|----------------|-------------------------------------------------------------------|
| `host`            | `'0.0.0.0'`    | The address the server listens on (`'localhost'`, `'127.0.0.1'`, `'::'`) |
| `port`            | `8080`         | `0` picks a free port                                             |
| `shared`          | `false`        | Several isolates listen on the same port and share the connections |
| `maxBodySize`     | 10 MB          | A bigger body is a 413 when it's read; `null` for no limit        |
| `handleSignals`   | `true`         | SIGINT/SIGTERM shut the server down gracefully                    |
| `shutdownTimeout` | 10 seconds     | How long the graceful shutdown waits for the requests in progress |
| `onShutdown`      | —              | Called on a graceful shutdown, before the dependencies are disposed |
| `autoCompress`    | `false`        | gzip the responses for a client that accepts it (a stream is never compressed) |
| `idleTimeout`     | 120 seconds    | How long an idle keep-alive connection stays open; `null` keeps them |
| `securityContext` | —              | Serve HTTPS with this certificate and key                         |

- It's `const`: `const ServerConfig(port: 9000)`.
- `ServerConfig.fromEnv(env)` reads `PORT` and `HOST`, the variables that Cloud Run, Heroku,
  Render and Kubernetes set, and takes the other options (and the defaults of `port`/`host`) as
  parameters.
- `Winter.start` validates it before opening the port: a port out of `0-65535`, a negative
  `maxBodySize`, `shutdownTimeout` or `idleTimeout`, or an empty host, is an `ArgumentError`.
- HTTPS: usually the proxy in front of the app terminates TLS. To serve it from the app:

  ```dart
  await Winter.start(
    config: ServerConfig(
      port: 8443,
      securityContext: SecurityContext()
        ..useCertificateChain('cert.pem')
        ..usePrivateKey('key.pem'),
    ),
  );
  ```

### Where `Winter.start` finds its configuration

For the `ServerConfig`, the router and the `SecurityConfig`, in this order:

1. The argument of `Winter.start(config: ..., router: ..., securityConfig: ...)`.
2. The one registered in `di` (`di.put(ServerConfig(...))`).
3. The default (`const ServerConfig()`, an empty `WinterRouter`, `SecurityConfig()`).

The one used is registered in `di`, and `Winter.close()` restores what was there before.

### `WinterContext`

`Winter.context` holds the global services: `env`, `om` (the object mapper), `eh` (the exception
handler), `di`, `logger` and `localeConfig`. Replace any of them with `setUp`, before starting the
server:

```dart
Winter.context.setUp(
  env: Env.load(),
  logger: const ConsoleLogger(minLevel: LogLevel.debug),
);
```

`Winter.start(context: WinterContext(...))` replaces the whole context instead.

## Common cases

### A secret with a fallback for development

```dart
final secret = env.find<String>('JWT_SECRET');
if (secret == null && env.profile == 'prod') {
  throw StateError('JWT_SECRET is required in production');
}
```

### Tests

```dart
setUp(() {
  Winter.context.setUp(env: Env(env: {'DATABASE_URL': 'postgres://localhost/test'}));
});
```

Or `Env.load(profile: 'test')` with a `.env.test` file, or
`Env.load(environment: {...})` to read the files without the variables of the machine.

### Running behind a platform that sets `PORT`

```dart
await Winter.start(config: ServerConfig.fromEnv(env, shutdownTimeout: const Duration(seconds: 25)));
```

Keep the `shutdownTimeout` below the grace period of the platform
(`terminationGracePeriodSeconds` in Kubernetes is 30 by default).

## Typical mistakes and limitations

- **`Env.load()` without `setUp`**: the global `env` is still `Env()` (only the process). Register
  it with `Winter.context.setUp(env: Env.load())`.
- **Reading the configuration everywhere**: read it once at start-up into a class (see the minimal
  example), so a missing variable fails before the server starts, not in a request.
- **A `.env.prod` with secrets in the repository**: in production the variables come from the
  platform; the files are for local development.
- **A value with leading or trailing spaces in a `String`**: it's kept on purpose (secrets). Quote
  it in the `.env` file if the spaces matter, or remove them.
- **Only one variable per line, no multi-line values**: use `\n` inside double quotes.

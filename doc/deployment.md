# Deployment

A Winter app compiles to a native executable: a small container image without the Dart SDK, that
starts in milliseconds. This guide covers the build, the container, the shutdown, the health
checks, several isolates and the proxy in front of the app.

The whole setup is in [`example/apps/production`](../example/apps/production).

## Minimal example

```dockerfile
# Build a native executable
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart compile exe lib/main.dart -o /app/server

# A scratch image with the executable and the runtime libraries it needs
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
WORKDIR /app
EXPOSE 8080
CMD ["/app/server"]
```

```dart
void main() async {
  final env = Env.load(); // .env locally; the variables of the platform in the container
  Winter.context.setUp(env: env, logger: const JsonLogger());

  await Winter.start(
    config: ServerConfig.fromEnv(env), // PORT and HOST of the platform
    router: router,
  );
}
```

## How it works

### The build

`dart compile exe` produces an AOT executable: no JIT warm-up, a lower memory use, and no SDK in the
image. Winter has no `build_runner` step and no mirrors, so nothing else is needed. The object
mapper finds types by `Type`, never by name, so `--obfuscate` works too.

### Configuration

The platform passes the configuration as variables of the process: `PORT` (Cloud Run, Heroku,
Kubernetes), the database URL, the secrets. `Env.load()` reads them **over** `.env` and
`.env.<WINTER_PROFILE>`, so the same code runs on a laptop (with a `.env`) and in the container
(without files). Check every required variable at start, so a missing one names itself in the first
restart:

```dart
env.requireAll(['DATABASE_URL', 'JWT_SECRET']);
```

See [configuration](configuration.md).

### Logs

`JsonLogger` writes one JSON object per line, with the request id: the format Cloud Logging,
Datadog or Loki parse. A client sees the id in the `X-Request-Id` of the response (and in a 500), so
an error report leads to its logs. See [logging](logging.md).

### Graceful shutdown

On `SIGTERM` (`docker stop`, a new deploy, Kubernetes scaling down) Winter:

1. Stops accepting connections.
2. Waits for the requests in progress, up to `ServerConfig.shutdownTimeout` (10 s by default).
3. Calls `onShutdown`.
4. Runs the `onDispose` of the dependencies (`di.disposeAll()`), in reverse order: the database
   pool closes after everything that uses it.

A second signal forces the close. Keep `shutdownTimeout` below the grace period of the platform, or
the process is killed before it finishes: Kubernetes waits `terminationGracePeriodSeconds` (30 s by
default), `docker stop` 10 s (`--time`).

```dart
ServerConfig.fromEnv(
  env,
  shutdownTimeout: const Duration(seconds: 25),
  onShutdown: () => logger.info('Stopped accepting requests'),
)
```

In Kubernetes, a `preStop` sleep of a few seconds gives the load balancer time to stop sending new
requests before the shutdown starts.

### Health checks

Two routes, two questions:

```dart
Route.get(path: '/health', handler: (request) => ResponseEntity.ok(body: {'status': 'up'})),
Route.get(
  path: '/ready',
  handler: (request) async {
    if (!await di.find<Database>().ping()) {
      throw ServiceUnavailableException(detail: 'The database is not available', retryAfter: 5);
    }
    return ResponseEntity.ok(body: {'status': 'ready'});
  },
),
```

- **Liveness** (`/health`): the process answers. If it fails, the platform restarts the container.
- **Readiness** (`/ready`): its dependencies answer. If it fails (503), the instance leaves the load
  balancer without a restart.

Leave them out of the rate limiter and of the authentication (`shouldFilter`, or a route key).

### Behind a proxy

In production a load balancer or a reverse proxy (nginx, an ingress) sits in front of the app:

- **HTTPS ends at the proxy**: the app serves HTTP inside the network, with
  `SecurityHeaders(hsts: true)` so browsers keep using HTTPS. To serve HTTPS from the app, see
  `ServerConfig.securityContext` in [configuration](configuration.md).
- **The IP of the client** is in `X-Forwarded-For`: `request.clientIp(trustedProxies: 1)` (one entry
  per proxy you control). Never trust it without a proxy: a client can send any value.
- **Compression**: usually the proxy does it; `ServerConfig(autoCompress: true)` does it in the app.

### Several isolates

A Dart isolate runs on one core. To use several, start one server per isolate on the same port with
`shared: true`: `dart:io` balances the connections between them.

```dart
Future<void> main() async {
  for (var i = 0; i < Platform.numberOfProcessors; i++) {
    await Isolate.spawn(serve, null);
  }
}

Future<void> serve(Object? _) async {
  await Winter.start(
    config: const ServerConfig(port: 8080, shared: true),
    router: router(),
  );
}
```

Every isolate has its own memory: its own `Winter.context`, its own dependencies, its own rate
limiter and caches. Anything shared (sessions, limits, caches) goes to an external store (Redis, the
database). Often it's simpler to run one isolate per container and let the platform add containers.

## Common cases

### A production checklist

- `dart compile exe` and a `scratch` (or distroless) image.
- `PORT` from the environment (`ServerConfig.fromEnv`), secrets from the secret manager of the
  platform, never in the image.
- `JsonLogger`, and no bodies, tokens nor passwords in the logs.
- `shutdownTimeout` below the grace period, and `onDispose` on every resource.
- `/health` and `/ready`.
- `trustedProxies` equal to the proxies in front, HSTS when TLS ends at the proxy, CORS with your
  origins.
- `maxBodySize` as small as your biggest request.

## Typical mistakes and limitations

- **`shutdownTimeout` longer than the grace period**: the process is killed in the middle.
- **A rate limit or a cache in memory with several instances**: each one keeps its own.
- **`trustedProxies` without a proxy**: any client chooses its IP.
- **Copying `.env` into the image**: the production configuration comes from the platform.

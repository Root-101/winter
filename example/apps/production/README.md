# Production Example

A Winter app ready to run in a container: its configuration comes from the environment, it writes
JSON logs with the request id, it has health checks for the platform, it shuts down gracefully on
`SIGTERM`, and it builds into a small native image.

## Key Concepts

### 1. Configuration from the environment (`ProductionApp.loadEnv`)
*   `Env.load()` reads `.env` (local defaults) and `.env.<WINTER_PROFILE>` (`.env.prod`) **under**
    the variables of the process: in the container the platform sets them, and its secrets never go
    in a file.
*   `env.requireAll([...])` names every missing variable at once.
*   Typed values: `RATE_LIMIT` (int), `HSTS` (bool), `CORS_ORIGINS` (a list), `SHUTDOWN_TIMEOUT`
    (`25s`), `LOG_LEVEL` (an enum).
*   `ServerConfig.fromEnv(env)` reads `PORT` and `HOST`, the variables that Cloud Run, Heroku and
    Kubernetes set.

### 2. Logs (`ProductionApp.loggerFor`)
`LOG_FORMAT=json` gives a `JsonLogger`: one JSON object per line, with the request id and the W3C
trace (`traceId`, `spanId`), for Cloud Logging, Datadog or Loki. Locally, a readable `ConsoleLogger`
at `debug`.

### 3. Distributed tracing (`StockClient`)
A request that comes with a `traceparent` (from a gateway, or a service with OpenTelemetry)
continues that trace. `GET /products/{sku}/stock` calls the stock service (`STOCK_URL`) with
`requestTrace!.headers`, so both services show up in one trace and their logs share the `traceId`
(which is also the request id when no `X-Request-Id` came).

### 4. Health checks
*   `GET /health` (liveness, `Route.health()`): the process answers.
*   `GET /ready` (readiness, `Route.health(checks: {'database': ...})`): the database answers;
    otherwise a 503 `{"status": "fail", "checks": {"database": [{"status": "fail"}]}}`
    (`application/health+json`), which takes the instance
    out of the load balancer without restarting it.

### 5. Security behind a proxy
*   `ServerConfig(trustedProxies: TrustedProxies(TRUSTED_PROXIES))`: the IP of the client, the
    scheme and the host come from the `X-Forwarded-*` of the load balancer (never trusted locally).
*   `RateLimiterFilter` by client IP (the forwarded one).
*   CORS with the origins of `CORS_ORIGINS`, and HSTS with `HSTS=true` (TLS ends at the proxy).
*   `maxBodySize` of 1 MB.

### 6. Graceful shutdown
On `SIGTERM` (`docker stop`, a deploy) Winter stops accepting connections, waits for the requests in
progress (up to `SHUTDOWN_TIMEOUT`, below the 30 s grace period of Kubernetes), calls
`onShutdown`, and then the `onDispose` of the `Database` closes it.

### 7. Docker
`Dockerfile` compiles a native executable (`dart compile exe`) into a `scratch` image: no Dart SDK
inside, and it starts in milliseconds.

## How to Run

```bash
dart pub get
dart run lib/main.dart                     # local: .env, readable logs
WINTER_PROFILE=prod dart run lib/main.dart # .env.prod on top: JSON logs, HSTS
dart test

docker build -t winter-production .
docker run -p 8080:8080 -e DATABASE_URL=postgres://... winter-production
```

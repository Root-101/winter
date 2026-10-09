# Logging

Every log of Winter, and of your app, goes through `logger`, the `WinterLogger` of
`Winter.context`:

- `ConsoleLogger` (the default) writes readable lines for development; `JsonLogger` writes one JSON
  object per line for production (Cloud Logging, Datadog, Loki...).
- Every request has an **id**: it's in every log written for it, in its response and in a 500, so
  a client can report it and its logs can be found.
- The logs never contain the data of a request (bodies, query strings, the values of a failed
  deserialization).

The decisions behind it are in [`DECISIONS.md` §7](../DECISIONS.md#7-logging).

## Minimal example

```dart
import 'package:winter/winter.dart';

void main() async {
  Winter.context.setUp(logger: const JsonLogger()); // production

  await Winter.start(
    globalFilterConfig: FilterConfig([LoggingFilter()]),
    router: WinterRouter(
      routes: [
        Route.post(
          path: '/orders',
          handler: (request) {
            logger.info('Order created', fields: {'orderId': 42});
            return ResponseEntity(201);
          },
        ),
      ],
    ),
  );
}
```

`POST /orders` writes:

```json
{"time":"2026-10-07T16:11:07.171Z","severity":"INFO","message":"REQUEST: POST /orders","requestId":"8f1c2a47-..."}
{"orderId":42,"time":"2026-10-07T16:11:07.172Z","severity":"INFO","message":"Order created","requestId":"8f1c2a47-..."}
{"time":"2026-10-07T16:11:07.175Z","severity":"INFO","message":"RESPONSE: POST /orders => 201 (3 ms)","requestId":"8f1c2a47-..."}
```

## How it works

### Levels and methods

`LogLevel.debug`, `info`, `warning` and `error`, from the most verbose to the most important.

```dart
logger.debug('Cache miss', fields: {'key': key});
logger.info('Order created', fields: {'orderId': order.id});
logger.warning('Payment retried', error: error);
logger.error('Payment failed', error: error, stackTrace: stackTrace);
```

Every level takes an `error`, its `stackTrace` and `fields` (structured data). Before building an
expensive message, check the level:

```dart
if (logger.isEnabled(LogLevel.debug)) {
  logger.debug('State: ${expensiveDump()}');
}
```

### `ConsoleLogger` and `JsonLogger`

| Logger            | For          | A line                                                                      |
|-------------------|--------------|-----------------------------------------------------------------------------|
| `ConsoleLogger()` | Development  | `2026-10-07T16:11:07.171Z [INFO] [8f1c...] Order created orderId=42`        |
| `JsonLogger()`    | Production   | `{"orderId":42,"time":"...","severity":"INFO","message":"Order created","requestId":"8f1c..."}` |

- Both take `minLevel` (default `LogLevel.info`): `ConsoleLogger(minLevel: LogLevel.debug)`.
- The time is always UTC.
- `ConsoleLogger` writes debug and info to stdout, warning and error to stderr, with the error and
  the stack trace in the next lines.
- `JsonLogger` writes everything to stdout, one line per log. `time`, `severity` and `message`
  are the keys that Cloud Logging reads by itself (Datadog and Loki map them easily); `requestId`
  is there inside a request; `error` and `stackTrace` are strings. The `fields` are members of
  their own and never replace those keys; a field that is not a JSON value is written as its text.

### The request id

Every request has an id, without adding anything:

- The `X-Request-Id` of the request when it's valid (1 to 128 letters, digits and `.`, `_`, `:`,
  `-`), so an id created by a gateway or a load balancer is kept along the way. Otherwise, a new
  random UUID.
- It's in the `X-Request-Id` header of the response, in every log written during the request
  (also from services, after an `await`), and in the body of a 500:

  ```json
  { "requestId": "8f1c2a47-...", "type": "about:blank", "title": "Internal Server Error", "status": 500 }
  ```

- Read it anywhere with `requestId` (null outside a request), for example to pass it to another
  service: `headers: {'X-Request-Id': requestId!}`.

### What Winter logs

| Level   | What                                                                     |
|---------|--------------------------------------------------------------------------|
| info    | `Server started on port 8080 (0.2 sec)`, `Shutting down...`, `Server stopped` |
| info    | `REQUEST`/`RESPONSE` of every request, with `LoggingFilter`                 |
| info    | The routes loaded, only with `RouterConfig(onLoadedRoutes: DefaultOnLoadedRoutes.log())` |
| warning | A duplicated or invalid route (with `RouterConfig` `ignore()`; by default it fails), languages without Winter's messages, requests still in progress at the end of the shutdown |
| error   | An unexpected error (the 500), with its stack trace; a failing `onDispose` or `onComplete` |
| debug   | A rate limited request (with the client id), the type of the error of a failed deserialization |

### `LoggingFilter`

```dart
await Winter.start(globalFilterConfig: FilterConfig([LoggingFilter()]), router: router);
```

It writes two lines per request, both in info and with the request id:
`REQUEST: GET /users/1` when it arrives, and `RESPONSE: GET /users/1 => 200 (12 ms)` when it's
answered (error responses too). `LoggingFilter(logRequest: ..., logResponse: ...)` replaces them.

**It never logs the body nor the query string**: they may contain passwords, tokens or personal
data (`?email=...`), and a body may be huge. For the same reason, a failed deserialization logs the
type of the error (`FormatException`), never its message, which can include the value sent.

## Configuration

```dart
Winter.context.setUp(
  logger: env.profile == 'prod'
      ? const JsonLogger()
      : const ConsoleLogger(minLevel: LogLevel.debug),
);
```

### A logger of your own

Extend `WinterLogger` and implement `log` (and `isEnabled`, if it filters levels):

```dart
class MemoryLogger extends WinterLogger {
  final List<String> lines = [];

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    lines.add('${level.name} ${requestId ?? '-'} $message');
  }
}
```

Read `requestId` inside `log` to add the id of the request.

## Common cases

### Testing what was logged

Replace the logger with one that keeps the lines (like `MemoryLogger` above):

```dart
setUp(() {
  memory = MemoryLogger();
  Winter.context.setUp(logger: memory);
});
```

### Following a request across services

Send the id to the services you call, so their logs share it:

```dart
await http.get(url, headers: {HttpHeader.xRequestId: requestId!});
```

## Typical mistakes and limitations

- **Logging a body, a token or a password**: never. Log ids (`orderId`, `userId`) in `fields`.
- **`JsonLogger` in development**: the lines are hard to read; use `ConsoleLogger` locally.
- **The request id in a browser**: the client can read the `X-Request-Id` header only if CORS
  exposes it: `CorsFilter` always does (`Access-Control-Expose-Headers`).
- **A log outside a request** (start-up, a `Timer`) has no request id.

# Error handling examples

One file per case, each a server of its own: `dart run lib/<case>.dart` (port 8080). The tests run
each one in memory: `dart test`.

| Case | File | What it shows |
|------|------|---------------|
| Domain exceptions | [`domain_exceptions.dart`](lib/domain_exceptions.dart) | Exceptions of the domain mapped with `on<T>()` to a status, a `type` URI and extensions; the mapping of a base type as a fallback; the 404 of the router changed |
| Custom handler | [`custom_handler.dart`](lib/custom_handler.dart) | `handle` overridden: a timeout of another service is a 504, a `SocketException` a 502; `logUnhandledError` reporting to an error tracker with the request id; a `ResponseException` in a legacy format |

Guide: [error handling](../../doc/error-handling.md).

# Filter examples

One file per case, each a server of its own: `dart run lib/<case>.dart` (port 8080). The tests run
each one in memory: `dart test`.

| Case | File | What it shows |
|------|------|---------------|
| Custom filters | [`custom_filters.dart`](lib/custom_filters.dart) | Code after the handler (`Server-Timing`), a changed request passed to the chain, `order`, `shouldFilter`, filters that see the 404 too |
| Request context | [`request_context.dart`](lib/request_context.dart) | Multi-tenancy: the tenant from a header or the subdomain, saved under a typed `ContextKey`, read as `request.tenant` |
| Maintenance mode | [`maintenance_mode.dart`](lib/maintenance_mode.dart) | Short-circuiting the chain with a 503 and `Retry-After`, switched at runtime, the health check exempt |
| Response cache | [`response_cache.dart`](lib/response_cache.dart) | A route filter that keeps successful `GET` responses for a while, `X-Cache` and `Age`, a fake clock in the test |

Guide: [filters](../../doc/filters.md).

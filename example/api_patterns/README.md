# API patterns

Patterns that real APIs need sooner or later, built with what Winter already has (filters,
headers, `ApiException`). One file per case, each a server of its own: `dart run lib/<case>.dart`
(port 8080). The tests run each one in memory: `dart test`.

| Case | File | What it shows |
|------|------|---------------|
| Pagination | [`pagination.dart`](lib/pagination.dart) | `page`/`size` with a limit, `X-Total-Count`, `Link` with `first`/`prev`/`next`/`last` from `WebLink.pages` (keeping the other params), exposed through CORS |
| Conditional requests | [`conditional_requests.dart`](lib/conditional_requests.dart) | `ETag` and the 304 the server gives for `If-None-Match`; optimistic locking with `request.checkPreconditions`: 412 for a stale version, 428 without `If-Match` |
| Content negotiation | [`content_negotiation.dart`](lib/content_negotiation.dart) | JSON or CSV by `Accept` (with `q`), 406, `Vary: Accept` |
| File download | [`file_download.dart`](lib/file_download.dart) | A CSV export streamed row by row, `Content-Disposition` with a name that isn't ASCII, `inline` vs `attachment` |
| Client preferences | [`prefer_return.dart`](lib/prefer_return.dart) | `Prefer: return=minimal` (RFC 7240): a 201 without body and `Preference-Applied`; `Vary: Prefer` added by itself |
| Long-running jobs | [`async_jobs.dart`](lib/async_jobs.dart) | `202 Accepted` + `Location` of the job, polling with `Retry-After`, `303 See Other` to the result |
| Idempotency keys | [`idempotency_keys.dart`](lib/idempotency_keys.dart) | `IdempotencyFilter` on the route: the first answer of a retried POST replayed (`Idempotency-Key`), 422 for another body, 409 while running, 400 without a key |
| Request timeout | [`request_timeout.dart`](lib/request_timeout.dart) | `ServerConfig(requestTimeout:)`, off by default: a route slower than the limit is a 503, a fast one answers as always; tested with timers that fire at once |
| API versioning | [`api_versioning.dart`](lib/api_versioning.dart) | `/v1` and `/v2` as parent routes, a `DeprecationFilter` in the old version: `Deprecation`/`Sunset`/`Link` on its responses and `deprecated` in OpenAPI |

Guides: [requests and responses](../../doc/requests-and-responses.md), [filters](../../doc/filters.md),
[error handling](../../doc/error-handling.md).

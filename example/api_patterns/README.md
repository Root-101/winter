# API patterns

Patterns that real APIs need sooner or later, built with what Winter already has (filters,
headers, `ApiException`). One file per case, each a server of its own: `dart run lib/<case>.dart`
(port 8080). The tests run each one in memory: `dart test`.

| Case | File | What it shows |
|------|------|---------------|
| Pagination | [`pagination.dart`](lib/pagination.dart) | `page`/`size` with a limit, `X-Total-Count`, `Link` with `first`/`prev`/`next`/`last`, exposed through CORS |
| Conditional requests | [`conditional_requests.dart`](lib/conditional_requests.dart) | `ETag` and a 304 for `If-None-Match`; optimistic locking with `If-Match`: 412 for a stale version, 428 without it |
| Content negotiation | [`content_negotiation.dart`](lib/content_negotiation.dart) | JSON or CSV by `Accept` (with `q`), 406, `Vary: Accept` |
| File download | [`file_download.dart`](lib/file_download.dart) | A CSV export streamed row by row, `Content-Disposition` with a name that isn't ASCII, `inline` vs `attachment` |
| Long-running jobs | [`async_jobs.dart`](lib/async_jobs.dart) | `202 Accepted` + `Location` of the job, polling with `Retry-After`, `303 See Other` to the result |
| Idempotency keys | [`idempotency_keys.dart`](lib/idempotency_keys.dart) | A route filter that replays the first answer of a retried POST (`Idempotency-Key`), 422 for another body, 409 while running |
| API versioning | [`api_versioning.dart`](lib/api_versioning.dart) | `/v1` and `/v2` as parent routes, `Deprecation`/`Sunset`/`Link` added by a filter of the old version |

Guides: [requests and responses](../../doc/requests-and-responses.md), [filters](../../doc/filters.md),
[error handling](../../doc/error-handling.md).

# Security examples

One file per case, each a server of its own: `dart run lib/<case>.dart` (port 8080). The tests run
each one in memory: `dart test`. A whole app with JWT, roles and permissions is
[`apps/auth_jwt`](../apps/auth_jwt); CORS, HSTS and a rate limit behind a proxy from the
environment are in [`apps/production`](../apps/production).

| Case | File | What it shows |
|------|------|---------------|
| API keys | [`api_key.dart`](lib/api_key.dart) | Keys stored hashed, permissions per key, a global `AuthFilter` with `shouldFilter` and its own `challenge`, 401 vs 403 |
| Basic auth | [`basic_auth.dart`](lib/basic_auth.dart) | An admin area with `WWW-Authenticate: Basic`, a constant-time comparison, a broken header taken as no credentials |
| Webhook signatures | [`webhook_signature.dart`](lib/webhook_signature.dart) | HMAC-SHA256 over the raw bytes (`bytes()` then `body<T>()`), a timestamp against replays, a fake clock in the test |
| CORS with cookies | [`cors_with_credentials.dart`](lib/cors_with_credentials.dart) | A SPA on another origin: a list of origins, credentials, preflight, exposed headers, `SameSite=None` cookie |
| Login throttling | [`login_throttling.dart`](lib/login_throttling.dart) | A `RateLimiterFilter` per IP on one route, a `RateLimiter` per account with `peek`/`check`/`reset` |
| Resource ownership | [`resource_ownership.dart`](lib/resource_ownership.dart) | "The author or an admin": a `rule()` when the path names the owner, `requestPrincipal` + 403 in the service otherwise |

Guide: [security](../../doc/security.md).

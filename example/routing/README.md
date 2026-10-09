# Routing examples

One file per case, each a server of its own: `dart run lib/<case>.dart` (port 8080). The tests run
each one in memory: `dart test`.

| Case | File | What it shows |
|------|------|---------------|
| Hello world | [`hello_world.dart`](lib/hello_world.dart) | One route, and the route table in the logs |
| Path and query params | [`path_and_query_params.dart`](lib/path_and_query_params.dart) | `pathParam<int>`, a regex param, `queryParam<T>` with enums and booleans, repeated params, a 400 that names the param |
| Nested routes | [`nested_routes.dart`](lib/nested_routes.dart) | `Route.parent`, filters inherited by the children, `basePath`, route keys, 405 with `Allow` |
| CRUD | [`crud.dart`](lib/crud.dart) | A service in `di`, 201 with `Location`, 404, a PATCH with `PatchValue`, 204 |
| Static files | [`static_files.dart`](lib/static_files.dart) | `Route.static` with the folder `web/`: index, `Cache-Control`, ETag and 304, `Range` |
| Health check | [`health_check.dart`](lib/health_check.dart) | `Route.health` for liveness and readiness, a 503 when a check is down |

Guide: [routing](../../doc/routing.md).

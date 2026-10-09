# Winter examples

Two kinds of examples:

- **By topic**: many small examples, each about one case. One package per topic, one file per case
  (`lib/<case>.dart`, a server of its own on port 8080) and its test (`test/<case>_test.dart`, in
  memory). Each topic has a README with the table of its cases.
- **Apps**: complete applications that combine several systems on purpose.

The smallest server is [`main.dart`](main.dart).

## By topic

| Topic | Cases |
|-------|-------|
| [routing](routing) | Hello world, path and query params, nested routes, a CRUD, static files, health checks |
| [bodies](bodies) | Every kind of request body: none, JSON, text/XML/CSV, urlencoded form, form-data, streamed upload, binary, GraphQL |
| [validation](validation) | Basic rules, nested objects, lists and maps, custom rules, async rules ("the email is already registered") |
| [object_mapper](object_mapper) | Field naming, typed fields and their errors, adapters, partial updates (PATCH), unknown fields, sealed classes, generic types |
| [openapi](openapi) | The document without any docs, bodies from examples, schemas by hand, `BodyDocs`, a whole documented API with Swagger UI, exporting the document |
| [realtime](realtime) | Server-Sent Events, a WebSocket chat |
| [i18n](i18n) | Responses and validation messages in the language of the request, with slang |

## Apps

| App | What it combines |
|-----|------------------|
| [auth_jwt](apps/auth_jwt) | Register and login with JWT, a global filter that authenticates, roles and permissions (`hasRole(...) & hasPermission(...)`), controllers, async validation |
| [orders](apps/orders) | An orders API: snake_case JSON, `Money` as text, enums, nested validation, `rejectUnknownFields`, typed params |
| [files_gallery](apps/files_gallery) | A photo gallery: a login form and a session cookie, uploads checked by their bytes, a streamed video upload, protected static files, Server-Sent Events and a WebSocket chat |
| [production](apps/production) | Ready for a container: `.env` and profiles, `JsonLogger`, liveness and readiness, rate limit behind a proxy, CORS and HSTS from the environment, graceful shutdown, a Dockerfile |

## Running them

Every folder is a standalone package that depends on Winter by path:

```bash
cd example/routing
dart pub get
dart run lib/crud.dart     # a case of a topic (an app: dart run lib/main.dart)
dart test                  # the tests of every case
```

# OpenAPI examples

The OpenAPI 3.1 document of the routes (`Route.openApi`) and Swagger UI (`Route.swaggerUi`), one
file per case. Each is a server of its own: `dart run lib/<case>.dart`, then open
http://localhost:8080/docs (`/api/v1/docs` in `documented_api`). The tests check the document of
each one in memory: `dart test`.

| Case | File | What it shows |
|------|------|---------------|
| Automatic | [`automatic.dart`](lib/automatic.dart) | Without any `RouteDocs`: paths, typed path params (`integer`, `pattern`), the security of an `AuthFilter` (401/403, Bearer), the 429 of a rate limit, the health check, the Problem Details errors |
| From examples | [`from_examples.dart`](lib/from_examples.dart) | The bodies from an example: the schema inferred from its JSON, the rules of `validate()` as `required`, `minLength`, `format`, `exclusiveMinimum`, `enum`; a list response; `responses: {409: '...'}` |
| Hand written | [`hand_written.dart`](lib/hand_written.dart) | `JsonSchema` by hand: optional, nullable, enums, a map; `QueryParam`s; the body of an error of your own |
| `BodyDocs` | [`body_docs.dart`](lib/body_docs.dart) | A schema and an example together, a JSON example with `rulesFrom:` a model without `toJson()`, a description, another content type, `RouteDocs.none` |
| A documented API | [`documented_api.dart`](lib/documented_api.dart) | A `basePath`, groups with tags (`Route.parent` with `docs`), an admin group with its security, `servers`, and "Authorize" in Swagger |
| Export the document | [`export_document.dart`](lib/export_document.dart) | `OpenApi(...).toJson()` without a server, written to `openapi.json` for a client generator |

```bash
dart run lib/documented_api.dart
curl localhost:8080/api/v1/openapi.json
```

Guide: [OpenAPI](../../doc/openapi.md).

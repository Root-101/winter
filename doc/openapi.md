# OpenAPI

Winter writes the OpenAPI 3.1 document of your routes, serves it as JSON and shows it in Swagger
UI. What it can find by itself (paths, params, security, errors) needs nothing; the bodies come from
an **example** of each model (its schema and the rules of its `validate()` are inferred from it), or
from a **schema written by hand** where you want more precision, or from both.

- `Route.openApi(openApi: OpenApi(...))` serves `GET /openapi.json`; `Route.swaggerUi()` serves
  `GET /docs`.
- `RouteDocs` on a route says what Winter can't find: a summary, tags, the query params, the
  bodies.
- An example is written by the object mapper, like a response: its schema always matches what the
  API sends, and the rules of `validate()` become `required`, `format`, `minLength`, `minimum`,
  `enum`... nothing is written twice.

Examples, one file per case: [`example/openapi`](../example/openapi).

## Minimal example

```dart
final router = WinterRouter(
  routes: [
    Route.post(
      path: '/users',
      handler: createUser,
      docs: RouteDocs(
        summary: 'Create a user',
        tags: ['users'],
        status: 201,
        request: CreateUser(name: 'Ann Lee', email: 'ann@example.com', age: 30),
        response: User(id: 7, name: 'Ann Lee', email: 'ann@example.com'),
      ),
    ),
  ],
);
router
  ..addRoute(Route.openApi(openApi: OpenApi(title: 'Users API', version: '1.0.0')))
  ..addRoute(Route.swaggerUi()); // http://localhost:8080/docs

await Winter.start(router: router);
```

With `CreateUser` as it is in the app (a `toJson()` and its `validate()`):

```dart
@override
ConstraintValidatorContext validate() => ConstraintValidatorContext()
  ..field('name', name).notNull().notBlank()
  ..field('email', email).notNull().email()
  ..field('age', age).min(18);
```

the body of the request is documented as:

```yaml
requestBody:
  required: true
  content:
    application/json:
      schema:
        type: object
        required: [name, email]            # notNull()
        properties:
          name:  {type: string, minLength: 1}     # notBlank()
          email: {type: string, format: email}     # email()
          age:   {type: integer, minimum: 18}      # min(18)
      example: {name: Ann Lee, email: ann@example.com, age: 30}
```

## How it works

### What Winter finds by itself

For every route with a handler (not the hidden ones):

| From                                 | In the document                                         |
|--------------------------------------|---------------------------------------------------------|
| The method and the path              | the operation; `/users/{id\|[0-9]+}` is `/users/{id}`   |
| A path param `{id}`                  | a string param                                          |
| `{id\|[0-9]+}`, `{id\|\d+}`          | an integer param                                        |
| `{code\|[A-Z][A-Z]}` (another regex) | a string with `pattern: ^[A-Z][A-Z]$`                   |
| An `AuthFilter` that runs for it     | `security`, a 401 (and a 403 when it has `rules`)       |
| Its `challenge` (`Bearer`, `Basic`, `Cookie name="sid"`, `ApiKey header="X-API-Key"`, another scheme like `Digest`) | the security scheme (`bearerAuth`, `basicAuth`, `cookieAuth`, `apiKeyAuth` with `in: header`/`query`/`cookie`, `digestAuth`); one per kind, so two `Cookie` or `ApiKey` challenges with different names share the last one |
| A `RateLimiterFilter`                | a 429                                                   |
| A request body                       | a 400 and a 415                                         |
| A path param                         | a 400 and a 404                                         |
| A request that is `Validatable`      | a 422 with its violations                               |

The filters that run for a route are found the way the server finds them: the global ones and the
route's, and their `shouldFilter` is run with a request to that route, so a global `AuthFilter`
that skips `/public` doesn't mark `/public` as protected. The errors are Problem Details
(`#/components/responses/...`), the format of every error of Winter.

`Route.health` is documented by itself (its `UP`/`DOWN` body and its 503). `Route.static` and
`Route.websocket` are left out (a tree of files, a WebSocket: not operations of an API); give them
`docs:` to show them. A path with a regex outside a param (`/files/.*`) can't be written in
OpenAPI and is left out.

### The bodies: four ways

A body of `RouteDocs` (`request`, `response` and the values of `responses`) can be:

**1. An example** (the usual one): an object, written by the object mapper (so its `toJson()` or
serializer must exist), or a JSON value. Its schema is inferred: types, nested objects, arrays (from
their first element) and dates (`date-time`). If it's `Validatable`, the rules of its `validate()`
become constraints, also the ones of the nested objects (`valid()`, `validEach()`).

```dart
request: CreateUser(name: 'Ann Lee', email: 'ann@example.com', age: 30),
response: [User(id: 7, name: 'Ann Lee')],   // a list of users
```

**2. A schema written by hand**, when the inferred one isn't precise enough (a field that may be
missing, an enum that `validate()` doesn't check, a format):

```dart
request: JsonSchema.object({
  'amount': JsonSchema.number(minimum: 0.01),
  'currency': JsonSchema.string(enumValues: ['EUR', 'USD']),
  'note': JsonSchema.string(maxLength: 200, nullable: true),
}, required: ['amount', 'currency']),
```

**3. Nothing**: the operation is documented without a body schema (its path, params, security and
errors still are).

**4. Both**, with `BodyDocs`: the schema wins, and the example is shown in Swagger (and its
"Try it out" is filled with it). `BodyDocs` also gives a description, another content type, or the
model whose rules apply when the example is plain JSON:

```dart
request: BodyDocs(
  schema: JsonSchema.object({'name': JsonSchema.string(), 'nickname': JsonSchema.string(nullable: true)}),
  example: {'nickname': null},
  description: 'Only the fields sent change',
),

// A model without toJson(): its JSON as the example, the model for its rules
request: BodyDocs(
  example: {'name': 'Ann Lee', 'email': 'ann@example.com'},
  rulesFrom: CreateUser(name: 'Ann Lee', email: 'ann@example.com', age: 30),
),
```

A JSON example (a `Map`) is taken as it is, like the object mapper takes a `Map`: write it with the
names the client sends (`full_name` with `FieldNaming.snakeCase`). An object is renamed by the
mapper.

In `responses`, a `String` is just the description of a status without a body:

```dart
responses: {
  409: 'The email is already registered',
  402: JsonSchema.object({'missing': JsonSchema.number()}),
},
```

### The rules of `validate()` in the schema

The rules are read without being evaluated (no rule runs, nothing has side effects; the
asynchronous ones of `validateAsync()` never run):

| Rule                                   | Constraint                                     |
|----------------------------------------|------------------------------------------------|
| `notNull()`                            | the field is in `required`                     |
| `notBlank()`                           | `minLength: 1`                                 |
| `notEmpty()`                           | `minLength`, `minItems` or `minProperties: 1`  |
| `size(min:, max:)`                     | `minLength`/`maxLength` (`minItems`... for a list) |
| `email()`, `url()`, `uuid()`           | `format: email`, `uri`, `uuid`                 |
| `pattern(...)`                         | `pattern` (a `RegExp` or a String)             |
| `min(n)`, `max(n)` (`inclusive: false`)| `minimum`, `maximum` (`exclusiveMinimum`...)   |
| `positive()`, `positiveOrZero()`...    | `exclusiveMinimum: 0`, `minimum: 0`...         |
| `oneOf(values)`, `isEnum(values)`      | `enum`                                         |
| `custom(...)`, `past()`, your own      | nothing (they can't be written in a schema)    |

A field the example doesn't have (a `null` dropped by `includeNulls: false`) gets no constraint:
give the example every field.

### `RouteDocs`

| Field         | What it says                                                        |
|---------------|---------------------------------------------------------------------|
| `summary`, `description` | a line, and more (Markdown)                              |
| `tags`        | the groups in Swagger; the children of a `Route.parent` with `docs` take its tags |
| `status`      | the status of success (200; 201 for a creation, 204 without body)   |
| `request`, `response` | the bodies (above)                                          |
| `responses`   | other statuses: `{409: 'Already registered'}`                       |
| `query`       | the query params the handler reads: `[QueryParam('page', JsonSchema.integer(minimum: 1))]` |
| `operationId` | an id for the clients generated from the document                   |
| `deprecated`, `hidden` | `RouteDocs.none` leaves a route out                         |

### Serving the document

```dart
router
  ..addRoute(Route.openApi(openApi: OpenApi(
      title: 'Users API',
      version: '1.0.0',
      description: 'Everything about users',
      servers: ['https://api.example.com'],
    )))
  ..addRoute(Route.swaggerUi(specUrl: '/openapi.json', title: 'Users API'));
```

- `OpenApi` documents the router of the running server; give it `router:` to document another one
  (or in a test). It's built by the first request to `/openapi.json`.
- With a `basePath`, the routes added with `addRoute` take it too: give Swagger the full URL
  (`Route.swaggerUi(specUrl: '/api/v1/openapi.json')`).
- Swagger UI is loaded by the browser from a CDN (unpkg), at a fixed version; its page allows it in
  its `Content-Security-Policy`. Protect both routes with `filterConfig:` if the document is not
  public.
- `OpenApi(...).toJson()` gives the document as a `Map`: write it to a file for a client generator.

## Common cases

### A list with a query param

```dart
Route.get(
  path: '/orders',
  handler: listOrders,
  docs: RouteDocs(
    summary: 'The orders, by page',
    query: [
      QueryParam('page', JsonSchema.integer(minimum: 1), description: 'From 1'),
      QueryParam('status', JsonSchema.string(enumValues: ['pending', 'paid'])),
    ],
    response: [Order.example()],
  ),
)
```

### A whole group with its tags

```dart
Route.parent(
  path: '/admin',
  filterConfig: FilterConfig([AuthFilter(rules: hasRole('admin'))]),
  docs: const RouteDocs(tags: ['admin']),
  routes: [...], // every child is in "admin", with its 401 and 403
)
```

### Testing the document

```dart
test('the API is documented', () {
  final document = OpenApi(title: 'API', version: '1', router: router).toJson();
  expect((document['paths'] as Map).keys, contains('/users/{id}'));
});
```

## Typical mistakes and limitations

- **An example without `toJson()`** is a `StateError` that says so when the document is built:
  give its JSON in `BodyDocs(example: {...}, rulesFrom: model)`.
- **A JSON example with the Dart names** (`fullName`) when the API uses `snakeCase`: a `Map` is
  never renamed; write the names the client sends.
- **A field missing from the example** has no schema and no constraint.
- **A param regex with `{}`** can't be in a route (`{code|[A-Z]{3}}`): write `[A-Z][A-Z][A-Z]`.
- The schema of a body is inferred per route: the same model in several routes is repeated, not a
  `$ref` (a `JsonSchema.raw({r'$ref': ...})` can point to a schema of your own).
- WebSockets and Server-Sent Events are not described by OpenAPI.

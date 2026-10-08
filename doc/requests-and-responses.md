# Requests and responses

A handler receives a `RequestEntity` and returns a `ResponseEntity`. Both are Winter's own types on
top of `dart:io`:

- The request is **read-only**: headers (case insensitive, with every value), cookies, path and
  query params with their type, and a body that is read once and cached by `body<T>()`.
- The response takes a **value** (`body: user`) and writes it as JSON, text, bytes or a stream,
  with its `Content-Type` and `Content-Length`.
- A filter changes either one with `copyWith`.

The decisions behind it are in [`DECISIONS.md` §11](../DECISIONS.md#11-from-shelf-to-dartio).

## Minimal example

```dart
import 'dart:io';

import 'package:winter/winter.dart';

void main() async {
  await Winter.start(
    router: WinterRouter(
      routes: [
        Route.post(
          path: '/sessions',
          handler: (request) async {
            final Login login = await request.body<Login>();
            return ResponseEntity.created(
              location: '/sessions/current',
              body: {'user': login.user},
              cookies: [Cookie('session', 'abc123')..secure = true],
            );
          },
        ),
        Route.get(
          path: '/users/{id}',
          handler: (request) => ResponseEntity.ok(
            body: {
              'id': request.pathParam<int>('id'),
              'page': request.queryParam<int>('page') ?? 1,
              'session': request.cookie('session')?.value,
              'language': request.headers['accept-language'],
            },
          ),
        ),
      ],
    ),
  );
}
```

## How it works

### The request

| Member                             | What it is                                                     |
|------------------------------------|----------------------------------------------------------------|
| `method`, `httpMethod`             | `GET` (always upper case), and as an `HttpMethod`              |
| `requestedUri`                     | The absolute URI, with its query                               |
| `headers`                          | One value per header, case insensitive (several are joined with `, `) |
| `headersAll`                       | Every value of each header (`headersAll['x-tag']` → `['a', 'b']`) |
| `cookies`, `cookie('name')`        | The `Cookie`s (of `dart:io`) of the `Cookie` header            |
| `pathParams`, `pathParam<T>()`     | The params of the route (see [routing](routing.md#path-params)) |
| `queryParams`, `queryParamsAll`, `queryParam<T>()` | The query (the last value, or every value)     |
| `mimeType`, `encoding`             | Of the `Content-Type` (`application/json`, its charset)        |
| `contentLength`                    | The `Content-Length`, if it's known                            |
| `clientIp()`, `connectionInfo`     | The client (see [security](security.md#rate-limiter))          |
| `context`                          | Data of this request for the filters (the security context, the route...) |
| `locale`, `securityContext`, `principal<T>()` | Extensions of i18n and security                     |

Every map is read-only: a filter that needs to change the request passes a copy to the chain (see
[`copyWith`](#copywith)).

### The body of a request

```dart
final CreateUser user = await request.body<CreateUser>();      // JSON → object, validated
final Map<String, dynamic> raw = await request.body<Map<String, dynamic>>();
final String text = await request.body<String>();
```

- `body<T>()` decodes the JSON with the object mapper and validates a `Validatable` (see
  [object mapper](object-mapper.md) and [validation](validation.md)). It caches the body: call it
  as many times as you want, with any `T`.
- The text is decoded with the charset of the `Content-Type` (UTF-8 without one).
- `read()` (the bytes) and `readAsString()` read the stream itself: once, and not after `body<T>()`.
- A body over `ServerConfig.maxBodySize` (10 MB) is a **413** when it's read; a body nobody reads
  is never rejected.

### The response

```dart
ResponseEntity.ok(body: user)                         // 200, JSON
ResponseEntity.created(location: '/users/7', body: user)
ResponseEntity.noContent()                            // 204, no body
ResponseEntity(418, body: 'I am a teapot', headers: {'X-Tea': 'green'})
```

The type of the body decides how it's written:

| `body`               | Written as                 | `Content-Type`                               |
|----------------------|----------------------------|----------------------------------------------|
| `null`               | Nothing                    | None                                         |
| `String`             | Text                       | `text/plain; charset=utf-8`                  |
| `Uint8List`          | Bytes                      | `application/octet-stream`                   |
| `Stream<List<int>>`  | As it's produced (chunked) | `application/octet-stream`                   |
| Anything else        | JSON (the object mapper)   | `application/json; charset=utf-8` (`application/problem+json` from 400) |

- A `Content-Type` in `headers` wins: `headers: {'content-type': 'text/html'}`.
- `Content-Length` is added for everything but a stream.
- `encoding:` changes the encoding of a text body and its charset.
- `body()` gives back the value (`user`), not the bytes.
- Several values of a header are a list: `headers: {'Link': ['<a>; rel=next', '<b>; rel=last']}`,
  and every cookie of `cookies:` is a `Set-Cookie` of its own.

The shortcuts: `ok`, `created`, `accepted`, `noContent`, and `badRequest`, `unauthorized`,
`forbidden`, `notFound`, `methodNotAllowed`, `tooManyRequests`, `internalServerError`. For an error,
throwing an `ApiException` gives a Problem Details (see [error handling](error-handling.md)).

### `copyWith`

Both types are changed with `copyWith`, which returns a new one:

```dart
final ResponseEntity response = await chain.doFilter(
  request.copyWith(headers: {'X-Forwarded-User': 'ann'}),
);
return response.copyWith(statusCode: 202, headers: {'X-Version': '2'});
```

- `headers` are added to the current ones; `null` removes one (`{'X-Debug': null}`).
- The request takes `context` (added too), a new `body` and a new `requestedUri`. Without a new
  body, the copy shares the one of the original: it's read once, and cached by `body<T>()` for both.
- The response takes `statusCode`, `body` (resolved again, with its `Content-Type`), `cookies`
  (added), `encoding` and `context`. Without a new body it's never serialized again.

### Server-Sent Events and other streams

```dart
Route.get(
  path: '/events',
  handler: (request) => ResponseEntity<Stream<List<int>>>(
    200,
    body: clock().map((time) => utf8.encode('data: $time\n\n')),
    headers: {'content-type': 'text/event-stream', 'cache-control': 'no-cache'},
  ),
)
```

Every chunk is sent as it's produced. `dart:io` sends the headers with the first chunk, so a stream
of events usually starts with one (or a comment, `: ok\n\n`). If the client leaves, or the stream
fails, the connection is closed and it's logged at debug: the server goes on.

### How a response is written

`HEAD`, `204` and `304` responses never have a body (a `HEAD` keeps the `Content-Length` of its
`GET`). Every response has a `Date`, and no `Server` nor `X-Powered-By` header. With
`ServerConfig(autoCompress: true)` a response is gzipped for a client that accepts it.

## Common cases

### A file

```dart
Route.get(
  path: '/report',
  handler: (request) => ResponseEntity<Stream<List<int>>>(
    200,
    body: File('report.pdf').openRead(),
    headers: {
      'content-type': 'application/pdf',
      'content-disposition': 'attachment; filename="report.pdf"',
    },
  ),
)
```

### Testing with a request in memory

```dart
final request = RequestEntity(
  'POST',
  Uri.parse('http://localhost/users'),
  headers: {'content-type': 'application/json', 'cookie': 'session=abc'},
  body: '{"name": "Ann"}',
);
```

`WinterTestClient` builds them for you; `TestResponse.headersAll`
has every value of each header.

## Typical mistakes and limitations

- **`read()` after `body<T>()`**: the stream is consumed; use `body<String>()`.
- **Changing `request.headers` or `queryParams`**: they are read-only; pass
  `request.copyWith(...)` to the chain.
- **A stream response without a first chunk**: the client waits for the headers until it comes.
- **A `List<int>` as a body**: it's JSON (`[1,2]`); bytes are a `Uint8List`.
- Forms (`application/x-www-form-urlencoded`), multipart and static files are not supported yet
  (phase 4 of the roadmap).

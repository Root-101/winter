# Requests and responses

A handler receives a `RequestEntity` and returns a `ResponseEntity`. Both are Winter's own types on
top of `dart:io`:

- The request is **read-only**: headers (case insensitive, with every value), cookies, path and
  query params with their type, and a body that is read once and cached by `body<T>()`.
- The response takes a **value** (`body: user`) and writes it as JSON, text, bytes or a stream,
  with its `Content-Type` and `Content-Length`.
- A filter changes either one with `copyWith`.

The decisions behind it are in [`DECISIONS.md` §10](../DECISIONS.md#10-the-http-layer).

Examples, one file per case: [`example/bodies`](../example/bodies).

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
| `route`                            | The `Route` that answers it (its `key`, its `path`), null without one |
| `context`                          | Data attached to the request, found by a typed `ContextKey` (see [below](#extending-a-request-the-context)) |
| `locale`, `securityContext`, `principal<T>()` | Extensions of i18n and security                     |

Every map is read-only: a filter that needs to change the request passes a copy to the chain (see
[`copyWith`](#copywith)).

### The body of a request

Every kind of body a client sends (the tabs of the **Body** of Postman) has its method:

| Body (Postman)           | `Content-Type`                       | Read with                                    |
|--------------------------|--------------------------------------|----------------------------------------------|
| none                     | —                                    | `body<T?>()` is `null`; `body<String>()` is `''` |
| raw > JSON, GraphQL      | `application/json`, `*/*+json`       | `body<T>()`: an object, validated            |
| raw > Text, XML, HTML, JavaScript, CSV | `text/plain`, `application/xml`, `text/html`... | `body<String>()`: the text as it came |
| x-www-form-urlencoded    | `application/x-www-form-urlencoded`  | `formData()` ([a form](#a-form))             |
| form-data                | `multipart/form-data`                | `formData()`, or `multipart()` for big files |
| binary                   | any (`image/png`, `application/pdf`, `application/octet-stream`) | `bytes()` (or `body<Uint8List>()`) |

```dart
final CreateUser user = await request.body<CreateUser>();      // JSON → object, validated
final Map<String, dynamic> raw = await request.body<Map<String, dynamic>>();
final Note? note = await request.body<Note?>();                // null without a body
final String xml = await request.body<String>();               // any text, as it came
final FormData form = await request.formData();                // urlencoded or form-data
final Uint8List image = await request.bytes();                 // binary, any Content-Type
```

- `body<T>()` decodes the JSON with the object mapper and validates a `Validatable` (see
  [object mapper](object-mapper.md) and [validation](validation.md)). Its `Content-Type` must be
  JSON, `text/plain` or none (a 415 otherwise), except for `body<String>()` and
  `body<Uint8List>()`, which read any body.
- `body<T>()`, `bytes()` and `formData()` read the body once and cache it: call them as many times
  as you want, even several of them.
- The text is decoded with the charset of the `Content-Type` (UTF-8 without one); bytes that are not
  text in it are a **400** (`The body is not valid utf-8 text`), never a 500.
- `read()` (the bytes as they arrive) and `readAsString()` read the stream itself: once, and not
  after the cached methods. `read()` is for a big body that goes to a file without being in memory.
- A body over `ServerConfig.maxBodySize` (10 MB) is a **413** when it's read; a body nobody reads
  is never rejected.

[`example/bodies`](../example/bodies) has a case for each kind, with the `curl` of each one.

### A form

An HTML `<form>` sends `application/x-www-form-urlencoded`, or `multipart/form-data` when it
uploads files. `formData()` reads both:

```dart
final FormData form = await request.formData();   // name=Ann+Lee&tag=a&tag=b&age=30
form['name'];                                     // 'Ann Lee' (or null)
form.fieldsAll['tag'];                            // ['a', 'b']
form.field<int>('age');                           // 30, typed like queryParam<T>
```

- `fields` has the last value of a repeated field, `fieldsAll` every value (several checkboxes).
- `field<T>(name, values:)` parses the same types as `queryParam<T>`: null if it's missing or
  empty, a **400** naming the field (never the value) if it isn't a `T`.
- Another `Content-Type`, or none, is a **415**; a malformed body is a **400**.
- It's cached like `body<T>()`, and the same 413 applies.

The files of a `multipart/form-data` form are in `files` (`filesAll` for `<input multiple>`):

```dart
final UploadedFile? photo = form.files['photo'];
photo?.filename;   // 'beach.png', as the client sent it
photo?.mimeType;   // 'image/png', as the client declared it
photo?.bytes;      // the content, a Uint8List
```

- A file input left empty (no name, no content) is not in `files`.
- **Never use `filename` as a path**: it can be `../../etc/passwd`. Save the file with a name of
  your own, and don't trust `mimeType` either: check the content if it matters.

### Big uploads: `multipart()`

`formData()` keeps the whole body in memory. To stream a big file to disk, read the parts as they
arrive:

```dart
await for (final MultipartPart part in request.multipart()) {
  if (part.isFile) {
    await part.read().pipe(File('uploads/${newId()}').openWrite());
  } else {
    fields[part.name!] = await part.readAsString();
  }
}
```

- Read each part (`read()`, `readAsBytes()`, `readAsString()`) before asking for the next one. A
  part you skip is discarded without keeping it, and can't be read later.
- `ServerConfig.maxBodySize` still applies (10 MB by default): raise it for big uploads.
- A malformed body, or one that ends early, is a **400** thrown where it's being read.
- Like `read()`, it consumes the body: once, and not after `body<T>()` or `formData()`.

### The response

```dart
ResponseEntity.ok(body: user)                         // 200, JSON
ResponseEntity.created(location: '/users/7', body: user)
ResponseEntity.noContent()                            // 204, no body
ResponseEntity.seeOther('/orders/7')                  // 303 + Location
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
- A header value is ASCII without line breaks (what `dart:io` can send): anything else is a **500**
  with the error logged, never a broken response nor a header injection. A file name with accents
  goes encoded: `'attachment; filename*=UTF-8\'\'${Uri.encodeComponent(name)}'`.
- Several values of a header are a list: `headers: {'Link': ['<a>; rel=next', '<b>; rel=last']}`,
  and every cookie of `cookies:` is a `Set-Cookie` of its own.

The shortcuts: `ok`, `created`, `accepted`, `noContent`; the redirects `redirect` (302),
`seeOther` (303), `temporaryRedirect` (307) and `permanentRedirect` (308), which take the
`Location`; and `badRequest`, `unauthorized`, `forbidden`, `notFound`, `methodNotAllowed`,
`conflict`, `unprocessableEntity`, `tooManyRequests`, `internalServerError`, `serviceUnavailable`
(`retryAfter:` in seconds, like `tooManyRequests`). A browser follows a 302 or a 303 with a `GET`;
a 307 or a 308 repeats the method and the body. For an error, throwing an `ApiException` gives a Problem Details (see [error handling](error-handling.md)).

### `copyWith`

Both types are changed with `copyWith`, which returns a new one:

```dart
final ResponseEntity response = await chain.doFilter(
  request.copyWith(headers: {'X-Forwarded-User': 'ann'}),
);
return response.copyWith(statusCode: 202, headers: {'X-Version': '2'});
```

- `headers` are added to the current ones; `null` removes one (`{'X-Debug': null}`).
- The request takes a new `body` and a new `requestedUri`; its `route` and the values of its
  `context` are kept. Without a new body, the copy shares the one of the original: it's read once,
  and cached by `body<T>()` for both.
- The response takes `statusCode`, `body` (resolved again, with its `Content-Type`), `cookies`
  (added) and `encoding`; the values of its `context` are kept. Without a new body it's never
  serialized again, and a body of text or bytes can be read again (`readAsString()`), so a filter
  can look at it; a stream only once.

### Extending a request: the context

A filter often finds something that the handler needs: the user of a token, the tenant of a
subdomain, the version of the API. It's saved in the `context` of the request, under a typed
`ContextKey`, and read through an extension, so the rest of the code sees a normal property.

It's how Winter itself adds the security to the request:

```dart
// lib/src/security/request_security_context.dart (Winter)
final ContextKey<RequestSecurityContext> _securityContextKey =
    ContextKey<RequestSecurityContext>('winter.security');

extension RequestSecurityContextX on RequestEntity {
  RequestSecurityContext get securityContext => context.putIfAbsent(
    _securityContextKey,
    RequestSecurityContext<dynamic>.empty,
  );
}
```

The same for data of your app, a tenant read from the subdomain:

```dart
class Tenant {
  final String id;

  const Tenant(this.id);
}

/// The key: private to this file, so nobody else reads or overwrites it
final ContextKey<Tenant> _tenantKey = ContextKey<Tenant>('tenant');

/// The extension: `request.tenant` everywhere, with its type
extension TenantX on RequestEntity {
  Tenant? get tenant => context.get(_tenantKey);
  set tenant(Tenant? value) => context.set(_tenantKey, value);
}

/// The filter that sets it, before the handler
class TenantFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) async {
    final String host = request.requestedUri.host; // acme.example.com
    if (!host.contains('.')) throw const BadRequestException(detail: 'No tenant');
    request.tenant = Tenant(host.split('.').first);
    return chain.doFilter(request);
  }
}

// The handler
Route.get(
  path: '/projects',
  handler: (request) => ResponseEntity.ok(body: projects.of(request.tenant!.id)),
)
```

- A `ContextKey` is an object, not a name: two packages that both call their key `'tenant'` never
  overwrite each other, and `get` returns the type of the key, without casts.
- `context.get(key)`, `context.set(key, value)` (`null` removes it), `context.putIfAbsent(key,
  create)` (created the first time, like the security context) and `context.contains(key)`.
- A copy of the request (`copyWith`) starts with the same values; a value set on the copy (by a
  later filter) isn't seen by the original.
- A response has a `context` too, for a filter that marks a response for an outer filter.
- Code that doesn't receive the request (a service) reads the request scope instead:
  `requestPrincipal<T>()`, `requestLocale`, `requestId`.

### Server-Sent Events

A stream of events from the server to the browser (notifications, progress, a live feed) over a
normal HTTP response. `ResponseEntity.sse` sends a `Stream<ServerSentEvent>`:

```dart
Route.get(
  path: '/orders/events',
  handler: (request) => ResponseEntity.sse(
    orders.changes.map(
      (order) => ServerSentEvent.json(order, event: 'order', id: '${order.version}'),
    ),
  ),
)
```

```js
// In the browser
const events = new EventSource('/orders/events');
events.addEventListener('order', (event) => render(JSON.parse(event.data)));
```

What goes through the connection:

```text
:

event: order
id: 7
data: {"id":42,"status":"paid"}

:
```

`ServerSentEvent` builds each event:

| Code                                              | Sent                                            |
|---------------------------------------------------|-------------------------------------------------|
| `ServerSentEvent(data: 'Hello')`                  | `data: Hello` (an `onmessage` in the browser)   |
| `ServerSentEvent(data: 'a\nb')`                   | `data: a` and `data: b` (the client joins them) |
| `ServerSentEvent(event: 'order', data: ...)`      | `event: order` (`addEventListener('order')`)    |
| `ServerSentEvent(id: '42', ...)`                  | `id: 42`, sent back in `Last-Event-ID` on reconnect |
| `ServerSentEvent(retry: Duration(seconds: 5))`    | `retry: 5000`: how long the client waits to reconnect |
| `ServerSentEvent.json(order, event: 'order')`     | the data as JSON in one line, by the object mapper |
| `ServerSentEvent.comment('note')`                 | `: note`, ignored by the client                 |

- **Headers**: `Content-Type: text/event-stream; charset=utf-8`, `Cache-Control: no-cache` and
  `X-Accel-Buffering: no` (nginx would buffer the events otherwise).
- **At once**: a comment is sent first, so the browser gets the headers (and its `open` event)
  without waiting for the first event.
- **Keep-alive**: a comment every `keepAlive` (15 seconds by default; `null` for none) without
  events, so a proxy doesn't close the connection as idle.
- **The client leaves**: the subscription to your stream is cancelled; free what it uses in its
  `onCancel` (`StreamController(onCancel: ...)`), or use a broadcast stream.
- **The server shuts down**: the streams end when `Winter.close`/`shutdown` starts, so an endless
  stream never holds the graceful shutdown; the browser reconnects by itself (to another
  instance). An error of your stream is logged and ends it.
- **Reconnecting**: read the last id the client got with
  `request.headers[HttpHeader.lastEventId]` and send what it missed.
- `event` and `id` can't have a line break (it would start another event): an `ArgumentError`.

[`example/realtime`](../example/realtime) has a countdown that resumes from `Last-Event-ID`, and
`example/apps/files_gallery` sends every new photo to the open pages this way.

### Other streams

Any `Stream<List<int>>` body is sent as it's produced (chunked), with `application/octet-stream`
unless you give a `Content-Type`. `dart:io` sends the headers with the first chunk. If the client
leaves, or the stream fails, the connection is closed and it's logged at debug: the server goes
on.

### How a response is written

The status line has the reason phrase of `StatusCode` (`HTTP/1.1 422 Unprocessable Entity`).
`HEAD`, `204` and `304` responses never have a body (a `HEAD` keeps the `Content-Length` of its
`GET`). Every response has a `Date`, and no `Server` nor `X-Powered-By` header. With
`ServerConfig(autoCompress: true)` a response is gzipped for a client that accepts it.

## Common cases

### A file

To serve the files of a folder (with `ETag`, 304 and `Range`), use `Route.static` or
`StaticFiles` ([routing](routing.md#static-files)). A single generated file:

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

- **`read()` after `body<T>()`** (or `formData()`): the stream is consumed; use `body<String>()`.
- **Collecting the parts of `multipart()` to read them later** (`toList()`): each part must be read
  before the next one arrives; use `formData()` to have every file at once.
- **Changing `request.headers` or `queryParams`**: they are read-only; pass
  `request.copyWith(...)` to the chain.
- **A stream response without a first chunk**: the client waits for the headers until it comes.
- **A `List<int>` as a body**: it's JSON (`[1,2]`); bytes are a `Uint8List`.
- Forms (`application/x-www-form-urlencoded`), multipart and static files are not supported yet
  (phase 4 of the roadmap).

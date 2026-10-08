# Error handling

Every error of a Winter app is answered the same way: a **Problem Details** (RFC 9457), sent as
`application/problem+json`.

```json
{ "type": "about:blank", "title": "Not Found", "status": 404, "detail": "User 42 not found" }
```

- Throw an `ApiException` (or one of its shortcuts, like `NotFoundException`) anywhere: in a
  handler, a service or a filter.
- Anything else that is thrown (an unknown `Exception`, an `Error` like a `StateError`) is a bug:
  it's logged and answered with a generic **500**, without any detail.
- The errors of Winter itself (no route, not authenticated, too many requests...) are exceptions
  too, so one `ExceptionHandler` formats all of them, and you can change any of them.

The decisions behind it are in [`DECISIONS.md` §4](../DECISIONS.md#4-exceptions-and-error-handling).

## Minimal example

```dart
import 'package:winter/winter.dart';

class UserService {
  final Map<int, String> _users = {1: 'Ann'};

  String find(int id) =>
      _users[id] ?? (throw NotFoundException(detail: 'User $id not found'));
}

void main() async {
  final service = UserService();

  await Winter.start(
    router: WinterRouter(
      routes: [
        Route.get(
          path: '/users/{id}',
          handler: (request) => ResponseEntity.ok(
            body: service.find(request.pathParam<int>('id')),
          ),
        ),
      ],
    ),
  );
}
```

`GET /users/7` answers `404`:

```json
{ "type": "about:blank", "title": "Not Found", "status": 404, "detail": "User 7 not found" }
```

## How it works

### Problem Details

| Member      | Content                                                                          |
|-------------|----------------------------------------------------------------------------------|
| `type`      | A URI that identifies the kind of problem; `about:blank` when the status says it all |
| `title`     | A short summary of the kind of problem: the reason phrase of the status (`Not Found`) |
| `status`    | The status code                                                                  |
| `detail`    | What happened this time, for the client. Only when there is one; never in a 500  |
| extensions  | Members of your own (`"violations"` in a 422, `"email"` below)                   |

The `title` is never translated: it's the standard reason phrase. What the user reads is the
`detail`, which your app writes in the language of the request (`t.users.notFound(id: id)`).

The names of the members of Winter are fixed, whatever the `fieldNaming` of the object mapper:
`requestId` (in a 500), `violations` and their `fieldName`, `message`, `code` and `params`. A
client reads the errors of every Winter app the same way. The **value** of `fieldName` does follow
`fieldNaming` (`first_name`): it's the name of the field the client sent. Your `extensions` keep
the names you give them.

### The errors and their status

| Thrown                                         | Status | `detail`                                   |
|------------------------------------------------|--------|--------------------------------------------|
| `ApiException` or a shortcut                   | Its own | Its `detail`                              |
| A body that is not valid JSON, or has the wrong shape (`DeserializationException`) | 400 | Where and why: `$.items[1].price: expected a number, got a string` |
| A body with a `Content-Type` that is not JSON  | 415    | The expected `Content-Type`                |
| A body bigger than `ServerConfig.maxBodySize`  | 413    | —                                          |
| A failed validation (`ValidationException`)    | 422    | — (the `violations` member, see [validation](validation.md)) |
| No route for the path (`NotFoundException`)    | 404    | —                                          |
| The path exists for other methods (`MethodNotAllowedException`) | 405 | — (the `Allow` header lists them) |
| `AuthFilter`: nobody authenticated / not allowed | 401 / 403 | —                                     |
| `RateLimiterFilter`: too many requests         | 429    | — (`Retry-After` and `X-RateLimit-*` headers) |
| `ResponseException(response)`                  | Its own | The response is sent as it is (not a Problem Details) |
| Anything else: any other `Exception`, any `Error` | 500 | — (logged with its stack trace, never sent) |

### The shortcuts

`ApiException(status, detail:, type:, title:, extensions:, headers:)` works for any status of
`StatusCode`. The common ones have a shortcut with the same parameters:

| Status | Exception                          | Status | Exception                          |
|--------|------------------------------------|--------|------------------------------------|
| 400    | `BadRequestException`              | 413    | `PayloadTooLargeException`         |
| 401    | `UnauthorizedException`            | 415    | `UnsupportedMediaTypeException`    |
| 403    | `ForbiddenException`               | 422    | `UnprocessableEntityException`, `ValidationException` |
| 404    | `NotFoundException`                | 429    | `TooManyRequestsException(retryAfter:)` |
| 405    | `MethodNotAllowedException(allowedMethods)` | 500 | `InternalServerErrorException`  |
| 409    | `ConflictException`                | 503    | `ServiceUnavailableException(retryAfter:)` |

Most of them are `const`: `throw const NotFoundException()`.

```dart
throw ApiException(
  StatusCode.conflict,
  detail: 'The email is already registered',
  type: 'https://api.example.com/errors/email-taken',
  extensions: {'email': email},
);
```

```json
{
  "email": "ann@example.com",
  "type": "https://api.example.com/errors/email-taken",
  "title": "Conflict",
  "status": 409,
  "detail": "The email is already registered"
}
```

An extension never replaces `type`, `title`, `status` nor `detail`.

### Where the errors are handled

The `ExceptionHandler` runs **inside** the filter chain, right where the error is thrown. So every
outer filter gets a response, not the error:

- `CorsFilter` adds its headers to the error too (a browser sees the 404 or the 500, not a CORS
  error).
- `LogsFilter` logs the error response with its status.
- A `catch` around `chain.doFilter(request)` in your filter never fires: the chain already turned
  the error into a response. Read `response.statusCode` instead.

Errors thrown before the chain (while routing) go to the same handler.

### The 500

Anything that is not one of the errors above is a bug of the server. `SimpleExceptionHandler`
logs it with its stack trace (`logger.error`, see `logUnhandledError`) and answers:

```json
{ "type": "about:blank", "title": "Internal Server Error", "status": 500 }
```

The message of the error, its type and its stack trace never reach the client. If a custom
`ExceptionHandler` throws itself, Winter logs both errors and answers the same 500.

## Configuration

### Your own exceptions: `on<T>()`

Register the answer for an exception of your app:

```dart
Winter.context.setUp(
  exceptionHandler: SimpleExceptionHandler()
    ..on<EmailTakenException>(
      (request, e) => ConflictException(detail: 'The email ${e.email} is taken'),
    )
    ..on<PaymentFailedException>(
      (request, e) => ResponseEntity(402, body: {'reason': e.reason}),
    ),
);
```

- The function returns an `ApiException` (sent as a Problem Details), a `ProblemDetails`, or a
  `ResponseEntity` (sent as it is).
- When several registered types match, **the most specific one wins**, whatever the order: with
  `on<Exception>` and `on<EmailTakenException>`, an `EmailTakenException` uses the second.
  Registering a type again replaces it.
- It works for the errors of Winter too: `on<NotFoundException>` changes the 404 of the router,
  `on<UnauthorizedException>` the 401 of `AuthFilter`.
- If the function throws, what it throws is answered by the default rules (never by the
  mappings again, so they can't loop).

### Inheritance

For more than a function per type, extend `SimpleExceptionHandler` and override `handle`, the
default rules (the mappings of `on()` still run first):

```dart
class MyExceptionHandler extends SimpleExceptionHandler {
  @override
  Future<ResponseEntity> handle(
    RequestEntity request,
    Object error,
    StackTrace stackTrace,
  ) async {
    // Answer it as another error: the default rules format it (headers included)
    final Object answered = error is TimeoutException
        ? ServiceUnavailableException(retryAfter: 5)
        : error;
    return super.handle(request, answered, stackTrace);
  }
}
```

To replace everything, implement `ExceptionHandler` (one method:
`call(RequestEntity request, Object error, StackTrace stackTrace)`). It receives `Exception`s and
`Error`s alike.

### Logging the 500

`SimpleExceptionHandler(logUnhandledError: (request, error, stackTrace) => ...)` replaces how the
unexpected errors are logged (by default `logger.error` with the method, the path and the stack
trace).

## Common cases

### A translated `detail`

```dart
AppMessages get t => appMessages(requestLocale); // a getter, never a final

throw NotFoundException(detail: t.orders.notFound(id: id));
```

The response gets `Vary: Accept-Language` by itself, since it depends on the language.

### `WWW-Authenticate`, `Retry-After` and other headers

```dart
throw const UnauthorizedException(headers: {'WWW-Authenticate': 'Bearer'});
throw ServiceUnavailableException(retryAfter: 30);
```

### A status that is not in `StatusCode`, or a body that is not a Problem Details

`throw ResponseException(ResponseEntity(299, body: ...))` ends the request with that response as
it is. Prefer an `ApiException`: clients can read every Problem Details the same way.

### Testing errors

```dart
final response = await client.get('/users/7');

expect(response.statusCode, 404);
expect(response.headers['content-type'], 'application/problem+json; charset=utf-8');
expect((response.json as Map)['detail'], 'User 7 not found');
```

Compare the decoded JSON, never the text: the responses are indented by default
(`ObjectMapper.prettyPrint`).

## Typical mistakes and limitations

- **Putting internal details in `detail`**: it goes to the client. An unexpected error should be
  thrown as it is (it's logged, and the client gets a 500 without details).
- **Catching an exception in a filter around `chain.doFilter`**: it never fires, the chain already
  answered. Check the status of the response.
- **`ApiException` only takes the statuses of `StatusCode`**: a custom code needs a
  `ResponseException`.
- **The 400 and the 422 name the fields differently on purpose**: the 400 has a JSON path in its
  `detail` (`$.items[1].price`, the JSON doesn't have the shape of the type: a bug of the client),
  the 422 a field name in each violation (`items[1].price`, the user typed an invalid value in a
  form).
- **The 401 has no `WWW-Authenticate`** unless you add it (planned for the security review).

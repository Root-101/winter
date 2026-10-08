# Object mapper

The `ObjectMapper` converts your objects to JSON (the bodies of the responses) and JSON back to
your objects (`request.body<T>()`). The global one is `om` (`Winter.context.objectMapper`).

- Objects with a `toJson()` method are serialized as they are: no interface to implement, so the
  models of `json_serializable` and `freezed` work out of the box.
- To read a type from a body, register a `Deserializer` once. `List<T>`, `Set<T>`,
  `Map<String, T>` and `T?` come with it.
- Deserialization is strict, and its errors are a 400 that says where the bad value is
  (`$.items[1].price: expected a number, got a string`) without exposing any detail of the server.

The decisions behind it (and why) are in [`DECISIONS.md` §2](../DECISIONS.md#2-object-mapper).

## Minimal example

```dart
import 'package:winter/winter.dart';

class User {
  final int id;
  final String name;

  User({required this.id, required this.name});

  factory User.fromJson(Map<String, dynamic> json) =>
      User(id: json['id'] as int, name: json['name'] as String);

  Map<String, Object?> toJson() => {'id': id, 'name': name};
}

void main() async {
  om.addDeserializer(Deserializer<User>.json(User.fromJson));

  await Winter.start(
    router: WinterRouter(
      routes: [
        Route.post(
          path: '/users',
          handler: (request) async {
            final User user = await request.body<User>();
            return ResponseEntity(201, body: user); // serialized with toJson()
          },
        ),
        Route.post(
          path: '/users/batch',
          handler: (request) async {
            final users = await request.body<List<User>>(); // no extra registration
            return ResponseEntity.ok(body: users);
          },
        ),
      ],
    ),
  );
}
```

## How it works

### Serialization (objects → JSON)

`ResponseEntity(body: object)` calls `om.encode(object)`. Every value is converted with the first
rule that applies:

| Value                                   | JSON                                                        |
|-----------------------------------------|-------------------------------------------------------------|
| `null`, `String`, `num`, `bool`         | As it is                                                    |
| `List`, any other `Iterable` (`Set`...) | An array, each element converted                            |
| `Map`                                   | An object, keys converted to `String`, values converted     |
| A type with a registered `Serializer`   | What the serializer returns, converted again                |
| A subtype of a type with a `Serializer` | The same (the first registered one that matches)            |
| An object with a `toJson()` method      | What `toJson()` returns, converted again                    |
| An enum without `toJson()`              | Its `name`                                                  |
| `DateTime` (default serializer)         | ISO-8601 **in UTC**: `2026-01-01T16:30:00.000Z`             |
| `Duration` (default serializer)         | Milliseconds (`5400000`), or ISO-8601, see `durationFormat` |
| Anything else                           | `MissingSerializerError` (500)                              |

Because the result of a `toJson()` or a serializer is converted again, a `toJson()` can return
`DateTime`s, enums and other objects without converting them itself:

```dart
Map<String, Object?> toJson() => {
  'id': id,
  'createdAt': createdAt, // DateTime → "2026-01-01T00:00:00.000Z"
  'status': status, // enum → "paid"
  'customer': customer, // another object → its toJson()
  'lines': lines, // List<Line> → [ ... ]
};
```

- `toJson()` is found dynamically, so it must be a method that takes no arguments. Which rule a
  class uses is decided the first time it's serialized and cached per `runtimeType`.
- `encode` works in a single pass: the `JsonEncoder` writes maps, lists and primitives itself and
  only asks the mapper for the objects. `om.serialize(object)` gives the JSON value (maps and
  lists) instead of the text.

### Deserialization (JSON → objects)

`request.body<T>()` calls `om.decode<T>(body)`: it decodes the JSON text and then converts the
value with the deserializer of `T`. `om.deserialize<T>(value)` does the second step only, for a
value that is already decoded.

Deserializers are found by the exact `Type` you ask for. These are registered by default:

| Type                         | Accepts                                                       |
|------------------------------|---------------------------------------------------------------|
| `String`                     | A JSON string                                                 |
| `int`                        | A number without decimals: `12` or `12.0`, never `12.5`       |
| `double`, `num`              | Any number                                                    |
| `bool`                       | `true` or `false`                                             |
| `DateTime`                   | Anything `DateTime.parse` accepts (with `Z`, an offset, or none) |
| `Duration`                   | Milliseconds, or ISO-8601, see `durationFormat`               |
| `Object`                     | Any value except `null`                                       |
| `dynamic`, `Object?`         | Any value, as it is                                           |
| `Map`, `Map<String, dynamic>` | A JSON object, as it is                                      |
| `List<dynamic>`              | A JSON array, as it is                                        |

Types are **strict**: `"12"` is not an `int` and `"true"` is not a `bool` (400). JSON has a single
number type, so `12.0` is a valid `int` and `1` a valid `double`.

#### Registering a deserializer

| Written in JSON as | Constructor                          | Example                                                       |
|--------------------|--------------------------------------|---------------------------------------------------------------|
| An object          | `Deserializer<T>.json(fromJson)`     | `Deserializer<User>.json(User.fromJson)`                      |
| A string           | `Deserializer<T>.string(fromString)` | `Deserializer<Uri>.string(Uri.parse)`                         |
| An integer         | `Deserializer<T>.integer(fromInt)`   | `Deserializer<Cents>.integer(Cents.new)`                      |
| A number           | `Deserializer<T>.number(fromNumber)` | `Deserializer<Ratio>.number(Ratio.new)`                       |
| A boolean          | `Deserializer<T>.boolean(fromBool)`  | `Deserializer<Flag>.boolean(Flag.new)`                        |
| An enum `name`     | `Deserializer<T>.enumByName(values)` | `Deserializer<Status>.enumByName(Status.values)`                      |
| Anything else      | `Deserializer<T>(fromAnyValue)`      | `Deserializer<Point>((data) => Point.fromList(data as List))` |

The typed constructors check the JSON type before calling your function, so a wrong one is a 400
that says what was expected (`$.url: expected a string, got an integer`). If your function throws
(`Uri.parse` with an invalid URI), the 400 is `invalid value` at the path of the value. With the
plain `Deserializer<T>(...)` constructor every failure is `invalid value`.

**Enums** are serialized by their `name` without registering anything, but reading one needs its
deserializer, since Dart can't list the values of an enum from its type:

```dart
om.addDeserializer(Deserializer<Status>.enumByName(Status.values));
// body<Status>(), List<Status>, Map<String, Status>...
// "refunded" → 400 $.status: expected one of pending, paid, got another string
```

The names are case sensitive, and the value sent by the client is never echoed in the message.
An enum with its own `toJson()` is written differently, so it needs its own deserializer.

#### Generic types

Registering `Deserializer<T>` also registers, derived from it:

- `T?`
- `List<T>`, `List<T>?` and `List<T?>`
- `Set<T>` and `Set<T>?`
- `Map<String, T>`, `Map<String, T>?` and `Map<String, T?>`

The default types have them too, so `body<List<int>>()` or `body<Map<String, DateTime>>()` need
nothing. Deeper types are registered explicitly, by building them from the deserializer of the
inner type with `list()`, `set()`, `map()` and `nullable()`. Their derived types come with them:

```dart
// List<List<User>>, Map<String, List<User>>, List<User>?... from List<User>
om.addDeserializer(Deserializer<User>.json(User.fromJson).list());

// The default deserializers are reached with deserializerOf<T>()
om.addDeserializer(om.deserializerOf<int>().list()); // Map<String, List<int>>...
```

An explicit registration wins over a derived one, and removing a deserializer
(`om.removeDeserializer<User>()`) removes its derived types.

### Errors

| Problem                                              | Exception                        | Response |
|------------------------------------------------------|----------------------------------|----------|
| The body is not valid JSON, or it's empty            | `DeserializationFormatException` | 400      |
| A value has the wrong type, a `fromJson` throws      | `DeserializationException`       | 400      |
| `Content-Type` that is not JSON (see below)          | `UnsupportedMediaTypeException`  | 415      |
| No deserializer for the type                         | `MissingDeserializerError`       | 500      |
| No serializer, `toJson()` nor enum for an object     | `MissingSerializerError`         | 500      |
| A serializer or a `toJson()` throws                  | `SerializationException`         | 500      |

The 400 is a Problem Details (see [error handling](error-handling.md)) whose `detail` is
`path: reason`, and it never contains a Dart type, a stack trace or a file path:

| Body                   | Asked for          | Message                                               |
|------------------------|--------------------|-------------------------------------------------------|
| `{"a":1,"b":"x"}`      | `Map<String, int>` | `$.b: expected an integer, got a string`              |
| `[{"name":"A"}, 1]`    | `List<User>`       | `$[1]: expected an object, got an integer`            |
| `[{"name":"A"}, {}]`   | `List<User>`       | `$[1]: invalid value`                                 |
| `{"first name": true}` | `Map<String, int>` | `$["first name"]: expected an integer, got a boolean` |
| `{"name": `            | `User`             | `The body is not valid JSON`                          |

The path goes as deep as the mapper walks the data itself (lists, maps, primitives). Inside your
`fromJson` it can't know which field failed, so the message is `invalid value` at the path of the
object. The original error is in `DeserializationException.cause` and is logged at `debug`.

A missing serializer or deserializer is a 500 on purpose: it's a bug of the server, not something
the client can fix. Its message (only in the logs) says how to register it.

### The `Content-Type` of the request

`body<T>()` reads the body as JSON when the `Content-Type` is `application/json`, any `*/*+json`
(`application/merge-patch+json`), `text/plain` or missing. Any other one (a form, multipart,
XML...) is a **415**.

`text/plain` is accepted because `package:http` and the browser's `fetch()` send it for a String
body when no header is given. `curl -d` sends `application/x-www-form-urlencoded`, so call it with
`-H 'Content-Type: application/json'`.

`body<String>()` is different: it decodes a JSON string (`"hello"` → `hello`) only when the
`Content-Type` is JSON, and returns the text as it is otherwise. It never answers 415.

## Configuration

Replace the global mapper at start-up (before `Winter.start`), or pass one to a single call:

```dart
Winter.context.setUp(
  objectMapper: ObjectMapper(
    serializers: [Serializer<Money>((money) => money.toString())],
    deserializers: [
      Deserializer<User>.json(User.fromJson),
      Deserializer<Money>.string(Money.parse),
    ],
    fieldNaming: FieldNaming.snakeCase,
  ),
);

final user = await request.body<User>(objectMapper: anotherMapper);
final response = ResponseEntity(200, body: user, objectMapper: anotherMapper);
```

| Option           | Default        | Effect                                                                      |
|------------------|----------------|-----------------------------------------------------------------------------|
| `includeNulls`   | `true`         | `false` drops the fields with a `null` value                                |
| `fieldNaming`    | `none`         | `snakeCase` (`user_id`) or `kebabCase` (`user-id`)                          |
| `durationFormat` | `milliseconds` | `iso8601`: `PT1H30M`, `-PT0.5S`, `P1DT2H` (hours are not grouped into days) |
| `prettyPrint`    | `true`         | `false` writes compact JSON, for smaller responses                          |

`includeNulls` and `fieldNaming` only apply to **objects**: the maps returned by a `toJson()` or a
serializer, and the map given to `Deserializer.json`. A `Map` you serialize or ask for directly
(`body<Map<String, int>>()`) holds data, so its keys are never renamed and its nulls are kept. The
errors of Winter (`ProblemDetails`, `ConstraintViolation`) keep their names too (see
[error handling](error-handling.md#problem-details)).

A response with a text body says its charset: `application/json; charset=utf-8` (and
`application/problem+json; charset=utf-8`, `text/plain; charset=utf-8`).

The responses are indented by default (`prettyPrint`), which makes them easy to read in a browser
or with curl. Turn it off when the size of the responses matters, and in tests compare the decoded
JSON (`jsonDecode(response.body)`) instead of the text.

## Common cases

### `json_serializable` and `freezed`

Their models have `toJson()` and `fromJson`, so they only need the deserializer:

```dart
om
  ..addDeserializer(Deserializer<Order>.json(Order.fromJson))
  ..addDeserializer(Deserializer<Customer>.json(Customer.fromJson));
```

Configure the names and the nulls in their annotations (`@JsonSerializable(fieldRename:
FieldRename.snake, includeIfNull: false)`), not in the mapper: `fieldNaming` would rename the keys
twice.

A `freezed` class is implemented by a private subclass (`_$OrderImpl`), so a
`Serializer<Order>`, if you register one, applies to it as a supertype.

### A type you don't own

Register a `Serializer` and a `Deserializer` for it:

```dart
om
  ..addSerializer(Serializer<Uri>((uri) => uri.toString()))
  ..addDeserializer(Deserializer<Uri>.string(Uri.parse));
```

A value that is not a string is a 400 `expected a string, got ...`, and an invalid URI (`Uri.parse`
throws) a 400 `invalid value`, both at the path of the value.

### Sealed classes and subtypes

A serializer of the base type applies to every subtype. For each class the mapper uses, in this
order: the serializer of its exact type, the first registered serializer of a supertype, and its
`toJson()`:

```dart
om.addSerializer(
  Serializer<Shape>(
    (shape) => switch (shape) {
      Circle(:final radius) => {'type': 'circle', 'radius': radius},
      Square(:final side) => {'type': 'square', 'side': side},
    },
  ),
);
```

Deserializers are never matched by subtype: `body<Shape>()` uses the deserializer of `Shape`,
which decides which subtype to build.

### Validation

A 400 means the body doesn't have the shape of the type. Rules about the values (a minimum, an
email...) are a 422 of the validation, see [validation](validation.md).

## Typical mistakes and limitations

- **Forgetting the type argument**: inside a list (`deserializers: [...]`) Dart infers the type
  from the list, not from the arguments: `Deserializer.json(User.fromJson)` is a
  `Deserializer<dynamic>` and `Deserializer.enumByName(Status.values)` a `Deserializer<Enum>`. Both
  are an `ArgumentError` when they are created, so it shows at start; always write the type:
  `Deserializer<User>.json(...)`, `Deserializer<Status>.enumByName(...)`.
- **Enums are not read automatically**: `body<Status>()` without
  `Deserializer<Status>.enumByName(Status.values)` is a `MissingDeserializerError` (500), even though
  writing them needs nothing.
- **Asking for a type that is not registered**, like `List<List<User>>` without registering
  `List<User>`, is a `MissingDeserializerError` (500), not a 400.
- **`deserialize` with JSON text**: `om.deserialize<User>('{"id":1}')` receives a String, not an
  object (400). Use `om.decode<User>(...)` for text.
- **A `toJson` with parameters** (`toJson({bool full = true})` works, `toJson(bool full)` doesn't)
  or a `toJson` getter is not used.
- **`fieldNaming` and acronyms**: `userID` is written `user_id` and read back as `userId`. Use
  camelCase names without acronyms.
- **`fieldNaming` inside a model**: a parent `fromJson` reads its children itself, so the whole
  object given to `Deserializer.json` is renamed, including the keys of a `Map` field inside it.
- **Map keys** must be serializable to a `String`, `num`, `bool` or `null` (an enum becomes its
  name). A `List` as a key is a `SerializationException`.
- **Only `Map<String, T>`** can be deserialized: JSON keys are always strings.
- **A serializer for `String`, `num`, `bool`, `List` or `Map`** is never used: they are written as
  they are.
- **Cost**: in the benchmark (`benchmark/object_mapper_benchmark.dart`, AOT) `om.encode` is
  ~1.1–1.2x the time of a hand-written `jsonEncode` of JSON-only maps, and `om.decode` ~1.0x of
  `jsonDecode` + `fromJson`.

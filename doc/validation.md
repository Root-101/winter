# Validation

Validation checks the **values** of a request (an email, a minimum, a date in the future) and
answers **422** with every violation, in the language of the request. It runs after the
[object mapper](object-mapper.md), which checks the **shape** (a string where a number was
expected is a 400).

- A model implements `Validatable` and lists its rules with `cvc.field(name, value)`.
- `request.body<T>()` validates it by default.
- The validators depend on the type of the value, so `.min(3)` on a String doesn't compile.
- Each violation has a `code` and `params` for clients that show their own texts.

The decisions behind it are in [`DECISIONS.md` §3](../DECISIONS.md#3-validation).

## Minimal example

```dart
import 'package:winter/winter.dart';

class CreateUser implements Validatable {
  final String? email;
  final String? password;
  final int? age;

  CreateUser({this.email, this.password, this.age});

  factory CreateUser.fromJson(Map<String, dynamic> json) => CreateUser(
    email: json['email'] as String?,
    password: json['password'] as String?,
    age: json['age'] as int?,
  );

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('email', email).notNull().email()
    ..field('password', password, sensitive: true).notNull().size(min: 8)
    ..field('age', age).min(18);
}

void main() async {
  om.addDeserializer(Deserializer<CreateUser>.json(CreateUser.fromJson));

  await Winter.start(
    router: WinterRouter(
      routes: [
        Route.post(
          path: '/users',
          handler: (request) async {
            final user = await request.body<CreateUser>(); // validated: 422 if invalid
            return ResponseEntity(201, body: {'email': user.email});
          },
        ),
      ],
    ),
  );
}
```

`POST /users` with `{"email": "x", "age": 16}` answers a Problem Details (like every error, see
[error handling](error-handling.md)) with the `violations`:

```json
{
  "violations": [
    { "fieldName": "email", "message": "The value is not a valid email", "code": "email" },
    { "fieldName": "password", "message": "The field cannot be null", "code": "notNull" },
    { "fieldName": "age", "message": "The minimum is 18", "code": "min.inclusive", "params": { "value": 18 } }
  ],
  "type": "about:blank",
  "title": "Unprocessable Entity",
  "status": 422
}
```

## How it works

### Fields and rules

`cvc.field(name, value)` starts the validation of a field and returns a `FieldValidator<T>`, where
`T` is the type of the value. Each validator chained on it **runs right away**, and a failure adds
a `ConstraintViolation` to the context.

`validate()` is usually written with cascades (`..field(...)`), one per field, as in the minimal
example. A block body with a `final cvc` works the same, and is clearer when a rule needs an `if`.

Every validator returns the same `FieldValidator<T>`, so the type is kept along the chain:
`field('count', 3).min(1).custom((count) => ...)` receives an `int`.

- Every validator except `notNull()` **passes on `null`**: an optional field is only checked when
  it has a value. Add `notNull()` first for a required one.
- A rule with `stopOnFailure: true` skips the next rules of **that field** (not of the others).
  `notNull()` stops by default, so `notNull().email()` never reports both.
- The order of the violations is the order of the rules.

### Validators

| Value                  | Validator                                       | Fails when                                      | `code`                         |
|------------------------|-------------------------------------------------|-------------------------------------------------|--------------------------------|
| Any                    | `notNull()`                                     | it's `null`                                     | `notNull`                      |
| Any                    | `oneOf(values)`                                 | it's not one of `values` (`==`)                 | `oneOf`                        |
| Any                    | `isEnum(values, resolver:)`                     | it's not the `name` (or the `resolver` value) of an enum value | `isEnum`        |
| Any                    | `custom((value) => message?)`                   | the function returns a message                  | the one you give, or none      |
| `String`               | `notBlank()`                                    | it's empty or only whitespace                   | `notBlank`                     |
| `String`               | `size(min:, max:)`                              | its length is out of the range (inclusive)      | `size.min`, `size.max`         |
| `String`               | `email()`                                       | it's not an email (`<input type="email">` rules, with a dot in the domain, at most 254 characters and 64 before the `@`) | `email` |
| `String`               | `pattern(regExpOrString)`                       | it has no match (anchor it with `^...$`)        | `pattern`                      |
| `String`               | `url(schemes: ['http', 'https'])`               | it's not an absolute URL with one of the schemes and a host, or it has whitespace | `url` |
| `String`               | `uuid(version:)`                                | it's not `8-4-4-4-12` hex digits (of the version, if given) | `uuid`             |
| `num`                  | `min(n, inclusive: true)`, `max(n, ...)`        | it's below / above `n` (or equal, when not inclusive) | `min.inclusive`, `min.exclusive`, `max.*` |
| `num`                  | `positive()`, `positiveOrZero()`                | it's `<= 0` / `< 0`                             | `positive`, `positiveOrZero`   |
| `num`                  | `negative()`, `negativeOrZero()`                | it's `>= 0` / `> 0`                             | `negative`, `negativeOrZero`   |
| `List`, `Set`, `Map`   | `size(min:, max:)`                              | its number of elements is out of the range      | `size.min`, `size.max`         |
| `List`, `Set`, `Map`   | `notEmpty()`                                    | it has no elements                              | `notEmpty`                     |
| `DateTime`             | `past()`, `pastOrPresent()`                     | it's not before now / it's after now            | `past`, `pastOrPresent`        |
| `DateTime`             | `future()`, `futureOrPresent()`                 | it's not after now / it's before now            | `future`, `futureOrPresent`    |
| A `Validatable`        | `valid()`                                       | its own `validate()` has violations             | the ones of its rules          |
| A list of `Validatable`| `validEach()`                                   | any element has violations                      | the ones of its rules          |

Every validator takes `message:` (your own text) and `stopOnFailure:`.

### The response: 422

`body<T>()` validates a `Validatable` body (and every element of a list of them, with its index:
`[1].email`) and throws a `ValidationException` when there is any violation. Outside a body, call
`cvc.throwOnFailure()` yourself (in a service, for example). The exception handler answers **422**
with a Problem Details whose `violations` member is the list of violations:

| Key         | Content                                                                 |
|-------------|-------------------------------------------------------------------------|
| `fieldName` | The name of the field, with its path when it's nested: `address.zip`, `items[0].quantity`. With `ObjectMapper(fieldNaming: snakeCase)` every name is converted (`home_address.zip_code`), so it's the name the client sent |
| `message`   | The text, in the language of the request (`Accept-Language`)            |
| `code`      | The validator, for the validators of Winter (the key of its text)       |
| `params`    | The parameters of the text, when there are: `{"value": 18}`, `{"values": ["S", "M"]}`. Only JSON values: an allowed value that is an object is sent as its text |

**The value that failed is never in the response**: the client knows what it sent, and repeating
it would put personal data and long texts back in the response. It's kept in
`ConstraintViolation.value` (for logs), except for a `sensitive` field, whose value is never
stored.

A partial update (PATCH) is usually a model of its own, whose fields are all optional: since every
validator except `notNull()` passes on `null`, only the fields that came are validated, and the
body is still validated by default:

```dart
class UpdateUser implements Validatable {
  final String? email;
  final int? age;

  UpdateUser({this.email, this.age});

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('email', email).email() // no notNull(): it may not come
    ..field('age', age).min(18);
}
```

`body<T>(validate: false)` reads a body without validating it at all.

### Nested objects and lists

```dart
@override
ConstraintValidatorContext validate() => ConstraintValidatorContext()
  ..field('address', address).notNull().valid() // address.zip
  ..field('items', items).notEmpty().validEach(); // items[0].quantity
```

`valid()` and `validEach()` call the `validate()` of the nested objects and prefix their
violations with the path. A `null` nested object or element is skipped (check it with `notNull()`).
For anything else, `cvc.merge(other.validate(), prefix: 'name')` merges a context by hand.

### Messages and languages

Without `message:`, the text is Winter's, in the language of the request: English and Spanish
today, see the i18n section of [`DECISIONS.md`](../DECISIONS.md#1-translated-messages-i18n). A
`message:` is used as it is, so translate it with the texts of your app:

```dart
AppMessages get t => appMessages(requestLocale); // a getter, never a final

cvc.field('product', product).notBlank(message: t.orders.productRequired);
```

The text is only built when the rule fails, so a valid request never reads the language (and
doesn't get a `Vary: Accept-Language`).

## Configuration

`ConstraintValidatorContext(clock: ...)` gives the current time to `past()`, `future()` and their
`OrPresent` versions (default `DateTime.now`). The objects validated with `valid()` and
`validEach()` use the same clock, so a test can fix it for the whole tree:

```dart
final cvc = ConstraintValidatorContext(clock: () => DateTime(2026, 1, 1));
cvc.field('booking', booking).valid(); // booking.date.future() compares with 2026-01-01
```

## Common cases

### Your own validator

Write a generic extension on the `FieldValidator` of the type it validates, and call `addRule`:

```dart
extension SlugValidator<T extends String?> on FieldValidator<T> {
  FieldValidator<T> slug({String? message}) => addRule(
    (value) => value == null || RegExp(r'^[a-z0-9-]+$').hasMatch(value),
    message: () => message ?? 'Only lowercase letters, digits and -',
    code: 'slug',
  );
}

cvc.field('slug', slug).notNull().slug();
```

- `<T extends String?> on FieldValidator<T>` (and returning `FieldValidator<T>`) keeps the exact
  type of the field along the chain, like the validators of Winter. With
  `on FieldValidator<String?>`, a validator chained after it would see a `String?`.
- `isValid` returns whether the value passes (pass on `null` like the validators of Winter).
- `message` is a function: it's only called when the rule fails, so it can read `requestLocale`.
- Give a `code` (and `params`) if clients need one.

For a one-off rule, `custom((value) => value == password ? null : 'The passwords differ')`.

### A rule that depends on several fields

Validate it on one of the fields with `custom`, which can read the others:

```dart
cvc.field('endDate', endDate).notNull().custom(
  (end) => end!.isAfter(startDate!) ? null : 'The end must be after the start',
  code: 'dateRange',
);
```

### Sensitive fields

`cvc.field('password', password, sensitive: true)` never stores the value in the violation, so it
can't appear in a log or in `toString()`. The response never has values anyway.

### Testing a model

`violationsOf(fieldName)` gives the violations of a field, in order:

```dart
test('the email must be valid', () {
  final violations = CreateUser(email: 'x', password: '12345678').validate();

  expect(violations.violationsOf('email').single.code, 'email');
  expect(violations.violationsOf('password'), isEmpty);
});
```

Compare the `code` instead of the `message`: it doesn't change with the language. For a date,
give the context a fixed `clock` (see [Configuration](#configuration)).

### Checks that need a database ("the email already exists")

`validate()` is synchronous. Check it in the service and throw a `ConflictException`, or a
`ValidationException` with your own `ConstraintViolation` to answer 422 like the rest. Asynchronous
validations are planned for 1.x (`DECISIONS.md` §3.8).

## Typical mistakes and limitations

- **A validator that doesn't compile**: the type of the value decides which validators exist.
  `cvc.field('age', ageText).min(18)` fails because `ageText` is a String; a `dynamic` value only
  has the validators for any type (`notNull`, `oneOf`, `isEnum`, `custom`). Give the field the
  type it has: `cvc.field<String?>('name', json['name'] as String?)`.
- **Building the context in a `static final`**: the messages are resolved when the rules run, so
  build the context inside `validate()`, once per call.
- **Forgetting `notNull()`**: every other validator passes on `null`.
- **Validating twice**: `body<T>()` already validates a `Validatable`; an extra
  `.validate().throwOnFailure()` in the handler is harmless but unnecessary.
- **`size()` uses the same text for Strings and collections**: "The minimum is 3" (characters or
  elements).
- **`fieldName` is a path without `$`** (`items[0].name`), while the 400 of the object mapper
  says `$.items[0].name` in its `detail`. On purpose: the 422 names a field of a form, the 400 a
  place of the JSON (see [error handling](error-handling.md)).

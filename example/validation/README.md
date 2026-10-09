# Validation examples

One file per case, each a server of its own: `dart run lib/<case>.dart` (port 8080). The tests run
each one in memory: `dart test`.

| Case | File | What it shows |
|------|------|---------------|
| Basic rules | [`basic_rules.dart`](lib/basic_rules.dart) | `notNull`, `notBlank`, `email`, `size`, `min`/`max`, `url`, a `sensitive` field, the 422 and `violationsOf` in a unit test |
| Nested objects | [`nested_objects.dart`](lib/nested_objects.dart) | `valid()` for an object, `validEach()` for a list and a map: `address.zipCode`, `items[1].quantity`, `prices["eur"].cents` |
| Custom rules | [`custom_rules.dart`](lib/custom_rules.dart) | A reusable validator (an extension with `addRule`), `custom` with a `code` and `params`, a rule over two fields, `oneOf` |
| Async rules | [`async_rules.dart`](lib/async_rules.dart) | `AsyncValidatable` and `cvc.check`: "the email is already registered", only after the synchronous rules pass |

```bash
curl -i localhost:8080/users -H 'Content-Type: application/json' -d '{"email": "x", "age": 16}'
```

Guide: [validation](../../doc/validation.md). The messages in other languages: [`../i18n`](../i18n).

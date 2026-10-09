# Object mapper examples

One file per case, each a server of its own: `dart run lib/<case>.dart` (port 8080). The tests run
each one in memory: `dart test`.

| Case | File | What it shows |
|------|------|---------------|
| Field naming | [`field_naming.dart`](lib/field_naming.dart) | `toJson()` with Dart names sent as snake_case, `includeNulls: false`, dates in UTC, enums by name, a `Map` never renamed |
| Typed fields | [`typed_fields.dart`](lib/typed_fields.dart) | `json.field<T>`, `json.object`, optional fields, a 400 that names the path (`$.phones[1].number`), 415 for another `Content-Type` |
| Adapters | [`adapters.dart`](lib/adapters.dart) | `JsonAdapter<Money>.string` and `JsonAdapter<Uri>`: both directions, `List<Money>` and `Map<String, Uri>` derived |
| Partial update | [`partial_update.dart`](lib/partial_update.dart) | `json.patch<T>` and `PatchValue`: absent keeps, `null` clears |
| Unknown fields | [`unknown_fields.dart`](lib/unknown_fields.dart) | `rejectUnknownFields`, and a type (a webhook) that keeps accepting anything |
| Sealed classes | [`sealed_classes.dart`](lib/sealed_classes.dart) | A `Serializer` of the base type and a `Deserializer` that picks the subtype by `type` |
| Generic types | [`generic_types.dart`](lib/generic_types.dart) | `List<T>` as the body, `Map<String, List<T>>` with `list()`, `mapWithKeys<int>` and `mapWithKeys<Enum>` |

```bash
curl -i localhost:8080/contacts -H 'Content-Type: application/json' -d '{"name": 1}'
```

Guide: [object mapper](../../doc/object-mapper.md).

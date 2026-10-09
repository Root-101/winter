# Orders app

An orders API with the object mapper and validation working together: nested DTOs, lists, a
`Map<String, T>`, a type with its own serializer, enums, snake_case JSON and a 422 that names every
invalid field the way the client sent it.

## Key Concepts

### 1. The object mapper of the app (`OrdersApp.objectMapper()`)
*   `fieldNaming: FieldNaming.snakeCase`: the models use `customerEmail`, the JSON `customer_email`.
*   `includeNulls: false`: an order without `deliver_on` doesn't write it.
*   `rejectUnknownFields: true`: a key that the `fromJson` never reads (`"is_paid": true`, a typo
    like `"emial"`) is a 400 `$.is_paid: unknown field`, against mass assignment.
*   `JsonAdapter<Money>.string` writes an amount as text (`"12.50 EUR"`) and reads it back, in one
    registration: `"12 euros"` is a 400.
*   `Deserializer<Shipping>.enumByName(Shipping.values)` reads an enum by name; the type is always
    written (inside a list Dart would infer `Enum`).
*   `Deserializer<CreateOrder>.json(CreateOrder.fromJson)`, with typed fields in the hand-written
    `fromJson`: `json.field<String>('customerEmail')`, `json.field<List<OrderItem>>('items')`,
    `json.field<DateTime?>('deliverOn')` (may be missing) and
    `json.object('shippingAddress', Address.fromJson)` for an object that isn't registered. A
    wrong field is a 400 that names it as the client sent it:
    `$.items[0].quantity: expected an integer, got a string`, `$.customer_email: missing`.

### 2. Nested validation (`CreateOrder.validate()`)
*   `.valid()` validates the nested `Address`, `.validEach()` every `OrderItem`.
*   `email()`, `pattern()`, `positive()`, `max()`, `notEmpty()`, `size()`, `future()` and a
    `custom()` rule with its own `code`.
*   `request.body<CreateOrder>()` validates the body: a failure is a 422 whose `fieldName`s follow
    the JSON (`shipping_address.zip_code`, `items[0].quantity`).

### 3. Typed params and responses
*   `request.pathParam<int>('id')` and `request.queryParam<int>('page')`: `/orders/abc` is a 400.
*   `request.queryParam('shipping', values: Shipping.values)`: an enum from the query, any case.
*   `ResponseEntity.created(location: ..., body: order)`.

### 4. Tests in memory (`test/orders_test.dart`)
`WinterTestClient` runs the whole pipeline without a port, with a new `OrderService` per test.

## How to Run

1. Installation: `dart pub get`.
2. Execution: `dart run lib/main.dart`.
3. Tests: `dart test`.

```bash
curl -X POST localhost:8080/orders -H 'content-type: application/json' -d '{
  "customer_email": "ann@example.com",
  "shipping_address": {"street": "Main St 1", "city": "Madrid", "zip_code": "28001"},
  "items": [{"product_id": "p-1", "quantity": 2, "unit_price": "12.50 EUR"}],
  "shipping": "express"
}'
```

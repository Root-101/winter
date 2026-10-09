/// Nested objects (`valid()`), lists (`validEach()`) and maps of them: each violation names its
/// path (`address.zipCode`, `items[1].quantity`, `prices["eur"]`).
///
/// Run: `dart run lib/nested_objects.dart`
library;

import 'package:winter/winter.dart';

class Address implements Validatable {
  final String street;
  final String zipCode;

  Address(this.street, this.zipCode);

  factory Address.fromJson(Map<String, dynamic> json) =>
      Address(json.field<String>('street'), json.field<String>('zipCode'));

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('street', street).notBlank()
    ..field('zipCode', zipCode).pattern(RegExp(r'^\d{5}$'));
}

class Item implements Validatable {
  final String product;
  final int quantity;

  Item(this.product, this.quantity);

  factory Item.fromJson(Map<String, dynamic> json) =>
      Item(json.field<String>('product'), json.field<int>('quantity'));

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('product', product).notBlank()
    ..field('quantity', quantity).positive().max(100);
}

class Price implements Validatable {
  final int cents;

  Price(this.cents);

  factory Price.fromJson(Map<String, dynamic> json) =>
      Price(json.field<int>('cents'));

  @override
  ConstraintValidatorContext validate() =>
      ConstraintValidatorContext()..field('cents', cents).positive();
}

class CreateOrder implements Validatable {
  final Address? address;
  final List<Item> items;

  /// A price per currency
  final Map<String, Price> prices;

  CreateOrder(this.address, this.items, this.prices);

  factory CreateOrder.fromJson(Map<String, dynamic> json) => CreateOrder(
    json.field<Address?>('address'),
    json.field<List<Item>>('items'),
    json.field<Map<String, Price>?>('prices') ?? const {},
  );

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    // notNull first: a missing address is one violation, not a crash
    ..field('address', address).notNull().valid()
    // The rules of the list itself, then the ones of each item
    ..field('items', items).notEmpty().size(max: 10).validEach()
    ..field('prices', prices).validEach();
}

ObjectMapper objectMapper() => ObjectMapper(
  deserializers: [
    Deserializer<CreateOrder>.json(CreateOrder.fromJson),
    Deserializer<Address>.json(Address.fromJson),
    Deserializer<Item>.json(Item.fromJson),
    Deserializer<Price>.json(Price.fromJson),
  ],
);

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/orders',
      handler: (request) async {
        final CreateOrder order = await request.body<CreateOrder>();
        return ResponseEntity.ok(body: {'items': order.items.length});
      },
    ),
  ],
);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}

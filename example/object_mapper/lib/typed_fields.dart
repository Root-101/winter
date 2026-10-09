/// A hand-written `fromJson` with typed fields (`json.field<T>`, `json.object`): a wrong value is a
/// 400 whose message names the exact path, never a Dart error.
///
/// Run: `dart run lib/typed_fields.dart`, then
/// `curl localhost:8080/contacts -H 'Content-Type: application/json' -d '{"name": 1}'`
library;

import 'package:winter/winter.dart';

class Phone {
  final String number;
  final bool primary;

  Phone(this.number, this.primary);

  factory Phone.fromJson(Map<String, dynamic> json) => Phone(
    json.field<String>('number'),
    json.field<bool?>('primary') ?? false,
  );

  Map<String, Object?> toJson() => {'number': number, 'primary': primary};
}

class Address {
  final String city;
  final String? zipCode;

  Address(this.city, this.zipCode);

  factory Address.fromJson(Map<String, dynamic> json) =>
      Address(json.field<String>('city'), json.field<String?>('zipCode'));

  Map<String, Object?> toJson() => {'city': city, 'zipCode': zipCode};
}

class Contact {
  final String name;
  final DateTime? birthday;
  final Address address;
  final List<Phone> phones;

  Contact(this.name, this.birthday, this.address, this.phones);

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    // Missing or not a string: `$.name: ...`
    json.field<String>('name'),
    // T? may be missing or null
    json.field<DateTime?>('birthday'),
    // An object of a class that isn't registered: errors at `$.address.city`
    json.object('address', Address.fromJson),
    // A list of a registered type: errors at `$.phones[1].number`
    json.field<List<Phone>?>('phones') ?? const [],
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'birthday': birthday,
    'address': address,
    'phones': phones,
  };
}

ObjectMapper objectMapper() => ObjectMapper(
  deserializers: [
    Deserializer<Contact>.json(Contact.fromJson),
    Deserializer<Phone>.json(Phone.fromJson),
  ],
);

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/contacts',
      handler: (request) async =>
          ResponseEntity.ok(body: await request.body<Contact>()),
    ),
  ],
);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}

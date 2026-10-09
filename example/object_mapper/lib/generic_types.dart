/// Collections as the body: lists and maps of a registered type come by themselves, deeper ones
/// are registered with `list()`/`map()`, and maps with keys that aren't strings with
/// `mapWithKeys<K>()`.
///
/// Run: `dart run lib/generic_types.dart`
library;

import 'package:winter/winter.dart';

enum Status { pending, paid }

class Item {
  final String name;
  final int quantity;

  Item(this.name, this.quantity);

  factory Item.fromJson(Map<String, dynamic> json) =>
      Item(json.field<String>('name'), json.field<int>('quantity'));
}

ObjectMapper objectMapper() {
  final mapper = ObjectMapper(
    deserializers: [
      // Also List<Item>, Set<Item>, Map<String, Item> and their nullable forms
      Deserializer<Item>.json(Item.fromJson),
      Deserializer<Status>.enumByName(Status.values),
    ],
  );
  return mapper
    // Map<String, List<Item>>, List<List<Item>>... from List<Item>
    ..addDeserializer(mapper.deserializerOf<Item>().list())
    // {"7": 2} -> Map<int, int>; {"paid": 3} -> Map<Status, int>
    ..addDeserializer(mapper.deserializerOf<int>().mapWithKeys<int>())
    ..addDeserializer(mapper.deserializerOf<int>().mapWithKeys<Status>());
}

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/items',
      handler: (request) async {
        final List<Item> items = await request.body<List<Item>>();
        return ResponseEntity.ok(body: {'units': _units(items)});
      },
    ),
    Route.post(
      path: '/items/by-box',
      handler: (request) async {
        final Map<String, List<Item>> boxes = await request
            .body<Map<String, List<Item>>>();
        return ResponseEntity.ok(
          body: {
            for (final MapEntry(:key, :value) in boxes.entries)
              key: _units(value),
          },
        );
      },
    ),
    Route.post(
      path: '/stock',
      handler: (request) async {
        final Map<int, int> stock = await request.body<Map<int, int>>();
        return ResponseEntity.ok(
          body: {'products': stock.keys.toList()..sort()},
        );
      },
    ),
    Route.post(
      path: '/orders/count',
      handler: (request) async {
        final Map<Status, int> counts = await request.body<Map<Status, int>>();
        return ResponseEntity.ok(body: {'paid': counts[Status.paid] ?? 0});
      },
    ),
  ],
);

int _units(List<Item> items) =>
    items.fold(0, (sum, item) => sum + item.quantity);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}

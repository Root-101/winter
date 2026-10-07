// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:winter/winter.dart';

/// Cost of the object mapper compared with doing it by hand, on a list of orders
/// (each one with a nested customer, a DateTime, an enum and a list of lines):
///
/// - encode: `om.encode(orders)` vs `jsonEncode` of a `toJson()` that already returns JSON values.
///   The mapper walks the result of `toJson()` again (DateTime, enums, nested objects), so it
///   does two passes.
/// - decode: `om.decode<List<Order>>` vs `jsonDecode` + `Order.fromJson`.
///
/// Run with: dart run benchmark/object_mapper_benchmark.dart
/// (or compile it with `dart compile exe` to measure AOT, the way a server runs)
void main() {
  const orderCount = 1000;
  const iterations = 300;

  final orders = [for (var i = 0; i < orderCount; i++) _order(i)];
  final animals = [for (var i = 0; i < orderCount; i++) _Dog('dog $i', i)];

  final withToJson = ObjectMapper(prettyPrint: false);
  final withSerializer = ObjectMapper(
    prettyPrint: false,
    serializers: [Serializer<Order>((order) => order.toJson())],
  );
  final withSupertype = ObjectMapper(
    prettyPrint: false,
    serializers: [
      Serializer<_Animal>((animal) => {'name': animal.name, 'age': animal.age}),
    ],
  );
  final withDeserializer = ObjectMapper(
    prettyPrint: false,
    deserializers: [Deserializer<Order>.json(Order.fromJson)],
  );

  final json = jsonEncode([for (final order in orders) order.toJsonValues()]);
  if (withToJson.encode(orders) != json) {
    throw StateError('The mapper and the baseline must write the same JSON');
  }

  print(
    '--- Object mapper benchmark ($orderCount orders, $iterations iterations) ---',
  );
  print('JSON size: ${(json.length / 1024).toStringAsFixed(0)} KB');
  print('');

  _compare(iterations, {
    'encode: jsonEncode(toJson()) by hand': () =>
        jsonEncode([for (final order in orders) order.toJsonValues()]),
    'encode: om.encode, toJson() called dynamically': () =>
        withToJson.encode(orders),
    'encode: om.encode, Serializer<Order>': () => withSerializer.encode(orders),
  });
  _compare(iterations, {
    'encode: jsonEncode of animals by hand': () => jsonEncode([
      for (final a in animals) {'name': a.name, 'age': a.age},
    ]),
    'encode: om.encode, Serializer of a supertype': () =>
        withSupertype.encode(animals),
  });
  _compare(iterations, {
    'decode: jsonDecode + fromJson by hand': () => [
      for (final e in jsonDecode(json) as List)
        Order.fromJson(e as Map<String, dynamic>),
    ],
    'decode: om.decode<List<Order>>': () =>
        withDeserializer.decode<List<Order>>(json),
  });
}

/// Measures every case [iterations] times and prints the time of one run, and its ratio to the
/// first case. The cases are interleaved in rounds, so they all run in the same state of the
/// process: measured one after the other, the later ones were up to 3x slower (the GC state, even
/// for the same code).
void _compare(int iterations, Map<String, Object? Function()> cases) {
  const rounds = 10;
  final perRound = iterations ~/ rounds;
  final elapsed = {for (final name in cases.keys) name: 0};

  for (final body in cases.values) {
    for (var i = 0; i < perRound; i++) {
      body();
    }
  }
  for (var round = 0; round < rounds; round++) {
    for (final MapEntry(key: name, value: body) in cases.entries) {
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < perRound; i++) {
        body();
      }
      elapsed[name] = elapsed[name]! + stopwatch.elapsedMicroseconds;
    }
  }

  final double baseline = elapsed.values.first / (perRound * rounds) / 1000;
  for (final MapEntry(key: name, value: micros) in elapsed.entries) {
    final double ms = micros / (perRound * rounds) / 1000;
    final ratio = name == cases.keys.first
        ? ''
        : ' (x${(ms / baseline).toStringAsFixed(2)})';
    print('${name.padRight(50)} ${ms.toStringAsFixed(3).padLeft(8)} ms$ratio');
  }
  print('');
}

enum Status { pending, paid }

class Customer {
  final String name;
  final String email;

  Customer(this.name, this.email);

  factory Customer.fromJson(Map<String, dynamic> json) =>
      Customer(json['name'] as String, json['email'] as String);

  Map<String, Object?> toJson() => {'name': name, 'email': email};
}

class Line {
  final String product;
  final int quantity;
  final double price;

  Line(this.product, this.quantity, this.price);

  factory Line.fromJson(Map<String, dynamic> json) => Line(
    json['product'] as String,
    json['quantity'] as int,
    (json['price'] as num).toDouble(),
  );

  Map<String, Object?> toJson() => {
    'product': product,
    'quantity': quantity,
    'price': price,
  };
}

class Order {
  final int id;
  final Customer customer;
  final DateTime createdAt;
  final Status status;
  final List<Line> lines;

  Order(this.id, this.customer, this.createdAt, this.status, this.lines);

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    json['id'] as int,
    Customer.fromJson(json['customer'] as Map<String, dynamic>),
    DateTime.parse(json['createdAt'] as String),
    Status.values.byName(json['status'] as String),
    [
      for (final line in json['lines'] as List)
        Line.fromJson(line as Map<String, dynamic>),
    ],
  );

  /// What a model usually returns: the mapper converts the DateTime, the enum and the objects
  Map<String, Object?> toJson() => {
    'id': id,
    'customer': customer,
    'createdAt': createdAt,
    'status': status,
    'lines': lines,
  };

  /// Only JSON values, ready for `jsonEncode` (the baseline)
  Map<String, Object?> toJsonValues() => {
    'id': id,
    'customer': customer.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'status': status.name,
    'lines': [for (final line in lines) line.toJson()],
  };
}

Order _order(int i) => Order(
  i,
  Customer('Customer $i', 'customer$i@example.com'),
  DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
  Status.values[i % Status.values.length],
  [for (var l = 0; l < 3; l++) Line('Product $l', l + 1, 9.99 * (l + 1))],
);

abstract class _Animal {
  final String name;
  final int age;

  _Animal(this.name, this.age);
}

class _Dog extends _Animal {
  _Dog(super.name, super.age);
}

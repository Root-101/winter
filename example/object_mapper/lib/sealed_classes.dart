/// A sealed class in JSON: one `Serializer` of the base type writes every subtype with a `type`,
/// and one `Deserializer` reads the `type` to build the right one.
///
/// Run: `dart run lib/sealed_classes.dart`
library;

import 'dart:math' as math;

import 'package:winter/winter.dart';

sealed class Shape {
  double get area;
}

class Circle extends Shape {
  final double radius;

  Circle(this.radius);

  @override
  double get area => math.pi * radius * radius;
}

class Square extends Shape {
  final double side;

  Square(this.side);

  @override
  double get area => side * side;
}

ObjectMapper objectMapper() => ObjectMapper(
  // A serializer of the base type applies to every subtype
  serializers: [
    Serializer<Shape>(
      (shape) => switch (shape) {
        Circle(:final radius) => {'type': 'circle', 'radius': radius},
        Square(:final side) => {'type': 'square', 'side': side},
      },
    ),
  ],
  // Deserializers are looked up by exact type: the one of Shape picks the subtype
  deserializers: [
    Deserializer<Shape>.json(
      (json) => switch (json.field<String>('type')) {
        'circle' => Circle(json.field<double>('radius')),
        'square' => Square(json.field<double>('side')),
        _ => throw const FormatException('unknown shape'),
      },
    ),
  ],
);

WinterRouter router() => WinterRouter(
  routes: [
    // List<Shape> comes with Deserializer<Shape>
    Route.post(
      path: '/shapes/largest',
      handler: (request) async {
        final List<Shape> shapes = await request.body<List<Shape>>();
        return ResponseEntity.ok(
          body: shapes.reduce((a, b) => a.area >= b.area ? a : b),
        );
      },
    ),
  ],
);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}

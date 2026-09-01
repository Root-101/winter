@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

import 'object_mapper_models.dart';

void main() {
  group('Mapper with serializers in constructor', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapper(
        serializers: [Serializer<Tool>((object) => object.toJson())],
        deserializers: [Deserializer<Tool>((j) => Tool.fromJson(j))],
      );
    });

    test('Serialize - Tool', () async {
      Tool object = Tool(name: 'Drill');
      Map<String, dynamic> expectedJson = {'NAME': 'Drill'};

      dynamic json = parser.serialize(object);

      expect(expectedJson, json);
    });

    test('Deserialize - Tool', () async {
      Map<String, dynamic> json = {'NAME': 'Drill'};
      Tool expectedObject = Tool(name: 'Drill');

      Tool object = parser.deserialize(json);

      expect(expectedObject, object);
    });

    test('Deserialize from JSON String - Tool', () async {
      String json = '{"NAME": "Drill"}';
      Tool expectedObject = Tool(name: 'Drill');

      Tool object = parser.deserialize<Tool>(json);

      expect(expectedObject, object);
    });

    //this is more to see if the serialize/deserialize create/return the same object,
    //but its related more to the logic of toJson/fromJson than the actually logic of object mapper
    test('Serialize/Deserialize consistency - Tool', () async {
      Map<String, dynamic> json = {'NAME': 'Drill'};
      Tool expectedObject = Tool(name: 'Drill');

      Tool object = parser.deserialize(json);

      expect(expectedObject, object);
    });

    test('serialize - null', () {
      expect(parser.serialize(null), isNull);
    });

    test('serialize - Map', () {
      Map<String, dynamic> map = {'key': 'value'};
      expect(parser.serialize(map), map);
    });
  });

  group('No serializer/deserializer', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapper();
    });

    test('No Serializer - Worker', () {
      Worker object = Worker(name: 'worker #1');

      expect(() => parser.serialize(object), throwsA(isA<StateError>()));
    });

    test('No Deserializer - Worker', () {
      Map<String, dynamic> json = {'name': 'workter #1'};

      expect(
        () => parser.deserialize<Worker>(json),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Serializable Interface', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapper(
        deserializers: [Deserializer<Gadget>((j) => Gadget.fromJson(j))],
      );
    });

    test('Serialize - Gadget (implements Serializable)', () {
      Gadget gadget = Gadget(id: 'G1');
      expect(parser.serialize(gadget), {'id': 'G1'});
    });

    test('Serialize List - Gadgets', () {
      List<Gadget> gadgets = [Gadget(id: 'G1'), Gadget(id: 'G2')];
      expect(parser.serialize(gadgets), [
        {'id': 'G1'},
        {'id': 'G2'},
      ]);
    });

    test('Deserialize - Gadget', () {
      Map<String, dynamic> json = {'id': 'G1'};
      expect(parser.deserialize<Gadget>(json), Gadget(id: 'G1'));
    });

    test('Deserialize from JSON String - Gadget', () {
      String jsonStr = '{"id": "G1"}';
      expect(parser.deserialize<Gadget>(jsonStr), Gadget(id: 'G1'));
    });
  });

  group('Collections and Primitives', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapper(
        serializers: [Serializer<Tool>((object) => object.toJson())],
        deserializers: [
          Deserializer<Tool>((j) => Tool.fromJson(j)),
          Deserializer<List<int>>((j) {
            return List.of(j).cast<int>();
          }),
        ],
      );
    });

    test('serializeList and deserializeList', () {
      List<Tool> tools = [Tool(name: 'A'), Tool(name: 'B')];
      dynamic json = parser.serialize(tools);

      expect(json, [
        {'NAME': 'A'},
        {'NAME': 'B'},
      ]);

      List<Tool> back = parser.deserialize<List<Tool>>(json);
      expect(back, tools);
    });

    test('Serialize List with non-serializable element throws StateError', () {
      List<dynamic> list = [Tool(name: 'A'), Worker(name: 'W')];
      expect(() => parser.serialize(list), throwsStateError);
    });

    group('Default parsers', () {
      test('DateTime', () {
        DateTime now = DateTime.now();
        expect(parser.serialize(now), now.toIso8601String());
        expect(
          parser.deserialize<DateTime>(now.toIso8601String()),
          DateTime.parse(now.toIso8601String()),
        );
      });

      test('Duration', () {
        Duration duration = const Duration(days: 1);
        expect(parser.serialize(duration), duration.inMilliseconds);
        expect(parser.deserialize<Duration>(duration.inMilliseconds), duration);
      });

      test('String', () {
        expect(parser.serialize('test'), 'test');
        expect(parser.deserialize<String>('test'), 'test');
      });

      test('num, int, double', () {
        expect(parser.serialize(123), 123);
        expect(parser.deserialize<int>('123'), 123);

        expect(parser.serialize(123.45), 123.45);
        expect(parser.deserialize<double>('123.45'), 123.45);
      });

      test('bool', () {
        expect(parser.serialize(true), true);
        expect(parser.deserialize<bool>('true'), true);
        expect(parser.deserialize<bool>(true), true);
      });

      test('dynamic', () {
        expect(parser.serialize('dynamic' as dynamic), 'dynamic');
        expect(parser.deserialize<dynamic>('dynamic'), 'dynamic');
        expect(parser.deserialize<dynamic>(123), 123);
      });

      test('Object', () {
        Object obj = 'object';
        expect(parser.serialize(obj), 'object');
        expect(parser.deserialize<Object>('object'), 'object');
      });

      test('Null', () {
        expect(parser.serialize(null), isNull);
        expect(parser.deserialize<Null>(null), isNull);
      });

      test('List of primitives', () {
        List<int> numbers = [1, 2, 3];
        expect(parser.serialize(numbers), [1, 2, 3]);
        expect(parser.deserialize<List<int>>(jsonDecode('[1, 2, 3]')), [
          1,
          2,
          3,
        ]);

        List<String> strings = ['a', 'b'];
        expect(parser.serialize(strings), ['a', 'b']);
        expect(parser.deserialize<List<String>>(['a', 'b']), ['a', 'b']);
      });

      test('List of List of primitives', () {
        List<List<int>> numbers = [
          [1],
          [2],
          [3],
        ];
        expect(parser.serialize(numbers), [
          [1],
          [2],
          [3],
        ]);
        expect(
          parser.deserialize<List<List<int>>>(jsonDecode('[[1], [2], [3]]')),
          [
            [1],
            [2],
            [3],
          ],
        );
      });

      test('List of default objects', () {
        DateTime now = DateTime.now();
        List<DateTime> dates = [now];
        expect(parser.serialize(dates), [now.toIso8601String()]);
        expect(parser.deserialize<List<DateTime>>([now.toIso8601String()]), [
          DateTime.parse(now.toIso8601String()),
        ]);
      });
    });
  });

  group('Advanced and Edge Cases', () {
    test('Overwriting default serializers/deserializers', () {
      final parser = ObjectMapper(
        serializers: [Serializer<DateTime>((d) => d.microsecondsSinceEpoch)],
        //with millis test fail for precision Expected: DateTime:<2026-06-21 21:17:08.399301> ---- Actual: DateTime:<2026-06-21 21:17:08.399>
        deserializers: [
          Deserializer<DateTime>((v) => DateTime.fromMicrosecondsSinceEpoch(v)),
        ],
      );

      final now = DateTime.now();
      final serialized = parser.serialize(now);
      expect(serialized, now.microsecondsSinceEpoch);
      expect(parser.deserialize<DateTime>(serialized), now);
    });

    test('Heterogeneous List serialization', () {
      final parser = ObjectMapper(
        serializers: [Serializer<Tool>((t) => t.toJson())],
      );
      // Gadget is Serializable, Tool has explicit Serializer
      final list = [Tool(name: 'Hammer'), Gadget(id: 'G1')];
      final result = parser.serialize(list);

      expect(result, isA<List>());
      final resultList = result as List;
      expect(resultList[0], {'NAME': 'Hammer'});
      expect(resultList[1], {'id': 'G1'});
    });

    test('Empty list serialization and deserialization', () {
      final parser = ObjectMapper();
      expect(parser.serialize([]), []);
      expect(parser.deserialize<List<int>>([]), []);
    });

    test('Nested objects (Serialization behavior)', () {
      final parser = ObjectMapper();
      final workshop = Workshop(
        name: 'Main',
        gadgets: [Gadget(id: 'G1')],
      );

      final result = parser.serialize(workshop);
      // Note: current implementation does NOT recursively serialize maps returned by toJson
      expect(result, {
        'name': 'Main',
        'gadgets': [Gadget(id: 'G1')],
      });
    });

    test('Deserialize num from numeric data', () {
      final parser = ObjectMapper();
      expect(parser.deserialize<num>(123), 123);
      expect(parser.deserialize<num>(123.45), 123.45);
      expect(parser.deserialize<num>('123.45'), 123.45);
    });

    test('Serialize list of maps', () {
      final parser = ObjectMapper();
      final list = [
        {'id': 1},
        {'id': 2},
      ];
      expect(parser.serialize(list), list);
    });

    test(
      'Serializer/Deserializer with explicit dynamic (triggers warning)',
      () {
        // This won't fail but will exercise the warning logic in constructor
        Serializer<dynamic>((obj) => obj);
        Deserializer<dynamic>((data) => data);
      },
    );
  });

  group('Exception Handling', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapper();
    });

    test('SerializationException - Serializer throws Exception', () {
      parser.addSerializer<Tool>(
        Serializer<Tool>((t) => throw Exception('Serialization failed')),
      );
      expect(
        () => parser.serialize(Tool(name: 'Hammer')),
        throwsA(isA<SerializationException>()),
      );
    });

    test('SerializationException - Serializer throws Error', () {
      parser.addSerializer<Tool>(
        Serializer<Tool>((t) => throw ArgumentError('Invalid argument')),
      );
      expect(
        () => parser.serialize(Tool(name: 'Hammer')),
        throwsA(isA<SerializationException>()),
      );
    });

    test('DeserializationException - Deserializer throws Exception', () {
      parser.addDeserializer<Tool>(
        Deserializer<Tool>((j) => throw Exception('Deserialization failed')),
      );
      expect(
        () => parser.deserialize<Tool>({'NAME': 'Hammer'}),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('DeserializationException - Deserializer throws Error', () {
      parser.addDeserializer<Tool>(
        Deserializer<Tool>((j) => throw ArgumentError('Invalid argument')),
      );
      expect(
        () => parser.deserialize<Tool>({'NAME': 'Hammer'}),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('DeserializationFormatException - Invalid JSON String', () {
      parser.addDeserializer<Tool>(Deserializer<Tool>((j) => Tool.fromJson(j)));
      expect(
        () => parser.deserialize<Tool>('invalid json'),
        throwsA(isA<DeserializationFormatException>()),
      );
    });

    test('StateError is rethrown when no serializer found', () {
      expect(() => parser.serialize(Worker(name: 'W')), throwsStateError);
    });

    test('StateError is rethrown when no deserializer found', () {
      expect(() => parser.deserialize<Worker>({}), throwsStateError);
    });
  });

  group('Add and Remove Serializers/Deserializers', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapper();
    });

    test('Add and remove Serializer', () {
      Tool tool = Tool(name: 'Hammer');

      // Should fail initially
      expect(() => parser.serialize(tool), throwsA(isA<StateError>()));

      // Add serializer
      parser.addSerializer<Tool>(Serializer<Tool>((t) => t.toJson()));
      expect(parser.serialize(tool), {'NAME': 'Hammer'});

      // Remove serializer
      parser.removeSerializer<Tool>();
      expect(() => parser.serialize(tool), throwsA(isA<StateError>()));
    });

    test('Add and remove Deserializer', () {
      Map<String, dynamic> json = {'NAME': 'Hammer'};

      // Should fail initially
      expect(() => parser.deserialize<Tool>(json), throwsA(isA<StateError>()));

      // Add deserializer
      parser.addDeserializer<Tool>(Deserializer<Tool>((j) => Tool.fromJson(j)));
      expect(parser.deserialize<Tool>(json), Tool(name: 'Hammer'));

      // Remove deserializer
      parser.removeDeserializer<Tool>();
      expect(() => parser.deserialize<Tool>(json), throwsA(isA<StateError>()));
    });
  });
}

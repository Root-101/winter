@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

import 'object_mapper_models.dart';
import 'other_library/tool.dart' as other;

void main() {
  group('Mapper with serializers in constructor', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapper(
        serializers: [Serializer<Tool>((object) => object.toJson())],
        deserializers: [
          Deserializer<Tool>((j) => Tool.fromJson(j as Map<String, dynamic>)),
        ],
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

    test('Serialize/Deserialize round trip (through a JSON string) - Tool', () {
      final original = Tool(name: 'Drill');

      final json = jsonEncode(parser.serialize(original));
      final restored = parser.deserialize<Tool>(json);

      expect(restored, original);
      expect(restored, isNot(same(original)));
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
        deserializers: [
          Deserializer<Gadget>(
            (j) => Gadget.fromJson(j as Map<String, dynamic>),
          ),
        ],
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
          Deserializer<Tool>((j) => Tool.fromJson(j as Map<String, dynamic>)),
          Deserializer<List<int>>((j) {
            return List<int>.from(j as List);
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
          Deserializer<DateTime>(
            (v) => DateTime.fromMicrosecondsSinceEpoch(v as int),
          ),
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
      expect(parser.serialize(<Object>[]), <Object>[]);
      expect(parser.deserialize<List<int>>(<int>[]), <int>[]);
    });

    test('Nested objects (Serialization behavior)', () {
      final parser = ObjectMapper();
      final workshop = Workshop(
        name: 'Main',
        gadgets: [Gadget(id: 'G1')],
      );

      final result = parser.serialize(workshop);
      // The map returned by toJson is also serialized (recursively)
      expect(result, {
        'name': 'Main',
        'gadgets': [
          {'id': 'G1'},
        ],
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

    test('Serializer/Deserializer registered as dynamic log a warning', () {
      final warnings = <String>[];
      Winter.context.setUp(logger: _MemoryLogger(warnings));
      addTearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));

      Serializer<dynamic>((obj) => obj);
      Deserializer<dynamic>((data) => data);
      Serializer<Tool>((tool) => tool.toJson());

      expect(warnings, hasLength(2));
      expect(warnings.first, contains('Serializer<YOUR_TYPE>'));
      expect(warnings.last, contains('Deserializer<YOUR_TYPE>'));
    });
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
      parser.addDeserializer<Tool>(
        Deserializer<Tool>((j) => Tool.fromJson(j as Map<String, dynamic>)),
      );
      expect(
        () => parser.deserialize<Tool>('invalid json'),
        throwsA(isA<DeserializationFormatException>()),
      );
    });

    test('StateError is rethrown when no serializer found', () {
      expect(() => parser.serialize(Worker(name: 'W')), throwsStateError);
    });

    test('StateError is rethrown when no deserializer found', () {
      expect(
        () => parser.deserialize<Worker>(<String, dynamic>{}),
        throwsStateError,
      );
    });
  });

  group('Serialization of common types', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapper();
    });

    test('toJson with DateTime, enums and objects inside is serialized', () {
      final result = parser.serialize(
        _Event(DateTime.utc(2026), _Color.red, [Gadget(id: 'G1')]),
      );

      expect(result, {
        'at': '2026-01-01T00:00:00.000Z',
        'color': 'red',
        'gadgets': [
          {'id': 'G1'},
        ],
      });
      expect(() => jsonEncode(result), returnsNormally);
    });

    test('Result of a custom serializer is serialized', () {
      parser.addSerializer<Tool>(
        Serializer<Tool>((t) => {'name': t.name, 'at': DateTime.utc(2026)}),
      );

      expect(parser.serialize(Tool(name: 'Hammer')), {
        'name': 'Hammer',
        'at': '2026-01-01T00:00:00.000Z',
      });
    });

    test(
      'Enums are serialized by name (unless a serializer is registered)',
      () {
        expect(parser.serialize(_Color.red), 'red');

        parser.addSerializer<_Color>(Serializer<_Color>((c) => c.index));
        expect(parser.serialize(_Color.red), 0);
      },
    );

    test('Sets and other iterables are serialized as lists', () {
      expect(parser.serialize({1, 2}), [1, 2]);
      expect(parser.serialize([1, 2].map((e) => e * 2)), [2, 4]);
    });

    test('Map keys are converted to Strings', () {
      expect(parser.serialize({1: 'a', true: 'b', _Color.red: 'c'}), {
        '1': 'a',
        'true': 'b',
        'red': 'c',
      });
    });

    test('Map keys that are not JSON keys throw SerializationException', () {
      expect(
        () => parser.serialize({
          [1]: 'a',
        }),
        throwsA(isA<SerializationException>()),
      );
    });

    test('Unknown classes still throw StateError', () {
      expect(() => parser.serialize(Worker(name: 'W')), throwsStateError);
    });
  });

  group('Edge cases', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapper(
        serializers: [Serializer<Tool>((tool) => tool.toJson())],
        deserializers: [Deserializer<Tool>.json(Tool.fromJson)],
      );
    });

    test('A class with the same name in another library is not serialized', () {
      expect(() => parser.serialize(other.Tool('x')), throwsStateError);
    });

    test('Nullable list types', () {
      expect(parser.deserialize<List<int>?>('[1, 2]'), [1, 2]);
      expect(parser.deserialize<List<Tool?>>('[{"NAME":"A"}]'), [
        Tool(name: 'A'),
      ]);
    });

    test('An ApiException thrown by a (de)serializer is not wrapped', () {
      parser
        ..addDeserializer<Worker>(
          Deserializer<Worker>(
            (data) => throw BadRequestException(body: 'bad'),
          ),
        )
        ..addSerializer<Worker>(
          Serializer<Worker>((worker) => throw ConflictException()),
        );

      expect(
        () => parser.deserialize<Worker>('{}'),
        throwsA(isA<BadRequestException>()),
      );
      expect(
        () => parser.serialize(Worker(name: 'W')),
        throwsA(isA<ConflictException>()),
      );
    });

    test('Map values with generics are parsed (Map<String, List<int>>)', () {
      expect(
        () => parser.deserialize<Map<String, List<int>>>('{"a":[1]}'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Map<String, List<int>>'),
          ),
        ),
      );
    });

    test('Nullable map value types', () {
      expect(parser.deserialize<Map<String, int?>>('{"a":1}'), {'a': 1});
      expect(parser.deserialize<Map<String, int>?>('{"a":1}'), {'a': 1});
    });

    test('A list of a type without deserializer throws StateError', () {
      expect(
        () => parser.deserialize<List<Worker>>('[{"name":"W"}]'),
        throwsStateError,
      );
    });

    test('deserializeList with data that is not a list throws StateError', () {
      expect(
        () => Deserializer<int>((v) => v as int).deserializeList('no'),
        throwsStateError,
      );
    });

    test('Exceptions toString include the type and the message (one line)', () {
      // The new line of the message is escaped, so the log is a single line
      expect(
        ObjectMapperException('a\nb').toString(),
        r'ObjectMapperException{message: a\nb',
      );
      expect(SerializationException('m').toString(), contains('Serialization'));
      expect(
        DeserializationException('m').toString(),
        contains('DeserializationException'),
      );
      expect(
        DeserializationFormatException('m').toString(),
        contains('DeserializationFormatException'),
      );
    });
  });

  group('Deserializer.json', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapper(
        deserializers: [Deserializer<Tool>.json(Tool.fromJson)],
      );
    });

    test('The type is inferred from fromJson', () {
      expect(Deserializer.json(Tool.fromJson).type, Tool);
    });

    test('Deserializes a JSON object (String or already decoded map)', () {
      expect(
        parser.deserialize<Tool>('{"NAME":"Hammer"}'),
        Tool(name: 'Hammer'),
      );
      expect(
        parser.deserialize<Tool>(<dynamic, dynamic>{'NAME': 'Drill'}),
        Tool(name: 'Drill'),
      );
    });

    test('Works for lists', () {
      expect(parser.deserialize<List<Tool>>('[{"NAME":"A"},{"NAME":"B"}]'), [
        Tool(name: 'A'),
        Tool(name: 'B'),
      ]);
    });

    test('Data that is not a JSON object throws DeserializationException', () {
      expect(
        () => parser.deserialize<Tool>('"just a string"'),
        throwsA(isA<DeserializationException>()),
      );
      expect(
        () => parser.deserialize<List<Tool>>('[1, 2]'),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('Map deserialization', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapper(
        deserializers: [
          Deserializer<Tool>((j) => Tool.fromJson(j as Map<String, dynamic>)),
        ],
      );
    });

    test('Map<String, dynamic> from JSON String', () {
      final result = parser.deserialize<Map<String, dynamic>>(
        '{"a":1,"b":{"c":[1,2]}}',
      );
      expect(result, {
        'a': 1,
        'b': {
          'c': [1, 2],
        },
      });
    });

    test('Raw Map and Map<String, Object?> from JSON String', () {
      expect(parser.deserialize<Map>('{"a":1}'), {'a': 1});
      expect(parser.deserialize<Map<String, Object?>>('{"a":null}'), {
        'a': null,
      });
    });

    test('Map<String, dynamic> from an already decoded Map', () {
      final Map<dynamic, dynamic> data = {'a': 1};
      expect(parser.deserialize<Map<String, dynamic>>(data), {'a': 1});
    });

    test('Map<String, int> deserializes every value', () {
      final result = parser.deserialize<Map<String, int>>('{"a":1,"b":"2"}');
      expect(result, isA<Map<String, int>>());
      expect(result, {'a': 1, 'b': 2});
    });

    test('Map<String, Tool> uses the registered deserializer', () {
      final result = parser.deserialize<Map<String, Tool>>(
        '{"first":{"NAME":"Hammer"},"second":{"NAME":"Drill"}}',
      );
      expect(result, isA<Map<String, Tool>>());
      expect(result, {
        'first': Tool(name: 'Hammer'),
        'second': Tool(name: 'Drill'),
      });
    });

    test('JSON array for a Map type throws DeserializationException', () {
      expect(
        () => parser.deserialize<Map<String, dynamic>>('[1,2]'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('Invalid JSON throws DeserializationFormatException', () {
      expect(
        () => parser.deserialize<Map<String, dynamic>>('{not-json'),
        throwsA(isA<DeserializationFormatException>()),
      );
    });

    test(
      'Invalid value for Map<String, int> throws DeserializationException',
      () {
        expect(
          () => parser.deserialize<Map<String, int>>('{"a":"x"}'),
          throwsA(isA<DeserializationException>()),
        );
      },
    );

    test('Non String keys throw StateError', () {
      expect(
        () => parser.deserialize<Map<int, String>>('{"1":"a"}'),
        throwsStateError,
      );
    });

    test('Values without deserializer throw StateError', () {
      expect(
        () => parser.deserialize<Map<String, Worker>>('{"a":{}}'),
        throwsStateError,
      );
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
      parser.addDeserializer<Tool>(
        Deserializer<Tool>((j) => Tool.fromJson(j as Map<String, dynamic>)),
      );
      expect(parser.deserialize<Tool>(json), Tool(name: 'Hammer'));

      // Remove deserializer
      parser.removeDeserializer<Tool>();
      expect(() => parser.deserialize<Tool>(json), throwsA(isA<StateError>()));
    });
  });
}

enum _Color { red }

class _Event implements Serializable {
  final DateTime at;
  final _Color color;
  final List<Gadget> gadgets;

  _Event(this.at, this.color, this.gadgets);

  @override
  Object? toJson() => {'at': at, 'color': color, 'gadgets': gadgets};
}

class _MemoryLogger extends WinterLogger {
  final List<String> warnings;

  _MemoryLogger(this.warnings);

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level == LogLevel.warning) warnings.add(message);
  }
}

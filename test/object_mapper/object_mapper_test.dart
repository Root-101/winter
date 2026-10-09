@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

import 'object_mapper_models.dart';
import 'other_library/tool.dart' as other;

/// The basics of the mapper: round trips, the default types, collections, registering and the
/// kind of each error. The decisions of §2 (and their edge cases) are in
/// object_mapper_behavior_test.dart.
void main() {
  group('Round trips', () {
    late ObjectMapper mapper;

    setUp(() {
      mapper = ObjectMapper(
        serializers: [Serializer<Tool>((tool) => tool.toJson())],
        deserializers: [
          Deserializer<Tool>((j) => Tool.fromJson(j as Map<String, dynamic>)),
          Deserializer<Gadget>.json(Gadget.fromJson),
        ],
      );
    });

    test('an object with a Serializer and a Deserializer', () {
      final Tool tool = Tool(name: 'Drill');

      expect(mapper.serialize(tool), {'NAME': 'Drill'});
      expect(mapper.deserialize<Tool>({'NAME': 'Drill'}), tool);
      expect(mapper.decode<Tool>('{"NAME": "Drill"}'), tool);

      final Tool restored = mapper.decode<Tool>(mapper.encode(tool));
      expect(restored, tool);
      expect(restored, isNot(same(tool)));
    });

    test('an object with toJson() and Deserializer.json', () {
      expect(mapper.serialize(Gadget(id: 'G1')), {'id': 'G1'});
      expect(mapper.decode<Gadget>('{"id": "G1"}'), Gadget(id: 'G1'));
      expect(Deserializer.json(Gadget.fromJson).type, Gadget);
    });

    test('lists and maps of objects', () {
      final List<Tool> tools = [Tool(name: 'A'), Tool(name: 'B')];

      expect(mapper.deserialize<List<Tool>>(mapper.serialize(tools)), tools);
      expect(mapper.decode<Map<String, Tool>>('{"first":{"NAME":"Hammer"}}'), {
        'first': Tool(name: 'Hammer'),
      });
      expect(mapper.decode<List<Tool?>>('[{"NAME":"A"}]'), [Tool(name: 'A')]);
    });

    test('null, maps and lists of maps are kept as they are', () {
      final List<Map<String, Object>> list = [
        {'id': 1},
        {'id': 2},
      ];

      expect(mapper.serialize(null), isNull);
      expect(mapper.serialize({'key': 'value'}), {'key': 'value'});
      expect(mapper.serialize(list), list);
    });
  });

  group('Default types', () {
    final ObjectMapper mapper = ObjectMapper();

    test('DateTime: ISO 8601 in UTC', () {
      final DateTime date = DateTime.utc(2026, 1, 2, 3, 4, 5);

      expect(mapper.serialize(date), '2026-01-02T03:04:05.000Z');
      expect(mapper.deserialize<DateTime>('2026-01-02T03:04:05.000Z'), date);
      expect(mapper.serialize([date]), ['2026-01-02T03:04:05.000Z']);
    });

    test('Duration: milliseconds', () {
      expect(mapper.serialize(const Duration(days: 1)), 86400000);
      expect(mapper.deserialize<Duration>(86400000), const Duration(days: 1));
    });

    test('String, int, double, num, bool', () {
      expect(mapper.deserialize<String>('test'), 'test');
      expect(mapper.decode<int>('123'), 123);
      expect(mapper.decode<double>('123.45'), 123.45);
      expect(mapper.deserialize<num>(123), 123);
      expect(mapper.decode<num>('123.45'), 123.45);
      expect(mapper.decode<bool>('true'), isTrue);
    });

    test('dynamic, Object and Null take any JSON value', () {
      expect(mapper.deserialize<dynamic>(123), 123);
      expect(mapper.deserialize<Object>('object'), 'object');
      expect(mapper.deserialize<Null>(null), isNull);
    });

    test('lists of primitives, also nested and empty', () {
      expect(mapper.deserialize<List<int>>(jsonDecode('[1, 2, 3]')), [1, 2, 3]);
      expect(mapper.deserialize<List<String>>(['a', 'b']), ['a', 'b']);
      expect(mapper.deserialize<List<int>>(<int>[]), isEmpty);
      expect(mapper.serialize(<Object>[]), isEmpty);
    });

    test('maps of primitives', () {
      expect(mapper.decode<Map<String, dynamic>>('{"a":1,"b":{"c":[1,2]}}'), {
        'a': 1,
        'b': {
          'c': [1, 2],
        },
      });
      expect(mapper.decode<Map>('{"a":1}'), {'a': 1});
      expect(mapper.decode<Map<String, Object?>>('{"a":null}'), {'a': null});
      expect(
        mapper.deserialize<Map<String, dynamic>>(<dynamic, dynamic>{'a': 1}),
        {'a': 1},
      );
      expect(
        mapper.decode<Map<String, int>>('{"a":1}'),
        isA<Map<String, int>>(),
      );
      expect(mapper.decode<Map<String, int?>>('{"a":1}'), {'a': 1});
      expect(mapper.decode<Map<String, int>?>('{"a":1}'), {'a': 1});
      expect(mapper.decode<List<int>?>('[1, 2]'), [1, 2]);
    });

    test('a default can be replaced', () {
      final ObjectMapper micros = ObjectMapper(
        serializers: [Serializer<DateTime>((d) => d.microsecondsSinceEpoch)],
        deserializers: [
          Deserializer<DateTime>(
            (v) => DateTime.fromMicrosecondsSinceEpoch(v as int, isUtc: true),
          ),
        ],
      );
      final DateTime date = DateTime.utc(2026, 1, 1, 0, 0, 0, 0, 1);

      expect(micros.deserialize<DateTime>(micros.serialize(date)), date);
    });
  });

  group('Serialization of values inside values', () {
    final ObjectMapper mapper = ObjectMapper(
      serializers: [Serializer<Tool>((t) => t.toJson())],
    );

    test(
      'the result of toJson() is serialized again (dates, enums, objects)',
      () {
        final Object? result = mapper.serialize(
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
      },
    );

    test('the result of a serializer is serialized again', () {
      final ObjectMapper withDate = ObjectMapper(
        serializers: [
          Serializer<Tool>((t) => {'name': t.name, 'at': DateTime.utc(2026)}),
        ],
      );

      expect(withDate.serialize(Tool(name: 'Hammer')), {
        'name': 'Hammer',
        'at': '2026-01-01T00:00:00.000Z',
      });
    });

    test('a list mixing objects with a serializer and with toJson()', () {
      expect(mapper.serialize([Tool(name: 'Hammer'), Gadget(id: 'G1')]), [
        {'NAME': 'Hammer'},
        {'id': 'G1'},
      ]);
      expect(
        mapper.serialize(
          Workshop(
            name: 'Main',
            gadgets: [Gadget(id: 'G1')],
          ),
        ),
        {
          'name': 'Main',
          'gadgets': [
            {'id': 'G1'},
          ],
        },
      );
    });

    test('enums by name, unless a serializer is registered', () {
      final ObjectMapper byIndex = ObjectMapper(
        serializers: [Serializer<_Color>((c) => c.index)],
      );

      expect(mapper.serialize(_Color.red), 'red');
      expect(byIndex.serialize(_Color.red), 0);
    });

    test('sets and other iterables are lists', () {
      expect(mapper.serialize({1, 2}), [1, 2]);
      expect(mapper.serialize([1, 2].map((e) => e * 2)), [2, 4]);
    });

    test('map keys become strings; a key that is not a JSON key fails', () {
      expect(mapper.serialize({1: 'a', true: 'b', _Color.red: 'c'}), {
        '1': 'a',
        'true': 'b',
        'red': 'c',
      });
      expect(
        () => mapper.serialize({
          [1]: 'a',
        }),
        throwsA(isA<SerializationException>()),
      );
    });
  });

  group('Registering', () {
    test('add and remove a Serializer: toJson() is used without it', () {
      final ObjectMapper mapper = ObjectMapper();
      final Tool tool = Tool(name: 'Hammer');

      expect(mapper.serialize(tool), {'NAME': 'Hammer'});
      mapper.addSerializer<Tool>(Serializer<Tool>((t) => t.name));
      expect(mapper.serialize(tool), 'Hammer');
      mapper.removeSerializer<Tool>();
      expect(mapper.serialize(tool), {'NAME': 'Hammer'});
    });

    test('add and remove a Deserializer', () {
      final ObjectMapper mapper = ObjectMapper();
      final Map<String, dynamic> json = {'NAME': 'Hammer'};

      mapper.addDeserializer<Tool>(Deserializer<Tool>.json(Tool.fromJson));
      expect(mapper.deserialize<Tool>(json), Tool(name: 'Hammer'));
      mapper.removeDeserializer<Tool>();
      expect(
        () => mapper.deserialize<Tool>(json),
        throwsA(isA<MissingDeserializerError>()),
      );
    });

    test('a Serializer or Deserializer without its type fails at once', () {
      expect(
        () => Serializer<dynamic>((obj) => obj),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Serializer<Money>'),
          ),
        ),
      );
      expect(
        () => Deserializer<dynamic>((data) => data),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Deserializer<User>.json'),
          ),
        ),
      );
      expect(() => Serializer<Tool>((tool) => tool.toJson()), returnsNormally);
    });

    test('inside a list, a Deserializer without its type is dynamic or Enum: it fails', () {
      expect(
        () => ObjectMapper(deserializers: [Deserializer.json(Tool.fromJson)]),
        throwsArgumentError,
      );
      // Dart infers Deserializer<Enum> from the list, not Deserializer<_Kind> from the values
      expect(
        () => ObjectMapper(
          deserializers: [Deserializer.enumByName(_Kind.values)],
        ),
        throwsArgumentError,
      );
      expect(
        () => Deserializer<String>.enumByName(['a']),
        throwsArgumentError,
        reason: 'not the values of an enum',
      );
      expect(
        ObjectMapper(
          deserializers: [Deserializer<_Kind>.enumByName(_Kind.values)],
        ).deserialize<_Kind>('b'),
        _Kind.b,
      );
    });
  });

  group('The kind of each error', () {
    late ObjectMapper mapper;

    setUp(() {
      mapper = ObjectMapper(
        deserializers: [Deserializer<Tool>.json(Tool.fromJson)],
      );
    });

    test('nothing to serialize it with: MissingSerializerError (a 500)', () {
      expect(
        () => mapper.serialize(other.Tool('x')),
        throwsA(isA<MissingSerializerError>()),
      );
      expect(
        () => mapper.serialize([Tool(name: 'A'), other.Tool('W')]),
        throwsA(isA<MissingSerializerError>()),
      );
    });

    test(
      'nothing to deserialize it with: MissingDeserializerError (a 500)',
      () {
        for (final void Function() read in [
          () => mapper.deserialize<Worker>(<String, dynamic>{}),
          () => mapper.decode<List<Worker>>('[{"name":"W"}]'),
          () => mapper.decode<Map<String, Worker>>('{"a":{}}'),
        ]) {
          expect(read, throwsA(isA<MissingDeserializerError>()));
        }
      },
    );

    test(
      'a serializer that throws (Exception or Error): SerializationException',
      () {
        for (final Object error in [
          Exception('failed'),
          ArgumentError('bad'),
        ]) {
          final ObjectMapper failing = ObjectMapper(
            serializers: [Serializer<Tool>((t) => throw error)],
          );

          expect(
            () => failing.serialize(Tool(name: 'Hammer')),
            throwsA(isA<SerializationException>()),
          );
        }
      },
    );

    test('a deserializer that throws, or the wrong shape: DeserializationException (a 400)', () {
      for (final Object error in [Exception('failed'), ArgumentError('bad')]) {
        final ObjectMapper failing = ObjectMapper(
          deserializers: [Deserializer<Tool>((j) => throw error)],
        );

        expect(
          () => failing.deserialize<Tool>({'NAME': 'Hammer'}),
          throwsA(isA<DeserializationException>()),
        );
      }
      for (final void Function() read in [
        () => mapper.decode<Tool>('"just a string"'),
        () => mapper.decode<List<Tool>>('[1, 2]'),
        () => mapper.decode<List<int>>('"no"'),
        () => mapper.decode<Map<String, dynamic>>('[1,2]'),
        () => mapper.decode<Map<String, int>>('{"a":"x"}'),
      ]) {
        expect(read, throwsA(isA<DeserializationException>()));
      }
    });

    test('text that is not JSON: DeserializationFormatException (a 400)', () {
      expect(
        () => mapper.decode<Tool>('invalid json'),
        throwsA(isA<DeserializationFormatException>()),
      );
      expect(
        () => mapper.decode<Map<String, dynamic>>('{not-json'),
        throwsA(isA<DeserializationFormatException>()),
      );
    });

    test('an ApiException thrown by a serializer is not wrapped', () {
      final ObjectMapper conflicting = ObjectMapper(
        serializers: [
          Serializer<Worker>((worker) => throw const ConflictException()),
        ],
      );

      expect(
        () => conflicting.serialize(Worker(name: 'W')),
        throwsA(isA<ConflictException>()),
      );
    });

    test('toString has the type and the message in one line', () {
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
}

enum _Color { red }

class _Event {
  final DateTime at;
  final _Color color;
  final List<Gadget> gadgets;

  _Event(this.at, this.color, this.gadgets);

  Object? toJson() => {'at': at, 'color': color, 'gadgets': gadgets};
}

enum _Kind { a, b }

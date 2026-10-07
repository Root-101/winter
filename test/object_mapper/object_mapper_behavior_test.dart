@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

import 'object_mapper_models.dart';
import 'other_library/tool.dart' as other;

/// The behavior decided in the review of the object mapper (DECISIONS.md §2)
void main() {
  late ObjectMapper mapper;

  setUp(() {
    mapper = ObjectMapper(
      serializers: [Serializer<Tool>((tool) => tool.toJson())],
      deserializers: [Deserializer<Tool>.json(Tool.fromJson)],
    );
  });

  group('Generic types are found by type, not by name (§2.1)', () {
    Matcher missingDeserializer() => throwsA(
      isA<MissingDeserializerError>().having(
        (e) => e.message,
        'message',
        contains('No deserializer'),
      ),
    );

    test('List<T> of a class with the same name in another library', () {
      // There is only a deserializer for the `Tool` of object_mapper_models.dart
      expect(
        () => mapper.decode<List<other.Tool>>('[{"NAME":"A"}]'),
        missingDeserializer(),
      );
    });

    test('Map<String, T> of a class with the same name in another library', () {
      expect(
        () => mapper.decode<Map<String, other.Tool>>('{"a":{"NAME":"A"}}'),
        missingDeserializer(),
      );
    });

    test('T?, List<T>, Set<T> and Map<String, T> are derived from T', () {
      expect(mapper.decode<Tool?>('{"NAME":"A"}'), Tool(name: 'A'));
      expect(mapper.decode<Tool?>('null'), isNull);
      expect(mapper.deserialize<Tool?>(null), isNull);
      expect(mapper.decode<List<Tool>>('[{"NAME":"A"}]'), [Tool(name: 'A')]);
      expect(mapper.decode<List<Tool>?>('null'), isNull);
      expect(mapper.decode<List<Tool?>>('[null]'), [null]);

      final set = mapper.decode<Set<Tool>>('[{"NAME":"A"},{"NAME":"A"}]');
      expect(set, isA<Set<Tool>>());
      expect(set, {Tool(name: 'A')});

      final map = mapper.decode<Map<String, Tool>>('{"a":{"NAME":"A"}}');
      expect(map, isA<Map<String, Tool>>());
      expect(map, {'a': Tool(name: 'A')});
      expect(mapper.decode<Map<String, Tool?>>('{"a":null}'), {'a': null});
    });

    test('The default types have their derived types too', () {
      expect(mapper.decode<List<DateTime>>('["2026-01-01T00:00:00Z"]'), [
        DateTime.utc(2026),
      ]);
      expect(mapper.decode<Map<String, bool>>('{"a":true}'), {'a': true});
      expect(mapper.decode<Set<String>>('["a","a"]'), {'a'});
    });

    test('Deeper types are not derived', () {
      expect(
        () => mapper.decode<List<List<Tool>>>('[[{"NAME":"A"}]]'),
        missingDeserializer(),
      );
    });

    test('Deeper types are registered with list(), set(), map()', () {
      mapper
        ..addDeserializer(Deserializer<Tool>.json(Tool.fromJson).list())
        ..addDeserializer(Deserializer<Tool>.json(Tool.fromJson).map().list());

      // List<List<Tool>> and Map<String, List<Tool>> are derived from List<Tool>
      expect(mapper.decode<List<List<Tool>>>('[[{"NAME":"A"}],[]]'), [
        [Tool(name: 'A')],
        <Tool>[],
      ]);
      expect(mapper.decode<Map<String, List<Tool>>>('{"a":[{"NAME":"A"}]}'), {
        'a': [Tool(name: 'A')],
      });
      expect(mapper.decode<List<Map<String, Tool>>>('[{"a":{"NAME":"A"}}]'), [
        {'a': Tool(name: 'A')},
      ]);
    });

    test(
      'deserializerOf<T>() gives the registered or derived deserializer',
      () {
        mapper.addDeserializer(mapper.deserializerOf<DateTime>().list());

        expect(
          mapper.decode<List<List<DateTime>>>('[["2026-01-01T00:00:00Z"]]'),
          [
            [DateTime.utc(2026)],
          ],
        );
        expect(mapper.deserializerOf<List<Tool>>().type, List<Tool>);
        expect(() => mapper.deserializerOf<Worker>(), missingDeserializer());
      },
    );

    test('An explicit deserializer wins over a derived one', () {
      mapper.addDeserializer(Deserializer<List<Tool>>((data) => <Tool>[]));

      expect(mapper.decode<List<Tool>>('[{"NAME":"A"}]'), isEmpty);
    });

    test('Removing a deserializer removes its derived types', () {
      mapper.removeDeserializer<Tool>();

      expect(() => mapper.decode<List<Tool>>('[]'), missingDeserializer());
    });

    test('body<T?>() answers 200, not a 500', () async {
      final client = _client(
        (request) async => ResponseEntity.ok(
          body: (await request.body<Tool?>(om: mapper))?.name,
        ),
      );

      final response = await client.post(
        '/',
        headers: _json,
        body: '{"NAME":"A"}',
      );

      expect(response.statusCode, 200);
      expect(response.body, 'A');
    });
  });

  group('toJson() without Serializable (§2.2)', () {
    // That's what json_serializable and freezed generate
    test('is serialized with its toJson()', () {
      expect(mapper.serialize(Worker(name: 'W')), {'name': 'W'});
    });

    test('is serialized inside lists and maps', () {
      expect(
        mapper.serialize({
          'workers': [Worker(name: 'W')],
        }),
        {
          'workers': [
            {'name': 'W'},
          ],
        },
      );
    });

    test('a response with it answers 200, not a 500', () async {
      final client = _client(
        (request) => ResponseEntity.ok(body: Worker(name: 'W')),
      );

      final response = await client.get('/');

      expect(response.statusCode, 200);
      expect(response.json, {'name': 'W'});
    });

    test('an enum with toJson() uses it instead of its name', () {
      expect(mapper.serialize(_Level.high), 3);
      expect(mapper.serialize(_Plain.value), 'value');
    });

    test('an error inside toJson() is not taken as a missing toJson()', () {
      expect(
        () => mapper.serialize(_BrokenToJson()),
        throwsA(isA<SerializationException>()),
      );
    });

    test('a toJson getter that is not a method is not a toJson()', () {
      expect(
        () => mapper.serialize(_ToJsonGetter()),
        throwsA(isA<MissingSerializerError>()),
      );
    });

    test('a class without toJson() nor serializer says how to fix it', () {
      expect(
        () => mapper.serialize(other.Tool('x')),
        throwsA(
          isA<MissingSerializerError>().having(
            (e) => e.message,
            'message',
            contains('Serializer<Tool>'),
          ),
        ),
      );
    });
  });

  group('A serializer applies to subtypes (§2.3)', () {
    setUp(() {
      mapper.addSerializer(Serializer<_Animal>((animal) => {'kind': 'animal'}));
    });

    test('a subtype without serializer uses the one of its supertype', () {
      expect(mapper.serialize(_Dog()), {'kind': 'animal'});
    });

    test('the exact type wins over the supertype', () {
      mapper.addSerializer(Serializer<_Dog>((dog) => {'kind': 'dog'}));

      expect(mapper.serialize(_Dog()), {'kind': 'dog'});
      expect(mapper.serialize(_Cat()), {'kind': 'animal'});
    });

    test('a serializer of a supertype wins over toJson()', () {
      expect(mapper.serialize(_Cat()), {'kind': 'animal'});
    });

    test('the cache is cleared when the serializers change', () {
      expect(mapper.serialize(_Cat()), {'kind': 'animal'});

      mapper.removeSerializer<_Animal>();

      expect(mapper.serialize(_Cat()), {'cat': true});
    });
  });

  group('DateTime (§2.6)', () {
    test('a local DateTime is serialized in UTC', () {
      final local = DateTime(2026, 1, 1, 10, 30);

      final result = mapper.serialize(local) as String;

      expect(result, local.toUtc().toIso8601String());
      expect(DateTime.parse(result).isAtSameMomentAs(local), isTrue);
    });

    test('a UTC DateTime is serialized with Z', () {
      expect(mapper.serialize(DateTime.utc(2026)), '2026-01-01T00:00:00.000Z');
    });

    test('an invalid date is a 400 without the parser message', () {
      expect(
        () => mapper.decode<DateTime>('"yesterday"'),
        throwsA(
          isA<DeserializationException>().having(
            (e) => e.message,
            'message',
            r'$: expected an ISO-8601 date, got an invalid string',
          ),
        ),
      );
    });
  });

  group('Deserialization errors (§2.5)', () {
    final internals = [
      'subtype',
      'type cast',
      "'Null'",
      'radix',
      'Instance of',
      'character',
      'file:',
    ];

    Matcher withoutInternals() => isA<DeserializationException>().having(
      (e) => e.message,
      'message',
      allOf([for (final word in internals) isNot(contains(word))]),
    );

    Matcher withMessage(String message) => throwsA(
      isA<DeserializationException>().having(
        (e) => e.message,
        'message',
        message,
      ),
    );

    test('a missing field in fromJson', () {
      expect(() => mapper.decode<Tool>('{}'), withMessage(r'$: invalid value'));
    });

    test('a field with the wrong type in fromJson', () {
      expect(
        () => mapper.decode<Tool>('{"NAME": 1}'),
        throwsA(withoutInternals()),
      );
    });

    test('the original error is kept as the cause', () {
      expect(
        () => mapper.decode<Tool>('{}'),
        throwsA(
          isA<DeserializationException>().having(
            (e) => e.cause,
            'cause',
            isA<TypeError>(),
          ),
        ),
      );
    });

    test('invalid and empty JSON', () {
      expect(
        () => mapper.decode<Tool>('{"NAME": '),
        throwsA(
          isA<DeserializationFormatException>().having(
            (e) => e.message,
            'message',
            'The body is not valid JSON',
          ),
        ),
      );
      expect(() => mapper.decode<Tool>('  '), withMessage('The body is empty'));
      expect(mapper.decode<Tool?>(''), isNull);
    });

    test('the error says where the value is', () {
      expect(
        () => mapper.decode<Map<String, int>>('{"a":1,"b":"x"}'),
        withMessage(r'$.b: expected an integer, got a string'),
      );
      expect(
        () => mapper.decode<List<Tool>>('[{"NAME":"A"},1]'),
        withMessage(r'$[1]: expected an object, got an integer'),
      );
      mapper.addDeserializer(mapper.deserializerOf<int>().list().nullable());
      expect(
        () => mapper.decode<Map<String, List<int>?>>('{"a b":[1, true]}'),
        withMessage(r'$["a b"][1]: expected an integer, got a boolean'),
      );
    });

    test('a nested error inside a list of fromJson has its index', () {
      expect(
        () => mapper.decode<List<Tool>>('[{"NAME":"A"},{}]'),
        withMessage(r'$[1]: invalid value'),
      );
    });

    test('an ApiException thrown by a deserializer is not wrapped', () {
      mapper.addDeserializer(
        Deserializer<Worker>((data) => throw ConflictException()),
      );

      expect(
        () => mapper.decode<List<Worker>>('[{}]'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('the 400 sent to the client has no Dart internals', () async {
      final client = _client((request) async {
        await request.body<Tool>(om: mapper);
        return ResponseEntity.ok();
      });

      final response = await client.post('/', headers: _json, body: '{}');

      expect(response.statusCode, 400);
      expect(response.body, r'$: invalid value');
    });
  });

  group('Strict types (§2.4)', () {
    test('a JSON string is not a number', () {
      expect(
        () => mapper.decode<Map<String, int>>('{"a":"12"}'),
        throwsA(isA<DeserializationException>()),
      );
      expect(
        () => mapper.decode<List<double>>('["1.5"]'),
        throwsA(isA<DeserializationException>()),
      );
      expect(
        () => mapper.decode<num>('"1"'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('a JSON string is not a bool', () {
      expect(
        () => mapper.decode<Map<String, bool>>('{"a":"true"}'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('a number is not a string', () {
      expect(
        () => mapper.decode<List<String>>('[1]'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('a JSON number without decimals is an int (12.0)', () {
      // JSON has a single number type: 12.0 and 12 are the same value
      expect(mapper.decode<Map<String, int>>('{"a":12.0}'), {'a': 12});
      expect(
        () => mapper.decode<Map<String, int>>('{"a":12.5}'),
        throwsA(
          isA<DeserializationException>().having(
            (e) => e.message,
            'message',
            r'$.a: expected an integer, got a decimal number',
          ),
        ),
      );
    });

    test('a JSON int is a double and a num', () {
      expect(mapper.decode<List<double>>('[1]'), [1.0]);
      expect(mapper.decode<num>('1.5'), 1.5);
    });

    test('null is not a value for a non nullable type', () {
      expect(
        () => mapper.decode<List<int>>('[null]'),
        throwsA(isA<DeserializationException>()),
      );
      expect(
        () => mapper.decode<Object>('null'),
        throwsA(isA<DeserializationException>()),
      );
      expect(mapper.decode<List<int?>>('[null]'), [null]);
    });

    test('a raw Map needs a JSON object', () {
      expect(mapper.decode<Map>('{"a":1}'), {'a': 1});
      expect(
        () => mapper.decode<Map>('[1]'),
        throwsA(
          isA<DeserializationException>().having(
            (e) => e.message,
            'message',
            r'$: expected an object, got an array',
          ),
        ),
      );
    });

    test('a value that is not JSON is described without its Dart type', () {
      expect(
        () => mapper.deserialize<String>(Duration.zero),
        throwsA(
          isA<DeserializationException>().having(
            (e) => e.message,
            'message',
            r'$: expected a string, got an unsupported value',
          ),
        ),
      );
    });
  });

  group('body<T>() and the Content-Type of the request (§2.7)', () {
    late WinterTestClient client;

    setUp(() {
      client = _client((request) async {
        final type = request.url.queryParameters['type'];
        final Object? body = type == 'string'
            ? await request.body<String>(om: mapper)
            : (await request.body<Tool>(om: mapper)).name;
        return ResponseEntity.ok(body: body);
      });
    });

    Future<TestResponse> post(
      String body, {
      String? contentType,
      bool string = false,
    }) => client.post(
      string ? '/?type=string' : '/',
      headers: {HttpHeader.contentType: ?contentType},
      body: body,
    );

    test('body<String>() decodes a JSON string', () async {
      final response = await post(
        '"hello"',
        contentType: 'application/json',
        string: true,
      );

      expect(response.statusCode, 200);
      expect(response.body, 'hello');
    });

    test('body<String>() of any other body returns it as is', () async {
      for (final contentType in [
        'text/plain',
        'application/x-www-form-urlencoded',
        null,
      ]) {
        final response = await post(
          '"hello"',
          contentType: contentType,
          string: true,
        );

        expect(response.body, '"hello"', reason: '$contentType');
      }
    });

    test('a form body for a JSON type is a 415', () async {
      final response = await post(
        'NAME=A',
        contentType: 'application/x-www-form-urlencoded',
      );

      expect(response.statusCode, 415);
      expect(response.body, contains('application/json'));
    });

    test('JSON, +json, text/plain and no Content-Type are accepted', () async {
      // package:http and fetch() send text/plain for a String body
      for (final contentType in [
        'application/json',
        'application/json; charset=utf-8',
        'application/merge-patch+json',
        'text/plain; charset=utf-8',
        null,
      ]) {
        final response = await post('{"NAME":"A"}', contentType: contentType);

        expect(response.statusCode, 200, reason: '$contentType');
        expect(response.body, 'A');
      }
    });
  });

  group('encode() in a single pass', () {
    late ObjectMapper compact;

    setUp(() {
      compact = ObjectMapper(
        prettyPrint: false,
        serializers: [Serializer<Tool>((tool) => tool.toJson())],
      );
    });

    test('gives the same JSON as jsonEncode(serialize())', () {
      final values = <Object?>[
        null,
        'a',
        1,
        1.5,
        true,
        [1, 'a'],
        {'a': DateTime.utc(2026)},
        {1, 2},
        {1: 'a', _Plain.value: 'b'},
        [Worker(name: 'W'), Tool(name: 'T'), _Level.high, _Plain.value],
        const Duration(seconds: 1),
      ];
      for (final value in values) {
        expect(
          compact.encode(value),
          jsonEncode(compact.serialize(value)),
          reason: '$value',
        );
      }
    });

    test('throws the same errors as serialize()', () {
      compact.addSerializer(
        Serializer<Worker>((worker) => throw ConflictException()),
      );
      final cyclic = <Object?>[];
      cyclic.add(cyclic);

      for (final (value, matcher) in [
        (other.Tool('x'), isA<MissingSerializerError>()),
        (Worker(name: 'W'), isA<ConflictException>()),
        (_BrokenToJson(), isA<SerializationException>()),
        (cyclic, isA<SerializationException>()),
        (
          {
            [1]: 'a',
          },
          isA<SerializationException>(),
        ),
      ]) {
        expect(() => compact.encode(value), throwsA(matcher), reason: '$value');
      }
    });

    test('a serializer that returns the same object is an error', () {
      compact.addSerializer(Serializer<Worker>((worker) => worker));

      expect(
        () => compact.serialize(Worker(name: 'W')),
        throwsA(isA<SerializationException>()),
      );
      expect(
        () => compact.encode(Worker(name: 'W')),
        throwsA(isA<SerializationException>()),
      );
    });
  });

  group('Options (§2.8)', () {
    test('includeNulls: false drops the null fields of the objects', () {
      final mapper = ObjectMapper(includeNulls: false);

      expect(mapper.serialize(_Profile(null, null)), <String, Object?>{});
      expect(mapper.serialize(_Profile('Ann', null)), {'firstName': 'Ann'});
      // A Map serialized directly is data: it keeps its nulls
      expect(mapper.serialize({'a': null}), {'a': null});
    });

    test('fieldNaming renames the fields of the objects', () {
      final snake = ObjectMapper(fieldNaming: FieldNaming.snakeCase);
      final kebab = ObjectMapper(fieldNaming: FieldNaming.kebabCase);

      expect(snake.serialize(_Profile('Ann', 'ID-1')), {
        'first_name': 'Ann',
        'user_id': 'ID-1',
      });
      expect(kebab.serialize(_Profile('Ann', 'ID-1')), {
        'first-name': 'Ann',
        'user-id': 'ID-1',
      });
      // A Map serialized directly is data: its keys are not renamed
      expect(snake.serialize({'firstName': 1}), {'firstName': 1});
    });

    test('fieldNaming renames the keys given to Deserializer.json', () {
      final mapper = ObjectMapper(
        fieldNaming: FieldNaming.snakeCase,
        deserializers: [Deserializer<_Profile>.json(_Profile.fromJson)],
      );

      final profile = mapper.decode<_Profile>(
        '{"first_name":"Ann","user_id":"ID-1"}',
      );

      expect(profile.firstName, 'Ann');
      expect(profile.userId, 'ID-1');
      // Round trip
      expect(mapper.decode<_Profile>(mapper.encode(profile)).userId, 'ID-1');
      // A Map deserialized directly is data
      expect(mapper.decode<Map<String, int>>('{"a_b":1}'), {'a_b': 1});

      final kebab = ObjectMapper(
        fieldNaming: FieldNaming.kebabCase,
        deserializers: [Deserializer<_Profile>.json(_Profile.fromJson)],
      );
      expect(
        kebab.decode<_Profile>('{"first-name":"Ann","user-id":"ID-1"}').userId,
        'ID-1',
      );
    });

    test('fieldNaming converts acronyms and keeps a leading separator', () {
      final mapper = ObjectMapper(
        fieldNaming: FieldNaming.snakeCase,
        serializers: [
          Serializer<_Raw>((raw) => {'HTTPServer': 1, 'userID': 2, '_id': 3}),
        ],
        deserializers: [Deserializer<_Raw>.json(_Raw.new)],
      );

      expect(mapper.serialize(_Raw({})), {
        'http_server': 1,
        'user_id': 2,
        '_id': 3,
      });
      expect(
        mapper.decode<_Raw>('{"http_server":1,"user_id":2,"_id":3}').json,
        {'httpServer': 1, 'userId': 2, '_id': 3},
      );
    });

    test('durationFormat', () {
      final millis = ObjectMapper();
      final iso = ObjectMapper(durationFormat: DurationFormat.iso8601);
      const duration = Duration(hours: 1, minutes: 30);

      expect(millis.serialize(duration), 5400000);
      expect(millis.decode<Duration>('5400000'), duration);

      expect(iso.serialize(duration), 'PT1H30M');
      expect(iso.decode<Duration>('"PT1H30M"'), duration);
      expect(iso.serialize(Duration.zero), 'PT0S');
      expect(iso.serialize(const Duration(hours: 25)), 'PT25H');
      expect(iso.serialize(const Duration(milliseconds: -1500)), '-PT1.5S');
      expect(
        iso.decode<Duration>('"-PT1.5S"'),
        const Duration(milliseconds: -1500),
      );
      expect(iso.decode<Duration>('"P1DT2H"'), const Duration(hours: 26));
      expect(
        iso.decode<Duration>('"PT0.000001S"'),
        const Duration(microseconds: 1),
      );
      for (final invalid in ['"P"', '"PT"', '"1H"', '5400000']) {
        expect(
          () => iso.decode<Duration>(invalid),
          throwsA(isA<DeserializationException>()),
          reason: invalid,
        );
      }
    });

    test(
      'prettyPrint (on by default) indents encode() and the responses',
      () async {
        expect(ObjectMapper().encode({'a': 1}), '{\n  "a": 1\n}');
        expect(ObjectMapper(prettyPrint: false).encode({'a': 1}), '{"a":1}');

        final response = ResponseEntity(
          200,
          body: {'a': 1},
          objectMapper: ObjectMapper(),
        );
        expect(await response.readAsString(), '{\n  "a": 1\n}');
      },
    );
  });
}

final Map<String, String> _json = {HttpHeader.contentType: 'application/json'};

WinterTestClient _client(
  FutureOr<ResponseEntity> Function(RequestEntity request) handler,
) => WinterTestClient.build(
  router: WinterRouter(
    routes: [
      Route.get(path: '/', handler: handler),
      Route.post(path: '/', handler: handler),
    ],
  ),
);

enum _Level {
  high;

  int toJson() => 3;
}

enum _Plain { value }

class _BrokenToJson {
  Object? toJson() => (null as dynamic).missing();
}

class _ToJsonGetter {
  int get toJson => 1;
}

abstract class _Animal {}

class _Dog extends _Animal {}

class _Cat extends _Animal {
  Map<String, Object?> toJson() => {'cat': true};
}

class _Profile {
  final String? firstName;
  final String? userId;

  _Profile(this.firstName, this.userId);

  factory _Profile.fromJson(Map<String, dynamic> json) =>
      _Profile(json['firstName'] as String?, json['userId'] as String?);

  Map<String, Object?> toJson() => {'firstName': firstName, 'userId': userId};
}

class _Raw {
  final Map<String, dynamic> json;

  _Raw(this.json);
}

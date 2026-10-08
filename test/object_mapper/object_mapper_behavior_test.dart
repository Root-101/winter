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

  group('Generic types are found by type, not by name (§2)', () {
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
          body: (await request.body<Tool?>(objectMapper: mapper))?.name,
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

  group('toJson() without Serializable (§2)', () {
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

  group('A serializer applies to subtypes (§2)', () {
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

  group('DateTime (§2)', () {
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

  group('Deserialization errors (§2)', () {
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
        Deserializer<Worker>((data) => throw const ConflictException()),
      );

      expect(
        () => mapper.decode<List<Worker>>('[{}]'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('the 400 sent to the client has no Dart internals', () async {
      final client = _client((request) async {
        await request.body<Tool>(objectMapper: mapper);
        return ResponseEntity.ok();
      });

      final response = await client.post('/', headers: _json, body: '{}');

      expect(response.statusCode, 400);
      expect((response.json as Map)['detail'], r'$: invalid value');
    });
  });

  group('Strict types (§2)', () {
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

  group('body<T>() and the Content-Type of the request (§2)', () {
    late WinterTestClient client;

    setUp(() {
      client = _client((request) async {
        final type = request.requestedUri.queryParameters['type'];
        final Object? body = type == 'string'
            ? await request.body<String>(objectMapper: mapper)
            : (await request.body<Tool>(objectMapper: mapper)).name;
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

  group('Enums: Deserializer<E>.enumByName', () {
    setUp(() {
      mapper.addDeserializer(Deserializer<_Status>.enumByName(_Status.values));
    });

    test('reads the name, the way enums are serialized', () {
      expect(mapper.decode<_Status>('"paid"'), _Status.paid);
      expect(
        mapper.decode<_Status>(mapper.encode(_Status.pending)),
        _Status.pending,
      );
    });

    test('the type is inferred and the derived types come with it', () {
      expect(Deserializer<_Status>.enumByName(_Status.values).type, _Status);
      expect(mapper.decode<List<_Status>>('["paid","pending"]'), [
        _Status.paid,
        _Status.pending,
      ]);
      expect(mapper.decode<_Status?>('null'), isNull);
    });

    test('an unknown name lists the valid ones, without echoing the value', () {
      expect(
        () => mapper.decode<Map<String, _Status>>('{"a":"refunded"}'),
        throwsA(
          isA<DeserializationException>().having(
            (e) => e.message,
            'message',
            r'$.a: expected one of pending, paid, got another string',
          ),
        ),
      );
      expect(
        () => mapper.decode<_Status>('1'),
        throwsA(
          isA<DeserializationException>().having(
            (e) => e.message,
            'message',
            r'$: expected one of pending, paid, got an integer',
          ),
        ),
      );
    });

    test('the name is case sensitive', () {
      expect(
        () => mapper.decode<_Status>('"PAID"'),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('Typed deserializers: string, integer, number, boolean', () {
    setUp(() {
      mapper
        ..addDeserializer(Deserializer<Uri>.string(Uri.parse))
        ..addDeserializer(Deserializer<_Cents>.integer(_Cents.new))
        ..addDeserializer(Deserializer<_Ratio>.number(_Ratio.new))
        ..addDeserializer(Deserializer<_Flag>.boolean(_Flag.new));
    });

    test('convert the JSON value of their type', () {
      expect(
        mapper.decode<Uri>('"https://example.com/a"'),
        Uri.parse('https://example.com/a'),
      );
      expect(mapper.decode<_Cents>('150').value, 150);
      expect(mapper.decode<_Cents>('150.0').value, 150);
      expect(mapper.decode<_Ratio>('0.5').value, 0.5);
      expect(mapper.decode<_Flag>('true').value, isTrue);
      expect(mapper.decode<List<Uri>>('["a"]'), [Uri.parse('a')]);
    });

    test('another JSON type is a 400 that says what was expected', () {
      Matcher withMessage(String message) => throwsA(
        isA<DeserializationException>().having(
          (e) => e.message,
          'message',
          message,
        ),
      );

      expect(
        () => mapper.decode<Map<String, Uri>>('{"url":1}'),
        withMessage(r'$.url: expected a string, got an integer'),
      );
      expect(
        () => mapper.decode<_Cents>('1.5'),
        withMessage(r'$: expected an integer, got a decimal number'),
      );
      expect(
        () => mapper.decode<_Ratio>('"0.5"'),
        withMessage(r'$: expected a number, got a string'),
      );
      expect(
        () => mapper.decode<_Flag>('"true"'),
        withMessage(r'$: expected a boolean, got a string'),
      );
    });

    test('a function that throws is a 400 invalid value', () {
      expect(
        () => mapper.decode<List<Uri>>('["ok", "http://[::1"]'),
        throwsA(
          isA<DeserializationException>()
              .having((e) => e.message, 'message', r'$[1]: invalid value')
              .having((e) => e.cause, 'cause', isA<FormatException>()),
        ),
      );
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
        Serializer<Worker>((worker) => throw const ConflictException()),
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

  group('Options (§2)', () {
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
  group('JsonAdapter: a serializer and a deserializer in one', () {
    test('string, integer, number and value adapters read what they write', () {
      final mapper = ObjectMapper(
        adapters: [
          JsonAdapter<Uri>.string(
            toJson: (uri) => uri.toString(),
            fromJson: Uri.parse,
          ),
          JsonAdapter<_Cents>.integer(
            toJson: (cents) => cents.value,
            fromJson: _Cents.new,
          ),
          JsonAdapter<_Ratio>.number(
            toJson: (ratio) => ratio.value,
            fromJson: _Ratio.new,
          ),
          JsonAdapter<_Flag>.value(
            toJson: (flag) => flag.value ? 'yes' : 'no',
            fromJson: (json) => _Flag(json == 'yes'),
          ),
        ],
      );
      final Uri uri = Uri.parse('https://example.com/a?b=1');

      expect(mapper.serialize(uri), 'https://example.com/a?b=1');
      expect(mapper.deserialize<Uri>('https://example.com/a?b=1'), uri);
      expect(mapper.serialize(_Cents(1250)), 1250);
      expect(mapper.deserialize<_Cents>(1250).value, 1250);
      expect(mapper.deserialize<_Ratio>(0.5).value, 0.5);
      expect(mapper.serialize(_Flag(true)), 'yes');
      expect(mapper.deserialize<_Flag>('no').value, isFalse);
      // Its derived types come with it, like for any deserializer
      expect(mapper.deserialize<List<Uri>>(['https://a.com']), [
        Uri.parse('https://a.com'),
      ]);
      expect(
        () => mapper.deserialize<Uri>(12),
        throwsA(
          isA<DeserializationException>().having(
            (e) => e.message,
            'message',
            r'$: expected a string, got an integer',
          ),
        ),
      );
    });

    test('a json adapter follows fieldNaming both ways', () {
      final mapper = ObjectMapper(fieldNaming: FieldNaming.snakeCase)
        ..addAdapter(
          JsonAdapter<_Profile>.json(
            toJson: (profile) => {'firstName': profile.firstName},
            fromJson: (json) => _Profile(json['firstName'] as String, null),
          ),
        );

      expect(mapper.serialize(_Profile('Ann', null)), {'first_name': 'Ann'});
      expect(
        mapper.deserialize<_Profile>({'first_name': 'Ann'}).firstName,
        'Ann',
      );
    });

    test('a type inferred as dynamic is an ArgumentError', () {
      expect(
        () => JsonAdapter<dynamic>.string(
          toJson: (value) => '$value',
          fromJson: (json) => json,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Map keys that are not String: mapWithKeys<K>()', () {
    final mapper = ObjectMapper(
      prettyPrint: false,
      deserializers: [Deserializer<_Status>.enumByName(_Status.values)],
    );
    mapper
      ..addDeserializer(mapper.deserializerOf<String>().mapWithKeys<int>())
      ..addDeserializer(mapper.deserializerOf<int>().mapWithKeys<_Status>())
      ..addDeserializer(mapper.deserializerOf<int>().mapWithKeys<DateTime>())
      ..addDeserializer(mapper.deserializerOf<int>().mapWithKeys<bool>())
      ..addDeserializer(mapper.deserializerOf<int>().mapWithKeys<double>())
      ..addDeserializer(mapper.deserializerOf<int>().mapWithKeys<num>())
      ..addDeserializer(mapper.deserializerOf<int>().mapWithKeys<String>());

    test('every key reads back what the mapper writes', () {
      final Map<int, String> byId = {1: 'a', 20: 'b'};
      final Map<_Status, int> counts = {_Status.pending: 2, _Status.paid: 5};
      final Map<DateTime, int> byDay = {DateTime.utc(2026, 1, 2): 3};

      expect(mapper.encode(byId), '{"1":"a","20":"b"}');
      expect(mapper.decode<Map<int, String>>(mapper.encode(byId)), byId);
      expect(mapper.decode<Map<_Status, int>>(mapper.encode(counts)), counts);
      expect(mapper.decode<Map<DateTime, int>>(mapper.encode(byDay)), byDay);
      expect(mapper.deserialize<Map<bool, int>>({'true': 1, 'false': 0}), {
        true: 1,
        false: 0,
      });
      expect(mapper.deserialize<Map<double, int>>({'1.5': 1}), {1.5: 1});
      expect(mapper.deserialize<Map<num, int>>({'2': 1}), {2: 1});
      expect(mapper.deserialize<Map<String, int>>({'a': 1}), {'a': 1});
    });

    test('a key that is not a K is a 400 at its path', () {
      final Map<String, Object?> cases = {
        r'$.abc: expected an integer as the key': {'abc': 'x'},
        r'$.unknown: expected one of pending, paid, got another string': {
          'unknown': 1,
        },
        r'$.maybe: expected true or false as the key': {'maybe': 1},
        r'$["1.5"]: expected an integer, got a string': {'1.5': 'no'},
      };
      final List<Object? Function(Object?)> decoders = [
        mapper.deserialize<Map<int, String>>,
        mapper.deserialize<Map<_Status, int>>,
        mapper.deserialize<Map<bool, int>>,
        mapper.deserialize<Map<double, int>>,
      ];
      var i = 0;
      for (final MapEntry(key: message, value: json) in cases.entries) {
        expect(
          () => decoders[i++](json),
          throwsA(
            isA<DeserializationException>().having(
              (e) => e.message,
              'message',
              message,
            ),
          ),
        );
      }
    });

    test('a key type without a deserializer is a MissingDeserializerError', () {
      final other = ObjectMapper();
      other.addDeserializer(other.deserializerOf<int>().mapWithKeys<Uri>());

      expect(
        () => other.deserialize<Map<Uri, int>>({'https://a.com': 1}),
        throwsA(isA<MissingDeserializerError>()),
      );
    });
  });

  group('encodeBytes and decodeBytes: straight to and from UTF-8', () {
    final Object value = {
      'name': 'Begoña 😀',
      'at': DateTime.utc(2026, 1, 2),
      'status': _Status.paid,
      'items': [1, 2.5, null, true],
    };

    test('encodeBytes writes the bytes of encode, compact or indented', () {
      for (final mapper in [ObjectMapper(), ObjectMapper(prettyPrint: false)]) {
        expect(mapper.encodeBytes(value), utf8.encode(mapper.encode(value)));
      }
      expect(
        () => ObjectMapper().encodeBytes(Object()),
        throwsA(isA<MissingSerializerError>()),
      );
      expect(
        () => ObjectMapper().encodeBytes(_BrokenToJson()),
        throwsA(isA<SerializationException>()),
      );
    });

    test('decodeBytes reads what decode reads, with the same errors', () {
      final mapper = ObjectMapper(
        deserializers: [Deserializer<_Status>.enumByName(_Status.values)],
      );
      final List<int> bytes = utf8.encode('{"name": "Begoña 😀", "n": [1, 2]}');

      expect(
        mapper.decodeBytes<Map<String, dynamic>>(bytes),
        mapper.decode<Map<String, dynamic>>(utf8.decode(bytes)),
      );
      expect(mapper.decodeBytes<_Status>(utf8.encode('"paid"')), _Status.paid);
      expect(mapper.decodeBytes<int?>(utf8.encode(' \n\t ')), isNull);
      for (final List<int> invalid in [
        utf8.encode(' '),
        utf8.encode('{"a": '),
        [0x7B, 0xFF, 0x7D],
      ]) {
        expect(
          () => mapper.decodeBytes<Map<String, dynamic>>(invalid),
          throwsA(isA<DeserializationFormatException>()),
          reason: '$invalid',
        );
      }
      expect(
        () => mapper.decodeBytes<_Status>(utf8.encode('"lost"')),
        throwsA(isA<DeserializationException>()),
      );
    });

    test(
      'body<T>() of a JSON in another charset still reads its text',
      () async {
        final request = RequestEntity(
          'POST',
          Uri.parse('http://localhost/'),
          headers: {
            HttpHeader.contentType: 'application/json; charset=iso-8859-1',
          },
          body: latin1.encode('{"name": "Begoña"}'),
        );

        expect(await request.body<Map<String, dynamic>>(), {'name': 'Begoña'});
      },
    );
  });

  group('Replacing the mapper warns about what is lost', () {
    late List<String> logs;
    late ObjectMapper previous;

    setUp(() {
      logs = [];
      previous = om;
      Winter.context.setUp(logger: _ListLogger(logs));
    });

    tearDown(() {
      Winter.context.setUp(logger: const ConsoleLogger());
      Winter.context.setUp(objectMapper: previous);
    });

    test('the types of the app that the new mapper has not', () {
      Winter.context.setUp(
        objectMapper: ObjectMapper()
          ..addDeserializer(Deserializer<_Cents>.integer(_Cents.new))
          ..addSerializer(Serializer<_Ratio>((ratio) => ratio.value))
          ..addAdapter(
            JsonAdapter<Uri>.string(
              toJson: (uri) => '$uri',
              fromJson: Uri.parse,
            ),
          ),
      );
      logs.clear();

      Winter.context.setUp(
        objectMapper: ObjectMapper(
          fieldNaming: FieldNaming.snakeCase,
          deserializers: [Deserializer<_Cents>.integer(_Cents.new)],
        ),
      );

      expect(logs, [
        'warning: The object mapper was replaced, and the new one has no serializer or '
            'deserializer of _Ratio, Uri, registered in the previous one. Register them in the '
            'new mapper, or set up the mapper before registering them.',
      ]);
    });

    test(
      'nothing to say: only defaults, the same mapper, or all of them kept',
      () {
        Winter.context.setUp(objectMapper: ObjectMapper());
        Winter.context.setUp(objectMapper: om);
        // Registered and removed: nothing of the app is left to lose
        Winter.context.setUp(
          objectMapper: ObjectMapper()
            ..addDeserializer(Deserializer<_Cents>.integer(_Cents.new))
            ..removeDeserializer<_Cents>(),
        );
        Winter.context.setUp(objectMapper: ObjectMapper());
        // Kept by the new mapper
        Winter.context.setUp(
          objectMapper: ObjectMapper(
            deserializers: [Deserializer<_Cents>.integer(_Cents.new)],
          ),
        );
        Winter.context.setUp(
          objectMapper: ObjectMapper(
            deserializers: [Deserializer<_Cents>.integer(_Cents.new)],
          ),
        );

        expect(logs, isEmpty);
      },
    );
  });

  group('TestResponse.as<T>()', () {
    test(
      'reads the body with the mapper, like body<T>() reads a request',
      () async {
        final mapper = ObjectMapper(
          adapters: [
            JsonAdapter<Uri>.string(
              toJson: (uri) => uri.toString(),
              fromJson: Uri.parse,
            ),
          ],
        );
        final client = WinterTestClient.build(
          router: WinterRouter(
            routes: [
              Route.get(
                path: '/links',
                handler: (request) => ResponseEntity.ok(
                  body: mapper.encode([Uri.parse('https://a.com')]),
                  headers: {HttpHeader.contentType: 'application/json'},
                ),
              ),
            ],
          ),
        );

        final TestResponse response = await client.get('/links');

        expect(response.as<List<Uri>>(objectMapper: mapper), [
          Uri.parse('https://a.com'),
        ]);
        expect(response.as<List<String>>(), ['https://a.com']);
        expect(
          () => response.as<List<int>>(),
          throwsA(isA<DeserializationException>()),
        );
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

enum _Status { pending, paid }

class _Cents {
  final int value;

  _Cents(this.value);
}

class _Ratio {
  final num value;

  _Ratio(this.value);
}

class _Flag {
  final bool value;

  _Flag(this.value);
}

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

class _ListLogger extends WinterLogger {
  final List<String> logs;

  _ListLogger(this.logs);

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => logs.add('${level.name}: $message');
}

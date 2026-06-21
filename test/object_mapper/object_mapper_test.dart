@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

import 'models.dart';

void main() {
  baseTests(
    'Mapper with serializers in constructor',
    () => ObjectMapperImpl(
      serializers: [Serializer<Tool>((object) => object.toJson())],
      deserializers: [Deserializer<Tool>((json) => Tool.fromJson(json))],
    ),
  );
  baseTests('Mapper with serializers added after', () {
    ObjectMapper om = ObjectMapperImpl();

    om.addSerializer(Serializer<Tool>((object) => object.toJson()));
    om.addDeserializer(Deserializer<Tool>((json) => Tool.fromJson(json)));

    return om;
  });

  group('No serializer/deserializer', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapperImpl();
    });

    test('No Serializer - Tool', () {
      Tool object = Tool(name: 'Drill');

      expect(() => parser.serialize<Tool>(object), throwsA(isA<StateError>()));
    });

    test('No Deserializer - Tool', () {
      Map<String, dynamic> json = {'NAME': 'Drill'};

      expect(() => parser.deserialize<Tool>(json), throwsA(isA<StateError>()));
    });
  });

  group('Serializer via \'implements Serializable\'', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapperImpl();
    });

    test('Serialize - SerializableTool', () {
      SerializableTool object = SerializableTool(name: 'Drill');
      Map<String, dynamic> expectedJson = {'NAME': 'Drill'};

      dynamic json = parser.serialize(object);

      expect(expectedJson, json);
    });
  });

  group('Advanced usage', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapperImpl();
    });

    test('Overwrite serializer', () {
      parser.addSerializer(Serializer<Tool>((t) => {'v': 1}));
      parser.addSerializer(Serializer<Tool>((t) => {'v': 2}));

      expect(parser.serialize(Tool(name: 'x')), {'v': 2});
    });

    test('Remove serializer/deserializer', () {
      parser.addSerializer(Serializer<Tool>((t) => {}));
      parser.addDeserializer(Deserializer<Tool>((j) => Tool.empty()));

      parser.removeSerializer<Tool>();
      parser.removeDeserializer<Tool>();

      expect(
        () => parser.serialize(Tool(name: 'x')),
        throwsA(isA<StateError>()),
      );
      expect(() => parser.deserialize<Tool>({}), throwsA(isA<StateError>()));
    });

    test('Nested objects', () {
      parser.addSerializer(Serializer<Tool>((t) => t.toJson()));
      parser.addSerializer(
        Serializer<Worker>(
          (w) => {
            'name': w.name,
            'tool': parser.serialize(w.tool), // Using the parser for nesting
          },
        ),
      );

      Worker worker = Worker(
        name: 'John',
        tool: Tool(name: 'Hammer'),
      );
      dynamic json = parser.serialize(worker);

      expect(json, {
        'name': 'John',
        'tool': {'NAME': 'Hammer'},
      });
    });

    test('Inferred type in serialize', () {
      // Testing that the static type S is used
      parser.addSerializer(Serializer<Tool>((t) => {'type': 'Tool'}));

      Tool tool = Tool(name: 'Generic');
      expect(parser.serialize(tool), {'type': 'Tool'});

      // If we pass it as dynamic, S becomes dynamic
      expect(
        () => parser.serialize(tool as dynamic),
        throwsA(isA<StateError>()),
      );
    });

    test('List of objects (manual mapping)', () {
      parser.addSerializer(Serializer<Tool>((t) => t.toJson()));

      List<Tool> tools = [Tool(name: 'Drill'), Tool(name: 'Hammer')];
      dynamic jsonList = tools.map((t) => parser.serialize(t)).toList();

      expect(jsonList, [
        {'NAME': 'Drill'},
        {'NAME': 'Hammer'},
      ]);
    });

    test('List of objects (manual deserialization)', () {
      parser.addDeserializer(Deserializer<Tool>((j) => Tool.fromJson(j)));

      List<Map<String, dynamic>> jsonList = [
        {'NAME': 'Drill'},
        {'NAME': 'Hammer'},
      ];
      List<Tool> tools = jsonList
          .map((j) => parser.deserialize<Tool>(j))
          .toList();

      expect(tools, [Tool(name: 'Drill'), Tool(name: 'Hammer')]);
    });
  });

  group('Collections and Primitives', () {
    late ObjectMapper parser;

    setUp(() {
      parser = ObjectMapperImpl();
    });

    test('serializeList and deserializeList', () {
      parser.addSerializer(Serializer<Tool>((t) => t.toJson()));
      parser.addDeserializer(Deserializer<Tool>((j) => Tool.fromJson(j)));

      List<Tool> tools = [Tool(name: 'A'), Tool(name: 'B')];
      dynamic json = parser.serializeList(tools);

      expect(json, [
        {'NAME': 'A'},
        {'NAME': 'B'},
      ]);

      List<Tool> back = parser.deserializeList<Tool>(json);
      expect(back, tools);
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

      test('Uri', () {
        Uri uri = Uri.parse('https://google.com');
        expect(parser.serialize(uri), uri.toString());
        expect(parser.deserialize<Uri>(uri.toString()), uri);
      });

      test('RegExp', () {
        RegExp regExp = RegExp(r'\d+');
        expect(parser.serialize(regExp), regExp.pattern);
        expect(
          parser.deserialize<RegExp>(regExp.pattern).pattern,
          regExp.pattern,
        );
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
      });

      test('List of primitives', () {
        List<int> numbers = [1, 2, 3];
        expect(parser.serializeList(numbers), [1, 2, 3]);
        expect(parser.deserializeList<int>(['1', '2', '3']), [1, 2, 3]);

        List<String> strings = ['a', 'b'];
        expect(parser.serializeList(strings), ['a', 'b']);
        expect(parser.deserializeList<String>(['a', 'b']), ['a', 'b']);
      });

      test('List of default objects', () {
        DateTime now = DateTime.now();
        List<DateTime> dates = [now];
        expect(parser.serializeList(dates), [now.toIso8601String()]);
        expect(parser.deserializeList<DateTime>([now.toIso8601String()]), [
          DateTime.parse(now.toIso8601String()),
        ]);
      });
    });
  });
}

void baseTests(String description, ObjectMapper Function() createParser) {
  group(description, () {
    late ObjectMapper parser;

    setUp(() {
      parser = createParser();
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

    //this is more to see if the serialize/deserialize create/return the same object,
    //but its related more to the logic of toJson/fromJson than the actually logic of object mapper
    test('Serialize/Deserialize consistency - Tool', () async {
      Map<String, dynamic> json = {'NAME': 'Drill'};
      Tool expectedObject = Tool(name: 'Drill');

      Tool object = parser.deserialize(json);

      expect(expectedObject, object);
    });
  });
}

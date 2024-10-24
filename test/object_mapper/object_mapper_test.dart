@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../bin/winter.dart';
import 'models.dart';

late ObjectMapper parser;

void main() {
  setUpAll(() {
    // Global config for all tests
    ///it's used `prettyPrint: false` to avoid errors with indentation & spacing
    parser = ObjectMapperImpl(
      namingStrategy: NamingStrategies.snakeCase, //by default use
      prettyPrint: false,
    );
  });

  //---------- Utils ----------\\
  String removeIndentation(String input) {
    // Expresión regular para eliminar espacios fuera de las comillas
    return input.replaceAllMapped(RegExp(r'("(?:\\.|[^"\\])*")|\s+'), (match) {
      // Si coincide con una cadena (dentro de comillas), la devuelve sin modificar
      if (match[1] != null) {
        return match[1]!;
      }
      // Si es un espacio fuera de las comillas, lo elimina
      return '';
    });
  }

  test('Remove indentation', () async {
    String expectedResult = '''
    {
      "user_name": "John Doe",
      "user_id": 1,
      "duration": "P1Y",
      "is_active": true,
      "addresses": [
        {"street_name": "Main Street", "house_number": 123},
        {"street_name": "Second Street", "house_number": 456}
      ],
      "single_address": {"street_name": "Third Street", "house_number": 789},
      "additional_attributes": {
        "key1": "value1",
        "key2": 42,
        "key3": true
      }
    }
    ''';
    expectedResult = removeIndentation(expectedResult);

    String string2 =
        '{"user_name":"John Doe","user_id":1,"duration":"P1Y","is_active":true,"addresses":[{"street_name":"Main Street","house_number":123},{"street_name":"Second Street","house_number":456}],"single_address":{"street_name":"Third Street","house_number":789},"additional_attributes":{"key1":"value1","key2":42,"key3":true}}';

    expect(expectedResult, string2);
  });

  //---------- Object via Serializable----------\\
  test('Serialize/Deserialize - Tool', () async {
    Tool object = Tool(name: 'Drill');

    String expectedResult = '{"NAME":"Drill"}';

    String jsonString = parser.serialize(object);
    expect(expectedResult, jsonString);

    Tool deserialized = parser.deserialize<Tool>(jsonString);

    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<Tool>', () async {
    List<Tool> object = [
      Tool(name: 'Drill'),
      Tool(name: 'Screwdriver'),
      Tool(name: 'Hammer'),
    ];
    String expectedResult =
        '[{"NAME":"Drill"},{"NAME":"Screwdriver"},{"NAME":"Hammer"}]';

    String jsonString = parser.serialize(object);
    expect(expectedResult, jsonString);

    List<Tool> deserialized = parser.deserializeList<Tool>(jsonString);

    expect(deserialized, object);
  });

  test('Serialize/Deserialize - Map<String, Tool>', () async {
    Map<String, Tool> object = {
      'drill': Tool(name: 'Drill'),
      'screw': Tool(name: 'Screwdriver'),
      'hamm': Tool(name: 'Hammer'),
    };

    String expectedResult =
        '{"drill":{"NAME":"Drill"},"screw":{"NAME":"Screwdriver"},"hamm":{"NAME":"Hammer"}}';

    String jsonString = parser.serialize(object);
    expect(expectedResult, jsonString);

    Map<String, Tool> deserialized =
        parser.deserializeMap<String, Tool>(jsonString);

    expect(deserialized, object);
  });

  //---------- Object via Serializable----------\\

  //---------- Object via Annotation----------\\
  test('Serialize/Deserialize - Computer', () async {
    Computer object = Computer.named(brand: 'hp');

    String expectedResult = '{"brand":"HP"}';

    String jsonString = parser.serialize(object);
    expect(expectedResult, jsonString);

    Computer deserialized = parser.deserialize<Computer>(jsonString);

    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<Computer>', () async {
    List<Computer> object = [
      Computer.named(brand: 'hp'),
      Computer.named(brand: 'gateway'),
      Computer.named(brand: 'mac'),
    ];

    String expectedResult =
        '[{"brand":"HP"},{"brand":"GATEWAY"},{"brand":"MAC"}]';

    String jsonString = parser.serialize(object);
    expect(expectedResult, jsonString);

    List<Computer> deserialized = parser.deserializeList<Computer>(jsonString);

    expect(deserialized, object);
  });
  //---------- Object via Annotation----------\\

  //---------- Field Name via Annotation----------\\
  test('Serialize/Deserialize - Mouse', () async {
    Mouse object = Mouse.named(brand: 'Logitech');

    String expectedResult = '{"mouse_brand":"Logitech"}';

    String jsonString = parser.serialize(object);
    expect(expectedResult, jsonString);

    Mouse deserialized = parser.deserialize<Mouse>(jsonString);

    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<Mouse>', () async {
    List<Mouse> object = [
      Mouse.named(brand: 'Logitech'),
      Mouse.named(brand: 'Gamer'),
      Mouse.named(brand: 'iMouse'),
    ];

    String expectedResult =
        '[{"mouse_brand":"Logitech"},{"mouse_brand":"Gamer"},{"mouse_brand":"iMouse"}]';

    String jsonString = parser.serialize(object);
    expect(expectedResult, jsonString);

    List<Mouse> deserialized = parser.deserializeList<Mouse>(jsonString);

    expect(deserialized, object);
  });
  //---------- Field Name via Annotation----------\\
  //---------- Object via Mirrors----------\\
  test('Serialize/Deserialize - Address', () async {
    Address object = Address.named(
      streetName: 'Main Street',
      houseNumber: 123,
    );

    String expectedResult = '{"street_name":"Main Street","house_number":123}';

    String jsonString = parser.serialize(object);
    expect(expectedResult, jsonString);

    Address deserialized = parser.deserialize<Address>(jsonString);

    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<Address>', () async {
    List<Address> object = [
      Address.named(
        streetName: 'Main Street 1',
        houseNumber: 1234,
      ),
      Address.named(
        streetName: 'Main Street 2',
        houseNumber: 1235,
      ),
      Address.named(
        streetName: 'Main Street 3',
        houseNumber: 1236,
      ),
    ];

    String expectedResult =
        '[{"street_name":"Main Street 1","house_number":1234},{"street_name":"Main Street 2","house_number":1235},{"street_name":"Main Street 3","house_number":1236}]';

    String jsonString = parser.serialize(object);
    expect(expectedResult, jsonString);

    List<Address> deserialized = parser.deserializeList<Address>(jsonString);

    expect(deserialized, object);
  });

  test('Serialize/Deserialize - User', () async {
    User object = User.named(
      userName: 'John Doe',
      userId: 1,
      duration: const Duration(days: 365),
      isActive: true,
      addresses: [
        Address.named(
          streetName: 'Main Street',
          houseNumber: 123,
        ),
        Address.named(
          streetName: 'Second Street',
          houseNumber: 456,
        ),
      ],
      singleAddress: Address.named(
        streetName: 'Third Street',
        houseNumber: 789,
      ),
      additionalAttributes: {
        'key1': 'value1',
        'key2': 42,
        'key3': true,
      },
    );

    String expectedResult = '''
    {
      "user_name": "John Doe",
      "user_id": 1,
      "duration": 31536000000,
      "is_active": true,
      "addresses": [
        {"street_name": "Main Street", "house_number": 123},
        {"street_name": "Second Street", "house_number": 456}
      ],
      "single_address": {"street_name": "Third Street", "house_number": 789},
      "additional_attributes": {
        "key1": "value1",
        "key2": 42,
        "key3": true
      }
    }
    ''';
    expectedResult = removeIndentation(expectedResult);

    String jsonString = parser.serialize(object);
    expect(expectedResult, jsonString);

    User deserialized = parser.deserialize<User>(jsonString);
    expect(deserialized, object);
  });

  test('Serialize/Deserialize - User', () async {
    User object = User.named(
      userName: 'John Doe',
      userId: 1,
      duration: const Duration(days: 365),
      isActive: true,
      addresses: [
        Address.named(
          streetName: 'Main Street',
          houseNumber: 123,
        ),
        Address.named(
          streetName: 'Second Street',
          houseNumber: 456,
        ),
      ],
      singleAddress: Address.named(
        streetName: 'Third Street',
        houseNumber: 789,
      ),
      additionalAttributes: {
        'key1': 'value1',
        'key2': 42,
        'key3': true,
      },
    );

    String expectedResult = '''
    {
      "user_name": "John Doe",
      "user_id": 1,
      "duration": 31536000000,
      "is_active": true,
      "addresses": [
        {"street_name": "Main Street", "house_number": 123},
        {"street_name": "Second Street", "house_number": 456}
      ],
      "single_address": {"street_name": "Third Street", "house_number": 789},
      "additional_attributes": {
        "key1": "value1",
        "key2": 42,
        "key3": true
      }
    }
    ''';
    expectedResult = removeIndentation(expectedResult);

    String jsonString = parser.serialize(object);
    expect(expectedResult, jsonString);

    User deserialized = parser.deserialize<User>(jsonString);
    expect(deserialized, object);
  });

  //---------- Maps ----------\\
  test('Serialize - Map<String, dynamic>', () async {
    Map<String, dynamic> object = {'name': 'John', 'age': 30, 'active': true};
    String result = '{"name":"John","age":30,"active":true}';
    String jsonString = parser.serialize(object);

    expect(jsonString, result);
  });

  test('Serialize - Map<String, String>', () async {
    Map<String, dynamic> object = {'name': 'John', 'age': '30', 'active': true};
    String result = '{"name":"John","age":"30","active":true}';
    String jsonString = parser.serialize(object);

    expect(jsonString, result);
  });

  //---------- Lists ----------\\
  test('Serialize/Deserialize - List<dynamic>', () async {
    List<dynamic> object = ['John', 30, 'active'];
    String expectedString = '["John",30,"active"]';
    String jsonString = parser.serialize(object);

    expect(expectedString, jsonString);

    List<dynamic> deserialized = parser.deserialize(jsonString);
    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<DateTime>', () async {
    List<DateTime> object = [
      DateTime(2023, 9, 1),
      DateTime(2024, 1, 1),
      DateTime(2025, 12, 31),
    ];
    String expectedResult =
        '["2023-09-01T00:00:00.000","2024-01-01T00:00:00.000","2025-12-31T00:00:00.000"]';
    String jsonString = parser.serialize(object);

    expect(expectedResult, jsonString);

    List<DateTime> deserialized = parser.deserializeList<DateTime>(jsonString);
    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<DateTime> (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        DateTime: (dynamic object) =>
            (object as DateTime).millisecondsSinceEpoch,
      },
      defaultDeserializerOverride: {
        DateTime: (dynamic value) => DateTime.fromMillisecondsSinceEpoch(value),
      },
      prettyPrint: false,
    );

    List<DateTime> object = [
      DateTime(2023, 9, 1),
      DateTime(2024, 1, 1),
      DateTime(2025, 12, 31),
    ];

    String jsonString = customParser.serialize(object);

    // Convert the list of DateTimes to a list of their millisecondsSinceEpoch
    String expectedSerializedResult =
        '[${object[0].millisecondsSinceEpoch},${object[1].millisecondsSinceEpoch},${object[2].millisecondsSinceEpoch}]';
    expect(jsonString, expectedSerializedResult);

    List<DateTime> deserialized =
        customParser.deserializeList<DateTime>(jsonString);
    expect(
      deserialized.map((d) => d.millisecondsSinceEpoch).toList(),
      object.map((d) => d.millisecondsSinceEpoch).toList(),
    );
  });

  test('Serialize/Deserialize - List<Duration>', () async {
    List<Duration> object = [
      const Duration(days: 1, hours: 5, minutes: 30),
      const Duration(hours: 10, minutes: 45),
      const Duration(seconds: 90),
    ];

    List<String> expectedResult =
        object.map((d) => d.inMilliseconds.toString()).toList();
    String jsonString = parser.serialize(object);

    expect(jsonString, '[${expectedResult.join(",")}]');

    List<Duration> deserialized = parser.deserializeList<Duration>(jsonString);

    expect(
      deserialized.map((d) => d.inMilliseconds).toList(),
      object.map((d) => d.inMilliseconds).toList(),
    );
  });

  test('Serialize/Deserialize - List<Duration> (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        Duration: (dynamic object) => (object as Duration).toString(),
      },
      defaultDeserializerOverride: {
        Duration: (dynamic value) {
          List<String> parts = (value as String).split('.');

          // Obtiene la parte de horas, minutos, segundos
          List<String> timeParts = parts[0].split(':');
          int hours = int.parse(timeParts[0]);
          int minutes = int.parse(timeParts[1]);
          int seconds = int.parse(timeParts[2]);

          // Obtiene la parte de milisegundos si existe
          int milliseconds = parts.length > 1 ? int.parse(parts[1]) : 0;

          return Duration(
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds ~/ 1000,
          );
        },
      },
      prettyPrint: false,
    );

    List<Duration> object = [
      const Duration(days: 1, hours: 5, minutes: 30),
      const Duration(hours: 10, minutes: 45),
      const Duration(seconds: 90),
    ];

    // Serializa las duraciones en el formato "hh:mm:ss.mmm"
    List<String> expectedSerializedResult =
        object.map((d) => d.toString()).toList();
    String jsonString = customParser.serialize(object);

    expect(
      jsonString,
      '[${expectedSerializedResult.map((e) => '"$e"').join(",")}]',
    );

    List<Duration> deserialized =
        customParser.deserializeList<Duration>(jsonString);
    expect(
      deserialized.map((d) => d.inMilliseconds).toList(),
      object.map((d) => d.inMilliseconds).toList(),
    );
  });

  //TODO: URI & REGEX
  test('Serialize - List<String>', () async {
    List<String> object = ['John', '30', 'active'];
    String expectedResult = '["John","30","active"]';
    String jsonString = parser.serialize(object);

    expect(expectedResult, jsonString);

    List<String> deserialized = parser.deserializeList<String>(jsonString);
    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<String> (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        String: (dynamic object) => object.toString().toUpperCase(),
      },
      defaultDeserializerOverride: {
        String: (dynamic value) => value.toString().toLowerCase(),
      },
      prettyPrint: false,
    );

    List<String> object = ['hello', 'world'];
    String expectedResult = '["HELLO","WORLD"]';
    String jsonString = customParser.serialize(object);

    expect(expectedResult, jsonString);

    List<String> deserialized =
        customParser.deserializeList<String>(jsonString);
    expect(deserialized, object.map((e) => e.toLowerCase()).toList());
  });

  test('Serialize/Deserialize - List<num>', () async {
    List<num> object = [1, 2.5, 3, 4.75];
    String expectedResult = '[1,2.5,3,4.75]';
    String jsonString = parser.serialize(object);

    expect(expectedResult, jsonString);

    List<num> deserialized = parser.deserializeList<num>(jsonString);
    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<num> (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        num: (dynamic object) => object.toString(),
      },
      defaultDeserializerOverride: {
        num: (dynamic value) => num.parse(value.toString()),
      },
      prettyPrint: false,
    );

    List<num> object = [123, 456.78, -90.12, 0];

    List<String> expectedSerializedResult =
        object.map((n) => n.toString()).toList();
    String jsonString = customParser.serialize(object);

    expect(jsonString, '[${expectedSerializedResult.join(",")}]');

    List<num> deserialized = customParser.deserializeList<num>(jsonString);
    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<int>', () async {
    List<int> object = [1, 2, 3, 4, 5];
    String expectedResult = '[1,2,3,4,5]';
    String jsonString = parser.serialize(object);

    expect(expectedResult, jsonString);

    List<int> deserialized = parser.deserializeList<int>(jsonString);
    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<int> (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        int: (dynamic object) => (object as int).toString(),
      },
      defaultDeserializerOverride: {
        int: (dynamic value) => int.parse(value),
      },
      prettyPrint: false,
    );

    List<int> object = [42, 100, 5];
    String jsonString = customParser.serialize(object);

    List<int> deserialized = customParser.deserializeList<int>(jsonString);
    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<double>', () async {
    List<double> object = [1.1, 2.2, 3.3, 4.4, 5.5];
    String expectedResult = '[1.1,2.2,3.3,4.4,5.5]';
    String jsonString = parser.serialize(object);

    expect(expectedResult, jsonString);

    List<double> deserialized = parser.deserializeList<double>(jsonString);
    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<double> (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        double: (dynamic object) => (object as double).toStringAsFixed(5),
      },
      defaultDeserializerOverride: {
        double: (dynamic value) => double.parse(value),
      },
      prettyPrint: false,
    );

    List<double> object = [42.42, 100.99, 3.14159];
    String jsonString = customParser.serialize(object);

    List<double> deserialized =
        customParser.deserializeList<double>(jsonString);
    expect(deserialized, object);
  });
  test('Serialize/Deserialize - List<bool>', () async {
    List<bool> object = [true, false, true, true];
    String expectedResult = '[true,false,true,true]';
    String jsonString = parser.serialize(object);

    expect(expectedResult, jsonString);

    List<bool> deserialized = parser.deserializeList<bool>(jsonString);
    expect(deserialized, object);
  });

  test('Serialize/Deserialize - List<bool> (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        bool: (dynamic object) => (object as bool) ? 'yes' : 'no',
      },
      defaultDeserializerOverride: {
        bool: (dynamic value) => value == 'yes',
      },
      prettyPrint: false,
    );

    List<bool> object = [true, false, true];
    String expectedString = '["yes","no","yes"]';
    String jsonString = customParser.serialize(object);

    expect(expectedString, jsonString);

    List<bool> deserialized = customParser.deserializeList<bool>(jsonString);
    expect(deserialized, object);
  });

  //---------- Single types ----------\\
  test('Serialize/Deserialize: DateTime', () async {
    DateTime object = DateTime.now();
    String expectedString = object.toIso8601String();
    String jsonString = parser.serialize(object);

    expect(expectedString, jsonString);

    DateTime deserializedObject = parser.deserialize<DateTime>(jsonString);
    expect(deserializedObject.toIso8601String(), object.toIso8601String());
  });

  test('Serialize/Deserialize: DateTime (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        DateTime: (dynamic object) =>
            (object as DateTime).millisecondsSinceEpoch,
      },
      defaultDeserializerOverride: {
        DateTime: (dynamic value) =>
            DateTime.fromMillisecondsSinceEpoch(int.parse(value)),
      },
    );

    DateTime object = DateTime.now();
    String expectedString = '${object.millisecondsSinceEpoch}';
    String jsonString = customParser.serialize(object);

    expect(expectedString, jsonString);

    DateTime deserializedObject =
        customParser.deserialize<DateTime>(jsonString);

    expect(
      deserializedObject.millisecondsSinceEpoch,
      object.millisecondsSinceEpoch,
    );
  });

  test('Serialize/Deserialize: Duration', () async {
    Duration object = const Duration(days: 365);
    int rawResult = object.inMilliseconds;
    String result = rawResult.toString();
    String jsonString = parser.serialize(object);

    expect(jsonString, result);

    Duration duration = parser.deserialize<Duration>(jsonString);
    expect(object.inMilliseconds, duration.inMilliseconds);
  });

  test('Serialize/Deserialize: Duration (Custom Parser)', () async {
    //use custom parser to double
    ObjectMapperImpl parser = ObjectMapperImpl(
      defaultSerializerOverride: {
        Duration: (dynamic object) => (object as Duration).toString(),
      },
      defaultDeserializerOverride: {
        Duration: (dynamic value) {
          List<String> parts = (value as String).split('.');

          // Obtiene la parte de horas, minutos, segundos
          List<String> timeParts = parts[0].split(':');
          int hours = int.parse(timeParts[0]);
          int minutes = int.parse(timeParts[1]);
          int seconds = int.parse(timeParts[2]);

          // Obtiene la parte de milisegundos si existe
          int milliseconds = parts.length > 1 ? int.parse(parts[1]) : 0;

          Duration d = Duration(
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds ~/ 1000,
          );
          return d;
        },
      },
    );

    Duration object =
        const Duration(days: 5, hours: 3, seconds: 20, milliseconds: 850);

    String expectedSerializedResult = object.toString();
    String jsonString = parser.serialize(object);

    expect(jsonString, expectedSerializedResult);

    Duration duration = parser.deserialize<Duration>(jsonString);
    expect(object.inMilliseconds, duration.inMilliseconds);
  });

  test('Serialize/Deserialize: Uri', () async {
    Uri object = Uri.parse('https://google.com');

    String expectedResult = object.toString();

    String jsonString = parser.serialize(object);

    expect(jsonString, expectedResult);

    Uri uri = Uri.parse(jsonString);
    expect(uri.toString(), object.toString());
  });

  test('Serialize/Deserialize: Uri (Custom Parser)', () async {
    //Can't think in a custom serializer for uri
  });

  test('Serialize/Deserialize: RegExp', () async {
    RegExp object = RegExp(r'^[a-zA-Z0-9]+$');
    String jsonString = parser.serialize(object);

    RegExp deserializedObject = parser.deserialize<RegExp>(jsonString);
    expect(deserializedObject.pattern, object.pattern);
  });

  test('Serialize/Deserialize: RegExp (Custom Parser)', () async {
    //Can't think in a custom serializer for regex
  });

  test('Serialize/Deserialize: String', () async {
    String object = 'Hello, world!';
    String expectedString = 'Hello, world!';
    String jsonString = parser.serialize(object);

    expect(expectedString, jsonString);

    String deserializedObject = parser.deserialize<String>(jsonString);
    expect(deserializedObject, object);
  });

  test('Serialize/Deserialize: String (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        String: (dynamic object) => object.toString().toUpperCase(),
      },
      defaultDeserializerOverride: {
        String: (dynamic value) => value.toString().toLowerCase(),
      },
    );

    String object = 'Hello, World!'.toLowerCase();
    String expectedString = 'Hello, world!'.toUpperCase();
    String jsonString = customParser.serialize(object);
    expect(expectedString, jsonString);

    String deserializedObject = customParser.deserialize<String>(jsonString);
    expect(deserializedObject, object.toLowerCase());
  });

  test('Serialize/Deserialize: num', () async {
    num object = 123.45;
    String expectedNum = '123.45';
    String jsonString = parser.serialize(object);
    expect(expectedNum, jsonString);

    num deserializedObject = parser.deserialize<num>(jsonString);
    expect(deserializedObject, object);
  });

  test('Serialize/Deserialize: num (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        num: (dynamic object) => (object as num).toString(),
      },
      defaultDeserializerOverride: {
        num: (dynamic value) => num.parse(value),
      },
    );

    num object = 123.45;
    String expectedNum = '123.45';
    String jsonString = customParser.serialize(object);
    expect(expectedNum, jsonString);

    num deserializedObject = customParser.deserialize<num>(jsonString);
    expect(deserializedObject, object);
  });

  test('Serialize/Deserialize: int', () async {
    int object = 42;
    String expectedNum = '42';
    String jsonString = parser.serialize(object);
    expect(expectedNum, jsonString);

    int deserializedObject = parser.deserialize<int>(jsonString);
    expect(deserializedObject, object);
  });

  test('Serialize/Deserialize: int (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        int: (dynamic object) => (object as int).toString(),
      },
      defaultDeserializerOverride: {
        int: (dynamic value) => int.parse(value),
      },
    );

    int object = 42;
    String jsonString = customParser.serialize(object);

    int deserializedObject = customParser.deserialize<int>(jsonString);
    expect(deserializedObject, object);
  });

  test('Serialize/Deserialize: double', () async {
    double object = 42.42;
    String expectedString = '42.42';
    String jsonString = parser.serialize(object);
    expect(expectedString, jsonString);

    double deserializedObject = parser.deserialize<double>(jsonString);
    expect(deserializedObject, object);
  });

  test('Serialize/Deserialize: double (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        double: (dynamic object) => (object as double).toStringAsFixed(5),
      },
      defaultDeserializerOverride: {
        double: (dynamic value) => double.parse(value),
      },
    );

    double object = 42.4200;
    String expectedString = '42.42000';
    String jsonString = customParser.serialize(object);
    expect(expectedString, jsonString);

    double deserializedObject = customParser.deserialize<double>(jsonString);
    expect(deserializedObject, object);
  });

  test('Serialize/Deserialize: bool', () async {
    bool object = true;
    String expectedString = 'true';
    String jsonString = parser.serialize(object);
    expect(expectedString, jsonString);

    bool deserializedObject = parser.deserialize<bool>(jsonString);
    expect(deserializedObject, object);
  });

  test('Serialize/Deserialize: bool (Custom Parser)', () async {
    ObjectMapperImpl customParser = ObjectMapperImpl(
      defaultSerializerOverride: {
        bool: (dynamic object) => (object as bool) ? 'yes' : 'no',
      },
      defaultDeserializerOverride: {
        bool: (dynamic value) => value == 'yes',
      },
    );

    bool object = true;
    String expectedString = 'yes';
    String jsonString = customParser.serialize(object);
    expect(expectedString, jsonString);

    bool deserializedObject = customParser.deserialize<bool>(jsonString);
    expect(deserializedObject, object);
  });
}

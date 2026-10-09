import 'package:winter/winter.dart';

/// A JSON Schema (the dialect of OpenAPI 3.1) of a body, written by hand when the one inferred
/// from an example isn't precise enough:
///
/// ```dart
/// JsonSchema.object({
///   'amount': JsonSchema.number(minimum: 0.01),
///   'currency': JsonSchema.string(enumValues: ['EUR', 'USD']),
///   'note': JsonSchema.string(maxLength: 200, nullable: true),
/// }, required: ['amount', 'currency'])
/// ```
///
/// {@category OpenAPI}
final class JsonSchema {
  final Map<String, Object?> _json;

  JsonSchema._(this._json);

  /// A schema written as JSON, for what the constructors don't cover (`oneOf`, `$ref`...)
  JsonSchema.raw(Map<String, Object?> json) : _json = Map.of(json);

  /// Any value
  JsonSchema.any({String? description}) : _json = {'description': ?description};

  /// A string; [format] is a JSON Schema format (`email`, `uri`, `uuid`, `date-time`...)
  JsonSchema.string({
    int? minLength,
    int? maxLength,
    String? pattern,
    String? format,
    List<String>? enumValues,
    String? description,
    Object? example,
    bool nullable = false,
  }) : _json = _typed('string', nullable, {
         'minLength': ?minLength,
         'maxLength': ?maxLength,
         'pattern': ?pattern,
         'format': ?format,
         'enum': ?enumValues,
         'description': ?description,
         'example': ?example,
       });

  /// An integer
  JsonSchema.integer({
    num? minimum,
    num? maximum,
    num? exclusiveMinimum,
    num? exclusiveMaximum,
    List<int>? enumValues,
    String? description,
    Object? example,
    bool nullable = false,
  }) : _json = _typed('integer', nullable, {
         'minimum': ?minimum,
         'maximum': ?maximum,
         'exclusiveMinimum': ?exclusiveMinimum,
         'exclusiveMaximum': ?exclusiveMaximum,
         'enum': ?enumValues,
         'description': ?description,
         'example': ?example,
       });

  /// A number
  JsonSchema.number({
    num? minimum,
    num? maximum,
    num? exclusiveMinimum,
    num? exclusiveMaximum,
    String? description,
    Object? example,
    bool nullable = false,
  }) : _json = _typed('number', nullable, {
         'minimum': ?minimum,
         'maximum': ?maximum,
         'exclusiveMinimum': ?exclusiveMinimum,
         'exclusiveMaximum': ?exclusiveMaximum,
         'description': ?description,
         'example': ?example,
       });

  /// A boolean
  JsonSchema.boolean({String? description, bool nullable = false})
    : _json = _typed('boolean', nullable, {'description': ?description});

  /// An array of [items]
  JsonSchema.array(
    JsonSchema items, {
    int? minItems,
    int? maxItems,
    bool uniqueItems = false,
    String? description,
    bool nullable = false,
  }) : _json = _typed('array', nullable, {
         'items': items._json,
         'minItems': ?minItems,
         'maxItems': ?maxItems,
         if (uniqueItems) 'uniqueItems': true,
         'description': ?description,
       });

  /// An object with [properties] (by their JSON names); the ones in [required] must be there
  JsonSchema.object(
    Map<String, JsonSchema> properties, {
    List<String> required = const [],
    bool additionalProperties = true,
    String? description,
    bool nullable = false,
  }) : _json = _typed('object', nullable, {
         'properties': {
           for (final MapEntry(:key, :value) in properties.entries)
             key: value._json,
         },
         if (required.isNotEmpty) 'required': required,
         if (!additionalProperties) 'additionalProperties': false,
         'description': ?description,
       });

  /// An object used as a map: any key, every value a [values]
  JsonSchema.map(
    JsonSchema values, {
    String? description,
    bool nullable = false,
  }) : _json = _typed('object', nullable, {
         'additionalProperties': values._json,
         'description': ?description,
       });

  static Map<String, Object?> _typed(
    String type,
    bool nullable,
    Map<String, Object?> rest,
  ) => {
    'type': nullable ? [type, 'null'] : type,
    ...rest,
  };

  /// The schema of the JSON value [json] (what the object mapper writes for an example): its
  /// types, objects and arrays, the first element giving the items of an array, and a string with
  /// a date and a time as `date-time`. A `null` says nothing of its type.
  factory JsonSchema.fromExample(Object? json) => JsonSchema._(_infer(json));

  static final RegExp _dateTime = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:?\d{2})?$',
  );

  /// The first element that isn't null (a `firstWhere` with an `orElse` returning null would fail
  /// on a `List<String>`)
  static Object? _firstNotNull(List<Object?> list) {
    for (final Object? element in list) {
      if (element != null) return element;
    }
    return null;
  }

  static Map<String, Object?> _infer(Object? json) => switch (json) {
    null => {},
    bool() => {'type': 'boolean'},
    int() => {'type': 'integer'},
    num() => {'type': 'number'},
    String() when _dateTime.hasMatch(json) => {
      'type': 'string',
      'format': 'date-time',
    },
    String() => {'type': 'string'},
    List() => {'type': 'array', 'items': _infer(_firstNotNull(json))},
    Map() => {
      'type': 'object',
      'properties': {
        for (final MapEntry(:key, :value) in json.entries)
          '$key': _infer(value),
      },
    },
    _ => {},
  };

  /// This schema with the constraints of [rules] (the rules of a `validate()`, see
  /// `validationRulesOf`), applied to the fields they name: `notNull` makes it required,
  /// `email` a format, `size` a length... Their fields are paths with the Dart names, converted
  /// to the JSON ones by [mapper]. A rule of a field the schema doesn't have is ignored.
  JsonSchema withRules(List<ConstraintViolation> rules, ObjectMapper mapper) {
    final Map<String, Object?> json = _deepCopy(_json) as Map<String, Object?>;
    for (final ConstraintViolation rule in rules) {
      final List<String> path = _steps(mapper.jsonFieldName(rule.fieldName));
      if (path.isEmpty) continue;
      final Map<String, Object?>? parent = _at(
        json,
        path.sublist(0, path.length - 1),
      );
      final String last = path.last;
      final Map<String, Object?>? field = _child(parent, last);
      if (parent == null || field == null) continue;
      _apply(rule, parent, last, field);
    }
    return JsonSchema._(json);
  }

  static void _apply(
    ConstraintViolation rule,
    Map<String, Object?> parent,
    String name,
    Map<String, Object?> field,
  ) {
    final Object? value = rule.params['value'];
    final String kind = switch (field['type']) {
      final List<Object?> types => '${types.first}',
      final Object? type => '$type',
    };
    String length(String suffix) => switch (kind) {
      'array' => '${suffix}Items',
      'object' => '${suffix}Properties',
      _ => '${suffix}Length',
    };
    switch (rule.code) {
      case 'notNull':
        if (!name.startsWith('[')) {
          final List<Object?> required = [
            ...?(parent['required'] as List<Object?>?),
          ];
          if (!required.contains(name)) {
            parent['required'] = required..add(name);
          }
        }
      case 'notBlank':
        field['minLength'] = 1;
      case 'notEmpty':
        field[length('min')] = 1;
      case 'size.min':
        field[length('min')] = value;
      case 'size.max':
        field[length('max')] = value;
      case 'email':
        field['format'] = 'email';
      case 'url':
        field['format'] = 'uri';
      case 'uuid':
        field['format'] = 'uuid';
      case 'pattern':
        if (rule.params['pattern'] != null) {
          field['pattern'] = rule.params['pattern'];
        }
      case 'min.inclusive':
        field['minimum'] = value;
      case 'min.exclusive':
        field['exclusiveMinimum'] = value;
      case 'max.inclusive':
        field['maximum'] = value;
      case 'max.exclusive':
        field['exclusiveMaximum'] = value;
      case 'positive':
        field['exclusiveMinimum'] = 0;
      case 'positiveOrZero':
        field['minimum'] = 0;
      case 'negative':
        field['exclusiveMaximum'] = 0;
      case 'negativeOrZero':
        field['maximum'] = 0;
      case 'oneOf' || 'isEnum':
        field['enum'] = rule.params['values'];
    }
  }

  /// `items[0].unit_price` → `items`, `[0]`, `unit_price`; `prices["eur"]` → `prices`, `["eur"]`
  static List<String> _steps(String path) => [
    for (final Match match in _step.allMatches(path)) match[0]!,
  ];

  static final RegExp _step = RegExp(
    r'\["(?:[^"\\]|\\.)*"\]|\[\d+\]|[^.\[\]]+',
  );

  static Map<String, Object?>? _at(
    Map<String, Object?> root,
    List<String> steps,
  ) {
    Map<String, Object?>? current = root;
    for (final String step in steps) {
      current = _child(current, step);
      if (current == null) return null;
    }
    return current;
  }

  /// The schema of the step [step] inside [schema]: a property, the items of an array, or the
  /// values of a map
  static Map<String, Object?>? _child(
    Map<String, Object?>? schema,
    String step,
  ) {
    if (schema == null) return null;
    if (step.startsWith('[') && !step.startsWith('["')) {
      return schema['items'] as Map<String, Object?>?;
    }
    final String key = step.startsWith('["')
        ? step.substring(2, step.length - 2)
        : step;
    final Object? property =
        (schema['properties'] as Map<String, Object?>?)?[key];
    if (property is Map<String, Object?>) return property;
    final Object? values = schema['additionalProperties'];
    return values is Map<String, Object?> ? values : null;
  }

  static Object? _deepCopy(Object? json) => switch (json) {
    final Map<String, Object?> map => {
      for (final MapEntry(:key, :value) in map.entries) key: _deepCopy(value),
    },
    final List<Object?> list => [for (final e in list) _deepCopy(e)],
    _ => json,
  };

  /// The schema as JSON (a copy)
  Map<String, Object?> toJson() => _deepCopy(_json) as Map<String, Object?>;

  @override
  String toString() => 'JsonSchema$_json';
}

import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

enum _Color { red, green }

/// A failing validation: the rule, the value that breaks it, and its message in every locale
class _Case {
  final String name;
  final void Function(ConstraintValidator validator) rule;
  final Object? value;
  final String en;
  final String es;

  const _Case(
    this.name,
    this.rule, {
    required this.value,
    required this.en,
    required this.es,
  });

  ConstrainViolation violation() {
    final cvc = ConstraintValidatorContext();
    final validator = cvc.buildValidator('field');
    rule(validator);
    validator.validate(value);
    return cvc.violations.single;
  }
}

final List<_Case> _cases = [
  _Case(
    'notNull',
    (v) => v.notNull(),
    value: null,
    en: 'The field cannot be null',
    es: 'El campo no puede ser null',
  ),
  _Case(
    'notBlank: empty',
    (v) => v.notBlank(),
    value: '',
    en: 'The field cannot be blank',
    es: 'El campo no puede estar vacío',
  ),
  _Case(
    'notBlank: only whitespace',
    (v) => v.notBlank(),
    value: '   ',
    en: 'The field cannot be blank',
    es: 'El campo no puede estar vacío',
  ),
  _Case(
    'notBlank: not a String',
    (v) => v.notBlank(),
    value: 5,
    en: 'The field cannot be blank',
    es: 'El campo no puede estar vacío',
  ),
  _Case(
    'size: min of a String',
    (v) => v.size(min: 3),
    value: 'ab',
    en: 'The minimum is 3',
    es: 'El mínimo es 3',
  ),
  _Case(
    'size: max of a String',
    (v) => v.size(max: 2),
    value: 'abc',
    en: 'The maximum is 2',
    es: 'El máximo es 2',
  ),
  _Case(
    'size: min of an Iterable',
    (v) => v.size(min: 2),
    value: [1],
    en: 'The minimum is 2',
    es: 'El mínimo es 2',
  ),
  _Case(
    'size: max of an Iterable',
    (v) => v.size(max: 1),
    value: {1, 2},
    en: 'The maximum is 1',
    es: 'El máximo es 1',
  ),
  _Case(
    'size: invalid type',
    (v) => v.size(min: 1),
    value: 5,
    en: 'The value must be a String or Iterable',
    es: 'El valor debe ser un String o un Iterable',
  ),
  _Case(
    'email: invalid',
    (v) => v.email(),
    value: 'not-an-email',
    en: 'The value is not a valid email',
    es: 'El valor no es un email válido',
  ),
  _Case(
    'email: not a String',
    (v) => v.email(),
    value: 1,
    en: 'The value must be a String',
    es: 'El valor debe ser un String',
  ),
  _Case(
    'min: inclusive',
    (v) => v.min(3),
    value: 2,
    en: 'The minimum is 3',
    es: 'El mínimo es 3',
  ),
  _Case(
    'min: exclusive',
    (v) => v.min(3, inclusive: false),
    value: 3,
    en: 'The value must be greater than 3',
    es: 'El valor debe ser mayor que 3',
  ),
  _Case(
    'min: decimal',
    (v) => v.min(0.5),
    value: 0.1,
    en: 'The minimum is 0.5',
    es: 'El mínimo es 0.5',
  ),
  _Case(
    'min: not a number',
    (v) => v.min(1),
    value: '5',
    en: 'The value must be a number',
    es: 'El valor debe ser un número',
  ),
  _Case(
    'max: inclusive',
    (v) => v.max(3),
    value: 4,
    en: 'The maximum is 3',
    es: 'El máximo es 3',
  ),
  _Case(
    'max: exclusive',
    (v) => v.max(3, inclusive: false),
    value: 3,
    en: 'The value must be less than 3',
    es: 'El valor debe ser menor que 3',
  ),
  _Case(
    'max: decimal',
    (v) => v.max(2.5),
    value: 3,
    en: 'The maximum is 2.5',
    es: 'El máximo es 2.5',
  ),
  _Case(
    'max: not a number',
    (v) => v.max(1),
    value: true,
    en: 'The value must be a number',
    es: 'El valor debe ser un número',
  ),
  _Case(
    'pattern: no match',
    (v) => v.pattern(r'^\d+$'),
    value: 'abc',
    en: 'The value has an invalid format',
    es: 'El valor tiene un formato no válido',
  ),
  _Case(
    'pattern: not a String',
    (v) => v.pattern(r'^\d+$'),
    value: 123,
    en: 'The value must be a String',
    es: 'El valor debe ser un String',
  ),
  _Case(
    'isEnum: by name',
    (v) => v.isEnum(_Color.values),
    value: 'blue',
    en: 'The value must be one of: red, green',
    es: 'El valor debe ser uno de: red, green',
  ),
  _Case(
    'isEnum: with resolver',
    (v) => v.isEnum(_Color.values, resolver: (c) => c.index),
    value: 7,
    en: 'The value must be one of: 0, 1',
    es: 'El valor debe ser uno de: 0, 1',
  ),
];

void main() {
  const english = WinterLocale.english;
  const spanish = WinterLocale.spanish;

  group('Every validator in every locale', () {
    for (final c in _cases) {
      group(c.name, () {
        test('message is always English', () {
          expect(c.violation().message, c.en);
        });

        test('en', () {
          expect(c.violation().messageFor(english), c.en);
        });

        test('es', () {
          expect(c.violation().messageFor(spanish), c.es);
        });

        test('a region uses its language (es-MX)', () {
          expect(
            c.violation().messageFor(const WinterLocale('es', 'MX')),
            c.es,
          );
        });

        test('a language without translations uses English (fr)', () {
          expect(c.violation().messageFor(const WinterLocale('fr')), c.en);
        });

        test('it is translatable (has localizedMessage)', () {
          expect(c.violation().localizedMessage, isNotNull);
        });
      });
    }
  });

  group('A custom message is used as is in every locale', () {
    final List<(String, void Function(ConstraintValidator), Object?)> rules = [
      ('notNull', (v) => v.notNull(message: 'Custom'), null),
      ('notBlank', (v) => v.notBlank(message: 'Custom'), ''),
      ('size', (v) => v.size(min: 3, message: 'Custom'), 'ab'),
      ('email', (v) => v.email(message: 'Custom'), 'x'),
      ('min', (v) => v.min(3, message: 'Custom'), 1),
      ('max', (v) => v.max(0, message: 'Custom'), 1),
      ('pattern', (v) => v.pattern(r'^\d+$', message: 'Custom'), 'x'),
      ('isEnum', (v) => v.isEnum(_Color.values, message: 'Custom'), 'x'),
    ];

    for (final (name, rule, value) in rules) {
      test(name, () {
        final cvc = ConstraintValidatorContext();
        final validator = cvc.buildValidator('field');
        rule(validator);
        validator.validate(value);
        final violation = cvc.violations.single;

        expect(violation.message, 'Custom');
        expect(violation.messageFor(spanish), 'Custom');
      });
    }
  });

  group('422 with every validator', () {
    late LocaleConfig previous;
    late WinterTestClient client;

    setUpAll(() {
      previous = Winter.context.localeConfig;
      Winter.context.setUp(
        localeConfig: LocaleConfig(supported: [english, spanish]),
      );
      client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.post(
              path: '/validate',
              handler: (request) async {
                final cvc = ConstraintValidatorContext();
                for (var i = 0; i < _cases.length; i++) {
                  final validator = cvc.buildValidator('field$i');
                  _cases[i].rule(validator);
                  validator.validate(_cases[i].value);
                }
                cvc.throwOnFailure();
                return ResponseEntity.ok();
              },
            ),
          ],
        ),
      );
    });

    tearDownAll(() => Winter.context.setUp(localeConfig: previous));

    Future<List<Map<String, dynamic>>> violations(
      String? acceptLanguage,
    ) async {
      final response = await client.post(
        '/validate',
        headers: {HttpHeader.acceptLanguage: ?acceptLanguage},
      );
      expect(response.statusCode, 422);
      expect(response.headers[HttpHeader.vary], HttpHeader.acceptLanguage);
      return [
        for (final v in jsonDecode(response.body) as List)
          v as Map<String, dynamic>,
      ];
    }

    test('Without header: every message in English', () async {
      final body = await violations(null);
      expect(body.map((v) => v['message']), [for (final c in _cases) c.en]);
    });

    test('Accept-Language: es: every message in Spanish', () async {
      final body = await violations('es');
      expect(body.map((v) => v['message']), [for (final c in _cases) c.es]);
      expect(body.map((v) => v['fieldName']), [
        for (var i = 0; i < _cases.length; i++) 'field$i',
      ]);
    });

    test('Accept-Language: fr, es;q=0.5: Spanish', () async {
      final body = await violations('fr, es;q=0.5');
      expect(body.map((v) => v['message']), [for (final c in _cases) c.es]);
    });
  });
}

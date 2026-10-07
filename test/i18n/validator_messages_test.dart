import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

enum _Color { red, green }

/// A failing validation: the rule (with the value that breaks it), and its message in every locale
class _Case {
  final String name;
  final void Function(ConstraintValidatorContext cvc, String field) rule;
  final String en;
  final String es;

  const _Case(this.name, this.rule, {required this.en, required this.es});

  /// The violation when validating in a request in [locale]
  ConstraintViolation violation([WinterLocale locale = WinterLocale.english]) =>
      RequestScope.run(RequestScope(locale: locale), () {
        final cvc = ConstraintValidatorContext();
        rule(cvc, 'field');
        return cvc.violations.single;
      });
}

final List<_Case> _cases = [
  _Case(
    'notNull',
    (cvc, f) => cvc.field(f, null).notNull(),
    en: 'The field cannot be null',
    es: 'El campo no puede ser null',
  ),
  _Case(
    'notBlank: empty',
    (cvc, f) => cvc.field(f, '').notBlank(),
    en: 'The field cannot be blank',
    es: 'El campo no puede estar vacío',
  ),
  _Case(
    'notBlank: only whitespace',
    (cvc, f) => cvc.field(f, '   ').notBlank(),
    en: 'The field cannot be blank',
    es: 'El campo no puede estar vacío',
  ),
  _Case(
    'size: min of a String',
    (cvc, f) => cvc.field(f, 'ab').size(min: 3),
    en: 'The minimum is 3',
    es: 'El mínimo es 3',
  ),
  _Case(
    'size: max of a String',
    (cvc, f) => cvc.field(f, 'abc').size(max: 2),
    en: 'The maximum is 2',
    es: 'El máximo es 2',
  ),
  _Case(
    'size: min of an Iterable',
    (cvc, f) => cvc.field(f, [1]).size(min: 2),
    en: 'The minimum is 2',
    es: 'El mínimo es 2',
  ),
  _Case(
    'size: max of an Iterable',
    (cvc, f) => cvc.field(f, {1, 2}).size(max: 1),
    en: 'The maximum is 1',
    es: 'El máximo es 1',
  ),
  _Case(
    'email: invalid',
    (cvc, f) => cvc.field(f, 'not-an-email').email(),
    en: 'The value is not a valid email',
    es: 'El valor no es un email válido',
  ),
  _Case(
    'min: inclusive',
    (cvc, f) => cvc.field(f, 2).min(3),
    en: 'The minimum is 3',
    es: 'El mínimo es 3',
  ),
  _Case(
    'min: exclusive',
    (cvc, f) => cvc.field(f, 3).min(3, inclusive: false),
    en: 'The value must be greater than 3',
    es: 'El valor debe ser mayor que 3',
  ),
  _Case(
    'min: decimal',
    (cvc, f) => cvc.field(f, 0.1).min(0.5),
    en: 'The minimum is 0.5',
    es: 'El mínimo es 0.5',
  ),
  _Case(
    'max: inclusive',
    (cvc, f) => cvc.field(f, 4).max(3),
    en: 'The maximum is 3',
    es: 'El máximo es 3',
  ),
  _Case(
    'max: exclusive',
    (cvc, f) => cvc.field(f, 3).max(3, inclusive: false),
    en: 'The value must be less than 3',
    es: 'El valor debe ser menor que 3',
  ),
  _Case(
    'max: decimal',
    (cvc, f) => cvc.field(f, 3).max(2.5),
    en: 'The maximum is 2.5',
    es: 'El máximo es 2.5',
  ),
  _Case(
    'pattern: no match',
    (cvc, f) => cvc.field(f, 'abc').pattern(r'^\d+$'),
    en: 'The value has an invalid format',
    es: 'El valor tiene un formato no válido',
  ),
  _Case(
    'isEnum: by name',
    (cvc, f) => cvc.field(f, 'blue').isEnum(_Color.values),
    en: 'The value must be one of: red, green',
    es: 'El valor debe ser uno de: red, green',
  ),
  _Case(
    'isEnum: with resolver',
    (cvc, f) => cvc.field(f, 7).isEnum(_Color.values, resolver: (c) => c.index),
    en: 'The value must be one of: 0, 1',
    es: 'El valor debe ser uno de: 0, 1',
  ),
  _Case(
    'size: max of a Map',
    (cvc, f) => cvc.field(f, {'a': 1, 'b': 2}).size(max: 1),
    en: 'The maximum is 1',
    es: 'El máximo es 1',
  ),
  _Case(
    'notEmpty: a list',
    (cvc, f) => cvc.field(f, <int>[]).notEmpty(),
    en: 'The field cannot be empty',
    es: 'El campo no puede estar vacío',
  ),
  _Case(
    'notEmpty: a map',
    (cvc, f) => cvc.field(f, <String, int>{}).notEmpty(),
    en: 'The field cannot be empty',
    es: 'El campo no puede estar vacío',
  ),
  _Case(
    'oneOf',
    (cvc, f) => cvc.field(f, 'c').oneOf(['a', 'b']),
    en: 'The value must be one of: a, b',
    es: 'El valor debe ser uno de: a, b',
  ),
  _Case(
    'url',
    (cvc, f) => cvc.field(f, 'not a url').url(),
    en: 'The value is not a valid URL',
    es: 'El valor no es una URL válida',
  ),
  _Case(
    'uuid',
    (cvc, f) => cvc.field(f, '1234').uuid(),
    en: 'The value is not a valid UUID',
    es: 'El valor no es un UUID válido',
  ),
  _Case(
    'positive',
    (cvc, f) => cvc.field(f, 0).positive(),
    en: 'The value must be greater than 0',
    es: 'El valor debe ser mayor que 0',
  ),
  _Case(
    'positiveOrZero',
    (cvc, f) => cvc.field(f, -1).positiveOrZero(),
    en: 'The value must be 0 or greater',
    es: 'El valor debe ser 0 o mayor',
  ),
  _Case(
    'negative',
    (cvc, f) => cvc.field(f, 0).negative(),
    en: 'The value must be less than 0',
    es: 'El valor debe ser menor que 0',
  ),
  _Case(
    'negativeOrZero',
    (cvc, f) => cvc.field(f, 1).negativeOrZero(),
    en: 'The value must be 0 or less',
    es: 'El valor debe ser 0 o menor',
  ),
  _Case(
    'past',
    (cvc, f) => cvc.field(f, DateTime(3000)).past(),
    en: 'The date must be in the past',
    es: 'La fecha debe estar en el pasado',
  ),
  _Case(
    'pastOrPresent',
    (cvc, f) => cvc.field(f, DateTime(3000)).pastOrPresent(),
    en: 'The date cannot be in the future',
    es: 'La fecha no puede estar en el futuro',
  ),
  _Case(
    'future',
    (cvc, f) => cvc.field(f, DateTime(2000)).future(),
    en: 'The date must be in the future',
    es: 'La fecha debe estar en el futuro',
  ),
  _Case(
    'futureOrPresent',
    (cvc, f) => cvc.field(f, DateTime(2000)).futureOrPresent(),
    en: 'The date cannot be in the past',
    es: 'La fecha no puede estar en el pasado',
  ),
];

void main() {
  const english = WinterLocale.english;
  const spanish = WinterLocale.spanish;

  group('Every validator in every locale', () {
    for (final c in _cases) {
      group(c.name, () {
        test('outside a request: the fallback (English)', () {
          final cvc = ConstraintValidatorContext();
          c.rule(cvc, 'field');
          expect(cvc.violations.single.message, c.en);
        });

        test('en', () {
          expect(c.violation(english).message, c.en);
        });

        test('es', () {
          expect(c.violation(spanish).message, c.es);
        });

        test('a region uses its language (es-MX)', () {
          expect(c.violation(const WinterLocale('es', 'MX')).message, c.es);
        });

        test('a language without translations uses English (fr)', () {
          expect(c.violation(const WinterLocale('fr')).message, c.en);
        });
      });
    }
  });

  group('A custom message is translated with the locale', () {
    /// Like the getter of an app over its own slang messages: `AppMessages get t => ...(requestLocale)`
    String custom() =>
        requestLocale.languageCode == 'es' ? 'Personalizado' : 'Custom';

    final List<(String, void Function(ConstraintValidatorContext cvc))>
    rules = [
      ('notNull', (cvc) => cvc.field('field', null).notNull(message: custom())),
      ('notBlank', (cvc) => cvc.field('field', '').notBlank(message: custom())),
      (
        'size',
        (cvc) => cvc.field('field', 'ab').size(min: 3, message: custom()),
      ),
      ('email', (cvc) => cvc.field('field', 'x').email(message: custom())),
      ('min', (cvc) => cvc.field('field', 1).min(3, message: custom())),
      ('max', (cvc) => cvc.field('field', 1).max(0, message: custom())),
      (
        'pattern',
        (cvc) => cvc.field('field', 'x').pattern(r'^\d+$', message: custom()),
      ),
      (
        'isEnum',
        (cvc) =>
            cvc.field('field', 'x').isEnum(_Color.values, message: custom()),
      ),
      (
        'oneOf',
        (cvc) => cvc.field('field', 'x').oneOf(['a'], message: custom()),
      ),
      ('url', (cvc) => cvc.field('field', 'x').url(message: custom())),
      ('positive', (cvc) => cvc.field('field', 0).positive(message: custom())),
      (
        'past',
        (cvc) => cvc.field('field', DateTime(3000)).past(message: custom()),
      ),
    ];

    for (final (name, rule) in rules) {
      test(name, () {
        String message(WinterLocale locale) =>
            RequestScope.run(RequestScope(locale: locale), () {
              final cvc = ConstraintValidatorContext();
              rule(cvc);
              return cvc.violations.single.message;
            });

        expect(message(english), 'Custom');
        expect(message(spanish), 'Personalizado');
      });
    }

    test('A fixed text is the same in every locale', () {
      final cvc = ConstraintValidatorContext();
      RequestScope.run(
        RequestScope(locale: spanish),
        () => cvc.field('field', null).notNull(message: 'Fixed'),
      );
      expect(cvc.violations.single.message, 'Fixed');
    });

    test('422: the custom message uses the language of the request', () async {
      final previous = Winter.context.localeConfig;
      Winter.context.setUp(
        localeConfig: LocaleConfig(supported: [english, spanish]),
      );
      addTearDown(() => Winter.context.setUp(localeConfig: previous));

      final client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.post(
              path: '/validate',
              handler: (request) {
                final cvc = ConstraintValidatorContext();
                cvc.field('prefix', null).notNull(message: custom());
                cvc.throwOnFailure();
                return ResponseEntity.ok();
              },
            ),
          ],
        ),
      );

      Future<String> message(String? acceptLanguage) async {
        final response = await client.post(
          '/validate',
          headers: {HttpHeader.acceptLanguage: ?acceptLanguage},
        );
        expect(response.statusCode, 422);
        expect(response.headers[HttpHeader.vary], HttpHeader.acceptLanguage);
        final violation =
            (((jsonDecode(response.body) as Map)['violations'] as List)).single
                as Map<String, dynamic>;
        return violation['message'] as String;
      }

      expect(await message(null), 'Custom');
      expect(await message('es-MX'), 'Personalizado');
    });
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
                  _cases[i].rule(cvc, 'field$i');
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
        for (final v
            in ((jsonDecode(response.body) as Map)['violations'] as List))
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

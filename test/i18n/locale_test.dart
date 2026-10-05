import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

class _User implements Validatable {
  final String? name;
  final List<String>? tags;

  _User({this.name, this.tags});

  factory _User.fromJson(Map<String, dynamic> json) => _User(
    name: json['name'] as String?,
    tags: (json['tags'] as List?)?.cast<String>(),
  );

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.buildValidator('name').notNull().size(min: 3, max: 10).validate(name);
    cvc.buildValidator('tags').size(max: 2).validate(tags);
    return cvc;
  }
}

void main() {
  const english = WinterLocale.english;
  const spanish = WinterLocale.spanish;

  group('Accept-Language', () {
    final config = LocaleConfig(supported: [english, spanish]);

    test('Without header or empty: fallback', () {
      expect(config.resolve(null), english);
      expect(config.resolve(''), english);
      expect(config.resolve('  '), english);
    });

    test('Exact language', () {
      expect(config.resolve('es'), spanish);
      expect(config.resolve('en'), english);
      expect(config.resolve('ES'), spanish);
    });

    test('Region falls back to the language', () {
      expect(config.resolve('es-MX'), spanish);
      expect(config.resolve('es_ar'), spanish);
      expect(config.resolve('zh-Hant-TW'), english);
    });

    test('Not supported: fallback', () {
      expect(config.resolve('fr'), english);
      expect(config.resolve('fr-CA, de;q=0.9'), english);
      expect(config.resolve('*'), english);
      expect(config.resolve('###, 1'), english);
    });

    test('Highest q wins, not the order of the header', () {
      expect(config.resolve('en;q=0.5, es;q=0.9'), spanish);
      expect(config.resolve('fr, es;q=0.8, en;q=0.7'), spanish);
      expect(config.resolve('es;q=0.8, en;q=0.8'), spanish);
      expect(config.resolve('en;q=0.8, es;q=0.8'), english);
    });

    test('q=0 (or invalid q) means not acceptable', () {
      expect(config.resolve('es;q=0, en;q=0.1'), english);
      expect(config.resolve('es;q=abc'), english);
    });

    test('Configurable fallback', () {
      final esFirst = LocaleConfig(
        supported: [english, spanish],
        fallback: spanish,
      );
      expect(esFirst.resolve(null), spanish);
      expect(esFirst.resolve('fr'), spanish);
      expect(esFirst.resolve('en'), english);
    });

    test('Region-specific supported locales', () {
      const mx = WinterLocale('es', 'MX');
      final regional = LocaleConfig(supported: [english, spanish, mx]);
      expect(regional.resolve('es-MX'), mx);
      expect(regional.resolve('es-AR'), spanish);

      ///Only `es-MX` supported: any `es-*` picks it
      final onlyMx = LocaleConfig(supported: [english, mx]);
      expect(onlyMx.resolve('es'), mx);
    });

    test('Default config only supports English', () {
      expect(LocaleConfig().resolve('es'), english);
    });

    test('WinterLocale parse and tag', () {
      expect(WinterLocale.tryParse('es-mx'), const WinterLocale('es', 'MX'));
      expect(WinterLocale.tryParse('es-419')?.toLanguageTag(), 'es-419');
      expect(WinterLocale.tryParse('x'), isNull);
      expect(const WinterLocale('es', 'MX').toString(), 'es-MX');
    });
  });

  group('Violations', () {
    /// Validate [user] as a request in [locale] would
    List<ConstrainViolation> validateIn(WinterLocale locale, _User user) =>
        RequestScope.run(
          RequestScope(locale: locale),
          () => user.validate().violations,
        );

    test('message is in the language of the request', () {
      final violation = validateIn(spanish, _User(name: 'ab')).single;

      expect(violation.message, 'El mínimo es 3');
      expect(violation.toJson(), {
        'value': 'ab',
        'fieldName': 'name',
        'message': 'El mínimo es 3',
      });
    });

    test('Outside a request: the fallback (English)', () {
      expect(
        _User(name: 'ab').validate().violations.single.message,
        'The minimum is 3',
      );
    });

    test('A fixed custom message is the same in every language', () {
      final cvc = ConstraintValidatorContext();
      RequestScope.run(
        RequestScope(locale: spanish),
        () => cvc
            .buildValidator('name')
            .notNull(message: 'Required')
            .validate(null),
      );
      expect(cvc.violations.single.message, 'Required');
    });

    test('A language without translations uses English', () {
      expect(
        validateIn(const WinterLocale('fr'), _User()).single.message,
        'The field cannot be null',
      );
    });

    test('Merge with prefix keeps the translation', () {
      final inner = ConstraintValidatorContext();
      RequestScope.run(
        RequestScope(locale: spanish),
        () => inner.buildValidator('name').notNull().validate(null),
      );
      final cvc = ConstraintValidatorContext()..merge(inner, prefix: 'user');
      final violation = cvc.violations.single;
      expect(violation.fieldName, 'user.name');
      expect(violation.message, 'El campo no puede ser null');
    });
  });

  test('422 without Vary when the app only answers in English', () async {
    final client = WinterTestClient.build(
      router: ServeRouter((request) {
        _User().validate().throwOnFailure();
        return ResponseEntity.ok();
      }),
    );

    final response = await client.get(
      '/',
      headers: {HttpHeader.acceptLanguage: 'es'},
    );
    expect(response.statusCode, 422);
    expect(response.headers[HttpHeader.vary], isNull);
    expect(response.body, contains('The field cannot be null'));
  });

  group('422 in the language of the request', () {
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
              path: '/users',
              handler: (request) async {
                final user = _User.fromJson(
                  await request.body<Map<String, dynamic>>(),
                );
                user.validate().throwOnFailure();
                return ResponseEntity.ok(body: request.locale.toLanguageTag());
              },
            ),
          ],
        ),
      );
    });

    tearDownAll(() => Winter.context.setUp(localeConfig: previous));

    Future<TestResponse> post(Object body, {String? acceptLanguage}) =>
        client.post(
          '/users',
          body: body,
          headers: {HttpHeader.acceptLanguage: ?acceptLanguage},
        );

    List<String> messages(TestResponse response) => [
      for (final v in jsonDecode(response.body) as List)
        (v as Map<String, dynamic>)['message'] as String,
    ];

    test('Without header: English', () async {
      final response = await post({'name': 'ab'});
      expect(response.statusCode, 422);
      expect(response.headers[HttpHeader.vary], HttpHeader.acceptLanguage);
      expect(messages(response), ['The minimum is 3']);
    });

    test('Accept-Language: es', () async {
      final response = await post({
        'name': 'abcdefghijkl',
        'tags': ['a', 'b', 'c'],
      }, acceptLanguage: 'es');
      expect(response.statusCode, 422);
      expect(response.headers[HttpHeader.vary], HttpHeader.acceptLanguage);
      expect(messages(response), ['El máximo es 10', 'El máximo es 2']);
      expect(
        jsonDecode(response.body),
        contains(containsPair('fieldName', 'name')),
      );
    });

    test('Accept-Language: es-MX, en;q=0.5 (null field)', () async {
      final response = await post({}, acceptLanguage: 'es-MX, en;q=0.5');
      expect(messages(response), ['El campo no puede ser null']);
    });

    test('Not supported language: English', () async {
      final response = await post({}, acceptLanguage: 'fr-FR');
      expect(messages(response), ['The field cannot be null']);
    });

    test('request.locale on a valid request', () async {
      final response = await post({'name': 'abcd'}, acceptLanguage: 'es-AR');
      expect(response.statusCode, 200);
      expect(response.body, 'es');
    });
  });
}

import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/src/winter_server.dart' show addVary;
import 'package:winter/winter.dart';

const WinterLocale english = WinterLocale.english;
const WinterLocale spanish = WinterLocale.spanish;

void main() {
  late LocaleConfig previous;

  setUpAll(() {
    previous = Winter.context.localeConfig;
    Winter.context.setUp(
      localeConfig: LocaleConfig(supported: [english, spanish]),
    );
  });

  tearDownAll(() => Winter.context.setUp(localeConfig: previous));

  Future<TestResponse> get(ResponseEntity Function(RequestEntity) handler) =>
      WinterTestClient.build(router: ServeRouter(handler))
          .get('/', headers: {HttpHeader.acceptLanguage: 'es'});

  group('Vary: Accept-Language is added when the language is read', () {
    test('requestLocale', () async {
      final response = await get(
        (_) => ResponseEntity.ok(body: requestLocale.toLanguageTag()),
      );
      expect(response.body, 'es');
      expect(response.headers[HttpHeader.vary], HttpHeader.acceptLanguage);
    });

    test('request.locale', () async {
      final response = await get(
        (request) => ResponseEntity.ok(body: request.locale.toLanguageTag()),
      );
      expect(response.headers[HttpHeader.vary], HttpHeader.acceptLanguage);
    });

    test('After an await, in a service that throws', () async {
      final client = WinterTestClient.build(
        router: ServeRouter((request) async {
          await Future<void>.delayed(Duration.zero);
          throw NotFoundException(
            detail: requestLocale == spanish ? 'No encontrado' : 'Not found',
          );
        }),
      );
      final response = await client.get(
        '/',
        headers: {HttpHeader.acceptLanguage: 'es'},
      );
      expect(response.statusCode, 404);
      expect((jsonDecode(response.body) as Map)['detail'], 'No encontrado');
      expect(response.headers[HttpHeader.vary], HttpHeader.acceptLanguage);
    });

    test('A 422 with the texts of Winter', () async {
      final response = await get((_) {
        final cvc = ConstraintValidatorContext();
        cvc.field('name', null).notNull();
        cvc.throwOnFailure();
        return ResponseEntity.ok();
      });
      expect(response.statusCode, 422);
      expect(response.headers[HttpHeader.vary], HttpHeader.acceptLanguage);
    });
  });

  group('Vary: Accept-Language is not added', () {
    test('When nobody reads the language', () async {
      final response = await get((_) => ResponseEntity.ok(body: 'same'));
      expect(response.headers[HttpHeader.vary], isNull);
    });

    test('A 422 with only fixed messages', () async {
      final response = await get((_) {
        final cvc = ConstraintValidatorContext();
        cvc.field('name', null).notNull(message: 'Required');
        cvc.throwOnFailure();
        return ResponseEntity.ok();
      });
      expect(response.statusCode, 422);
      expect(response.headers[HttpHeader.vary], isNull);
    });

    test('When the app only answers in one language', () async {
      Winter.context.setUp(localeConfig: LocaleConfig());
      addTearDown(
        () => Winter.context.setUp(
          localeConfig: LocaleConfig(supported: [english, spanish]),
        ),
      );

      final response = await get(
        (_) => ResponseEntity.ok(body: requestLocale.toLanguageTag()),
      );
      expect(response.body, 'en');
      expect(response.headers[HttpHeader.vary], isNull);
    });
  });

  group('It is merged with the Vary of the response', () {
    ResponseEntity withVary(String vary) => ResponseEntity.ok(
      body: requestLocale.toLanguageTag(),
      headers: {HttpHeader.vary: vary},
    );

    test('Another header is kept', () async {
      final response = await get((_) => withVary('Origin'));
      expect(response.headers[HttpHeader.vary], 'Origin, Accept-Language');
    });

    test('Already there (any case): not duplicated', () async {
      final response = await get((_) => withVary('origin, accept-language'));
      expect(response.headers[HttpHeader.vary], 'origin, accept-language');
    });

    test('* already varies on everything', () async {
      final response = await get((_) => withVary('*'));
      expect(response.headers[HttpHeader.vary], '*');
    });

    test('With the Vary: Origin of CORS', () async {
      final client = WinterTestClient.build(
        securityConfig: SecurityConfig(
          cors: const CorsConfig(allowedOrigins: ['https://app.com']),
        ),
        router: ServeRouter(
          (_) => ResponseEntity.ok(body: requestLocale.toLanguageTag()),
        ),
      );
      final response = await client.get(
        '/',
        headers: {
          HttpHeader.acceptLanguage: 'es',
          HttpHeader.origin: 'https://app.com',
        },
      );
      expect(response.headers[HttpHeader.vary], 'Origin, Accept-Language');
    });
  });

  group('addVary', () {
    String? vary(ResponseEntity response) => response.headers[HttpHeader.vary];

    test('Without Vary', () {
      expect(vary(addVary(ResponseEntity.ok(body: ''), 'Origin')), 'Origin');
    });

    test('Empty Vary', () {
      expect(
        vary(
          addVary(
            ResponseEntity.ok(body: '', headers: {'Vary': ' '}),
            'Origin',
          ),
        ),
        'Origin',
      );
    });

    test('Keeps the body', () async {
      final response = addVary(ResponseEntity.ok(body: 'body'), 'Origin');
      expect(await response.readAsString(), 'body');
    });
  });
}

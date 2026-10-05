import 'dart:async';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

const WinterLocale english = WinterLocale.english;
const WinterLocale spanish = WinterLocale.spanish;
const WinterLocale french = WinterLocale('fr');

/// Like a service of the app: it doesn't receive the request
String currentLanguage() => requestLocale.toLanguageTag();

void main() {
  late LocaleConfig previous;

  setUpAll(() {
    previous = Winter.context.localeConfig;
    Winter.context.setUp(
      localeConfig: LocaleConfig(supported: [english, spanish, french]),
    );
  });

  tearDownAll(() => Winter.context.setUp(localeConfig: previous));

  test('Outside a request it is the fallback', () {
    expect(requestLocale, english);
  });

  test('Outside a request it follows the configured fallback', () {
    final config = Winter.context.localeConfig;
    addTearDown(() => Winter.context.setUp(localeConfig: config));
    Winter.context.setUp(
      localeConfig: LocaleConfig(supported: [spanish], fallback: spanish),
    );

    expect(requestLocale, spanish);
    expect(
      RequestScope(securityContext: RequestSecurityContext<String>.empty())
          .locale,
      spanish,
    );
  });

  test(
    'A service reads the locale of the request without receiving it',
    () async {
      final client = WinterTestClient.build(
        router: ServeRouter(
          (request) => ResponseEntity.ok(body: currentLanguage()),
        ),
      );

      expect(
        (await client.get(
          '/',
          headers: {'Accept-Language': 'es-MX,en;q=0.5'},
        )).body,
        'es',
      );
      expect(
        (await client.get('/', headers: {'Accept-Language': 'de'})).body,
        'en',
      );
      expect((await client.get('/')).body, 'en');
    },
  );

  test('It is the same as request.locale', () async {
    final client = WinterTestClient.build(
      router: ServeRouter(
        (request) => ResponseEntity.ok(body: request.locale == requestLocale),
      ),
    );

    expect(
      (await client.get('/', headers: {'Accept-Language': 'fr'})).body,
      'true',
    );
  });

  test('Concurrent requests never see the locale of another one', () async {
    const List<String> languages = ['en', 'es', 'fr'];
    const int requests = 60;
    int arrived = 0;
    final gate = Completer<void>();

    final client = WinterTestClient.build(
      router: ServeRouter((request) async {
        final before = currentLanguage();

        ///Every request waits here until all of them are in progress
        if (++arrived == requests) gate.complete();
        await gate.future;

        return ResponseEntity.ok(body: '$before:${currentLanguage()}');
      }),
    );

    final responses = await Future.wait([
      for (int i = 0; i < requests; i++)
        client.get(
          '/',
          headers: {'Accept-Language': languages[i % languages.length]},
        ),
    ]);

    for (int i = 0; i < requests; i++) {
      final language = languages[i % languages.length];
      expect(responses[i].body, '$language:$language');
    }
  });

  test(
    'Work started by a request keeps its locale after the response',
    () async {
      final release = Completer<void>();
      final seen = Completer<String>();

      final client = WinterTestClient.build(
        router: ServeRouter((request) {
          if (request.headers['Accept-Language'] == 'es') {
            unawaited(() async {
              await release.future;
              seen.complete(currentLanguage());
            }());
          }
          return ResponseEntity.ok(body: currentLanguage());
        }),
      );

      expect(
        (await client.get('/', headers: {'Accept-Language': 'es'})).body,
        'es',
      );

      ///Another request in the meantime doesn't change it
      expect(
        (await client.get('/', headers: {'Accept-Language': 'fr'})).body,
        'fr',
      );
      release.complete();

      expect(await seen.future, 'es');
    },
  );

  test(
    'Concurrent validations answer each 422 in the language of its request',
    () async {
      const List<String> languages = ['en', 'es', 'fr'];
      const int requests = 30;
      int arrived = 0;
      final gate = Completer<void>();

      final client = WinterTestClient.build(
        router: ServeRouter((request) async {
          ///Every request validates after all of them are in progress
          if (++arrived == requests) gate.complete();
          await gate.future;

          final cvc = ConstraintValidatorContext();
          cvc.buildValidator('name').notNull().validate(null);
          cvc.throwOnFailure();
          return ResponseEntity.ok();
        }),
      );

      final responses = await Future.wait([
        for (int i = 0; i < requests; i++)
          client.get(
            '/',
            headers: {'Accept-Language': languages[i % languages.length]},
          ),
      ]);

      ///French has no translations in Winter: English
      const Map<String, String> expected = {
        'en': 'The field cannot be null',
        'es': 'El campo no puede ser null',
        'fr': 'The field cannot be null',
      };
      for (int i = 0; i < requests; i++) {
        expect(responses[i].statusCode, 422);
        expect(
          responses[i].headers[HttpHeader.vary],
          HttpHeader.acceptLanguage,
        );
        final violation =
            (responses[i].json as List).single as Map<String, dynamic>;
        expect(violation['message'], expected[languages[i % languages.length]]);
      }
    },
  );

  test('custom() can translate its text with requestLocale', () async {
    final client = WinterTestClient.build(
      router: ServeRouter((request) {
        final cvc = ConstraintValidatorContext();
        cvc
            .buildValidator('code')
            .custom(
              (value) => value == 'ok'
                  ? null
                  : (requestLocale == spanish
                        ? 'Código inválido'
                        : 'Invalid code'),
            )
            .validate(request.url.queryParameters['code']);
        cvc.throwOnFailure();
        return ResponseEntity.ok();
      }),
    );

    Future<String> message(String language) async {
      final response = await client.get(
        '/?code=x',
        headers: {'Accept-Language': language},
      );
      return ((response.json as List).single as Map<String, dynamic>)['message']
          as String;
    }

    expect(await message('es'), 'Código inválido');
    expect(await message('en'), 'Invalid code');
    expect((await client.get('/?code=ok')).statusCode, 200);
  });

  test('RequestScope.run gives a locale to code outside the server', () async {
    final String language = await RequestScope.run(
      RequestScope(
        securityContext: RequestSecurityContext<String>.empty(),
        locale: spanish,
      ),
      () async {
        await Future<void>.delayed(Duration.zero);
        return currentLanguage();
      },
    );

    expect(language, 'es');
    expect(requestLocale, english);
  });
}

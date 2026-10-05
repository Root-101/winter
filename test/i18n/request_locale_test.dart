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

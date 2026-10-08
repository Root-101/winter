@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The real server, configured from `.env` files, compared with `WinterTestClient`, and its
/// shutdown with a request in progress (DECISIONS.md §10)
void main() {
  late Directory directory;
  late Completer<void> slowStarted;
  late Completer<void> releaseSlow;
  late List<String> events;

  WinterRouter router() => WinterRouter(
    routes: [
      Route.get(
        path: '/greeting',
        handler: (request) => ResponseEntity.ok(
          body: {
            'text': request.locale == WinterLocale.spanish ? 'Hola' : 'Hello',
            'from': env.require<String>('GREETING_FROM'),
          },
        ),
      ),
      Route.get(
        path: '/text',
        handler: (request) => ResponseEntity.ok(body: 'año'),
      ),
      Route.get(
        path: '/slow',
        handler: (request) async {
          di.find<_Session>();
          slowStarted.complete();
          await releaseSlow.future;
          return ResponseEntity.ok(body: 'done');
        },
      ),
      Route.get(
        path: '/error',
        handler: (request) {
          di.find<_Session>();
          throw StateError('a bug');
        },
      ),
    ],
  );

  final security = SecurityConfig(
    cors: const CorsConfig(allowedOrigins: ['https://app.example']),
    securityHeaders: const SecurityHeaders(),
  );

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('winter_integration');
    await File('${directory.path}/.env')
        .writeAsString('PORT=9096\nGREETING_FROM=dotenv\n');
    await File('${directory.path}/.env.prod')
        .writeAsString('GREETING_FROM="the prod profile"\n');
  });

  tearDownAll(() async {
    await Winter.close(force: true);
    await directory.delete(recursive: true);
    Winter.context.setUp(
      env: Env(),
      dependencyInjection: DependencyInjection(),
      localeConfig: LocaleConfig(),
    );
  });

  test('the whole lifecycle of a server configured from .env files', () async {
    events = [];
    slowStarted = Completer<void>();
    releaseSlow = Completer<void>();

    final env = Env.load(
      directory: directory.path,
      profile: 'prod',
      environment: {},
    );
    final di = DependencyInjection()
      ..put<_Pool>(_Pool(), onDispose: (pool) => events.add('pool closed'))
      ..putScoped<_Session>(
        _Session.new,
        onDispose: (session) => events.add('session closed'),
      );
    Winter.context.setUp(
      env: env,
      dependencyInjection: di,
      localeConfig: LocaleConfig(
        supported: const [WinterLocale.english, WinterLocale.spanish],
      ),
    );

    await Winter.start(
      config: ServerConfig.fromEnv(
        env,
        handleSignals: false,
        onShutdown: () => events.add('onShutdown'),
      ),
      router: router(),
      securityConfig: security,
    );
    final memory = WinterTestClient.build(
      router: router(),
      securityConfig: security,
    );

    // The port of .env, the value of the profile over the one of .env
    final response = await http.get(
      Uri.parse('http://localhost:9096/greeting'),
      headers: {'accept-language': 'es', 'origin': 'https://app.example'},
    );
    expect(jsonDecode(response.body), {
      'text': 'Hola',
      'from': 'the prod profile',
    });

    // The real server and the test client send the same headers (but the date and the id)
    final inMemory = await memory.get(
      '/greeting',
      headers: {'accept-language': 'es', 'origin': 'https://app.example'},
    );
    Map<String, String> comparable(Map<String, String> headers) => {
      for (final MapEntry(:key, :value) in headers.entries)
        if (key.toLowerCase() != 'date' && key.toLowerCase() != 'x-request-id')
          key.toLowerCase(): value,
    };
    expect(comparable(response.headers), comparable(inMemory.headers));
    expect(response.headers, isNot(contains('x-powered-by')));

    // The scoped dependency of a failed request is disposed too
    final error = await http.get(Uri.parse('http://localhost:9096/error'));
    expect(error.statusCode, 500);
    expect(events, ['session closed']);

    // The shutdown waits for the request in progress, then disposes everything
    final slow = http.get(Uri.parse('http://localhost:9096/slow'));
    await slowStarted.future;
    final shutdown = Winter.shutdown();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(events, ['session closed'], reason: 'still waiting for /slow');

    releaseSlow.complete();
    expect((await slow).body, 'done');
    await shutdown;
    expect(events, [
      'session closed',
      'session closed',
      'onShutdown',
      'pool closed',
    ]);
    expect(Winter.isRunning, isFalse);
  });

  test(
    'Problem Details keep their names with any fieldNaming (§10.2)',
    () async {
      Winter.context.setUp(
        objectMapper: ObjectMapper(
          fieldNaming: FieldNaming.kebabCase,
          deserializers: [
            Deserializer<_Signup>.json(
              (json) => _Signup(json['firstName'] as String),
            ),
          ],
        ),
      );
      addTearDown(() => Winter.context.setUp(objectMapper: ObjectMapper()));
      final client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.post(
              path: '/signup',
              handler: (request) async =>
                  ResponseEntity.ok(body: await request.body<_Signup>()),
            ),
            Route.get(
              path: '/boom',
              handler: (request) => throw StateError('x'),
            ),
            Route.get(
              path: '/conflict',
              handler: (request) => throw const ApiException(
                StatusCode.conflict,
                extensions: {'retryAt': 1},
              ),
            ),
          ],
        ),
      );

      final invalid = await client.post(
        '/signup',
        headers: {'content-type': 'application/json'},
        body: {'first-name': ''},
      );
      final error = await client.get('/boom');
      final conflict = await client.get('/conflict');

      final violation =
          ((jsonDecode(invalid.body) as Map)['violations'] as List).single
              as Map;
      expect(violation.keys, containsAll(['fieldName', 'message', 'code']));
      expect(
        violation['fieldName'],
        'first-name',
        reason: 'the name the client sent',
      );
      expect(jsonDecode(error.body) as Map, contains('requestId'));
      expect(
        jsonDecode(conflict.body) as Map,
        contains('retryAt'),
        reason: 'the extensions of the app, as it gives them',
      );
    },
  );

  group('Content-Type (§10.1)', () {
    final client = WinterTestClient.build(router: router());

    setUp(() {
      Winter.context.setUp(
        env: Env(env: {'GREETING_FROM': 'test'}),
        localeConfig: LocaleConfig(
          supported: const [WinterLocale.english, WinterLocale.spanish],
        ),
      );
    });

    test('a text body always says its charset, in any language', () async {
      final english = await client.get('/greeting');
      final spanish = await client.get(
        '/greeting',
        headers: {'accept-language': 'es'},
      );
      final text = await client.get('/text');
      final error = await client.get('/missing');

      expect(
        english.headers['content-type'],
        'application/json; charset=utf-8',
      );
      expect(spanish.headers['content-type'], english.headers['content-type']);
      expect(text.headers['content-type'], 'text/plain; charset=utf-8');
      expect(text.body, 'año');
      expect(
        error.headers['content-type'],
        'application/problem+json; charset=utf-8',
      );
    });

    test('a body without text has no charset', () {
      final bytes = ResponseEntity<void>(
        200,
        headers: {'x': '1'},
      ).change(body: [1, 2]);
      final stream = ResponseEntity<Stream<List<int>>>(
        200,
        body: Stream.value([1]),
      );

      expect(bytes.headers['content-type'], 'application/octet-stream');
      expect(stream.headers['content-type'], 'application/octet-stream');
    });

    test('an encoding of the app is the charset', () {
      final response = ResponseEntity<String>(
        200,
        body: 'año',
        encoding: latin1,
      );

      expect(
        response.headers['content-type'],
        'text/plain; charset=iso-8859-1',
      );
    });
  });
}

class _Signup implements Validatable {
  final String firstName;

  _Signup(this.firstName);

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.field('firstName', firstName).notBlank();
    return cvc;
  }
}

class _Pool {}

class _Session {}

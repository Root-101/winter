@TestOn('vm')
library;

import 'dart:convert';

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// A router that fails while resolving the route (outside the filter chain)
class _FailingRouter extends AbstractWinterRouter {
  @override
  bool canHandle(RequestEntity request) => true;

  @override
  Route? resolveRoute(RequestEntity request) =>
      throw const ConflictException(detail: 'from resolveRoute');

  @override
  FutureOr<ResponseEntity> handler(RequestEntity request) =>
      ResponseEntity.ok();
}

void main() {
  int port = 9075;

  tearDown(() async {
    if (Winter.isRunning) await Winter.close(force: true);
  });

  group('Winter lifecycle', () {
    test('server throws when no server is running', () {
      expect(Winter.isRunning, isFalse);
      expect(() => Winter.server, throwsStateError);
    });

    test('a second start throws', () async {
      await Winter.start(config: ServerConfig(port: port));

      expect(Winter.server.config.port, port);
      await expectLater(
        Winter.start(config: ServerConfig(port: port + 1)),
        throwsStateError,
      );
    });

    test('the ServerConfig registered in the DI is used by start', () async {
      final config = ServerConfig(port: port);
      di.put<ServerConfig>(config);
      addTearDown(
        () => di.tryFind<ServerConfig>() == null
            ? null
            : di.delete<ServerConfig>(),
      );

      await Winter.start();

      expect(Winter.server.config, same(config));
      expect(
        (await http.get(Uri.parse('http://localhost:$port/'))).statusCode,
        404,
      );
    });

    test(
      'an exception outside the filter chain goes to the exception handler',
      () async {
        await Winter.start(
          config: ServerConfig(port: port),
          router: _FailingRouter(),
        );

        final response = await http.get(Uri.parse('http://localhost:$port/'));

        expect(response.statusCode, 409);
        expect(
          (jsonDecode(response.body) as Map)['detail'],
          'from resolveRoute',
        );
      },
    );
  });

  group('BuildContext', () {
    test('setUp replaces only the given components', () {
      final context = BuildContext();
      final objectMapper = ObjectMapper();
      final exceptionHandler = SimpleExceptionHandler();
      final dependencyInjection = DependencyInjection();
      final env = Env(env: {'KEY': 'value'});
      final logger = const ConsoleLogger(minLevel: LogLevel.error);

      final previousMapper = context.objectMapper;
      context.setUp(env: env);
      expect(context.env.find<String>('KEY'), 'value');
      expect(context.objectMapper, same(previousMapper));

      context.setUp(
        objectMapper: objectMapper,
        exceptionHandler: exceptionHandler,
        dependencyInjection: dependencyInjection,
        logger: logger,
      );
      expect(context.objectMapper, same(objectMapper));
      expect(context.exceptionHandler, same(exceptionHandler));
      expect(context.dependencyInjection, same(dependencyInjection));
      expect(context.logger, same(logger));
      expect(context.env, same(env));
    });

    test('the global getters point to Winter.context', () {
      expect(di, same(Winter.context.dependencyInjection));
      expect(om, same(Winter.context.objectMapper));
      expect(eh, same(Winter.context.exceptionHandler));
      expect(env, same(Winter.context.env));
      expect(logger, same(Winter.context.logger));
    });
  });

  test('maxBodySize: null accepts bodies of any size', () async {
    final client = WinterTestClient.build(
      maxBodySize: null,
      router: WinterRouter(
        routes: [
          Route.post(
            path: '/echo',
            handler: (request) async => ResponseEntity.ok(
              body: '${(await request.body<String>()).length}',
            ),
          ),
        ],
      ),
    );

    final response = await client.post('/echo', body: 'a' * (11 * 1024 * 1024));

    expect(response.statusCode, 200);
    expect(response.body, '${11 * 1024 * 1024}');
  });
}

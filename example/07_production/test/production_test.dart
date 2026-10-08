import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:production_example/production_example.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('Configuration', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('production_example');
      await File(
        '${directory.path}/.env',
      ).writeAsString('DATABASE_URL=memory://local\nLOG_LEVEL=debug\n');
      await File(
        '${directory.path}/.env.prod',
      ).writeAsString('LOG_FORMAT=json\nLOG_LEVEL=info\n');
    });

    tearDown(() => directory.delete(recursive: true));

    test('the profile and the process override the .env file', () {
      final env = ProductionApp.loadEnv(
        directory: directory.path,
        environment: {'WINTER_PROFILE': 'prod', 'PORT': '9000'},
      );

      expect(env.profile, 'prod');
      expect(env.find<String>('LOG_LEVEL'), 'info');
      expect(env.require<int>('PORT'), 9000);
      expect(ProductionApp.loggerFor(env), isA<JsonLogger>());
    });

    test('without a profile the logs are for a person', () {
      final env = ProductionApp.loadEnv(
        directory: directory.path,
        environment: {},
      );

      final logger = ProductionApp.loggerFor(env);
      expect(logger, isA<ConsoleLogger>());
      expect(logger.isEnabled(LogLevel.debug), isTrue);
    });

    test('a missing variable fails at start, naming it', () {
      expect(
        () => ProductionApp.loadEnv(
          directory: '${directory.path}/empty',
          environment: {},
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('DATABASE_URL'),
          ),
        ),
      );
    });
  });

  group('Health checks', () {
    late Database database;
    late WinterTestClient client;

    setUp(() {
      database = Database('memory://test');
      Winter.context.setUp(dependencyInjection: DependencyInjection());
      di.put<Database>(database);
      final env = Env(env: {'DATABASE_URL': 'memory://test'});
      client = WinterTestClient.build(
        router: ProductionApp.router(),
        globalFilterConfig: ProductionApp.filters(env),
        securityConfig: ProductionApp.security(env),
      );
    });

    test('/health only says that the process answers', () async {
      await database.close();

      final response = await client.get('/health');
      expect(response.statusCode, 200);
      expect(response.headers['x-request-id'], isNotNull);
    });

    test(
      '/ready is a 503 with Retry-After while the database is down',
      () async {
        expect((await client.get('/ready')).statusCode, 200);

        await database.close();
        final response = await client.get('/ready');

        expect(response.statusCode, 503);
        expect(response.headers['retry-after'], '5');
        expect(response.headers['x-ratelimit-limit'], '100');
      },
    );
  });

  test(
    'SIGTERM-like shutdown: requests finish, then the database closes',
    () async {
      Winter.context.setUp(dependencyInjection: DependencyInjection());
      await ProductionApp.start(
        env: Env(env: {'DATABASE_URL': 'memory://test', 'PORT': '9141'}),
      );
      final Database database = di.find<Database>();

      final response = await http.get(Uri.parse('http://localhost:9141/hello'));
      expect(response.body, 'Hello from local');

      await Winter.shutdown();

      expect(Winter.isRunning, isFalse);
      expect(database.isOpen, isFalse);
    },
  );
}

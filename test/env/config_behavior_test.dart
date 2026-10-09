@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The behavior decided in the review of the configuration (DECISIONS.md §6)
void main() {
  group('find and require (§6)', () {
    final env = Env(env: {'PORT': '9000', 'EMPTY': '  ', 'NAME': 'winter'});

    test('find returns null for a missing or empty variable', () {
      expect(env.find<int>('PORT'), 9000);
      expect(env.find<int>('MISSING'), isNull);
      expect(env.find<String>('EMPTY'), isNull);
      expect(env.find<int>('MISSING') ?? 8080, 8080);
    });

    test('a nullable type is supported', () {
      expect(env.find<int?>('PORT'), 9000);
      expect(env.find<String?>('MISSING'), isNull);
      expect(env.find<List<int>?>('PORT'), [9000]);
    });

    test('require returns the value, or a StateError that names it', () {
      final int port = env.require<int>('PORT');

      expect(port, 9000);
      expect(
        () => env.require<String>('EMPTY'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('EMPTY'),
          ),
        ),
      );
    });

    test('requireAll names every missing variable', () {
      expect(() => env.requireAll(['PORT', 'NAME']), returnsNormally);
      expect(
        () => env.requireAll(['DB_URL', 'PORT', 'EMPTY', 'JWT_SECRET']),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Missing env variables: DB_URL, EMPTY, JWT_SECRET',
          ),
        ),
      );
    });

    test('caseSensitive: false finds a key in any case', () {
      expect(env.find<String>('name', caseSensitive: false), 'winter');
      expect(env.require<int>('port', caseSensitive: false), 9000);
      expect(
        () => env.requireAll(['port'], caseSensitive: false),
        returnsNormally,
      );
    });

    test('an error never shows the value (it may be a secret)', () {
      final secrets = Env(
        env: {
          'DB_PASSWORD': 'hunter2',
          'LIST': 'hunter2,3',
          'LEVEL': 'hunter2',
        },
      );

      for (final read in [
        () => secrets.find<int>('DB_PASSWORD'),
        () => secrets.find<List<int>>('LIST'),
        () => secrets.findEnum('LEVEL', LogLevel.values),
      ]) {
        expect(
          read,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              isNot(contains('hunter2')),
            ),
          ),
        );
      }
      expect(
        () => secrets.find<int>('DB_PASSWORD'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'The env variable DB_PASSWORD is not an integer',
          ),
        ),
      );
    });
  });

  group('Types (§6)', () {
    final env = Env(
      env: {
        'SECRET': '  pa ss  ',
        'PORT': ' 8080 ',
        'FLAG': 'TRUE',
        'FLAGS': 'TRUE, false ,',
        'TIMEOUT': '30s',
        'TIMEOUTS': '250ms, 5m, 1H, 2d',
        'API': ' https://api.example.com/v1 ',
        'RELATIVE': '/api',
        'NAMES': ' a, b ,c',
        'RATIO': '0.5',
        'LEVEL': 'Warning',
      },
    );

    test('a String is returned as it is, the other types are trimmed', () {
      expect(env.find<String>('SECRET'), '  pa ss  ');
      expect(env.find<int>('PORT'), 8080);
      expect(env.find<List<String>>('NAMES'), ['a', 'b', 'c']);
    });

    test('bool and List<bool> accept any case; an empty item is skipped', () {
      expect(env.find<bool>('FLAG'), isTrue);
      expect(env.find<List<bool>>('FLAGS'), [true, false]);
    });

    test('Duration with a unit', () {
      expect(env.find<Duration>('TIMEOUT'), const Duration(seconds: 30));
      expect(env.find<List<Duration>>('TIMEOUTS'), [
        const Duration(milliseconds: 250),
        const Duration(minutes: 5),
        const Duration(hours: 1),
        const Duration(days: 2),
      ]);
      expect(
        () => Env(env: {'T': '30'}).find<Duration>('T'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('250ms, 30s, 5m, 1h, 2d'),
          ),
        ),
      );
    });

    test('Uri must be absolute', () {
      expect(env.find<Uri>('API'), Uri.parse('https://api.example.com/v1'));
      expect(() => env.find<Uri>('RELATIVE'), throwsStateError);
    });

    test('numbers', () {
      expect(env.find<double>('RATIO'), 0.5);
      expect(env.find<num>('RATIO'), 0.5);
      expect(env.find<double>('PORT'), 8080.0);
      expect(() => env.find<int>('RATIO'), throwsStateError);
    });

    test('enums by name, any case', () {
      expect(env.findEnum('LEVEL', LogLevel.values), LogLevel.warning);
      expect(env.findEnum('MISSING', LogLevel.values), isNull);
      expect(env.requireEnum('LEVEL', LogLevel.values), LogLevel.warning);
      expect(
        () => env.requireEnum('MISSING', LogLevel.values),
        throwsStateError,
      );
      expect(
        () => Env(env: {'L': 'loud'}).findEnum('L', LogLevel.values),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('debug, info, warning, error'),
          ),
        ),
      );
    });

    test('the unsupported type message lists every supported type', () {
      expect(
        () => env.find<Set<int>>('PORT'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('<Set<int>>'),
              contains('List<bool>'),
              contains('Duration'),
            ),
          ),
        ),
      );
    });

    test('put returns the value and find reads it back', () {
      final env = Env(env: {});

      expect(env.put('WHEN', DateTime.utc(2026)), DateTime.utc(2026));
      expect(env.put('TIMEOUT', const Duration(seconds: 2)), isA<Duration>());
      env
        ..put('PORTS', [1, 2])
        ..put('LEVEL', LogLevel.error);

      expect(env.find<Duration>('TIMEOUT'), const Duration(seconds: 2));
      expect(env.find<List<int>>('PORTS'), [1, 2]);
      expect(env.findEnum('LEVEL', LogLevel.values), LogLevel.error);
      expect(env.all, containsPair('WHEN', DateTime.utc(2026).toString()));
    });
  });

  group('.env files and profiles (§6)', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('winter_env_');
      addTearDown(() => directory.deleteSync(recursive: true));
    });

    void write(String name, String content) =>
        File('${directory.path}/$name').writeAsStringSync(content);

    test('process > .env.<profile> > .env', () {
      write('.env', 'PORT=8080\nDB_URL=postgres://localhost/app\nNAME=dev\n');
      write('.env.prod', 'DB_URL=postgres://db.internal/app\nNAME=prod\n');

      final env = Env.load(
        directory: directory.path,
        environment: {'WINTER_PROFILE': 'prod', 'NAME': 'process'},
      );

      expect(env.profile, 'prod');
      expect(env.require<int>('PORT'), 8080);
      expect(env.require<String>('DB_URL'), 'postgres://db.internal/app');
      expect(env.require<String>('NAME'), 'process');
    });

    test('missing files are ignored (a container has none)', () {
      final env = Env.load(
        directory: directory.path,
        environment: {'PORT': '9000'},
      );

      expect(env.profile, isNull);
      expect(env.require<int>('PORT'), 9000);
    });

    test('without environment, the variables of the process', () {
      write('.env', 'WINTER_TEST_ONLY_IN_FILE=1');
      final String processKey = Platform.environment.keys.first;

      final env = Env.load(directory: directory.path);

      expect(env.all[processKey], Platform.environment[processKey]);
      expect(env.find<int>('WINTER_TEST_ONLY_IN_FILE'), 1);
    });

    test('the profile can be given', () {
      write('.env.test', 'NAME=test');

      final env = Env.load(
        directory: directory.path,
        profile: 'test',
        environment: {},
      );

      expect(env.profile, 'test');
      expect(env.find<String>('NAME'), 'test');
    });

    test('the format: comments, export, quotes and escapes', () {
      final variables = Env.parseDotEnv([
        '# a comment',
        '',
        'PLAIN=value',
        'SPACES = around the equals ',
        'export EXPORTED=1',
        'COMMENTED=value # a comment',
        'HASH=a#b',
        'DOUBLE="line one\\nline two \\"quoted\\" \\\\ #not a comment"',
        "SINGLE='literal \\n # \$HOME'",
        'EMPTY=',
        'URL=postgres://user:pa=ss@host/db',
      ]);

      expect(variables, {
        'PLAIN': 'value',
        'SPACES': 'around the equals',
        'EXPORTED': '1',
        'COMMENTED': 'value',
        'HASH': 'a#b',
        'DOUBLE': 'line one\nline two "quoted" \\ #not a comment',
        'SINGLE': r'literal \n # $HOME',
        'EMPTY': '',
        'URL': 'postgres://user:pa=ss@host/db',
      });
    });

    test('an invalid line is a FormatException without its content', () {
      for (final line in [
        'NOT A VARIABLE',
        '=secret',
        'KEY="hunter2',
        "KEY='hunter2",
      ]) {
        expect(
          () => Env.parseDotEnv(['OK=1', line], source: '.env.prod'),
          throwsA(
            isA<FormatException>()
                .having((e) => e.message, 'message', startsWith('.env.prod:2'))
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('hunter2')),
                ),
          ),
          reason: line,
        );
      }
    });
  });

  group('ServerConfig (§6)', () {
    test('is const, with the defaults', () {
      const config = ServerConfig();

      expect(config.host, '0.0.0.0');
      expect(config.port, defaultServerPort);
      expect(config.shared, isFalse);
      expect(config.maxBodySize, defaultMaxBodySize);
    });

    test('fromEnv reads PORT and HOST, with the given defaults', () {
      final fromPlatform = ServerConfig.fromEnv(
        Env(env: {'PORT': '9000', 'HOST': ' 127.0.0.1 '}),
      );
      final withDefaults = ServerConfig.fromEnv(
        Env(env: {}),
        port: 7000,
        host: 'localhost',
        shared: true,
        maxBodySize: null,
      );

      expect(fromPlatform.port, 9000);
      expect(fromPlatform.host, '127.0.0.1');
      expect(withDefaults.port, 7000);
      expect(withDefaults.host, 'localhost');
      expect(withDefaults.shared, isTrue);
      expect(withDefaults.maxBodySize, isNull);
    });

    test('validate rejects a value out of its range', () {
      for (final config in [
        const ServerConfig(port: -1),
        const ServerConfig(port: 65536),
        const ServerConfig(maxBodySize: -1),
        const ServerConfig(shutdownTimeout: Duration(seconds: -1)),
        const ServerConfig(host: ' '),
      ]) {
        expect(config.validate, throwsArgumentError);
      }
      expect(
        const ServerConfig(port: 0, maxBodySize: null).validate,
        returnsNormally,
      );
    });

    test('Winter.start validates it before opening the port', () async {
      await expectLater(
        Winter.start(config: const ServerConfig(port: 70000)),
        throwsArgumentError,
      );
      expect(Winter.isRunning, isFalse);
      expect(di.isRegistered<ServerConfig>(), isFalse);
    });

    test('host and shared are used by Winter.start', () async {
      await Winter.start(
        config: const ServerConfig(
          host: '127.0.0.1',
          port: 9089,
          shared: true,
          handleSignals: false,
        ),
        router: WinterRouter(
          routes: [Route.get(path: '/', handler: (r) => ResponseEntity.ok())],
        ),
      );
      addTearDown(() => Winter.close(force: true));

      final client = HttpClient();
      final response = await (await client.get('127.0.0.1', 9089, '/')).close();
      client.close();

      expect(response.statusCode, 200);
    });
  });
}

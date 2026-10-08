@TestOn('vm')
library;

import 'dart:io' show InternetAddress, ServerSocket;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9065;

  tearDown(() async {
    if (Winter.isRunning) await Winter.close(force: true);
  });

  test('Different instances do not share dependencies', () {
    final first = DependencyInjection()..put<String>('first');
    final second = DependencyInjection();

    expect(first.find<String>(), 'first');
    expect(second.tryFind<String>(), isNull);
  });

  test('Generic types are different keys', () {
    final injection = DependencyInjection()
      ..put<List<int>>([1])
      ..put<List<String>>(['a']);

    expect(injection.find<List<int>>(), [1]);
    expect(injection.find<List<String>>(), ['a']);
  });

  test('Dependencies registered by start are removed on close', () async {
    expect(di.tryFind<ServerConfig>(), isNull);

    final config = ServerConfig(port: port);
    await Winter.start(config: config);

    expect(di.find<ServerConfig>(), same(config));
    expect(di.tryFind<SecurityConfig>(), isNotNull);

    await Winter.close(force: true);

    expect(di.tryFind<ServerConfig>(), isNull);
    expect(di.tryFind<SecurityConfig>(), isNull);
    expect(di.tryFind<BaseRouter>(), isNull);
  });

  test('Dependencies registered by the user are restored on close', () async {
    final userSecurityConfig = SecurityConfig();
    di.put<SecurityConfig>(userSecurityConfig);

    await Winter.start(
      config: ServerConfig(port: port),
      securityConfig: SecurityConfig(cors: const CorsConfig()),
    );
    expect(di.find<SecurityConfig>(), isNot(same(userSecurityConfig)));

    await Winter.close(force: true);

    expect(di.find<SecurityConfig>(), same(userSecurityConfig));
    di.delete<SecurityConfig>();
  });

  test('Any router registered as BaseRouter is used', () async {
    final router = MultiRouter([WinterRouter()]);
    di.put<BaseRouter>(router);

    await Winter.start(config: ServerConfig(port: port));
    expect(Winter.server.router, same(router));

    await Winter.close(force: true);
    expect(di.find<BaseRouter>(), same(router));
    di.delete<BaseRouter>();
  });

  test('A router registered as WinterRouter is used', () async {
    final router = WinterRouter();
    di.put(router);

    await Winter.start(config: ServerConfig(port: port));
    expect(Winter.server.router, same(router));

    await Winter.close(force: true);
    di.delete<WinterRouter>();
  });

  test('A failed start does not leave dependencies behind', () async {
    final blocker = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    try {
      await expectLater(
        Winter.start(config: ServerConfig(port: port)),
        throwsA(anything),
      );
      expect(Winter.isRunning, isFalse);
      expect(di.tryFind<ServerConfig>(), isNull);
    } finally {
      await blocker.close();
    }
  });

  test('start creates the asynchronous dependencies before the port', () async {
    di.putLazyAsync<String>(() async {
      expect(Winter.isRunning, isFalse);
      return 'connected';
    });
    addTearDown(() => di.delete<String>());

    await Winter.start(config: ServerConfig(port: port));

    expect(di.find<String>(), 'connected');
  });

  test('a failing asynchronous dependency stops the start', () async {
    di.putLazyAsync<String>(() async => throw StateError('no database'));
    addTearDown(() => di.delete<String>());
    Winter.context.setUp(logger: const _SilentLogger());
    addTearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));

    await expectLater(
      Winter.start(config: ServerConfig(port: port)),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('no database'),
        ),
      ),
    );
    expect(Winter.isRunning, isFalse);
    expect(di.tryFind<ServerConfig>(), isNull);
  });
}

class _SilentLogger extends WinterLogger {
  const _SilentLogger();

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {}
}

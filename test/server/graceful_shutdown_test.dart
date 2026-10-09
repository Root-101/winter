@TestOn('vm')
library;

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9074;
  final Uri slowUrl = Uri.parse('http://localhost:$port/slow');

  late Completer<void> handlerStarted;
  late Completer<void> releaseHandler;
  final events = <String>[];

  Future<void> startServer({FutureOr<void> Function()? onShutdown}) async {
    events.clear();
    handlerStarted = Completer<void>();
    releaseHandler = Completer<void>();
    await Winter.start(
      config: ServerConfig(
        port: port,
        shutdownTimeout: const Duration(seconds: 5),
        onShutdown: onShutdown,
      ),
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/slow',
            handler: (request) async {
              handlerStarted.complete();
              await releaseHandler.future;
              events.add('handler finished');
              return ResponseEntity.ok(body: 'finished');
            },
          ),
        ],
      ),
    );
  }

  tearDown(() async {
    if (!releaseHandler.isCompleted) releaseHandler.complete();
    if (Winter.isRunning) await Winter.close(force: true);
  });

  test('A request in progress finishes before the server closes', () async {
    await startServer();

    final pendingResponse = http.get(slowUrl);
    await handlerStarted.future;

    final closing = Winter.close(timeout: const Duration(seconds: 5));
    releaseHandler.complete();

    final response = await pendingResponse;
    await closing;

    expect(response.statusCode, 200);
    expect(response.body, 'finished');
    expect(Winter.isRunning, isFalse);
  });

  test('Without timeout, close waits until the requests finish', () async {
    await startServer();

    final pendingResponse = http.get(slowUrl);
    await handlerStarted.future;

    var closed = false;
    final closing = Winter.close().then((_) => closed = true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(closed, isFalse);

    releaseHandler.complete();
    await closing;
    expect((await pendingResponse).statusCode, 200);
  });

  test('shutdown without a running server does nothing', () async {
    await Winter.shutdown();

    expect(Winter.isRunning, isFalse);
  });

  test('After the timeout the remaining connections are closed', () async {
    await startServer();

    final pendingResponse = http
        .get(slowUrl)
        .then<Object>((r) => r, onError: (Object e) => e);
    await handlerStarted.future;

    final stopwatch = Stopwatch()..start();
    await Winter.close(timeout: const Duration(milliseconds: 200));

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
    expect(Winter.isRunning, isFalse);
    expect(await pendingResponse, isA<http.ClientException>());
  });

  test('shutdown waits for the requests and then calls onShutdown', () async {
    await startServer(onShutdown: () => events.add('onShutdown'));

    final pendingResponse = http.get(slowUrl);
    await handlerStarted.future;

    final shuttingDown = Winter.shutdown();
    releaseHandler.complete();
    await shuttingDown;

    expect(events, ['handler finished', 'onShutdown']);
    expect((await pendingResponse).statusCode, 200);
    expect(Winter.isRunning, isFalse);
  });

  test('A second shutdown (ex: a second Ctrl+C) forces the close', () async {
    var onShutdownCalls = 0;
    await startServer(onShutdown: () => onShutdownCalls++);

    final pendingResponse = http
        .get(slowUrl)
        .then<Object>((r) => r, onError: (Object e) => e);
    await handlerStarted.future;

    final stopwatch = Stopwatch()..start();
    final firstShutdown = Winter.shutdown();
    await Winter.shutdown();
    await firstShutdown;

    ///It doesn't wait for the shutdownTimeout (5 s)
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));

    expect(Winter.isRunning, isFalse);
    expect(onShutdownCalls, 1);
    expect(await pendingResponse, isA<http.ClientException>());
  });
}

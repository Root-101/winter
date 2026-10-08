@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

class _MemoryLogger extends WinterLogger {
  final List<String> logs = [];

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => logs.add('${level.name}: $message');
}

/// The response of [route] for a GET of `/events`, through the whole pipeline
Future<ResponseEntity> _get(Route route) async => Winter.buildHandler(
  router: WinterRouter(routes: [route]),
)(RequestEntity('GET', Uri.parse('http://localhost/events')));

void main() {
  group('ServerSentEvent', () {
    test('writes every field, and a line break makes several data lines', () {
      expect(ServerSentEvent(data: 'Hello').encode(), 'data: Hello\n\n');
      expect(
        ServerSentEvent(
          event: 'order',
          id: '42',
          retry: const Duration(seconds: 3),
          data: 'line 1\nline 2\r\nline 3',
        ).encode(),
        'event: order\nid: 42\nretry: 3000\n'
        'data: line 1\ndata: line 2\ndata: line 3\n\n',
      );
      expect(ServerSentEvent.comment('a\nb').encode(), ': a\n: b\n\n');
      expect(ServerSentEvent(event: 'ping').encode(), 'event: ping\n\n');
    });

    test('json writes the data in one line, with the object mapper', () {
      expect(
        ServerSentEvent.json({
          'at': DateTime.utc(2026),
          'items': [1, 2],
        }, event: 'tick').encode(),
        'event: tick\ndata: {"at":"2026-01-01T00:00:00.000Z","items":[1,2]}\n\n',
      );
    });

    test('an event or an id with a line break is an ArgumentError', () {
      expect(() => ServerSentEvent(event: 'a\ndata: x'), throwsArgumentError);
      expect(() => ServerSentEvent(id: '1\r2'), throwsArgumentError);
      expect(() => ServerSentEvent(id: '1\x002'), throwsArgumentError);
    });
  });

  group('ResponseEntity.sse', () {
    test(
      'the headers, a comment first, then the events until the end',
      () async {
        final ResponseEntity response = await _get(
          Route.get(
            path: '/events',
            handler: (request) => ResponseEntity.sse(
              Stream.fromIterable([
                ServerSentEvent(data: 'one'),
                ServerSentEvent(event: 'two', data: '2'),
              ]),
            ),
          ),
        );

        expect(response.statusCode, 200);
        expect(
          response.headers['content-type'],
          'text/event-stream; charset=utf-8',
        );
        expect(response.headers['cache-control'], 'no-cache');
        expect(response.headers['x-accel-buffering'], 'no');
        expect(response.isStreamed, isTrue);
        expect(
          await response.readAsString(),
          ':\n\ndata: one\n\nevent: two\ndata: 2\n\n',
        );
      },
    );

    test('a comment every keepAlive without events', () async {
      final List<void Function(Timer)> periodic = [];
      final StreamController<ServerSentEvent> events =
          StreamController<ServerSentEvent>();
      final List<String> received = [];

      await runZoned(
        () async {
          final ResponseEntity response = await _get(
            Route.get(
              path: '/events',
              handler: (request) => ResponseEntity.sse(
                events.stream,
                keepAlive: const Duration(seconds: 15),
              ),
            ),
          );
          final subscription = response.read().listen(
            (chunk) => received.add(utf8.decode(chunk)),
          );
          await Future<void>.delayed(Duration.zero);
          periodic.last(Timer(Duration.zero, () {}));
          events.add(ServerSentEvent(data: 'x'));
          await Future<void>.delayed(Duration.zero);
          periodic.last(Timer(Duration.zero, () {}));
          await events.close();
          await subscription.asFuture<void>();
        },
        zoneSpecification: ZoneSpecification(
          createPeriodicTimer: (self, parent, zone, period, callback) {
            expect(period, const Duration(seconds: 15));
            periodic.add(callback);
            return parent.createPeriodicTimer(
              zone,
              const Duration(days: 1),
              callback,
            );
          },
        ),
      );

      expect(received, [':\n\n', ':\n\n', 'data: x\n\n', ':\n\n']);
    });

    test(
      'when the client leaves, the stream of the app is cancelled',
      () async {
        final Completer<void> cancelled = Completer<void>();
        final StreamController<ServerSentEvent> events =
            StreamController<ServerSentEvent>(onCancel: cancelled.complete);
        final ResponseEntity response = await _get(
          Route.get(
            path: '/events',
            handler: (request) =>
                ResponseEntity.sse(events.stream, keepAlive: null),
          ),
        );

        final subscription = response.read().listen((_) {});
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        await cancelled.future.timeout(const Duration(seconds: 5));
      },
    );

    test('an error of the events is logged and ends the stream', () async {
      final _MemoryLogger memoryLogger = _MemoryLogger();
      Winter.context.setUp(logger: memoryLogger);
      addTearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));

      final ResponseEntity response = await _get(
        Route.get(
          path: '/events',
          handler: (request) => ResponseEntity.sse(
            Stream<ServerSentEvent>.multi((controller) {
              controller
                ..add(ServerSentEvent(data: 'one'))
                ..addError(StateError('the queue closed'));
            }),
            keepAlive: null,
          ),
        ),
      );

      expect(await response.readAsString(), ':\n\ndata: one\n\n');
      expect(memoryLogger.logs, [
        'error: The stream of Server-Sent Events failed',
      ]);
    });
  });

  group('With the real server', () {
    const int port = 9111;

    tearDown(() async {
      if (Winter.isRunning) await Winter.close(force: true);
    });

    test('a graceful close ends the open streams instead of waiting', () async {
      await Winter.start(
        config: const ServerConfig(
          port: port,
          handleSignals: false,
          shutdownTimeout: Duration(minutes: 5),
        ),
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/events',
              // Never ends by itself
              handler: (request) => ResponseEntity.sse(
                StreamController<ServerSentEvent>().stream,
                keepAlive: null,
              ),
            ),
          ],
        ),
      );
      final HttpClient client = HttpClient();
      addTearDown(() => client.close(force: true));
      final HttpClientResponse response = await (await client.getUrl(
        Uri.parse('http://localhost:$port/events'),
      )).close();
      final Future<String> body = utf8.decodeStream(response);

      expect(response.statusCode, 200);
      expect(response.headers.contentType?.mimeType, 'text/event-stream');

      await Winter.close(timeout: const Duration(minutes: 5))
          .timeout(const Duration(seconds: 10));
      expect(await body.timeout(const Duration(seconds: 10)), ':\n\n');
      expect(Winter.isRunning, isFalse);
    });
  });
}

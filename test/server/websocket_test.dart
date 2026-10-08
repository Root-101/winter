@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// Authenticates the request when the header 'X-User' is present
class _HeaderAuth extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String? user = request.headers['X-User'];
    if (user != null) {
      request.securityContext.setAuthentication(
        Authentication(principal: user),
      );
    }
    return chain.doFilter(request);
  }
}

class _SilentLogger extends WinterLogger {
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

void main() {
  const int port = 9112;
  const String base = 'ws://localhost:$port';
  late _SilentLogger memoryLogger;

  final WinterRouter router = WinterRouter(
    routes: [
      Route.websocket(
        path: '/echo/{room}',
        handler: (socket, request) async {
          final String room = request.pathParam<String>('room');
          await for (final Object? message in socket) {
            socket.add('$room: $message');
          }
        },
      ),
      Route.websocket(
        path: '/me',
        filterConfig: FilterConfig([AuthFilter()]),
        allowedOrigins: ['https://app.example.com'],
        handler: (socket, request) {
          socket.sendJson({
            'fromRequest': request.principal<String>(),
            'fromScope': requestPrincipal<String>(),
            'requestId': requestId,
          });
        },
      ),
      Route.websocket(
        path: '/chat',
        protocols: ['chat.v2', 'chat.v1'],
        handler: (socket, request) => socket.add('protocol ${socket.protocol}'),
      ),
      Route.websocket(
        path: '/broken',
        handler: (socket, request) => throw StateError('bug'),
      ),
      Route.websocket(path: '/idle', handler: (socket, request) {}),
    ],
  );

  setUp(() async {
    memoryLogger = _SilentLogger();
    Winter.context.setUp(logger: memoryLogger);
    await Winter.start(
      config: const ServerConfig(port: port, handleSignals: false),
      router: router,
      globalFilterConfig: FilterConfig([_HeaderAuth()]),
    );
  });

  tearDown(() async {
    if (Winter.isRunning) await Winter.close(force: true);
    Winter.context.setUp(logger: const ConsoleLogger());
  });

  test('a message goes and comes back, with the path params', () async {
    final WebSocket socket = await WebSocket.connect('$base/echo/lobby');
    final Future<Object?> reply = socket.first;

    socket.add('hello');

    expect(await reply.timeout(const Duration(seconds: 5)), 'lobby: hello');
    await socket.close();
  });

  test('the filters run before the upgrade: a 401 without a user', () async {
    await expectLater(
      WebSocket.connect('$base/me'),
      throwsA(isA<WebSocketException>()),
    );
  });

  test(
    'the handler has the principal, in the request and in the scope',
    () async {
      final WebSocket socket = await WebSocket.connect(
        '$base/me',
        headers: {'X-User': 'ann'},
      );

      final Map<String, Object?> message =
          jsonDecode(await socket.first as String) as Map<String, Object?>;

      expect(message['fromRequest'], 'ann');
      expect(message['fromScope'], 'ann');
      expect(message['requestId'], isNotEmpty);
      await socket.close();
    },
  );

  test(
    'allowedOrigins: another origin is refused, no origin is let in',
    () async {
      await expectLater(
        WebSocket.connect(
          '$base/me',
          headers: {'X-User': 'ann', 'Origin': 'https://evil.example.com'},
        ),
        throwsA(isA<WebSocketException>()),
      );
      final WebSocket allowed = await WebSocket.connect(
        '$base/me',
        headers: {'X-User': 'ann', 'Origin': 'https://app.example.com'},
      );
      await allowed.first;
      await allowed.close();
    },
  );

  test('the first subprotocol of the route that the client accepts', () async {
    final WebSocket socket = await WebSocket.connect(
      '$base/chat',
      protocols: ['chat.v1', 'chat.v2'],
    );

    expect(socket.protocol, 'chat.v2');
    expect(await socket.first, 'protocol chat.v2');
    await socket.close();

    await expectLater(
      WebSocket.connect('$base/chat', protocols: ['other']),
      throwsA(isA<WebSocketException>()),
    );
  });

  test(
    'an error of the handler is logged and closes the socket (1011)',
    () async {
      final WebSocket socket = await WebSocket.connect('$base/broken');

      // The close frame comes through the stream: listen to it
      await socket.drain<void>().timeout(const Duration(seconds: 5));

      expect(socket.closeCode, WebSocketStatus.internalServerError);
      expect(
        memoryLogger.logs,
        contains('error: The WebSocket handler of /broken failed'),
      );
    },
  );

  test(
    'closing the server closes the sockets (1001), without waiting',
    () async {
      final WebSocket socket = await WebSocket.connect('$base/idle');
      // The close frame comes through the stream: listen to it
      final Future<void> closed = socket.drain<void>();

      await Winter.close(timeout: const Duration(minutes: 5))
          .timeout(const Duration(seconds: 10));
      await closed.timeout(const Duration(seconds: 5));

      expect(socket.closeCode, WebSocketStatus.goingAway);
    },
  );

  test('a request that is not a handshake is a 426', () async {
    final WinterTestClient client = WinterTestClient.build(router: router);

    final TestResponse response = await client.get('/echo/lobby');

    expect(response.statusCode, 426);
    expect(response.headers['upgrade'], 'websocket');
    expect(
      response.headers['content-type'],
      startsWith('application/problem+json'),
    );
  });
}

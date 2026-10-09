@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:realtime_examples/websocket_chat.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// A WebSocket needs a real connection: a server on a port of its own
const int port = 9301;

void main() {
  final ChatRooms rooms = ChatRooms();

  setUpAll(
    () => Winter.start(
      config: const ServerConfig(port: port, handleSignals: false),
      router: router(rooms),
    ),
  );

  tearDownAll(() => Winter.close(force: true));

  /// A client of [room], with the messages it receives decoded
  Future<(WebSocket, StreamIterator<Map<String, Object?>>)> connect(
    String room,
    String name,
  ) async {
    final WebSocket socket = await WebSocket.connect(
      'ws://localhost:$port/chat/$room?name=$name',
    );
    return (
      socket,
      StreamIterator(
        socket.map(
          (message) => jsonDecode(message as String) as Map<String, Object?>,
        ),
      ),
    );
  }

  Future<Map<String, Object?>> next(
    StreamIterator<Map<String, Object?>> messages,
  ) async {
    expect(await messages.moveNext(), isTrue);
    return messages.current;
  }

  test('everyone in the room gets every message', () async {
    final (ann, annMessages) = await connect('lobby', 'Ann');
    expect(await next(annMessages), {
      'event': 'joined',
      'name': 'Ann',
      'online': 1,
    });

    final (bob, bobMessages) = await connect('lobby', 'Bob');
    expect(await next(annMessages), {
      'event': 'joined',
      'name': 'Bob',
      'online': 2,
    });
    expect(await next(bobMessages), {
      'event': 'joined',
      'name': 'Bob',
      'online': 2,
    });

    bob.add('Hello');
    expect(await next(annMessages), {
      'event': 'message',
      'name': 'Bob',
      'text': 'Hello',
    });
    expect(await next(bobMessages), {
      'event': 'message',
      'name': 'Bob',
      'text': 'Hello',
    });

    await bob.close();
    expect(await next(annMessages), {
      'event': 'left',
      'name': 'Bob',
      'online': 1,
    });
    await ann.close();
    await annMessages.cancel();
    await bobMessages.cancel();
  });

  test('a plain GET is a 426, another website a 403', () async {
    final HttpClient http = HttpClient();
    addTearDown(http.close);

    Future<int> status(Map<String, String> headers) async {
      final HttpClientRequest request = await http.get(
        'localhost',
        port,
        '/chat/lobby',
      );
      headers.forEach(request.headers.set);
      final HttpClientResponse response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    }

    expect(await status({}), 426);
    expect(
      await status({
        'Connection': 'Upgrade',
        'Upgrade': 'websocket',
        'Sec-WebSocket-Version': '13',
        'Sec-WebSocket-Key': 'dGhlIHNhbXBsZSBub25jZQ==',
        'Origin': 'https://evil.example',
      }),
      403,
    );
  });
}

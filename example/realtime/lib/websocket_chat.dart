/// A chat over WebSockets: one room per path, every message sent to everyone in the room. The
/// handshake goes through the filters, and a plain GET is a 426.
///
/// Run: `dart run lib/websocket_chat.dart`, then in two terminals
/// `dart run lib/websocket_chat.dart --client lobby Ann` and `... --client lobby Bob`
library;

import 'dart:convert';
import 'dart:io';

import 'package:winter/winter.dart';

/// The sockets of each room
class ChatRooms {
  final Map<String, Set<WebSocket>> _rooms = {};

  int count(String room) => _rooms[room]?.length ?? 0;

  Future<void> join(String room, String name, WebSocket socket) async {
    final Set<WebSocket> members = _rooms.putIfAbsent(room, () => {})
      ..add(socket);
    _broadcast(room, {
      'event': 'joined',
      'name': name,
      'online': members.length,
    });
    try {
      // Every message of this client, until it leaves
      await for (final Object? message in socket) {
        if (message is String && message.trim().isNotEmpty) {
          _broadcast(room, {'event': 'message', 'name': name, 'text': message});
        }
      }
    } finally {
      members.remove(socket);
      _broadcast(room, {
        'event': 'left',
        'name': name,
        'online': members.length,
      });
    }
  }

  void _broadcast(String room, Map<String, Object?> message) {
    for (final WebSocket socket in _rooms[room] ?? const <WebSocket>{}) {
      socket.sendJson(message);
    }
  }
}

WinterRouter router(ChatRooms rooms) => WinterRouter(
  routes: [
    Route.websocket(
      // ws://localhost:8080/chat/lobby?name=Ann
      path: '/chat/{room|[a-z0-9-]+}',
      // Browsers send the cookies to a socket of any website: list the origins of your pages
      allowedOrigins: ['http://localhost:8080'],
      handler: (socket, request) => rooms.join(
        request.pathParam<String>('room'),
        request.queryParam<String>('name') ?? 'anonymous',
        socket,
      ),
    ),
  ],
);

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == '--client') {
    return _client(args[1], args[2]);
  }
  await Winter.start(router: router(ChatRooms()));
}

/// A client in the terminal: prints what arrives, sends each line typed
Future<void> _client(String room, String name) async {
  final WebSocket socket = await WebSocket.connect(
    'ws://localhost:8080/chat/$room?name=${Uri.encodeQueryComponent(name)}',
  );
  socket.listen((message) => stdout.writeln(message));
  await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .forEach(socket.add);
  await socket.close();
}

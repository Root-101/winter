@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:files_example/files_example.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The chat needs a real WebSocket: this test starts the server
void main() {
  const int port = 9201;
  late Directory uploads;
  late Sessions sessions;

  setUp(() async {
    uploads = Directory.systemTemp.createTempSync('chat_example_');
    sessions = Sessions();
    await Winter.start(
      config: const ServerConfig(port: port, handleSignals: false),
      globalFilterConfig: FilterConfig([SessionFilter(sessions)]),
      router: FilesApp.router(
        sessions: sessions,
        files: FileStore(uploads),
        chat: Chat(),
        origins: ['http://localhost:$port'],
      ),
    );
  });

  tearDown(() async {
    await Winter.close(force: true);
    uploads.deleteSync(recursive: true);
  });

  Future<WebSocket> join(String user) => WebSocket.connect(
    'ws://localhost:$port/chat',
    headers: {'cookie': 'session=${sessions.open(user)}'},
  );

  Future<Map<String, Object?>> next(StreamIterator<Object?> messages) async {
    await messages.moveNext().timeout(const Duration(seconds: 5));
    return jsonDecode(messages.current as String) as Map<String, Object?>;
  }

  test('every logged in user gets the messages of all of them', () async {
    final WebSocket ann = await join('ann');
    final StreamIterator<Object?> annGets = StreamIterator(ann);
    expect(await next(annGets), {'from': 'server', 'text': 'ann joined'});

    final WebSocket bob = await join('bob');
    final StreamIterator<Object?> bobGets = StreamIterator(bob);
    expect(await next(annGets), {'from': 'server', 'text': 'bob joined'});
    expect(await next(bobGets), {'from': 'server', 'text': 'bob joined'});

    bob.add('Hi!');
    expect(await next(annGets), {'from': 'bob', 'text': 'Hi!'});
    expect(await next(bobGets), {'from': 'bob', 'text': 'Hi!'});

    await bob.close();
    expect(await next(annGets), {'from': 'server', 'text': 'bob left'});
    await ann.close();
  });

  test('without the session, or from another website, it is refused', () async {
    await expectLater(
      WebSocket.connect('ws://localhost:$port/chat'),
      throwsA(isA<WebSocketException>()),
    );
    await expectLater(
      WebSocket.connect(
        'ws://localhost:$port/chat',
        headers: {
          'cookie': 'session=${sessions.open('ann')}',
          'origin': 'https://evil.example.com',
        },
      ),
      throwsA(isA<WebSocketException>()),
    );
  });
}

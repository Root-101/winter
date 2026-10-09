import 'package:realtime_examples/server_sent_events.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  // No waiting in tests: the events go out at once
  final client = WinterTestClient.build(
    router: router(interval: Duration.zero),
  );

  test('the events of the countdown, then its end', () async {
    final response = await client.get('/countdown?from=2');

    expect(response.statusCode, 200);
    expect(
      response.headers['content-type'],
      'text/event-stream; charset=utf-8',
    );
    expect(response.headers['cache-control'], 'no-cache');
    expect(
      response.body,
      ':\n\n'
      'id: 2\ndata: 2\n\n'
      'id: 1\ndata: 1\n\n'
      'event: end\nid: 0\ndata: {"done":true}\n\n',
    );
  });

  test('a client that reconnects goes on after its last event', () async {
    final response = await client.get(
      '/countdown?from=5',
      headers: {HttpHeader.lastEventId: '2'},
    );

    expect(response.body, contains('id: 1\n'));
    expect(response.body, isNot(contains('id: 2\n')));
  });
}

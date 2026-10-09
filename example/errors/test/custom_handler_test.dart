import 'dart:async';
import 'dart:io' show SocketException;

import 'package:errors_examples/custom_handler.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late ErrorTracker tracker;
  late Future<double> Function() fetch;
  final client = WinterTestClient.build(router: router(() => fetch()));

  setUp(() {
    tracker = ErrorTracker();
    Winter.context.setUp(exceptionHandler: GatewayExceptionHandler(tracker));
  });

  test('a timeout of the other service is a 504, not reported', () async {
    fetch = () => Future.error(TimeoutException('slow'));

    final response = await client.get('/weather');

    expect(response.statusCode, 504);
    expect(
      (response.json as Map)['detail'],
      'The weather service did not answer in time',
    );
    expect(tracker.reported, isEmpty);
  });

  test('an unreachable service is a 502', () async {
    fetch = () => Future.error(const SocketException('refused'));

    expect((await client.get('/weather')).statusCode, 502);
  });

  test('a bug is a generic 500, reported with the request id', () async {
    fetch = () => Future.error(StateError('a bug'));

    final response = await client.get(
      '/weather',
      headers: {'x-request-id': 'req-42'},
    );

    expect(response.statusCode, 500);
    expect((response.json as Map)['requestId'], 'req-42');
    expect(tracker.reported, ['StateError (req-42)']);
  });

  test('a ResponseException is sent as it is', () async {
    final response = await client.get('/legacy/weather');

    expect(response.statusCode, 410);
    expect(response.json, {'error': 'Use /weather'});
  });
}

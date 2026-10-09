import 'package:filters_examples/custom_filters.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(
    globalFilterConfig: globalFilters,
    router: router(),
  );

  test('a filter after the handler adds Server-Timing', () async {
    final response = await client.get('/hello');

    expect(response.headers['server-timing'], startsWith('app;dur='));
  });

  test('a filter before the handler passes a changed request', () async {
    final sent = await client.get(
      '/hello',
      headers: {'x-client-version': '2.1'},
    );
    final missing = await client.get('/hello');

    expect(sent.json, {'clientVersion': '2.1'});
    expect(missing.json, {'clientVersion': 'unknown'});
  });

  test('shouldFilter skips the static files', () async {
    expect((await client.get('/hello')).headers['cache-control'], 'no-store');
    expect(
      (await client.get('/assets/app.js')).headers['cache-control'],
      'max-age=3600',
    );
  });

  test('the global filters see the errors too', () async {
    final response = await client.get('/missing');

    expect(response.statusCode, 404);
    expect(response.headers['server-timing'], isNotNull);
  });
}

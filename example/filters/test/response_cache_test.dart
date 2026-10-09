import 'package:filters_examples/response_cache.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late DateTime now;
  late int calls;
  late WinterTestClient client;

  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    calls = 0;
    client = WinterTestClient.build(
      router: router(
        fetchRates: () => {'EUR': 0.9 + ++calls / 100},
        cache: ResponseCacheFilter(
          ttl: const Duration(minutes: 5),
          clock: () => now,
        ),
      ),
    );
  });

  test('the second request comes from the cache, the same body', () async {
    final first = await client.get('/exchange-rates');
    now = now.add(const Duration(seconds: 30));
    final second = await client.get('/exchange-rates');

    expect(first.headers['x-cache'], 'MISS');
    expect(second.headers['x-cache'], 'HIT');
    expect(second.headers['age'], '30');
    expect(second.json, first.json);
    expect(second.headers['content-type'], startsWith('application/json'));
    expect(calls, 1);
  });

  test('after the ttl it is computed again', () async {
    await client.get('/exchange-rates');
    now = now.add(const Duration(minutes: 6));
    final response = await client.get('/exchange-rates');

    expect(response.headers['x-cache'], 'MISS');
    expect(calls, 2);
  });

  test('another query is another entry', () async {
    await client.get('/exchange-rates');
    await client.get('/exchange-rates?base=USD');

    expect(calls, 2);
  });
}

import 'package:filters_examples/maintenance_mode.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUp(() {
    final Maintenance maintenance = Maintenance();
    client = WinterTestClient.build(
      globalFilterConfig: globalFilters(maintenance),
      router: router(maintenance),
    );
  });

  Future<void> switchTo(String state) => client.put(
    '/admin/maintenance',
    headers: {'content-type': 'text/plain'},
    body: state,
  );

  test('off: every route answers', () async {
    expect((await client.get('/orders')).statusCode, 200);
  });

  test('on: a 503 with Retry-After, the health check still answers', () async {
    await switchTo('on');

    final response = await client.get('/orders');
    expect(response.statusCode, 503);
    expect(response.headers['retry-after'], '300');
    expect((await client.get('/health')).statusCode, 200);
  });

  test('off again from the exempt admin route', () async {
    await switchTo('on');
    await switchTo('off');

    expect((await client.get('/orders')).statusCode, 200);
  });
}

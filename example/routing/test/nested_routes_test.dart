import 'package:routing_examples/nested_routes.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  test('the basePath and a route key', () async {
    expect((await client.get('/api/v1/status')).json, {'key': 'status'});
  });

  test('the children of /admin inherit its filter', () async {
    final stats = await client.get('/api/v1/admin/stats');
    final deleted = await client.delete('/api/v1/admin/users/2');
    final status = await client.get('/api/v1/status');

    expect(stats.headers['x-area'], 'admin');
    expect(deleted.statusCode, 204);
    expect(deleted.headers['x-area'], 'admin');
    expect(status.headers, isNot(contains('x-area')));
  });

  test('405 with Allow for another method of an existing path', () async {
    final response = await client.post('/api/v1/admin/stats');

    expect(response.statusCode, 405);
    expect(response.headers['allow'], 'GET, HEAD, OPTIONS');
  });
}

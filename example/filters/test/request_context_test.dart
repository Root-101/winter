import 'package:filters_examples/request_context.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(
    globalFilterConfig: globalFilters,
    router: router(ProjectService()),
  );

  test('the tenant from the X-Tenant header', () async {
    final response = await client.get(
      '/projects',
      headers: {'x-tenant': 'acme'},
    );

    expect(response.json, {
      'tenant': 'acme',
      'projects': ['Rocket', 'Anvil'],
    });
  });

  test('the tenant from the subdomain', () async {
    // client.get() always calls localhost: a request built by hand has any host
    final ResponseEntity response = await client.handler(
      RequestEntity('GET', Uri.parse('http://globex.api.example.com/projects')),
    );

    expect((response.body() as Map)['tenant'], 'globex');
  });

  test('no tenant, or an unknown one, is a 404', () async {
    expect((await client.get('/projects')).statusCode, 404);
    expect(
      (await client.get(
        '/projects',
        headers: {'x-tenant': 'umbrella'},
      )).statusCode,
      404,
    );
  });
}

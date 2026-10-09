import 'package:routing_examples/path_and_query_params.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  test('a typed path param; a non-number does not match', () async {
    expect((await client.get('/products/7')).json, {'id': 7});
    expect((await client.get('/products/abc')).statusCode, 404);
    expect((await client.get('/products/by-slug/red%20shoes')).json, {
      'slug': 'red shoes',
    });
  });

  test('query params: defaults, enums, booleans and repeated ones', () async {
    expect((await client.get('/products')).json, {
      'page': 1,
      'sort': 'name',
      'onlyAvailable': false,
      'tags': <String>[],
    });
    expect(
      (await client.get(
        '/products?page=2&sort=PRICE&available=true&tag=a&tag=b',
      )).json,
      {
        'page': 2,
        'sort': 'price',
        'onlyAvailable': true,
        'tags': ['a', 'b'],
      },
    );
  });

  test('an invalid query param is a 400 that names it', () async {
    final response = await client.get('/products?page=two');

    expect(response.statusCode, 400);
    expect(
      (response.json as Map)['detail'],
      'The query param page must be an integer',
    );
  });
}

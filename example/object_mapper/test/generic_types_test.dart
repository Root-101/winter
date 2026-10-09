import 'package:object_mapper_examples/generic_types.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  String? detail(TestResponse response) =>
      (response.json as Map)['detail'] as String?;

  test('a list and a map of lists', () async {
    final items = [
      {'name': 'pen', 'quantity': 2},
      {'name': 'ink', 'quantity': 3},
    ];

    expect((await client.post('/items', body: items)).json, {'units': 5});
    expect(
      (await client.post(
        '/items/by-box',
        body: {'a': items, 'b': <Object>[]},
      )).json,
      {'a': 5, 'b': 0},
    );
  });

  test('maps with int and enum keys', () async {
    expect((await client.post('/stock', body: {'7': 2, '3': 0})).json, {
      'products': [3, 7],
    });
    expect(
      (await client.post(
        '/orders/count',
        body: {'paid': 3, 'pending': 1},
      )).json,
      {'paid': 3},
    );
  });

  test('a key that is not an integer is a 400', () async {
    final response = await client.post('/stock', body: {'abc': 1});

    expect(detail(response), r'$.abc: expected an integer as the key');
  });
}

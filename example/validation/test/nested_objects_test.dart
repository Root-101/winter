import 'package:test/test.dart';
import 'package:validation_examples/nested_objects.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  Map<String, String> violations(TestResponse response) => {
    for (final v in (response.json as Map)['violations'] as List)
      (v as Map)['fieldName'] as String: v['code'] as String,
  };

  test('a valid order', () async {
    final response = await client.post(
      '/orders',
      body: {
        'address': {'street': 'Main St 1', 'zipCode': '28001'},
        'items': [
          {'product': 'p-1', 'quantity': 2},
        ],
        'prices': {
          'eur': {'cents': 1250},
        },
      },
    );

    expect(response.json, {'items': 1});
  });

  test('each violation names its path', () async {
    final response = await client.post(
      '/orders',
      body: {
        'address': {'street': 'Main St 1', 'zipCode': '280'},
        'items': [
          {'product': 'p-1', 'quantity': 2},
          {'product': ' ', 'quantity': 0},
        ],
        'prices': {
          'eur': {'cents': 0},
        },
      },
    );

    expect(response.statusCode, 422);
    expect(violations(response), {
      'address.zipCode': 'pattern',
      'items[1].product': 'notBlank',
      'items[1].quantity': 'positive',
      'prices["eur"].cents': 'positive',
    });
  });

  test('a missing address and an empty list', () async {
    final response = await client.post('/orders', body: {'items': <Object>[]});

    expect(violations(response), {'address': 'notNull', 'items': 'notEmpty'});
  });
}

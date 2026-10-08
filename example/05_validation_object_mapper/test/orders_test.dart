import 'package:orders_example/orders_example.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUpAll(() => Winter.context.setUp(objectMapper: OrdersApp.objectMapper()));

  /// A new service (empty) for each test, in memory, without a port
  setUp(
    () => client = WinterTestClient.build(
      router: OrdersApp.router(OrderService()),
    ),
  );

  Map<String, Object?> validOrder({
    List<Map<String, Object?>>? items,
    Map<String, Object?>? address,
  }) => {
    'customer_email': 'ann@example.com',
    'shipping_address':
        address ??
        {'street': 'Main St 1', 'city': 'Madrid', 'zip_code': '28001'},
    'items':
        items ??
        [
          {'product_id': 'p-1', 'quantity': 2, 'unit_price': '12.50 EUR'},
          {'product_id': 'p-2', 'quantity': 1, 'unit_price': '5.00 EUR'},
        ],
    'shipping': 'express',
    'discounts': {'SUMMER': 10},
  };

  Map<String, String> violations(TestResponse response) => {
    for (final v in (response.json as Map)['violations'] as List)
      (v as Map)['fieldName'] as String: v['code'] as String,
  };

  test('creates an order: snake_case JSON, Money as text, the total', () async {
    final response = await client.post('/orders', body: validOrder());

    expect(response.statusCode, 201);
    expect(response.headers['location'], '/orders/1');
    expect(response.json, {
      'id': 1,
      'customer_email': 'ann@example.com',
      'shipping_address': {
        'street': 'Main St 1',
        'city': 'Madrid',
        'zip_code': '28001',
      },
      'items': [
        {'product_id': 'p-1', 'quantity': 2, 'unit_price': '12.50 EUR'},
        {'product_id': 'p-2', 'quantity': 1, 'unit_price': '5.00 EUR'},
      ],
      'shipping': 'express',
      'total': '30.00 EUR',
    }, reason: 'without deliver_on: includeNulls is false');
  });

  test('a 422 names every invalid field as the client sent it', () async {
    final response = await client.post(
      '/orders',
      body: {
        ...validOrder(
          address: {'street': ' ', 'city': 'Madrid', 'zip_code': '280'},
          items: [
            {'product_id': 'p-1', 'quantity': 0, 'unit_price': '1.00 EUR'},
          ],
        ),
        'customer_email': 'not an email',
        'deliver_on': '2020-01-01T00:00:00Z',
        'discounts': {'ALL': 90},
      },
    );

    expect(response.statusCode, 422);
    expect(violations(response), {
      'customer_email': 'email',
      'shipping_address.street': 'notBlank',
      'shipping_address.zip_code': 'pattern',
      'items[0].quantity': 'positive',
      'deliver_on': 'future',
      'discounts': 'discountTooBig',
    });
  });

  test('an empty list of items is a 422 too', () async {
    final response = await client.post('/orders', body: validOrder(items: []));

    expect(violations(response), {'items': 'notEmpty'});
  });

  test('a JSON of the wrong shape is a 400', () async {
    final notAnObject = await client.post('/orders', body: '[1]');
    final badEnum = await client.post(
      '/orders',
      body: {...validOrder(), 'shipping': 'teleport'},
    );
    final badMoney = await client.post(
      '/orders',
      body: validOrder(
        items: [
          {'product_id': 'p-1', 'quantity': 1, 'unit_price': '12 euros'},
        ],
      ),
    );

    expect(notAnObject.statusCode, 400);
    expect(badEnum.statusCode, 400);
    expect(badMoney.statusCode, 400);
  });

  test('a wrong field is a 400 that names it, as the client sent it', () async {
    Future<String> detail(Map<String, Object?> body) async =>
        ((await client.post('/orders', body: body)).json as Map)['detail']
            as String;

    expect(
      await detail(
        validOrder(
          address: {'street': 'Main St 1', 'city': 'Madrid', 'zip_code': 28001},
        ),
      ),
      r'$.shipping_address.zip_code: expected a string, got an integer',
    );
    expect(
      await detail(
        validOrder(
          items: [
            {'product_id': 'p-1', 'quantity': 'two', 'unit_price': '1.00 EUR'},
          ],
        ),
      ),
      r'$.items[0].quantity: expected an integer, got a string',
    );
    expect(
      await detail({...validOrder()}..remove('customer_email')),
      r'$.customer_email: missing',
    );
  });

  test('typed path and query params', () async {
    await client.post('/orders', body: validOrder());
    await client.post(
      '/orders',
      body: {...validOrder(), 'shipping': 'standard'},
    );

    expect((await client.get('/orders/2')).json['shipping'], 'standard');
    expect((await client.get('/orders/abc')).statusCode, 400);
    expect((await client.get('/orders/9')).statusCode, 404);
    expect(
      ((await client.get('/orders?shipping=EXPRESS')).json as List)
          .single['id'],
      1,
    );
    expect((await client.get('/orders?page=x')).statusCode, 400);
  });
}

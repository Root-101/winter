import 'package:errors_examples/domain_exceptions.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// An exception of the shop added later, without a mapping of its own
class PaymentDeclined extends ShopException {}

void main() {
  late WinterTestClient client;

  setUpAll(() => Winter.context.setUp(exceptionHandler: exceptionHandler()));

  setUp(() => client = WinterTestClient.build(router: router(Shop())));

  Future<Map<String, dynamic>> order(Map<String, Object> body) async =>
      (await client.post('/orders', body: body)).json as Map<String, dynamic>;

  test('OutOfStock is a 409 with its type and its data', () async {
    expect(await order({'sku': 'pen', 'quantity': 99}), {
      'sku': 'pen',
      'available': 3,
      'type': 'https://shop.example.com/errors/out-of-stock',
      'title': 'Conflict',
      'status': 409,
      'detail': 'Only 3 left of pen',
    });
  });

  test('CouponExpired is a 422, ProductNotFound a 404', () async {
    final expired = await order({
      'sku': 'pen',
      'quantity': 1,
      'coupon': 'SUMMER',
    });
    final missing = await order({'sku': 'ink', 'quantity': 1});

    expect(expired['status'], 422);
    expect(expired['type'], 'https://shop.example.com/errors/coupon-expired');
    expect(missing['status'], 404);
    expect(missing['detail'], 'Product ink not found');
  });

  test(
    'an exception without its own mapping uses the one of its base',
    () async {
      final ResponseEntity response = await exceptionHandler()(
        RequestEntity('POST', Uri.parse('http://localhost/orders')),
        PaymentDeclined(),
        StackTrace.current,
      );

      expect(response.statusCode, 400);
      expect(
        (response.body() as ProblemDetails).type,
        'https://shop.example.com/errors/shop',
      );
    },
  );

  test('the 404 of the router, changed', () async {
    final response = await client.get('/nowhere');

    expect(response.statusCode, 404);
    expect(
      (response.json as Map)['detail'],
      'No such endpoint, see https://shop.example.com/docs',
    );
  });
}

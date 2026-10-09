/// Exceptions of the domain, answered as Problem Details without the domain knowing HTTP: the
/// services throw `OutOfStock` or `CouponExpired`, and the exception handler maps each one with
/// `on<T>()` to a status, a `type` URI the client can switch on, and extensions with data.
///
/// It also changes the answer of an error of Winter: the 404 of a path without a route.
///
/// Run: `dart run lib/domain_exceptions.dart`, then
/// `curl -X POST localhost:8080/orders -H 'Content-Type: application/json' -d '{"sku": "pen", "quantity": 99}'`
library;

import 'package:winter/winter.dart';

/// The base of the exceptions of the shop: its mapping answers the ones without their own
abstract class ShopException implements Exception {
  const ShopException();
}

class OutOfStock extends ShopException {
  final String sku;
  final int available;

  const OutOfStock(this.sku, this.available);
}

class CouponExpired extends ShopException {
  final String code;

  const CouponExpired(this.code);
}

class ProductNotFound extends ShopException {
  final String sku;

  const ProductNotFound(this.sku);
}

class Shop {
  final Map<String, int> stock = {'pen': 3};

  void order(String sku, int quantity, String? coupon) {
    final int available = stock[sku] ?? (throw ProductNotFound(sku));
    if (coupon == 'SUMMER') throw CouponExpired(coupon!);
    if (quantity > available) throw OutOfStock(sku, available);
    stock[sku] = available - quantity;
  }
}

const String errors = 'https://shop.example.com/errors';

ExceptionHandler exceptionHandler() => SimpleExceptionHandler()
  ..on<OutOfStock>(
    (request, e) => ApiException(
      StatusCode.conflict,
      type: '$errors/out-of-stock',
      detail: 'Only ${e.available} left of ${e.sku}',
      extensions: {'sku': e.sku, 'available': e.available},
    ),
  )
  ..on<CouponExpired>(
    (request, e) => ApiException(
      StatusCode.unprocessableEntity,
      type: '$errors/coupon-expired',
      detail: 'The coupon ${e.code} expired',
    ),
  )
  ..on<ProductNotFound>(
    (request, e) => NotFoundException(detail: 'Product ${e.sku} not found'),
  )
  // Any other exception of the shop: the most specific mapping wins, so this one is the fallback
  ..on<ShopException>(
    (request, e) => const BadRequestException(type: '$errors/shop'),
  )
  // An error of Winter, changed: the 404 of an unknown path points to the docs
  ..on<NotFoundException>(
    (request, e) => NotFoundException(
      detail: e.detail ?? 'No such endpoint, see https://shop.example.com/docs',
    ),
  );

WinterRouter router(Shop shop) => WinterRouter(
  routes: [
    Route.post(
      path: '/orders',
      handler: (request) async {
        final Map<String, dynamic> order = await request
            .body<Map<String, dynamic>>();
        shop.order(
          order['sku'] as String,
          order['quantity'] as int,
          order['coupon'] as String?,
        );
        return ResponseEntity.created(location: '/orders/1');
      },
    ),
  ],
);

Future<void> main() async {
  Winter.context.setUp(exceptionHandler: exceptionHandler());
  await Winter.start(router: router(Shop()));
}

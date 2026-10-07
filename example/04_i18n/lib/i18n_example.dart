import 'dart:async';

import 'package:winter/winter.dart';

import 'i18n/t.dart';

/// Body of `POST /orders`
class OrderRequest implements Validatable {
  final String? product;
  final int? quantity;

  OrderRequest({this.product, this.quantity});

  factory OrderRequest.fromJson(Map<String, dynamic> json) => OrderRequest(
    product: json['product'] as String?,
    quantity: json['quantity'] as int?,
  );

  /// The validators are built here, inside the request, so `t` has its language
  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc
        .field('product', product)
        .notBlank(message: t.orders.productRequired); // text of the app
    cvc.field('quantity', quantity).notNull().min(1); // texts of Winter
    return cvc;
  }
}

/// A service: it doesn't receive the request, and it still answers in its language
class OrderService {
  final Map<int, OrderRequest> _orders = {};
  int _nextId = 1;

  int create(OrderRequest order) {
    order.validate().throwOnFailure();
    _orders[_nextId] = order;
    return _nextId++;
  }

  OrderRequest find(int id) {
    final order = _orders[id];
    if (order == null) {
      //`t` reads the language of the request: Winter adds `Vary: Accept-Language` by itself
      throw NotFoundException(detail: t.orders.notFound(id: id));
    }
    return order;
  }
}

/// Authenticates the request with the header 'X-User' (a real app would validate a token)
class HeaderAuthFilter extends Filter {
  @override
  FutureOr<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) {
    final user = request.headers['X-User'];
    if (user != null) {
      request.securityContext.setAuthentication(
        Authentication(principal: user),
      );
    }
    return chain.doFilter(request);
  }
}

class I18nServer {
  /// The languages the app answers in; English by default
  static void configure() {
    Winter.context.setUp(
      localeConfig: LocaleConfig(
        supported: [WinterLocale.english, WinterLocale.spanish],
      ),
    );
  }

  static WinterRouter router(OrderService service) => WinterRouter(
    routes: [
      Route.get(
        path: '/hello',
        filterConfig: FilterConfig([HeaderAuthFilter(), AuthFilter()]),
        handler: (request) => ResponseEntity.ok(
          body: t.greetings.hello(name: requestAuthentication!.name),
        ),
      ),
      Route.post(
        path: '/orders',
        handler: (request) async {
          final order = OrderRequest.fromJson(
            await request.body<Map<String, dynamic>>(),
          );
          final id = service.create(order);
          return ResponseEntity(
            201,
            body: {
              'id': id,
              'message': t.orders.created(id: id),
            },
          );
        },
      ),
      Route.get(
        path: '/orders/{id}',
        handler: (request) {
          final order = service.find(int.parse(request.pathParams['id']!));
          return ResponseEntity.ok(
            body: {'product': order.product, 'quantity': order.quantity},
          );
        },
      ),
    ],
  );

  static Future<void> start({int port = 8080}) async {
    configure();
    await Winter.start(
      config: ServerConfig(port: port),
      router: router(OrderService()),
    );
  }

  static Future<void> close() => Winter.close(force: true);
}

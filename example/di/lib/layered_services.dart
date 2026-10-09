/// The usual layers, repository → service → handler, wired in `di` by their interfaces, and two
/// implementations of the same interface told apart by a tag (a payment gateway per country).
/// The test swaps the real gateway for a fake in a child container, without touching the app.
///
/// Run: `dart run lib/layered_services.dart`, then
/// `curl -X POST localhost:8080/checkout -H 'Content-Type: application/json' -d '{"country": "MX", "amount": 100}'`
library;

import 'package:winter/winter.dart';

abstract interface class PaymentGateway {
  String charge(int amount);
}

class StripeGateway implements PaymentGateway {
  @override
  String charge(int amount) => 'stripe:$amount';
}

class MercadoPagoGateway implements PaymentGateway {
  @override
  String charge(int amount) => 'mercadopago:$amount';
}

abstract interface class OrderRepository {
  int save(String paymentId);
}

class InMemoryOrderRepository implements OrderRepository {
  final List<String> payments = [];

  @override
  int save(String paymentId) {
    payments.add(paymentId);
    return payments.length;
  }
}

class CheckoutService {
  final OrderRepository orders;
  final PaymentGateway Function(String country) gatewayFor;

  CheckoutService(this.orders, this.gatewayFor);

  int checkout(String country, int amount) =>
      orders.save(gatewayFor(country).charge(amount));
}

/// Every registration of the app, in one place. Each one finds its dependencies in `di` when
/// it's created (lazily), so a test can replace any of them first
void registerDependencies() {
  di
    ..putLazy<PaymentGateway>(StripeGateway.new, tag: 'default')
    ..putLazy<PaymentGateway>(MercadoPagoGateway.new, tag: 'latam')
    ..putLazy<OrderRepository>(InMemoryOrderRepository.new)
    ..putLazy<CheckoutService>(
      () => CheckoutService(
        di.find(),
        (country) => di.find<PaymentGateway>(
          tag: const {'MX', 'AR', 'BR'}.contains(country) ? 'latam' : 'default',
        ),
      ),
    );
}

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/checkout',
      handler: (request) async {
        final Map<String, dynamic> json = await request
            .body<Map<String, dynamic>>();
        final int id = di.find<CheckoutService>().checkout(
          json['country'] as String,
          json['amount'] as int,
        );
        return ResponseEntity.created(location: '/orders/$id');
      },
    ),
  ],
);

Future<void> main() async {
  registerDependencies();
  // Optional: create every lazy one now, so a broken registration fails at start
  di.createAll();
  await Winter.start(router: router());
}

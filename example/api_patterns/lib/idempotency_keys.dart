/// Idempotency keys, as payment APIs (Stripe, Adyen) use them: a client that didn't get the
/// answer of a POST (a timeout, a dropped connection) sends it again with the same
/// `Idempotency-Key`, and gets the first answer back instead of paying twice.
///
/// The `IdempotencyFilter` of Winter on the route does it, so the handler stays a plain handler:
///
/// - The same key and the same body: the stored response, with `Idempotent-Replayed: true`.
/// - The same key with another body: a 422 (a bug of the client).
/// - The same key while the first request is still running: a 409.
/// - No key: a 400.
///
/// The keys live in an `IdempotencyStore` for 24 hours: in memory here, a table or Redis with
/// several instances. With users, `partition:` the keys by user too.
///
/// Run: `dart run lib/idempotency_keys.dart`, then twice
/// `curl -i -X POST localhost:8080/payments -H 'Idempotency-Key: 8e03978e' -H 'Content-Type: application/json' -d '{"amount": 10}'`
library;

import 'package:winter/winter.dart';

class Payment {
  final int id;
  final int amount;

  const Payment(this.id, this.amount);

  Map<String, Object> toJson() => {'id': id, 'amount': amount};
}

WinterRouter router({
  required IdempotencyStore store,
  required Future<Payment> Function(int amount) charge,
}) => WinterRouter(
  routes: [
    Route.post(
      path: '/payments',
      filterConfig: FilterConfig([IdempotencyFilter(store: store)]),
      handler: (request) async {
        final Map<String, dynamic> json = await request
            .body<Map<String, dynamic>>();
        final Payment payment = await charge(json['amount'] as int);
        return ResponseEntity.created(
          location: '/payments/${payment.id}',
          body: payment,
        );
      },
    ),
  ],
);

Future<void> main() async {
  int nextId = 1;
  await Winter.start(
    router: router(
      store: InMemoryIdempotencyStore(),
      charge: (amount) async => Payment(nextId++, amount),
    ),
  );
}

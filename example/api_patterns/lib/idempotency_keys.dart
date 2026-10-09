/// Idempotency keys, as payment APIs (Stripe, Adyen) use them: a client that didn't get the
/// answer of a POST (a timeout, a dropped connection) sends it again with the same
/// `Idempotency-Key`, and gets the first answer back instead of paying twice.
///
/// A filter on the route does it, so the handler stays a plain handler:
///
/// - The same key and the same body: the stored response, with `Idempotent-Replayed: true`.
/// - The same key with another body: a 422 (a bug of the client).
/// - The same key while the first request is still running: a 409.
/// - No key: a 400.
///
/// Run: `dart run lib/idempotency_keys.dart`, then twice
/// `curl -i -X POST localhost:8080/payments -H 'Idempotency-Key: 8e03978e' -H 'Content-Type: application/json' -d '{"amount": 10}'`
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:winter/winter.dart';

/// What is kept of a response to send it again
class StoredResponse {
  final String body;
  final int statusCode;
  final Map<String, String> headers;

  const StoredResponse(this.body, this.statusCode, this.headers);
}

/// In memory here; in production a table or Redis, with an expiration (24 hours is common)
class IdempotencyStore {
  final Map<String, (String fingerprint, StoredResponse? response)> _entries =
      {};
}

class IdempotencyFilter extends Filter {
  final IdempotencyStore store;

  IdempotencyFilter(this.store);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String? key = request.headers['idempotency-key'];
    if (key == null || key.isEmpty || key.length > 255) {
      throw const BadRequestException(
        detail: 'Send an Idempotency-Key header (at most 255 characters)',
      );
    }
    // bytes() is cached: the handler reads the same body with body<T>()
    final Uint8List body = await request.bytes();
    final String fingerprint = base64.encode(body);

    final entry = store._entries[key];
    if (entry != null) {
      final (String storedFingerprint, StoredResponse? stored) = entry;
      if (storedFingerprint != fingerprint) {
        throw const UnprocessableEntityException(
          detail: 'This Idempotency-Key was used with another body',
        );
      }
      if (stored == null) {
        throw const ConflictException(
          detail: 'A request with this Idempotency-Key is still running',
        );
      }
      return ResponseEntity(
        stored.statusCode,
        body: stored.body,
        headers: {...stored.headers, 'Idempotent-Replayed': 'true'},
      );
    }

    store._entries[key] = (fingerprint, null);
    final ResponseEntity response = await chain.doFilter(request);
    if (response.statusCode >= 500) {
      // A failure of the server: let the client try again with the same key
      store._entries.remove(key);
    } else {
      store._entries[key] = (
        fingerprint,
        StoredResponse(await response.readAsString(), response.statusCode, {
          for (final String name in const ['content-type', 'location'])
            if (response.headers[name] != null) name: response.headers[name]!,
        }),
      );
    }
    return response;
  }
}

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
      filterConfig: FilterConfig([IdempotencyFilter(store)]),
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
      store: IdempotencyStore(),
      charge: (amount) async => Payment(nextId++, amount),
    ),
  );
}

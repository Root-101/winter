import 'dart:async';

import 'package:api_patterns_examples/idempotency_keys.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late List<int> charges;
  late WinterTestClient client;

  setUp(() {
    charges = [];
    client = WinterTestClient.build(
      router: router(
        store: IdempotencyStore(),
        charge: (amount) async {
          charges.add(amount);
          return Payment(charges.length, amount);
        },
      ),
    );
  });

  Future<TestResponse> pay(String key, int amount) => client.post(
    '/payments',
    headers: {'idempotency-key': key},
    body: {'amount': amount},
  );

  test(
    'a retry with the same key gets the first answer, charged once',
    () async {
      final first = await pay('k1', 10);
      final retry = await pay('k1', 10);

      expect(first.statusCode, 201);
      expect(retry.statusCode, 201);
      expect(retry.json, first.json);
      expect(retry.headers['location'], '/payments/1');
      expect(retry.headers['idempotent-replayed'], 'true');
      expect(charges, [10]);
    },
  );

  test('another key is another payment', () async {
    await pay('k1', 10);
    await pay('k2', 10);

    expect(charges, [10, 10]);
  });

  test('the same key with another body is a 422', () async {
    await pay('k1', 10);

    expect((await pay('k1', 99)).statusCode, 422);
    expect(charges, [10]);
  });

  test('the same key while the first one runs is a 409', () async {
    final Completer<void> slow = Completer<void>();
    final blocked = WinterTestClient.build(
      router: router(
        store: IdempotencyStore(),
        charge: (amount) async {
          await slow.future;
          return Payment(1, amount);
        },
      ),
    );
    Future<TestResponse> post() => blocked.post(
      '/payments',
      headers: {'idempotency-key': 'k1'},
      body: {'amount': 10},
    );

    final Future<TestResponse> first = post();
    expect((await post()).statusCode, 409);

    slow.complete();
    expect((await first).statusCode, 201);
  });

  test('no key is a 400', () async {
    final response = await client.post('/payments', body: {'amount': 10});

    expect(response.statusCode, 400);
    expect(charges, isEmpty);
  });
}

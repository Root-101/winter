import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// `Idempotency-Key` (draft-ietf-httpapi-idempotency-key-header)
void main() {
  late List<Object?> runs;
  late DateTime now;
  late InMemoryIdempotencyStore store;
  Completer<void>? gate;
  int status = 201;

  WinterTestClient client({
    bool required = true,
    FutureOr<String> Function(RequestEntity request)? partition,
  }) => WinterTestClient.build(
    router: WinterRouter(
      routes: [
        for (final path in ['/payments', '/refunds'])
          Route.post(
            path: path,
            filterConfig: FilterConfig([
              IdempotencyFilter(
                store: store,
                required: required,
                partition: partition,
              ),
            ]),
            handler: (request) async {
              final Map<String, dynamic> body = await request
                  .body<Map<String, dynamic>>();
              runs.add(body['amount']);
              await gate?.future;
              if (status == 500) throw StateError('db down');
              return ResponseEntity(
                status,
                body: {'id': runs.length, 'amount': body['amount']},
                headers: {HttpHeader.location: '/payments/${runs.length}'},
              );
            },
          ),
        Route.get(path: '/payments', handler: (r) => ResponseEntity.ok()),
        Route.post(
          path: '/events',
          filterConfig: FilterConfig([IdempotencyFilter(store: store)]),
          handler: (r) => ResponseEntity.sse(const Stream.empty()),
        ),
      ],
    ),
  );

  setUp(() {
    runs = [];
    now = DateTime.utc(2026, 10, 1);
    store = InMemoryIdempotencyStore(clock: () => now);
    gate = null;
    status = 201;
  });

  Future<TestResponse> pay(
    WinterTestClient client,
    String? key, {
    int amount = 10,
    String path = '/payments',
    Map<String, String> headers = const {},
  }) => client.post(
    path,
    headers: {HttpHeader.idempotencyKey: ?key, ...headers},
    body: {'amount': amount},
  );

  test('a retry gets the first answer, and the handler runs once', () async {
    final payments = client();
    final first = await pay(payments, 'k1');
    final retry = await pay(payments, 'k1');

    expect(first.statusCode, 201);
    expect(first.headers, isNot(contains('idempotent-replayed')));
    expect(retry.statusCode, 201);
    expect(retry.json, first.json);
    expect(retry.headers['location'], '/payments/1');
    expect(retry.headers['content-type'], first.headers['content-type']);
    expect(retry.headers['idempotent-replayed'], 'true');
    expect(runs, [10]);
  });

  test('the key quoted (the draft) or bare is the same key', () async {
    final payments = client();
    await pay(payments, '"k1"');

    expect((await pay(payments, 'k1')).headers['idempotent-replayed'], 'true');
    expect(runs, [10]);
  });

  test('the same key with another body is a 422', () async {
    final payments = client();
    await pay(payments, 'k1');

    expect((await pay(payments, 'k1', amount: 99)).statusCode, 422);
    expect(runs, [10]);
  });

  test('the same key while the first one runs is a 409', () async {
    final payments = client();
    gate = Completer<void>();
    final Future<TestResponse> first = pay(payments, 'k1');

    expect((await pay(payments, 'k1')).statusCode, 409);
    gate!.complete();
    expect((await first).statusCode, 201);
  });

  test('no key is a 400, and so is one that is not valid', () async {
    final payments = client();

    for (final key in [null, '', '"${'a' * 256}"', 'añ']) {
      expect((await pay(payments, key)).statusCode, 400, reason: key);
    }
    expect(runs, isEmpty);
  });

  test('not required: without a key it runs every time', () async {
    final payments = client(required: false);
    await pay(payments, null);
    await pay(payments, null);

    expect(runs, [10, 10]);
  });

  test('a failure of the server is not kept: the retry runs again', () async {
    final payments = client();
    status = 500;
    expect((await pay(payments, 'k1')).statusCode, 500);

    status = 201;
    expect((await pay(payments, 'k1')).statusCode, 201);
    expect(runs, [10, 10]);
  });

  test('neither is a 429; an error of the client is', () async {
    final payments = client();
    status = 429;
    await pay(payments, 'k1');
    status = 404;
    await pay(payments, 'k1');
    final replayed = await pay(payments, 'k1');

    expect(replayed.statusCode, 404);
    expect(replayed.headers['idempotent-replayed'], 'true');
    expect(runs, [10, 10]);
  });

  test('a key is per method and path, and per partition', () async {
    final payments = client(partition: (request) => request.headers['x-user']!);
    await pay(payments, 'k1', headers: {'x-user': 'ann'});
    await pay(payments, 'k1', headers: {'x-user': 'bob'});
    await pay(payments, 'k1', headers: {'x-user': 'ann'}, path: '/refunds');

    expect(runs, [10, 10, 10]);
  });

  test(
    'a space in a partition or a key never makes the id of another',
    () async {
      final payments = client(
        partition: (request) => request.headers['x-user']!,
      );
      await pay(payments, 'x', headers: {'x-user': 'carol k2'});
      final other = await pay(payments, 'k2 x', headers: {'x-user': 'carol'});

      expect(other.headers, isNot(contains('idempotent-replayed')));
      expect(runs, [10, 10]);
    },
  );

  test('the same key with another query is a 422', () async {
    final payments = client();
    await pay(payments, 'k1', path: '/payments?account=1');

    expect(
      (await pay(payments, 'k1', path: '/payments?account=2')).statusCode,
      422,
    );
  });

  test(
    'a typed response without body is kept, and replayed without one',
    () async {
      final typed = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.post(
              path: '/notes',
              filterConfig: FilterConfig([IdempotencyFilter(store: store)]),
              handler: (request) {
                runs.add('note');
                return ResponseEntity<String>(
                  201,
                  headers: {HttpHeader.location: '/notes/1'},
                );
              },
            ),
          ],
        ),
      );
      final first = await pay(typed, 'k1', path: '/notes');
      final retry = await pay(typed, 'k1', path: '/notes');

      expect(first.statusCode, 201);
      expect(retry.statusCode, 201);
      expect(retry.headers['idempotent-replayed'], 'true');
      expect(retry.headers, isNot(contains('content-type')));
      expect(runs, ['note']);
    },
  );

  test(
    'the store keeps at most maxKeys: a new one forgets the oldest',
    () async {
      final small = InMemoryIdempotencyStore(maxKeys: 2);
      for (final key in ['a', 'b', 'c']) {
        await small.reserve(
          key,
          fingerprint: 'f',
          expiry: const Duration(hours: 1),
        );
      }

      expect(small.size, 2);
      expect(
        await small.reserve(
          'a',
          fingerprint: 'f',
          expiry: const Duration(hours: 1),
        ),
        isNull,
      );
      expect(() => InMemoryIdempotencyStore(maxKeys: 0), throwsArgumentError);
    },
  );

  test('a GET is never filtered, and a stream is never kept', () async {
    final payments = client();

    expect((await payments.get('/payments')).statusCode, 200);
    await pay(payments, 'k1', path: '/events');
    expect(
      (await pay(payments, 'k1', path: '/events')).headers,
      isNot(contains('idempotent-replayed')),
    );
  });

  test('a key expires, and the expired ones are purged', () async {
    final payments = client();
    await pay(payments, 'k1');
    now = now.add(const Duration(hours: 25));

    expect(
      (await pay(payments, 'k1')).headers,
      isNot(contains('idempotent-replayed')),
    );
    expect(runs, [10, 10]);
    expect(store.size, 1);
    await store.clear();
    expect(store.size, 0);
  });

  test(
    'without an exception handler the error goes on, and the key is free',
    () async {
      final filter = IdempotencyFilter(store: store);
      final request = RequestEntity(
        'POST',
        Uri.parse('http://localhost/payments'),
        headers: {HttpHeader.idempotencyKey: 'k1'},
      );

      await expectLater(
        FilterChain([filter], (r) => throw StateError('bug')).doFilter(request),
        throwsStateError,
      );
      expect(store.size, 0);
      // Completing a key that isn't there does nothing
      await store.complete(
        'gone',
        IdempotentResponse(
          statusCode: 200,
          headers: const {},
          body: Uint8List(0),
        ),
      );
      expect(store.size, 0);
    },
  );

  test('an expiry that is not positive is an ArgumentError', () {
    expect(() => IdempotencyFilter(expiry: Duration.zero), throwsArgumentError);
  });
}

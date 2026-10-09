import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// A clock controlled by the test: no real waits, exact durations
class _FakeClock {
  DateTime now = DateTime.utc(2026);

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

void main() {
  late _FakeClock clock;

  setUp(() => clock = _FakeClock());

  RateLimiter limiter(int maxRequests, Duration window) =>
      RateLimiter(maxRequests: maxRequests, window: window, clock: clock.call);

  group('RateLimiter (Class)', () {
    Future<bool> allowed(RateLimiter limiter, String id) async =>
        (await limiter.check(id)).allowed;

    test('should allow requests within limit', () async {
      final rateLimiter = limiter(3, const Duration(seconds: 1));

      expect(await allowed(rateLimiter, 'user1'), isTrue);
      expect(await allowed(rateLimiter, 'user1'), isTrue);
      expect(await allowed(rateLimiter, 'user1'), isTrue);
    });

    test('should deny requests exceeding limit', () async {
      final rateLimiter = limiter(2, const Duration(seconds: 1));

      expect(await allowed(rateLimiter, 'user1'), isTrue);
      expect(await allowed(rateLimiter, 'user1'), isTrue);
      expect(await allowed(rateLimiter, 'user1'), isFalse);
    });

    test('should handle different IDs independently', () async {
      final rateLimiter = limiter(1, const Duration(seconds: 1));

      expect(await allowed(rateLimiter, 'user1'), isTrue);
      expect(await allowed(rateLimiter, 'user2'), isTrue);
      expect(await allowed(rateLimiter, 'user1'), isFalse);
      expect(await allowed(rateLimiter, 'user2'), isFalse);
    });

    test('a request is allowed again only after the whole window', () async {
      final rateLimiter = limiter(1, const Duration(seconds: 1));
      expect(await allowed(rateLimiter, 'user1'), isTrue);

      clock.advance(const Duration(seconds: 1));
      expect(await allowed(rateLimiter, 'user1'), isFalse);

      clock.advance(const Duration(microseconds: 1));
      expect(await allowed(rateLimiter, 'user1'), isTrue);
    });

    test('the window slides: each request expires on its own', () async {
      final rateLimiter = limiter(2, const Duration(seconds: 10));
      await rateLimiter.check('user1');
      clock.advance(const Duration(seconds: 6));
      await rateLimiter.check('user1');
      expect(await allowed(rateLimiter, 'user1'), isFalse);

      ///Only the first request left the window
      clock.advance(const Duration(seconds: 5));
      expect((await rateLimiter.peek('user1')).remaining, 1);
      expect(await allowed(rateLimiter, 'user1'), isTrue);
      expect(await allowed(rateLimiter, 'user1'), isFalse);
    });

    test(
      'remaining counts the requests left, peek does not record one',
      () async {
        final rateLimiter = limiter(5, const Duration(seconds: 1));
        await rateLimiter.check('user1');
        final second = await rateLimiter.check('user1');

        expect(second.remaining, 3);
        expect(second.limit, 5);
        expect((await rateLimiter.peek('user1')).remaining, 3);
        expect((await rateLimiter.peek('user1')).remaining, 3);
        expect((await rateLimiter.peek('user2')).remaining, 5);
      },
    );

    test('retryAfter is exactly the time until a slot is free', () async {
      final rateLimiter = limiter(1, const Duration(seconds: 1));
      expect((await rateLimiter.peek('user1')).retryAfter, Duration.zero);

      final first = await rateLimiter.check('user1');
      expect(first.allowed, isTrue);
      expect(first.retryAfter, Duration.zero);
      expect(
        (await rateLimiter.peek('user1')).retryAfter,
        const Duration(seconds: 1),
      );

      clock.advance(const Duration(milliseconds: 300));
      final denied = await rateLimiter.check('user1');
      expect(denied.allowed, isFalse);
      expect(denied.retryAfter, const Duration(milliseconds: 700));
    });

    test('resetAfter is the time until the oldest request expires', () async {
      final rateLimiter = limiter(2, const Duration(seconds: 10));
      expect((await rateLimiter.peek('id')).resetAfter, Duration.zero);

      await rateLimiter.check('id');
      clock.advance(const Duration(seconds: 4));
      final result = await rateLimiter.check('id');

      expect(result.resetAfter, const Duration(seconds: 6));
    });

    test('reset forgets one id, clear forgets all of them', () async {
      final store = InMemoryRateLimiterStore();
      final rateLimiter = RateLimiter(
        maxRequests: 1,
        window: const Duration(minutes: 1),
        store: store,
        clock: clock.call,
      );
      await rateLimiter.check('user1');
      await rateLimiter.check('user2');

      await rateLimiter.reset('user1');
      expect(await allowed(rateLimiter, 'user1'), isTrue);
      expect(await allowed(rateLimiter, 'user2'), isFalse);

      await rateLimiter.clear();
      expect(store.trackedIds, 0);
      expect(await allowed(rateLimiter, 'user2'), isTrue);
    });

    test(
      'a limit or a window that would break every request is an ArgumentError',
      () {
        expect(
          () => RateLimiter(maxRequests: 0, window: const Duration(minutes: 1)),
          throwsArgumentError,
        );
        expect(
          () => RateLimiter(maxRequests: 5, window: Duration.zero),
          throwsArgumentError,
        );
        expect(
          () =>
              RateLimiter(maxRequests: 5, window: const Duration(minutes: -1)),
          throwsArgumentError,
        );
      },
    );

    test(
      'a store of its own (Redis...) is used through the interface',
      () async {
        final store = _CountingStore();
        final rateLimiter = RateLimiter(
          maxRequests: 3,
          window: const Duration(seconds: 1),
          store: store,
        );

        await rateLimiter.check('a');
        await rateLimiter.peek('a');
        await rateLimiter.reset('a');
        await rateLimiter.clear();

        expect(store.calls, ['hit a record', 'hit a peek', 'reset a', 'clear']);
      },
    );
  });

  group('RateLimiterFilter', () {
    late RateLimiter rateLimiter;
    late RateLimiterFilter filter;
    late RequestEntity request;

    setUp(() {
      rateLimiter = limiter(2, const Duration(seconds: 1));
      filter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: rateLimiter,
        clientId: (req) => 'test-user',
      );
      request = RequestEntity('GET', Uri.parse('http://localhost/test'));
    });

    Future<ResponseEntity> handle(RequestEntity req) async =>
        ResponseEntity.ok();

    test('should allow request and add Rate-Limit headers', () async {
      final chain = FilterChain([], handle);

      final response = await _run(filter, request, chain);

      expect(response.statusCode, 200);
      expect(response.headers['X-RateLimit-Limit'], '2');
      expect(response.headers['X-RateLimit-Remaining'], '1');
      expect(response.headers['X-RateLimit-Reset'], '1');
    });

    test('should deny request when limit exceeded', () async {
      final chain = FilterChain([], handle);

      // Consume limit (2 requests)
      await _run(filter, request, chain);
      await _run(filter, request, chain);

      // Third one should fail
      final response = await _run(filter, request, chain);

      expect(response.statusCode, 429); // Too Many Requests
      expect(response.headers['X-RateLimit-Remaining'], '0');
      expect(response.headers['Retry-After'], '1');
    });

    test('should update remaining requests in headers', () async {
      final chain = FilterChain([], handle);

      final response1 = await _run(filter, request, chain);
      expect(response1.headers['X-RateLimit-Remaining'], '1');

      final response2 = await _run(filter, request, chain);
      expect(response2.headers['X-RateLimit-Remaining'], '0');
    });

    test('should handle different users independently', () async {
      final multiUserFilter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: limiter(1, const Duration(seconds: 1)),
        clientId: (req) => req.headers['user-id'] ?? 'anonymous',
      );
      final chain = FilterChain([], handle);
      final user1 = RequestEntity(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'user-id': '1'},
      );
      final user2 = RequestEntity(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'user-id': '2'},
      );

      expect((await _run(multiUserFilter, user1, chain)).statusCode, 200);
      expect((await _run(multiUserFilter, user2, chain)).statusCode, 200);
      expect((await _run(multiUserFilter, user1, chain)).statusCode, 429);
    });

    test('should allow requests again after window expires', () async {
      final chain = FilterChain([], handle);
      await _run(filter, request, chain);
      await _run(filter, request, chain);
      expect((await _run(filter, request, chain)).statusCode, 429);

      clock.advance(const Duration(seconds: 1, microseconds: 1));

      expect((await _run(filter, request, chain)).statusCode, 200);
    });

    test('Retry-After is the real wait, rounded up', () async {
      final chain = FilterChain([], handle);
      final slowFilter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: limiter(1, const Duration(seconds: 10)),
        clientId: (req) => 'test-user',
      );
      await _run(slowFilter, request, chain);

      clock.advance(const Duration(milliseconds: 2500));
      final response = await _run(slowFilter, request, chain);

      expect(response.statusCode, 429);
      expect(response.headers['Retry-After'], '8');
    });

    test('X-RateLimit-Reset counts down (not the window size)', () async {
      final chain = FilterChain([], handle);
      final countDownFilter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: limiter(5, const Duration(seconds: 3)),
        clientId: (req) => 'id',
      );

      final first = await _run(countDownFilter, request, chain);
      expect(first.headers['X-RateLimit-Reset'], '3');

      clock.advance(const Duration(seconds: 1));
      final second = await _run(countDownFilter, request, chain);
      expect(second.headers['X-RateLimit-Reset'], '2');
    });

    test('should work with an async ID extractor', () async {
      final asyncFilter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: limiter(1, const Duration(seconds: 1)),
        clientId: (req) async {
          await Future<void>.delayed(Duration.zero);
          return 'async-user';
        },
      );
      final chain = FilterChain([], handle);

      expect((await _run(asyncFilter, request, chain)).statusCode, 200);
      expect((await _run(asyncFilter, request, chain)).statusCode, 429);
    });

    test('should call log function only when limit exceeded', () async {
      final loggedIds = <String>[];
      final loggingFilter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: limiter(1, const Duration(seconds: 1)),
        clientId: (req) => 'test-user',
        onLimited: (req, id) => loggedIds.add(id),
      );
      final chain = FilterChain([], handle);

      await _run(loggingFilter, request, chain); // OK
      expect(loggedIds, isEmpty);

      await _run(loggingFilter, request, chain); // Limited
      expect(loggedIds, ['test-user']);
    });
  });

  group('InMemoryRateLimiterStore memory', () {
    late InMemoryRateLimiterStore store;

    RateLimiter limiterWithStore(int maxRequests, Duration window) =>
        RateLimiter(
          maxRequests: maxRequests,
          window: window,
          store: store,
          clock: clock.call,
        );

    setUp(() => store = InMemoryRateLimiterStore());

    test('inactive ids are purged automatically (once per window)', () async {
      final rateLimiter = limiterWithStore(1, const Duration(seconds: 1));
      await rateLimiter.check('ip-1');
      await rateLimiter.check('ip-2');
      expect(store.trackedIds, 2);

      clock.advance(const Duration(seconds: 2));
      await rateLimiter.check('ip-3');

      expect(store.trackedIds, 1);
    });

    test('ids with requests inside the window are not purged', () async {
      final rateLimiter = limiterWithStore(5, const Duration(seconds: 2));
      await rateLimiter.check('ip-1');

      clock.advance(const Duration(seconds: 1));
      await rateLimiter.check('ip-1');
      clock.advance(const Duration(milliseconds: 1500));
      await rateLimiter.check('ip-2');

      expect(store.trackedIds, 2);
      expect((await rateLimiter.peek('ip-1')).remaining, 4);
    });

    test('ids without requests (only consulted) are purged', () async {
      final rateLimiter = limiterWithStore(5, const Duration(seconds: 1));
      await rateLimiter.peek('only-consulted');
      expect(store.trackedIds, 1);

      store.purgeInactive(
        now: clock.now,
        threshold: const Duration(seconds: 2),
      );

      expect(store.trackedIds, 0);
    });

    test('purgeInactive keeps the ids with a recent request', () async {
      final rateLimiter = limiterWithStore(5, const Duration(seconds: 1));
      await rateLimiter.check('ip-1');

      clock.advance(const Duration(milliseconds: 1500));
      store.purgeInactive(
        now: clock.now,
        threshold: const Duration(seconds: 2),
      );
      expect(store.trackedIds, 1);

      clock.advance(const Duration(seconds: 1));
      store.purgeInactive(
        now: clock.now,
        threshold: const Duration(seconds: 2),
      );
      expect(store.trackedIds, 0);
    });
  });

  group('RateLimiterFilter in the pipeline', () {
    WinterTestClient client() => WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/limited',
            handler: (request) => ResponseEntity.ok(body: 'ok'),
            filterConfig: FilterConfig([
              RateLimiterFilter(
                maxRequests: 1,
                window: const Duration(minutes: 1),
                clientId: (request) => 'client',
              ),
            ]),
          ),
          Route.get(
            path: '/unlimited',
            handler: (request) => ResponseEntity.ok(body: 'ok'),
          ),
        ],
      ),
    );

    test(
      'the 429 is a Problem Details with Retry-After and the limits',
      () async {
        final limited = client();
        await limited.get('/limited');
        final response = await limited.get('/limited');

        expect(response.statusCode, 429);
        expect(
          response.headers['content-type'],
          startsWith('application/problem+json'),
        );
        expect(response.headers['retry-after'], isNotNull);
        expect(response.headers['x-ratelimit-limit'], '1');
        expect(response.headers['x-ratelimit-remaining'], '0');
      },
    );

    test('a route without the filter is never limited', () async {
      final unlimited = client();
      for (var i = 0; i < 5; i++) {
        final response = await unlimited.get('/unlimited');
        expect(response.statusCode, 200);
        expect(response.headers.containsKey('x-ratelimit-limit'), isFalse);
      }
    });
  });
}

/// Runs [filter] like the server does: an exception it throws becomes its response
Future<ResponseEntity> _run(
  Filter filter,
  RequestEntity request,
  FilterChain chain,
) async {
  try {
    return await filter.doFilter(request, chain);
  } catch (error, stackTrace) {
    return SimpleExceptionHandler()(request, error, stackTrace);
  }
}

/// A store that only records the calls, like a Redis one would receive them
class _CountingStore implements RateLimiterStore {
  final List<String> calls = [];

  @override
  Future<RateLimitResult> hit(
    String id, {
    required int limit,
    required Duration window,
    required DateTime now,
    bool record = true,
  }) async {
    calls.add('hit $id ${record ? 'record' : 'peek'}');
    return RateLimitResult(
      allowed: true,
      limit: limit,
      remaining: limit,
      resetAfter: Duration.zero,
      retryAfter: Duration.zero,
    );
  }

  @override
  Future<void> reset(String id) async => calls.add('reset $id');

  @override
  Future<void> clear() async => calls.add('clear');
}

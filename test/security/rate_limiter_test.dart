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
      RateLimiter(maxRequests, window, clock: clock.call);

  group('RateLimiter (Class)', () {
    test('should allow requests within limit', () {
      final rateLimiter = limiter(3, const Duration(seconds: 1));

      expect(rateLimiter.allowRequest('user1'), isTrue);
      expect(rateLimiter.allowRequest('user1'), isTrue);
      expect(rateLimiter.allowRequest('user1'), isTrue);
    });

    test('should deny requests exceeding limit', () {
      final rateLimiter = limiter(2, const Duration(seconds: 1));

      expect(rateLimiter.allowRequest('user1'), isTrue);
      expect(rateLimiter.allowRequest('user1'), isTrue);
      expect(rateLimiter.allowRequest('user1'), isFalse);
    });

    test('should handle different IDs independently', () {
      final rateLimiter = limiter(1, const Duration(seconds: 1));

      expect(rateLimiter.allowRequest('user1'), isTrue);
      expect(rateLimiter.allowRequest('user2'), isTrue);
      expect(rateLimiter.allowRequest('user1'), isFalse);
      expect(rateLimiter.allowRequest('user2'), isFalse);
    });

    test('a request is allowed again only after the whole window', () {
      final rateLimiter = limiter(1, const Duration(seconds: 1));
      expect(rateLimiter.allowRequest('user1'), isTrue);

      clock.advance(const Duration(seconds: 1));
      expect(rateLimiter.allowRequest('user1'), isFalse);

      clock.advance(const Duration(microseconds: 1));
      expect(rateLimiter.allowRequest('user1'), isTrue);
    });

    test('the window slides: each request expires on its own', () {
      final rateLimiter = limiter(2, const Duration(seconds: 10));
      rateLimiter.allowRequest('user1');
      clock.advance(const Duration(seconds: 6));
      rateLimiter.allowRequest('user1');
      expect(rateLimiter.allowRequest('user1'), isFalse);

      ///Only the first request left the window
      clock.advance(const Duration(seconds: 5));
      expect(rateLimiter.getRemaining('user1'), 1);
      expect(rateLimiter.allowRequest('user1'), isTrue);
      expect(rateLimiter.allowRequest('user1'), isFalse);
    });

    test('getRemaining should return correct number of remaining requests', () {
      final rateLimiter = limiter(5, const Duration(seconds: 1));
      rateLimiter.allowRequest('user1');
      rateLimiter.allowRequest('user1');

      expect(rateLimiter.getRemaining('user1'), equals(3));
      expect(rateLimiter.getRemaining('user2'), equals(5));
    });

    test('getWaitDuration is exactly the time until a slot is free', () {
      final rateLimiter = limiter(1, const Duration(seconds: 1));
      expect(rateLimiter.getWaitDuration('user1'), Duration.zero);

      rateLimiter.allowRequest('user1');
      expect(rateLimiter.getWaitDuration('user1'), const Duration(seconds: 1));

      clock.advance(const Duration(milliseconds: 300));
      expect(
        rateLimiter.getWaitDuration('user1'),
        const Duration(milliseconds: 700),
      );
    });

    test('reset forgets one id, clear forgets all of them', () {
      final rateLimiter = limiter(1, const Duration(minutes: 1));
      rateLimiter.allowRequest('user1');
      rateLimiter.allowRequest('user2');

      rateLimiter.reset('user1');
      expect(rateLimiter.allowRequest('user1'), isTrue);
      expect(rateLimiter.allowRequest('user2'), isFalse);

      rateLimiter.clear();
      expect(rateLimiter.trackedIds, 0);
      expect(rateLimiter.allowRequest('user2'), isTrue);
    });
  });

  group('RateLimiterFilter', () {
    late RateLimiter rateLimiter;
    late RateLimiterFilter filter;
    late RequestEntity request;

    setUp(() {
      rateLimiter = limiter(2, const Duration(seconds: 1));
      filter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: rateLimiter,
        onRequest: (req) => 'test-user',
      );
      request = RequestEntity('GET', Uri.parse('http://localhost/test'));
    });

    Future<ResponseEntity> handle(RequestEntity req) async =>
        ResponseEntity.ok();

    test('should allow request and add Rate-Limit headers', () async {
      final chain = FilterChain([], handle);

      final response = await filter.doFilter(request, chain);

      expect(response.statusCode, 200);
      expect(response.headers['X-RateLimit-Limit'], '2');
      expect(response.headers['X-RateLimit-Remaining'], '1');
      expect(response.headers['X-RateLimit-Reset'], '1');
    });

    test('should deny request when limit exceeded', () async {
      final chain = FilterChain([], handle);

      // Consume limit (2 requests)
      await filter.doFilter(request, chain);
      await filter.doFilter(request, chain);

      // Third one should fail
      final response = await filter.doFilter(request, chain);

      expect(response.statusCode, 429); // Too Many Requests
      expect(response.headers['X-RateLimit-Remaining'], '0');
      expect(response.headers['Retry-After'], '1');
    });

    test('should update remaining requests in headers', () async {
      final chain = FilterChain([], handle);

      final response1 = await filter.doFilter(request, chain);
      expect(response1.headers['X-RateLimit-Remaining'], '1');

      final response2 = await filter.doFilter(request, chain);
      expect(response2.headers['X-RateLimit-Remaining'], '0');
    });

    test('should handle different users independently', () async {
      final multiUserFilter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: limiter(1, const Duration(seconds: 1)),
        onRequest: (req) => req.headers['user-id'] ?? 'anonymous',
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

      expect((await multiUserFilter.doFilter(user1, chain)).statusCode, 200);
      expect((await multiUserFilter.doFilter(user2, chain)).statusCode, 200);
      expect((await multiUserFilter.doFilter(user1, chain)).statusCode, 429);
    });

    test('should allow requests again after window expires', () async {
      final chain = FilterChain([], handle);
      await filter.doFilter(request, chain);
      await filter.doFilter(request, chain);
      expect((await filter.doFilter(request, chain)).statusCode, 429);

      clock.advance(const Duration(seconds: 1, microseconds: 1));

      expect((await filter.doFilter(request, chain)).statusCode, 200);
    });

    test('Retry-After is the real wait, rounded up', () async {
      final chain = FilterChain([], handle);
      final slowFilter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: limiter(1, const Duration(seconds: 10)),
        onRequest: (req) => 'test-user',
      );
      await slowFilter.doFilter(request, chain);

      clock.advance(const Duration(milliseconds: 2500));
      final response = await slowFilter.doFilter(request, chain);

      expect(response.statusCode, 429);
      expect(response.headers['Retry-After'], '8');
    });

    test('X-RateLimit-Reset counts down (not the window size)', () async {
      final chain = FilterChain([], handle);
      final countDownFilter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: limiter(5, const Duration(seconds: 3)),
        onRequest: (req) => 'id',
      );

      final first = await countDownFilter.doFilter(request, chain);
      expect(first.headers['X-RateLimit-Reset'], '3');

      clock.advance(const Duration(seconds: 1));
      final second = await countDownFilter.doFilter(request, chain);
      expect(second.headers['X-RateLimit-Reset'], '2');
    });

    test('should work with an async ID extractor', () async {
      final asyncFilter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: limiter(1, const Duration(seconds: 1)),
        onRequest: (req) async {
          await Future<void>.delayed(Duration.zero);
          return 'async-user';
        },
      );
      final chain = FilterChain([], handle);

      expect((await asyncFilter.doFilter(request, chain)).statusCode, 200);
      expect((await asyncFilter.doFilter(request, chain)).statusCode, 429);
    });

    test('should call log function only when limit exceeded', () async {
      final loggedIds = <String>[];
      final loggingFilter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: limiter(1, const Duration(seconds: 1)),
        onRequest: (req) => 'test-user',
        log: (req, id) => loggedIds.add(id),
      );
      final chain = FilterChain([], handle);

      await loggingFilter.doFilter(request, chain); // OK
      expect(loggedIds, isEmpty);

      await loggingFilter.doFilter(request, chain); // Limited
      expect(loggedIds, ['test-user']);
    });
  });

  group('RateLimiter memory', () {
    test('inactive ids are purged automatically (once per window)', () {
      final rateLimiter = limiter(1, const Duration(seconds: 1));
      rateLimiter.allowRequest('ip-1');
      rateLimiter.allowRequest('ip-2');
      expect(rateLimiter.trackedIds, 2);

      clock.advance(const Duration(seconds: 2));
      rateLimiter.allowRequest('ip-3');

      expect(rateLimiter.trackedIds, 1);
    });

    test('ids with requests inside the window are not purged', () {
      final rateLimiter = limiter(5, const Duration(seconds: 2));
      rateLimiter.allowRequest('ip-1');

      clock.advance(const Duration(seconds: 1));
      rateLimiter.allowRequest('ip-1');
      clock.advance(const Duration(milliseconds: 1500));
      rateLimiter.allowRequest('ip-2');

      expect(rateLimiter.trackedIds, 2);
      expect(rateLimiter.getRemaining('ip-1'), 4);
    });

    test('ids without requests (only consulted) are purged', () {
      final rateLimiter = limiter(5, const Duration(seconds: 1));
      rateLimiter.getRemaining('only-consulted');
      expect(rateLimiter.trackedIds, 1);

      rateLimiter.purgeInactive();

      expect(rateLimiter.trackedIds, 0);
    });

    test('purgeInactive uses twice the window by default', () {
      final rateLimiter = limiter(5, const Duration(seconds: 1));
      rateLimiter.allowRequest('ip-1');

      clock.advance(const Duration(milliseconds: 1500));
      rateLimiter.purgeInactive();
      expect(rateLimiter.trackedIds, 1);

      clock.advance(const Duration(seconds: 1));
      rateLimiter.purgeInactive();
      expect(rateLimiter.trackedIds, 0);
    });

    test('getResetDuration is the time until the oldest request expires', () {
      final rateLimiter = limiter(2, const Duration(seconds: 10));
      expect(rateLimiter.getResetDuration('id'), Duration.zero);

      rateLimiter.allowRequest('id');
      clock.advance(const Duration(seconds: 4));
      rateLimiter.allowRequest('id');

      expect(rateLimiter.getResetDuration('id'), const Duration(seconds: 6));
    });
  });
}

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('RateLimiter (Class)', () {
    test('should allow requests within limit', () {
      final limiter = RateLimiter(3, const Duration(seconds: 1));

      expect(limiter.allowRequest('user1'), isTrue);
      expect(limiter.allowRequest('user1'), isTrue);
      expect(limiter.allowRequest('user1'), isTrue);
    });

    test('should deny requests exceeding limit', () {
      final limiter = RateLimiter(2, const Duration(seconds: 1));

      expect(limiter.allowRequest('user1'), isTrue);
      expect(limiter.allowRequest('user1'), isTrue);
      expect(limiter.allowRequest('user1'), isFalse);
    });

    test('should handle different IDs independently', () {
      final limiter = RateLimiter(1, const Duration(seconds: 1));

      expect(limiter.allowRequest('user1'), isTrue);
      expect(limiter.allowRequest('user2'), isTrue);
      expect(limiter.allowRequest('user1'), isFalse);
      expect(limiter.allowRequest('user2'), isFalse);
    });

    test(
      'should allow requests again after window expires',
      () async {
        final limiter = RateLimiter(1, const Duration(milliseconds: 50));

        expect(limiter.allowRequest('user1'), isTrue);
        expect(limiter.allowRequest('user1'), isFalse);

        await Future.delayed(const Duration(milliseconds: 60));

        expect(limiter.allowRequest('user1'), isTrue);
      },
    );

    test(
      'getRemaining should return correct number of remaining requests',
      () {
        final limiter = RateLimiter(5, const Duration(seconds: 1));
        limiter.allowRequest('user1');
        limiter.allowRequest('user1');

        expect(limiter.getRemaining('user1'), equals(3));
        expect(limiter.getRemaining('user2'), equals(5));
      },
    );

    test('getWaitDuration should return correct duration', () {
      final limiter = RateLimiter(1, const Duration(seconds: 1));
      limiter.allowRequest('user1');

      final wait = limiter.getWaitDuration('user1');
      expect(wait.inMilliseconds, greaterThan(0));
      expect(wait.inMilliseconds, lessThanOrEqualTo(1000));
    });
  });

  group('RateLimiterFilter', () {
    late RateLimiter limiter;
    late RateLimiterFilter filter;
    late RequestEntity request;

    setUp(() {
      limiter = RateLimiter(2, const Duration(seconds: 1));
      filter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: limiter,
        onRequest: (req) => 'test-user',
      );
      request = RequestEntity('GET', Uri.parse('http://localhost/test'));
    });

    Future<ResponseEntity> handle(RequestEntity req) async =>
        ResponseEntity.ok();

    test(
      'should allow request and add Rate-Limit headers',
      () async {
        final chain = FilterChain([], handle);

        final response = await filter.doFilter(request, chain);

        expect(response.statusCode, 200);
        expect(response.headers['X-RateLimit-Limit'], '2');
        expect(response.headers['X-RateLimit-Remaining'], '1');
        expect(response.headers['X-RateLimit-Reset'], '1');
      },
    );

    test('should deny request when limit exceeded', () async {
      final chain = FilterChain([], handle);

      // Consume limit (2 requests)
      await filter.doFilter(request, chain);
      await filter.doFilter(request, chain);

      // Third one should fail
      final response = await filter.doFilter(request, chain);

      expect(response.statusCode, 429); // Too Many Requests
      expect(response.headers['X-RateLimit-Remaining'], '0');
      expect(response.headers['Retry-After'], isNotNull);
    });

    test(
      'should update remaining requests in headers',
      () async {
        final chain = FilterChain([], handle);

        final response1 = await filter.doFilter(request, chain);
        expect(response1.headers['X-RateLimit-Remaining'], '1');

        final response2 = await filter.doFilter(request, chain);
        expect(response2.headers['X-RateLimit-Remaining'], '0');
      },
    );

    test('should handle different clients independently', () async {
      filter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: RateLimiter(1, const Duration(seconds: 1)),
        onRequest: (req) => req.headers['X-User-ID'] ?? 'anonymous',
      );

      final request1 = RequestEntity(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'X-User-ID': 'user1'},
      );
      final request2 = RequestEntity(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'X-User-ID': 'user2'},
      );

      final chain = FilterChain([], handle);

      final response1 = await filter.doFilter(request1, chain);
      final response2 = await filter.doFilter(request2, chain);

      expect(response1.statusCode, 200);
      expect(response2.statusCode, 200);

      final response1Blocked = await filter.doFilter(request1, chain);
      expect(response1Blocked.statusCode, 429);
    });

    test(
      'should allow requests again after window expires',
      () async {
        final limiter = RateLimiter(1, const Duration(milliseconds: 100));
        filter = RateLimiterFilter.fromRateLimiter(
          rateLimiter: limiter,
          onRequest: (req) => 'test-user',
        );
        final chain = FilterChain([], handle);

        await filter.doFilter(request, chain);
        final responseBlocked = await filter.doFilter(request, chain);
        expect(responseBlocked.statusCode, 429);

        await Future.delayed(const Duration(milliseconds: 150));

        final responseAllowed = await filter.doFilter(request, chain);
        expect(responseAllowed.statusCode, 200);
      },
    );

    test('should work with an async ID extractor', () async {
      filter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: RateLimiter(1, const Duration(seconds: 1)),
        onRequest: (req) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 'async-user';
        },
      );
      final chain = FilterChain([], handle);

      final response = await filter.doFilter(request, chain);
      expect(response.statusCode, 200);
    });

    test('should call log function when limit exceeded', () async {
      String? loggedId;
      filter = RateLimiterFilter.fromRateLimiter(
        rateLimiter: RateLimiter(1, const Duration(seconds: 1)),
        onRequest: (req) => 'test-user',
        log: (req, id) => loggedId = id,
      );
      final chain = FilterChain([], handle);

      await filter.doFilter(request, chain); // OK
      await filter.doFilter(request, chain); // Limited

      expect(loggedId, equals('test-user'));
    });
  });
}

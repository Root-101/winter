import 'dart:collection';

/// A rate limiter that implements the Sliding Window Log algorithm: no more than
/// [maxRequests] requests of the same id within any rolling [window].
///
/// ```dart
/// final limiter = RateLimiter(
///   maxRequests: 100,
///   window: const Duration(minutes: 1),
/// );
/// final result = await limiter.check(clientIp);
/// if (!result.allowed) throw TooManyRequestsException(retryAfter: result.retryAfter.inSeconds);
/// ```
///
/// The requests are kept in a [RateLimiterStore]. The default one is in memory, so the limit is
/// **per isolate and per process**: four instances of the server allow four times the limit. A
/// shared store (Redis) can implement the same interface.
///
/// {@category Security}
class RateLimiter {
  /// Maximum number of requests allowed within the given [window].
  final int maxRequests;

  /// The duration of the sliding window.
  final Duration window;

  /// Where the requests are kept
  final RateLimiterStore store;

  /// Source of the current time, `DateTime.now` by default.
  /// Tests can pass a fake clock to control the time without waiting.
  final DateTime Function() _clock;

  /// A limiter of [maxRequests] (1 or more) per [window] (positive): an [ArgumentError] otherwise.
  /// Without [store], an [InMemoryRateLimiterStore].
  RateLimiter({
    required this.maxRequests,
    required this.window,
    RateLimiterStore? store,
    DateTime Function()? clock,
  }) : store = store ?? InMemoryRateLimiterStore(),
       _clock = clock ?? DateTime.now {
    if (maxRequests < 1) {
      throw ArgumentError.value(
        maxRequests,
        'maxRequests',
        'Must be 1 or more',
      );
    }
    if (window <= Duration.zero) {
      throw ArgumentError.value(window, 'window', 'Must be positive');
    }
  }

  /// Records a request of [id] if it's allowed, and returns the state after it
  Future<RateLimitResult> check(String id) =>
      store.hit(id, limit: maxRequests, window: window, now: _clock());

  /// The state of [id] without recording a request: whether one would be allowed now
  Future<RateLimitResult> peek(String id) => store.hit(
    id,
    limit: maxRequests,
    window: window,
    now: _clock(),
    record: false,
  );

  /// Forgets the requests of [id]
  Future<void> reset(String id) => store.reset(id);

  /// Forgets every request
  Future<void> clear() => store.clear();
}

/// The state of an id after a request (see [RateLimiter.check])
///
/// {@category Security}
class RateLimitResult {
  /// Whether the request is allowed (and was recorded)
  final bool allowed;

  /// The max number of requests in the window
  final int limit;

  /// The requests left in the current window
  final int remaining;

  /// Until the oldest request leaves the window (one more is available then); zero without
  /// requests in the window
  final Duration resetAfter;

  /// Until a request is allowed again; zero when it's allowed now
  final Duration retryAfter;

  /// The result of a check
  const RateLimitResult({
    required this.allowed,
    required this.limit,
    required this.remaining,
    required this.resetAfter,
    required this.retryAfter,
  });
}

/// Where a [RateLimiter] keeps the requests of every id. It's asynchronous so a shared store
/// (Redis, a database) can implement it; [hit] must be atomic for an id.
///
/// {@category Security}
abstract interface class RateLimiterStore {
  /// The requests of [id] in the [window] that ends at [now]: if they are fewer than [limit],
  /// the request is allowed, and recorded when [record]
  Future<RateLimitResult> hit(
    String id, {
    required int limit,
    required Duration window,
    required DateTime now,
    bool record = true,
  });

  /// Forgets the requests of [id]
  Future<void> reset(String id);

  /// Forgets every request
  Future<void> clear();
}

/// The default [RateLimiterStore]: the timestamps of the requests of every id, in memory.
///
/// Once per window it forgets the ids without requests in it, so the memory doesn't grow with
/// every new id (ex: every new IP). It holds up to `limit` timestamps per active id.
///
/// {@category Security}
class InMemoryRateLimiterStore implements RateLimiterStore {
  /// [Queue] for O(1) removal of expired timestamps from the front.
  final Map<String, Queue<DateTime>> _requestsLog = {};

  /// Last time the inactive ids were purged automatically.
  DateTime? _lastPurge;

  /// Number of ids currently tracked (useful to monitor the memory usage).
  int get trackedIds => _requestsLog.length;

  @override
  Future<RateLimitResult> hit(
    String id, {
    required int limit,
    required Duration window,
    required DateTime now,
    bool record = true,
  }) async {
    _autoPurge(now, window);
    final logs = _cleanLogs(id, now, window);

    final bool allowed = logs.length < limit;
    if (allowed && record) logs.addLast(now);

    Duration until(DateTime moment) {
      final wait = moment.difference(now);
      return wait.isNegative ? Duration.zero : wait;
    }

    final int remaining = limit - logs.length;
    return RateLimitResult(
      allowed: allowed,
      limit: limit,
      remaining: remaining > 0 ? remaining : 0,
      resetAfter: logs.isEmpty ? Duration.zero : until(logs.first.add(window)),
      retryAfter: allowed ? Duration.zero : until(logs.first.add(window)),
    );
  }

  @override
  Future<void> reset(String id) async {
    _requestsLog.remove(id);
  }

  @override
  Future<void> clear() async {
    _requestsLog.clear();
  }

  /// Forgets the ids whose last request is older than [threshold] at [now]
  void purgeInactive({required DateTime now, required Duration threshold}) {
    _requestsLog.removeWhere((id, logs) {
      if (logs.isEmpty) return true;
      return now.difference(logs.last) > threshold;
    });
  }

  /// Once per [window], remove the ids without requests in the current window.
  /// Those ids don't have any useful info, all their requests are already expired.
  void _autoPurge(DateTime now, Duration window) {
    final DateTime? last = _lastPurge;
    if (last == null) {
      _lastPurge = now;
      return;
    }
    if (now.difference(last) < window) return;
    _lastPurge = now;
    purgeInactive(now: now, threshold: window);
  }

  Queue<DateTime> _cleanLogs(String id, DateTime now, Duration window) {
    final logs = _requestsLog.putIfAbsent(id, () => Queue<DateTime>());

    final expirationTime = now.subtract(window);
    while (logs.isNotEmpty && logs.first.isBefore(expirationTime)) {
      logs.removeFirst();
    }

    return logs;
  }
}

import 'dart:collection';

/// A rate limiter that implements the Sliding Window Log algorithm.
///
/// It tracks the exact timestamp of each request and ensures that
/// no more than [maxRequests] occur within any rolling [window].
class RateLimiter {
  /// Maximum number of requests allowed within the given [window].
  final int maxRequests;

  /// The duration of the sliding window.
  final Duration window;

  /// Internal storage for request timestamps per unique identifier.
  /// Uses [Queue] for O(1) removal of expired timestamps from the front.
  final Map<String, Queue<DateTime>> _requestsLog = {};

  /// Last time the inactive ids were purged automatically.
  DateTime _lastPurge = DateTime.now();

  RateLimiter(this.maxRequests, this.window);

  /// Checks if a request from [requestId] is allowed.
  ///
  /// If the request is allowed, it is automatically recorded.
  /// Returns `true` if the request is within limits, `false` otherwise.
  bool allowRequest(String requestId) {
    final now = DateTime.now();
    _autoPurge(now);
    final logs = _getAndCleanLogs(requestId, now);

    if (logs.length < maxRequests) {
      logs.addLast(now);
      return true;
    }

    return false;
  }

  /// Calculates how long a client should wait before their next request
  /// might be allowed.
  ///
  /// Returns [Duration.zero] if a request would be allowed immediately.
  Duration getWaitDuration(String requestId) {
    final now = DateTime.now();
    final logs = _getAndCleanLogs(requestId, now);

    if (logs.length < maxRequests) {
      return Duration.zero;
    }

    // The next slot opens up when the oldest request falls out of the window.
    final oldestRequest = logs.first;
    final nextAvailableAt = oldestRequest.add(window);
    final wait = nextAvailableAt.difference(now);

    return wait.isNegative ? Duration.zero : wait;
  }

  /// Calculates how long until the oldest request of [requestId] leaves the window,
  /// this is, when the remaining requests will increase again.
  ///
  /// Returns [Duration.zero] if there are no requests in the current window.
  Duration getResetDuration(String requestId) {
    final now = DateTime.now();
    final logs = _getAndCleanLogs(requestId, now);

    if (logs.isEmpty) {
      return Duration.zero;
    }

    final wait = logs.first.add(window).difference(now);
    return wait.isNegative ? Duration.zero : wait;
  }

  /// Returns the number of requests remaining for the given [requestId]
  /// within the current window.
  int getRemaining(String requestId) {
    final now = DateTime.now();
    final logs = _getAndCleanLogs(requestId, now);
    final remaining = maxRequests - logs.length;
    return remaining > 0 ? remaining : 0;
  }

  /// Number of ids currently tracked (useful to monitor the memory usage).
  int get trackedIds => _requestsLog.length;

  /// Manually clears the logs for a specific [requestId].
  void reset(String requestId) {
    _requestsLog.remove(requestId);
  }

  /// Removes all cached data.
  void clear() {
    _requestsLog.clear();
  }

  /// Cleans up memory by removing entries for IDs that haven't
  /// made a request in a long time.
  ///
  /// If [threshold] is not provided, it defaults to twice the [window].
  void purgeInactive({Duration? threshold}) {
    final now = DateTime.now();
    final limit = threshold ?? (window * 2);

    _requestsLog.removeWhere((id, logs) {
      if (logs.isEmpty) return true;
      return now.difference(logs.last) > limit;
    });
  }

  /// Once per [window], remove the ids without requests in the current window,
  /// so the memory doesn't grow forever with every new id (ex: every new IP).
  /// Those ids don't have any useful info, all their requests are already expired.
  void _autoPurge(DateTime now) {
    if (now.difference(_lastPurge) < window) return;
    _lastPurge = now;
    purgeInactive(threshold: window);
  }

  Queue<DateTime> _getAndCleanLogs(String requestId, DateTime now) {
    final logs = _requestsLog.putIfAbsent(requestId, () => Queue<DateTime>());

    final expirationTime = now.subtract(window);
    while (logs.isNotEmpty && logs.first.isBefore(expirationTime)) {
      logs.removeFirst();
    }

    return logs;
  }
}

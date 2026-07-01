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

  RateLimiter(this.maxRequests, this.window);

  /// Checks if a request from [requestId] is allowed.
  ///
  /// If the request is allowed, it is automatically recorded.
  /// Returns `true` if the request is within limits, `false` otherwise.
  bool allowRequest(String requestId) {
    final now = DateTime.now();
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

  /// Returns the number of requests remaining for the given [requestId]
  /// within the current window.
  int getRemaining(String requestId) {
    final now = DateTime.now();
    final logs = _getAndCleanLogs(requestId, now);
    final remaining = maxRequests - logs.length;
    return remaining > 0 ? remaining : 0;
  }

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

  Queue<DateTime> _getAndCleanLogs(String requestId, DateTime now) {
    final logs = _requestsLog.putIfAbsent(requestId, () => Queue<DateTime>());

    final expirationTime = now.subtract(window);
    while (logs.isNotEmpty && logs.first.isBefore(expirationTime)) {
      logs.removeFirst();
    }

    return logs;
  }
}

class RateLimiter {
  /// Max allowed requests
  final int maxRequests;

  /// Time window duration
  final Duration window;

  /// Storage all requests
  final Map<String, List<DateTime>> _requestsLog = {};

  RateLimiter(this.maxRequests, this.window);

  bool allowRequest(String requestId) {
    final now = DateTime.now();

    ///Clean up old requests
    _removeOldRequests(requestId, now);

    /// check if id has exceeded max-requests
    if ((_requestsLog[requestId]?.length ?? 0) >= maxRequests) {
      ///limit reached
      return false;
    }

    ///Register this request
    _logRequest(requestId, now);

    /// allow this request
    return true;
  }

  void _logRequest(String requestId, DateTime now) {
    if (!_requestsLog.containsKey(requestId)) {
      _requestsLog[requestId] = [];
    }

    ///Add request to log
    _requestsLog[requestId]!.add(now);
  }

  void _removeOldRequests(String userId, DateTime now) {
    if (!_requestsLog.containsKey(userId)) return;

    /// delete all requests outside the allowed time window
    _requestsLog[userId] = _requestsLog[userId]!
        .where((requestTime) => now.difference(requestTime) < window)
        .toList();
  }
}

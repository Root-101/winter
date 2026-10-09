/// A cache of responses in memory, as a route filter: an expensive `GET` (a report, a call to
/// another API) is computed once and served from memory for a while. `X-Cache` says whether it
/// was a hit, and `Age` how old the copy is.
///
/// Only successful responses are kept, and the key is the path with its query, so `?page=2` is
/// another entry. A response that depends on the user must not be cached like this.
///
/// Run: `dart run lib/response_cache.dart`, then twice `curl -i localhost:8080/exchange-rates`
library;

import 'package:winter/winter.dart';

class _Entry {
  final DateTime storedAt;
  final int statusCode;
  final String body;
  final String? contentType;

  _Entry(this.storedAt, this.statusCode, this.body, this.contentType);
}

class ResponseCacheFilter extends Filter {
  final Duration ttl;
  final DateTime Function() clock;
  final Map<String, _Entry> _entries = {};

  ResponseCacheFilter({required this.ttl, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  @override
  bool shouldFilter(RequestEntity request) => request.method == 'GET';

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String key = request.requestedUri.toString();
    final DateTime now = clock();

    final _Entry? cached = _entries[key];
    if (cached != null && now.difference(cached.storedAt) < ttl) {
      return ResponseEntity(
        cached.statusCode,
        body: cached.body,
        headers: {
          'X-Cache': 'HIT',
          HttpHeader.age: '${now.difference(cached.storedAt).inSeconds}',
          HttpHeader.contentType: ?cached.contentType,
        },
      );
    }

    final ResponseEntity response = await chain.doFilter(request);
    if (response.statusCode == 200) {
      // A JSON or text body can be read again after the filter: the client still gets it
      _entries[key] = _Entry(
        now,
        response.statusCode,
        await response.readAsString(),
        response.headers[HttpHeader.contentType],
      );
    }
    return response.copyWith(headers: {'X-Cache': 'MISS'});
  }
}

WinterRouter router({
  required Map<String, double> Function() fetchRates,
  required ResponseCacheFilter cache,
}) => WinterRouter(
  routes: [
    Route.get(
      path: '/exchange-rates',
      filterConfig: FilterConfig([cache]),
      handler: (request) => ResponseEntity.ok(body: fetchRates()),
    ),
  ],
);

Future<void> main() async => Winter.start(
  router: router(
    // An expensive call to another API
    fetchRates: () => {'EUR': 0.92, 'GBP': 0.79},
    cache: ResponseCacheFilter(ttl: const Duration(minutes: 5)),
  ),
);

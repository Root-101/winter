/// Writing filters: code before and after the handler, the `order` of the chain, `shouldFilter`
/// to skip a request, and passing a changed request to the rest of the chain.
///
/// Run: `dart run lib/custom_filters.dart`, then `curl -i localhost:8080/hello`
library;

import 'package:winter/winter.dart';

/// After the handler: how long it took, as `Server-Timing` (the browser shows it in its tools)
class TimingFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final ResponseEntity response = await chain.doFilter(request);
    return response.copyWith(
      headers: {'Server-Timing': 'app;dur=${stopwatch.elapsedMilliseconds}'},
    );
  }
}

/// Before the handler: a header for the next filters and the handler. The request is
/// read-only, so the filter passes a copy
class ClientVersionFilter extends Filter {
  // Runs before the filters with the default order (0)
  ClientVersionFilter() : super(order: -10);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String version = request.headers['x-client-version'] ?? 'unknown';
    return chain.doFilter(
      request.copyWith(headers: {'x-client-version': version}),
    );
  }
}

/// Not for every request: `shouldFilter` skips the static files
class NoCacheFilter extends Filter {
  @override
  bool shouldFilter(RequestEntity request) =>
      !request.requestedUri.path.startsWith('/assets/');

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final ResponseEntity response = await chain.doFilter(request);
    return response.copyWith(headers: {HttpHeader.cacheControl: 'no-store'});
  }
}

final FilterConfig globalFilters = FilterConfig([
  LoggingFilter(),
  TimingFilter(),
  NoCacheFilter(),
  ClientVersionFilter(),
]);

WinterRouter router() => WinterRouter(
  routes: [
    Route.get(
      path: '/hello',
      handler: (request) => ResponseEntity.ok(
        body: {'clientVersion': request.headers['x-client-version']},
      ),
    ),
    Route.get(
      path: '/assets/app.js',
      handler: (request) => ResponseEntity.ok(
        body: 'console.log("hi")',
        headers: {HttpHeader.cacheControl: 'max-age=3600'},
      ),
    ),
  ],
);

Future<void> main() async =>
    Winter.start(globalFilterConfig: globalFilters, router: router());

/// Maintenance mode, switched on and off while the server runs: a filter answers every request
/// with a 503 and `Retry-After` without reaching the handlers (it short-circuits the chain),
/// except the health check, so the orchestrator doesn't restart the instance, and the admin
/// route that switches it off.
///
/// Run: `dart run lib/maintenance_mode.dart`, then
/// `curl -X PUT localhost:8080/admin/maintenance -d on` and `curl -i localhost:8080/orders`
library;

import 'package:winter/winter.dart';

class Maintenance {
  bool enabled = false;
}

class MaintenanceFilter extends Filter {
  final Maintenance maintenance;

  /// The paths that keep answering
  final List<String> exempt;

  MaintenanceFilter(this.maintenance, {this.exempt = const []});

  @override
  bool shouldFilter(RequestEntity request) =>
      !exempt.any((prefix) => request.requestedUri.path.startsWith(prefix));

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (maintenance.enabled) {
      throw ServiceUnavailableException(
        retryAfter: 300,
        detail: 'Down for maintenance, back in a few minutes',
      );
    }
    return chain.doFilter(request);
  }
}

WinterRouter router(Maintenance maintenance) => WinterRouter(
  routes: [
    Route.get(
      path: '/orders',
      handler: (request) => ResponseEntity.ok(body: ['order 1']),
    ),
    Route.health(path: '/health'),
    // A real app protects this route (see example/security)
    Route.put(
      path: '/admin/maintenance',
      handler: (request) async {
        maintenance.enabled = await request.body<String>() == 'on';
        return ResponseEntity.ok(body: {'maintenance': maintenance.enabled});
      },
    ),
  ],
);

FilterConfig globalFilters(Maintenance maintenance) => FilterConfig([
  MaintenanceFilter(maintenance, exempt: ['/health', '/admin/']),
]);

Future<void> main() async {
  final Maintenance maintenance = Maintenance();
  await Winter.start(
    globalFilterConfig: globalFilters(maintenance),
    router: router(maintenance),
  );
}

/// Multi-tenancy: a filter finds the tenant of the request (the `X-Tenant` header, or the
/// subdomain `acme.api.example.com`) and saves it in the context of the request, under a typed
/// key. The handler reads `request.tenant`, a normal property, and gives it to the services.
///
/// Run: `dart run lib/request_context.dart`, then `curl -H 'X-Tenant: acme' localhost:8080/projects`
library;

import 'package:winter/winter.dart';

class Tenant {
  final String id;

  const Tenant(this.id);
}

/// The key: private to this file, so nobody else reads or overwrites it
final ContextKey<Tenant> _tenantKey = ContextKey<Tenant>('tenant');

/// `request.tenant` everywhere, with its type
extension TenantRequest on RequestEntity {
  Tenant get tenant =>
      context.get(_tenantKey) ?? (throw StateError('No TenantFilter'));
}

class TenantFilter extends Filter {
  final Set<String> tenants;

  TenantFilter(this.tenants) : super(order: -50);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String host = request.requestedUri.host;
    final String? id =
        request.headers['x-tenant'] ??
        (host.split('.').length > 2 ? host.split('.').first : null);
    if (id == null || !tenants.contains(id)) {
      throw const NotFoundException(detail: 'Unknown tenant');
    }
    request.context.set(_tenantKey, Tenant(id));
    return chain.doFilter(request);
  }
}

class ProjectService {
  final Map<String, List<String>> _projects = {
    'acme': ['Rocket', 'Anvil'],
    'globex': ['Dome'],
  };

  List<String> of(Tenant tenant) => _projects[tenant.id] ?? const [];
}

WinterRouter router(ProjectService projects) => WinterRouter(
  routes: [
    Route.get(
      path: '/projects',
      handler: (request) => ResponseEntity.ok(
        body: {
          'tenant': request.tenant.id,
          'projects': projects.of(request.tenant),
        },
      ),
    ),
  ],
);

final FilterConfig globalFilters = FilterConfig([
  TenantFilter({'acme', 'globex'}),
]);

Future<void> main() async => Winter.start(
  globalFilterConfig: globalFilters,
  router: router(ProjectService()),
);

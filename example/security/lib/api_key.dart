/// API keys for machine clients (a partner, a script, another service): a global filter reads
/// `X-API-Key` and gives the client the permissions of its key; `AuthFilter` protects everything
/// but `/public`, and each route asks for the permission it needs.
///
/// Run: `dart run lib/api_key.dart`, then `curl -H 'X-API-Key: read-key' localhost:8080/orders`
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:winter/winter.dart';

/// Who owns a key, and what it can do
class ApiClient {
  final String name;
  final Set<String> permissions;

  const ApiClient(this.name, this.permissions);

  @override
  String toString() => name;
}

/// The keys are kept hashed, like passwords: a leak of the table doesn't leak the keys
class ApiKeyStore {
  final Map<String, ApiClient> _byHash;

  ApiKeyStore(Map<String, ApiClient> clientsByKey)
    : _byHash = {
        for (final MapEntry(:key, :value) in clientsByKey.entries)
          hash(key): value,
      };

  static String hash(String key) => sha256.convert(utf8.encode(key)).toString();

  ApiClient? find(String key) => _byHash[hash(key)];
}

class ApiKeyFilter extends Filter {
  final ApiKeyStore store;

  ApiKeyFilter(this.store);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String? key = request.headers['x-api-key'];
    final ApiClient? client = key == null ? null : store.find(key);
    // A wrong key is the same as no key: AuthFilter answers the 401
    if (client != null) {
      request.securityContext.setAuthentication(
        Authentication<ApiClient>(
          principal: client,
          permissions: client.permissions,
        ),
      );
    }
    return chain.doFilter(request);
  }
}

WinterRouter router() => WinterRouter(
  routes: [
    Route.get(
      path: '/public/status',
      handler: (request) => ResponseEntity.ok(body: {'status': 'ok'}),
    ),
    Route.get(
      path: '/orders',
      filterConfig: hasPermission('orders.read').toFilterConfig(),
      handler: (request) => ResponseEntity.ok(
        body: {
          'client': requestPrincipal<ApiClient>().name,
          'orders': <Object>[],
        },
      ),
    ),
    Route.post(
      path: '/orders',
      filterConfig: hasPermission('orders.write').toFilterConfig(),
      handler: (request) => ResponseEntity.created(location: '/orders/1'),
    ),
  ],
);

/// The filters of the whole app: who is calling, then "somebody must be calling"
FilterConfig globalFilters(ApiKeyStore store) => FilterConfig([
  ApiKeyFilter(store),
  AuthFilter(
    challenge: 'ApiKey header="X-API-Key"',
    shouldFilter: (request) =>
        !request.requestedUri.path.startsWith('/public/'),
  ),
]);

final ApiKeyStore exampleKeys = ApiKeyStore({
  'read-key': const ApiClient('reporting', {'orders.read'}),
  'write-key': const ApiClient('shop', {'orders.read', 'orders.write'}),
});

Future<void> main() async => Winter.start(
  globalFilterConfig: globalFilters(exampleKeys),
  router: router(),
);

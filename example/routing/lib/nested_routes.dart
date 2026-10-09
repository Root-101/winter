/// Nested routes: a common prefix (`Route.parent`) whose filters the children inherit, a
/// `basePath`, and route keys that a filter uses.
///
/// Run: `dart run lib/nested_routes.dart`, then `curl -i localhost:8080/api/v1/admin/stats`
library;

import 'package:winter/winter.dart';

/// Adds `X-Area: admin` to every response of the routes under it
class AdminAreaFilter extends Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final ResponseEntity response = await chain.doFilter(request);
    return response.copyWith(headers: {'X-Area': 'admin'});
  }
}

WinterRouter router() => WinterRouter(
  basePath: '/api/v1',
  routes: [
    Route.get(
      path: '/status',
      key: 'status',
      handler: (request) =>
          ResponseEntity.ok(body: {'key': request.route?.key}),
    ),
    Route.parent(
      path: '/admin',
      filterConfig: FilterConfig([AdminAreaFilter()]),
      routes: [
        Route.get(
          path: '/stats',
          handler: (request) => ResponseEntity.ok(body: {'users': 2}),
        ),
        Route.parent(
          path: '/users',
          routes: [
            // /api/v1/admin/users/{id}: the paths join, the filter of /admin applies
            Route.delete(
              path: '/{id|[0-9]+}',
              handler: (request) => ResponseEntity.noContent(),
            ),
          ],
        ),
      ],
    ),
  ],
);

Future<void> main() async => Winter.start(router: router());

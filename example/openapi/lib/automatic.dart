/// What Winter documents by itself, without a single `RouteDocs`: the paths, the typed path
/// params, the security of the `AuthFilter`s, the 429 of a rate limit, the health check, and every
/// error as Problem Details.
///
/// Run: `dart run lib/automatic.dart`, then open http://localhost:8080/docs
library;

import 'package:winter/winter.dart';

WinterRouter router() {
  final router = WinterRouter(
    routes: [
      // {id|[0-9]+}: an integer param, with its 400 and 404
      Route.get(
        path: '/products/{id|[0-9]+}',
        handler: (request) =>
            ResponseEntity.ok(body: {'id': request.pathParam<int>('id')}),
      ),
      // Another regex: a string with a pattern
      Route.get(
        path: '/countries/{code|[A-Z][A-Z]}',
        handler: (request) => ResponseEntity.ok(
          body: {'code': request.pathParam<String>('code')},
        ),
      ),
      // An AuthFilter with rules: Bearer security, a 401 and a 403
      Route.delete(
        path: '/products/{id|[0-9]+}',
        filterConfig: FilterConfig([AuthFilter(rules: hasRole('admin'))]),
        handler: (request) => ResponseEntity.noContent(),
      ),
      // A rate limit: a 429
      Route.get(
        path: '/search',
        filterConfig: FilterConfig([
          RateLimiterFilter(
            maxRequests: 10,
            window: const Duration(minutes: 1),
          ),
        ]),
        handler: (request) => ResponseEntity.ok(body: const <Object>[]),
      ),
      // Documented by itself: its UP/DOWN body and its 503
      Route.health(path: '/health'),
    ],
  );
  return router
    ..addRoute(
      Route.openApi(
        openApi: OpenApi(title: 'Shop', version: '1.0.0', router: router),
      ),
    )
    ..addRoute(Route.swaggerUi(title: 'Shop'));
}

Future<void> main() async => Winter.start(router: router());

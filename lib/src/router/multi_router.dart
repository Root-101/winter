import 'dart:async';

import 'package:collection/collection.dart';
import 'package:winter/winter.dart';

class MultiRouter extends AbstractWinterRouter {
  final List<AbstractWinterRouter> routes;

  MultiRouter(this.routes);

  @override
  bool canHandle(RequestEntity request) {
    return routes.any((element) => element.canHandle(request));
  }

  ///Delegate to the same router that [handler] will use,
  ///so the route-level filters & path params of the inner routers are applied
  @override
  Route? resolveRoute(RequestEntity request) {
    return routes
        .firstWhereOrNull((element) => element.canHandle(request))
        ?.resolveRoute(request);
  }

  @override
  FutureOr<ResponseEntity> handler(RequestEntity request) {
    AbstractWinterRouter? router = routes.firstWhereOrNull(
      (element) => element.canHandle(request),
    );
    if (router == null) {
      ///Same responses as WinterRouter: 405 if the path exists but not for this method, 404 otherwise
      return methodNotAllowedOrNotFound(allowedMethods(request));
    }
    return router.handler(request);
  }

  ///Methods allowed for the path of the request in any inner router (in any nesting level)
  Set<HttpMethod> allowedMethods(RequestEntity request) {
    return {
      for (final router in routes)
        ...switch (router) {
          WinterRouter() => router.allowedMethods(request),
          MultiRouter() => router.allowedMethods(request),
          _ => const <HttpMethod>{},
        },
    };
  }
}

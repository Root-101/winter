import 'dart:async';

import 'package:collection/collection.dart';
import 'package:winter/winter.dart';

///A router made of [routers]: a request goes to the first one that can handle it
class MultiRouter extends AbstractWinterRouter {
  final List<AbstractWinterRouter> routers;

  MultiRouter(List<AbstractWinterRouter> routers)
    : routers = List.unmodifiable(routers);

  @override
  bool canHandle(RequestEntity request) {
    return routers.any((element) => element.canHandle(request));
  }

  ///Delegate to the same router that [handler] will use,
  ///so the route-level filters & path params of the inner routers are applied
  @override
  Route? resolveRoute(RequestEntity request) {
    return routers
        .firstWhereOrNull((element) => element.canHandle(request))
        ?.resolveRoute(request);
  }

  @override
  FutureOr<ResponseEntity> handler(RequestEntity request) {
    AbstractWinterRouter? router = routers.firstWhereOrNull(
      (element) => element.canHandle(request),
    );
    if (router == null) {
      ///Same responses as WinterRouter: 204 for OPTIONS, 405 if the path exists but not for this
      ///method, 404 otherwise
      return noRouteResponse(request, allowedMethods(request));
    }
    return router.handler(request);
  }

  ///Methods allowed for the path of the request in any inner router (in any nesting level)
  Set<HttpMethod> allowedMethods(RequestEntity request) {
    return {
      for (final router in routers)
        ...switch (router) {
          WinterRouter() => router.allowedMethods(request),
          MultiRouter() => router.allowedMethods(request),
          _ => const <HttpMethod>{},
        },
    };
  }
}

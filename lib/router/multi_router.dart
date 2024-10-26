import 'dart:async';

import 'package:collection/collection.dart';
import 'package:winter/winter.dart';

class MultiRouter extends AbstractWinterRouter {
  final List<AbstractWinterRouter> routes;

  MultiRouter(this.routes);

  @override
  bool canHandle(RequestEntity request) {
    return routes.any(
      (element) => element.canHandle(request),
    );
  }

  @override
  FutureOr<ResponseEntity> handler(RequestEntity request) {
    AbstractWinterRouter? router = routes.firstWhereOrNull(
      (element) => element.canHandle(request),
    );
    if (router == null) {
      throw StateError(
        'MultiRouter: Can\'t find a route to handle the request',
      );
    }
    return router.handler(request);
  }
}

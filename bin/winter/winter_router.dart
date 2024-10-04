import 'package:collection/collection.dart';

import 'winter.dart';

abstract class AbstractWinterRouter {
  WinterHandler call(RequestEntity request);
}

class WinterRouter extends AbstractWinterRouter {
  String basePath;
  final RouterConfig config;

  final List<Route> _rawRoutes;

  List<Route>? _expandedRoutes;

  WinterRouter({
    this.basePath = '',
    List<Route> routes = const [],
    RouterConfig? config,
  })  : _rawRoutes = routes,
        config = config ?? RouterConfig() {
    ///call getter to make flatten on init
    this.config.onLoadedRoutes.afterInit(expandedRoutes);
  }

  List<Route> get expandedRoutes {
    _expandedRoutes ??= _flattenRoutes(_rawRoutes, initialPath: basePath);

    return _expandedRoutes ?? [];
  }

  @override
  WinterHandler call(RequestEntity request) {
    ///find routes that match with the path
    String urlPath = '/${request.url.path}';
    List<Route> matchedRoutes = expandedRoutes
        .where(
          (element) => element.match(urlPath),
        )
        .toList();

    ///no routes found: 404
    if (matchedRoutes.isEmpty) {
      return (_) => ResponseEntity.notFound();
    } else {
      ///there is some route, check method (get, post, put...)
      Route? finalRoute = matchedRoutes.firstWhereOrNull(
        (element) => element.method == HttpMethod(request.method),
      );
      if (finalRoute == null) {
        ///no route matching method: 415
        return (_) => ResponseEntity.methodNotAllowed();
      } else {
        ///founded route: set up path params & return handler for this request
        request.setUpPathParams(finalRoute.path);
        return (newRequest) => finalRoute.handler(newRequest);
      }
    }
  }

  List<Route> _flattenRoutes(
    List<Route> routers, {
    String initialPath = '',
  }) {
    List<Route> result = [];

    void flattenRoutes(String parentPath, List<Route> routes) {
      for (var route in routes) {
        String fullPath =
            (parentPath + route.path).replaceAll(RegExp(r'/+'), '/');
        if (route is! ParentRoute) {
          final currentRoute = Route(
            path: fullPath,
            method: route.method,
            handler: route.handler,
          );
          if (isValidUri(fullPath)) {
            result.add(currentRoute);
          } else {
            config.onInvalidUrl.onInvalid(currentRoute);
          }
        }
        if (route.routes.isNotEmpty) {
          flattenRoutes(fullPath, route.routes);
        }
      }
    }

    flattenRoutes(basePath, routers);

    return result;
  }

  bool isValidUri(String path) {
    // Intenta crear un objeto Uri con solo el path
    try {
      path = path.replaceAll('{', '%7B');
      path = path.replaceAll('}', '%7D');
      Uri uri = Uri(path: path);
      // Valida que el path no contenga caracteres no permitidos y que no comience con "//"
      return !path.startsWith('//') && uri.path == path;
    } catch (e) {
      return false;
    }
  }
}

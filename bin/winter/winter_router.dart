import 'package:collection/collection.dart';

import 'winter.dart';

abstract class AbstractWinterRouter {
  bool canHandle(RequestEntity request);

  RequestHandler handler(RequestEntity request);
}

///Example:
///ServeRouter((request) => ResponseEntity.ok(body: 'Hello world!!!'))
///This will handle all request and always return a 200:Hello world!!!
class ServeRouter extends AbstractWinterRouter {
  final RequestHandler function;

  ServeRouter(this.function);

  @override
  bool canHandle(RequestEntity request) {
    return true;
  }

  @override
  RequestHandler handler(_) {
    return (newRequest) => function(newRequest);
  }
}

class WinterRouter extends AbstractWinterRouter {
  final String basePath;

  final List<Route> routes;

  WinterRouter({
    required this.routes,
    this.basePath = '',
  });

  ///Return the route that will handle the request
  ///If a null value is returned, it means that this router can handle the request with a route
  ///It will return an status code like 404 or 415
  Route? handlerRoute(RequestEntity request) {
    ///find routes that match with the path
    String urlPath = '/${request.url.path}';
    List<Route> matchedRoutes = routes
        .where(
          (element) => element.match(urlPath),
        )
        .toList();

    ///no routes found: 404
    if (matchedRoutes.isEmpty) {
      return null;
    } else {
      ///there is some route, check method (get, post, put...)
      return matchedRoutes.firstWhereOrNull(
        (element) => element.method == HttpMethod(request.method),
      );
    }
  }

  ///Return true or false if this router can successfully process a request
  ///This means if the router if found, and the methods match
  @override
  bool canHandle(RequestEntity request) {
    return handlerRoute(request) != null;
  }

  @override
  RequestHandler handler(RequestEntity request) {
    ///find routes that match with the path
    String urlPath = '/${request.url.path}';
    List<Route> matchedRoutes = routes
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

  @override
  String toString() {
    return 'WinterRouter{basePath: $basePath, routes: $routes}';
  }
}

class Route {
  final String path;
  final HttpMethod method;
  final RequestHandler handler;
  final FilterConfig filterConfig;

  Route._(
    this.path,
    this.method,
    this.handler,
    this.filterConfig,
  );

  Route.build({
    required this.path,
    required this.method,
    required this.handler,
    this.filterConfig = const FilterConfig([]),
  });

  factory Route({
    required String path,
    required HttpMethod method,
    required RequestHandler handler,
    FilterConfig? filterConfig,
  }) {
    if (!path.startsWith('/')) {
      throw ArgumentError.value(
        path,
        'path',
        'expected route to start with a slash',
      );
    }

    return Route._(
      path,
      method,
      handler,
      filterConfig ?? const FilterConfig([]),
    );
  }

  bool match(String rawActualUrl) {
    // Separar las partes de la URL y los parámetros de consulta
    String templateUrlPath = path.split('?').first;
    String actualUrlPath = rawActualUrl.split('?').first;

    // Crear una expresión regular para encontrar los parámetros de ruta en la plantilla
    final RegExp pathParamPattern = RegExp(r'{([^}]+)}');

    // Crear una expresión regular para capturar los valores correspondientes en la URL real
    String regexPattern = templateUrlPath.replaceAllMapped(
        pathParamPattern, (match) => r'([^/?]+)');
    regexPattern = '^' + regexPattern + r'$'; // Añadir el inicio y el final

    // Comprobar si la parte de la URL coincide
    final RegExpMatch? matchUrlPath =
        RegExp(regexPattern).firstMatch(actualUrlPath);

    return matchUrlPath != null;
  }

  @override
  String toString() {
    return 'Route{path: $path, method: $method, handler: $handler, filterConfig: $filterConfig}';
  }
}

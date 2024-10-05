import 'package:collection/collection.dart';

import 'winter.dart';

abstract class AbstractWinterRouter {
  bool canHandle(RequestEntity request);

  WinterHandler handler(RequestEntity request);
}

class WinterRouter extends AbstractWinterRouter {
  final String basePath;
  final RouterConfig config;

  final List<Route> routes;

  WinterRouter({
    required this.config,
    required this.routes,
    this.basePath = '',
  });

  ///Return true or false if this router can successfully process a request
  ///This means if the router if found, and the methods match
  @override
  bool canHandle(RequestEntity request) {
    ///find routes that match with the path
    String urlPath = '/${request.url.path}';
    List<Route> matchedRoutes = routes
        .where(
          (element) => element.match(urlPath),
        )
        .toList();

    ///no routes found: 404
    if (matchedRoutes.isEmpty) {
      return false;
    } else {
      ///there is some route, check method (get, post, put...)
      return matchedRoutes.firstWhereOrNull(
            (element) => element.method == HttpMethod(request.method),
          ) !=
          null;
    }
  }

  @override
  WinterHandler handler(RequestEntity request) {
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
}

class Route {
  final String path;
  final HttpMethod method;
  final RequestHandler handler;

  Route._(
    this.path,
    this.method,
    this.handler,
  );

  Route.build({
    required this.path,
    required this.method,
    required this.handler,
  });

  factory Route({
    required String path,
    required HttpMethod method,
    required RequestHandler handler,
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
}

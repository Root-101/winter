import 'dart:async';

import 'package:collection/collection.dart';

import 'winter.dart';

abstract class AbstractWinterRouter {
  bool canHandle(RequestEntity request);

  FutureOr<ResponseEntity> handler(RequestEntity request);
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
  FutureOr<ResponseEntity> handler(RequestEntity request) {
    return function(request);
  }
}

class WinterRouter extends AbstractWinterRouter {
  final RouterConfig config;

  final String basePath;

  final List<Route> routes;

  WinterRouter.build({
    required this.routes,
    required this.basePath,
    required this.config,
  });

  factory WinterRouter({
    List<Route>? routes,
    RouterConfig? config,
    String basePath = '',
  }) {
    List<Route> nonNullRoutes = [];
    RouterConfig nonNullConfig = config ?? RouterConfig();

    for (var route in (routes ?? [])) {
      if (isValidUri(route.path)) {
        nonNullRoutes.add(route);
      } else {
        nonNullConfig.onInvalidUrl(route);
      }
    }
    nonNullConfig.onLoadedRoutes(nonNullRoutes);

    return WinterRouter.build(
      config: nonNullConfig,
      routes: nonNullRoutes,
      basePath: basePath,
    );
  }

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
  FutureOr<ResponseEntity> handler(RequestEntity request) {
    ///find routes that match with the path
    String urlPath = '/${request.url.path}';
    List<Route> matchedRoutes = routes
        .where(
          (element) => element.match(urlPath),
        )
        .toList();

    ///no routes found: 404
    if (matchedRoutes.isEmpty) {
      return ResponseEntity.notFound();
    } else {
      ///there is some route, check method (get, post, put...)
      Route? finalRoute = matchedRoutes.firstWhereOrNull(
        (element) => element.method == HttpMethod(request.method),
      );
      if (finalRoute == null) {
        ///no route matching method: 415
        return ResponseEntity.methodNotAllowed();
      } else {
        return finalRoute.handler(request);
      }
    }
  }

  void addRoute(Route route) => routes.add(route);

  void add(
    String path,
    HttpMethod method,
    RequestHandler handler, {
    FilterConfig? filterConfig,
  }) =>
      routes.add(
        Route(
          path: path,
          method: method,
          handler: handler,
          filterConfig: filterConfig,
        ),
      );

  void get(
    String path,
    RequestHandler handler, {
    FilterConfig? filterConfig,
  }) =>
      routes.add(
        Route(
          path: path,
          method: HttpMethod.get,
          handler: handler,
          filterConfig: filterConfig,
        ),
      );

  void query(
    String path,
    RequestHandler handler, {
    FilterConfig? filterConfig,
  }) =>
      routes.add(
        Route(
          path: path,
          method: HttpMethod.query,
          handler: handler,
          filterConfig: filterConfig,
        ),
      );

  void post(
    String path,
    RequestHandler handler, {
    FilterConfig? filterConfig,
  }) =>
      routes.add(
        Route(
          path: path,
          method: HttpMethod.post,
          handler: handler,
          filterConfig: filterConfig,
        ),
      );

  void put(
    String path,
    RequestHandler handler, {
    FilterConfig? filterConfig,
  }) =>
      routes.add(
        Route(
          path: path,
          method: HttpMethod.put,
          handler: handler,
          filterConfig: filterConfig,
        ),
      );

  void patch(
    String path,
    RequestHandler handler, {
    FilterConfig? filterConfig,
  }) =>
      routes.add(
        Route(
          path: path,
          method: HttpMethod.patch,
          handler: handler,
          filterConfig: filterConfig,
        ),
      );

  void delete(
    String path,
    RequestHandler handler, {
    FilterConfig? filterConfig,
  }) =>
      routes.add(
        Route(
          path: path,
          method: HttpMethod.delete,
          handler: handler,
          filterConfig: filterConfig,
        ),
      );

  void head(
    String path,
    RequestHandler handler, {
    FilterConfig? filterConfig,
  }) =>
      routes.add(
        Route(
          path: path,
          method: HttpMethod.head,
          handler: handler,
          filterConfig: filterConfig,
        ),
      );

  void options(
    String path,
    RequestHandler handler, {
    FilterConfig? filterConfig,
  }) =>
      routes.add(
        Route(
          path: path,
          method: HttpMethod.options,
          handler: handler,
          filterConfig: filterConfig,
        ),
      );

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
    /// Clean up urls, remove query params
    String templateUrlPath = path.split('?').first;
    String actualUrlPath = rawActualUrl.split('?').first;

    /// Create a regular expression to find path parameters in the template
    final RegExp pathParamPattern = RegExp(r'{([^}]+)}');

    /// Create a regular expression to capture the corresponding values in the actual URL
    String regexPattern = templateUrlPath.replaceAllMapped(
      pathParamPattern,
      (match) => r'([^/?]+)',
    );

    /// Add start and end
    /// Same as '^$regexPattern\$' => '^something$'
    regexPattern = r'^' + regexPattern + r'$';

    /// Check if url match
    return RegExp(regexPattern).hasMatch(actualUrlPath);
  }

  @override
  String toString() {
    return 'Route{path: $path, method: $method, handler: $handler, filterConfig: $filterConfig}';
  }
}

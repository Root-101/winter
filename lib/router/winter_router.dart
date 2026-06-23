import 'dart:async';

import 'package:collection/collection.dart';
import 'package:winter/winter.dart';

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

  WinterRouter._({
    required this.routes,
    required this.basePath,
    required this.config,
  });

  factory WinterRouter({
    List<Route>? routes,
    RouterConfig? config,
    String basePath = '',
  }) {
    RouterConfig nonNullConfig = config ?? RouterConfig();

    WinterRouter router = WinterRouter._(
      config: nonNullConfig,
      routes: _flattenRoutes(routes ?? [], basePath, nonNullConfig),
      basePath: basePath,
    );
    nonNullConfig.onLoadedRoutes(router.routes);

    return router;
  }

  static List<Route> _flattenRoutes(
    List<Route> routes,
    String initialPath,
    RouterConfig config,
  ) {
    List<Route> result = [];

    void flattenRoutes(
      String parentPath,
      FilterConfig? parentFilterConfig,
      List<Route> routes,
    ) {
      for (var route in routes) {
        String fullPath = (parentPath + route.path).replaceAll(
          RegExp(r'/+'),
          '/',
        );

        FilterConfig? newParentFilterConfig = parentFilterConfig != null
            ? parentFilterConfig.merge(route.filterConfig)
            : route.filterConfig.merge(parentFilterConfig);

        //if handler & method are null, it's a 'parent route'
        if (route.handler != null && route.method != null) {
          final currentRoute = Route(
            path: fullPath,
            method: route.method!,
            handler: route.handler!,
            filterConfig: newParentFilterConfig,
          );
          if (isValidUri(fullPath)) {
            result.add(currentRoute);
          } else {
            config.onInvalidUrl(currentRoute);
          }
        }
        if (route.routes.isNotEmpty) {
          flattenRoutes(fullPath, newParentFilterConfig, route.routes);
        }
      }
    }

    flattenRoutes(initialPath, null, routes);

    return result;
  }

  ///Return the route that will handle the request
  ///If a null value is returned, it means that this router can handle the request with a route
  ///It will return an status code like 404 or 415
  Route? handlerRoute(RequestEntity request) {
    ///find routes that match with the path
    String urlPath = '/${request.url.path}';
    List<Route> matchedRoutes = routes
        .where((element) => element.match(urlPath))
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
        .where((element) => element.match(urlPath))
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
        return finalRoute.handler!(request);
      }
    }
  }

  void addRoute(Route route) => routes.add(route);

  void add(
    String path,
    HttpMethod method,
    RequestHandler handler, {
    FilterConfig? filterConfig,
  }) => routes.add(
    Route(
      path: path,
      method: method,
      handler: handler,
      filterConfig: filterConfig,
    ),
  );

  void get(String path, RequestHandler handler, {FilterConfig? filterConfig}) =>
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
  }) => routes.add(
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
  }) => routes.add(
    Route(
      path: path,
      method: HttpMethod.post,
      handler: handler,
      filterConfig: filterConfig,
    ),
  );

  void put(String path, RequestHandler handler, {FilterConfig? filterConfig}) =>
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
  }) => routes.add(
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
  }) => routes.add(
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
  }) => routes.add(
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
  }) => routes.add(
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
  final HttpMethod? method;
  final RequestHandler? handler;
  final FilterConfig filterConfig;

  final List<Route> routes;

  Route._(this.path, this.method, this.handler, this.filterConfig, this.routes);

  factory Route({
    required String path,
    HttpMethod? method,
    RequestHandler? handler,
    FilterConfig? filterConfig,
    List<Route> routes = const [],
  }) {
    if (!path.startsWith('/')) {
      throw ArgumentError.value(
        path,
        'path',
        'Expected route to start with a slash',
      );
    }
    if (method == null && handler != null) {
      throw ArgumentError.value(
        method,
        'method',
        'Method can\'t be null if handler is provided',
      );
    }
    if (handler == null && method != null) {
      throw ArgumentError.value(
        handler,
        'handler',
        'Handler can\'t be null if method is provided',
      );
    }

    return Route._(
      path,
      method,
      handler,
      filterConfig ?? const FilterConfig([]),
      routes,
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

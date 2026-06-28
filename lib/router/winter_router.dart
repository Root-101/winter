import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
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
    List<Route> rawResult = [];

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
            key: route.key,
            method: route.method!,
            handler: route.handler!,
            filterConfig: newParentFilterConfig,
          );
          if (isValidUri(fullPath)) {
            rawResult.add(currentRoute);
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

    List<Route> result = [];
    Set<String> seenKeys = {};

    for (var route in rawResult) {
      if (seenKeys.contains(route.key)) {
        config.onDuplicatedRoute(route);
      } else {
        seenKeys.add(route.key);
        result.add(route);
      }
    }

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

  final String key;

  Route._({
    required this.path,
    required this.key,
    required this.method,
    required this.handler,
    required this.filterConfig,
    required this.routes,
  });

  factory Route({
    required String path,
    String? key,
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
      path: path,
      key: key ?? _generateRouteKey(path, method),
      method: method,
      handler: handler,
      filterConfig: filterConfig ?? const FilterConfig([]),
      routes: routes,
    );
  }

  ///Create a prent route, a route without method nor handler
  ///Designed to be acommon ancestor to it's childs
  factory Route.parent({
    required String path,
    String? key,
    FilterConfig? filterConfig,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: null,
      handler: null,
      filterConfig: filterConfig,
      routes: routes,
    );
  }

  factory Route.get({
    required String path,
    required RequestHandler handler,
    String? key,
    FilterConfig? filterConfig,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: HttpMethod.get,
      handler: handler,
      filterConfig: filterConfig,
      routes: routes,
    );
  }

  factory Route.query({
    required String path,
    required RequestHandler handler,
    String? key,
    FilterConfig? filterConfig,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: HttpMethod.query,
      handler: handler,
      filterConfig: filterConfig,
      routes: routes,
    );
  }

  factory Route.post({
    required String path,
    required RequestHandler handler,
    String? key,
    FilterConfig? filterConfig,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: HttpMethod.post,
      handler: handler,
      filterConfig: filterConfig,
      routes: routes,
    );
  }

  factory Route.put({
    required String path,
    required RequestHandler handler,
    String? key,
    FilterConfig? filterConfig,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: HttpMethod.put,
      handler: handler,
      filterConfig: filterConfig,
      routes: routes,
    );
  }

  factory Route.patch({
    required String path,
    required RequestHandler handler,
    String? key,
    FilterConfig? filterConfig,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: HttpMethod.patch,
      handler: handler,
      filterConfig: filterConfig,
      routes: routes,
    );
  }

  factory Route.delete({
    required String path,
    required RequestHandler handler,
    String? key,
    FilterConfig? filterConfig,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: HttpMethod.delete,
      handler: handler,
      filterConfig: filterConfig,
      routes: routes,
    );
  }

  bool match(String rawActualUrl) {
    /// Clean up urls, remove query params
    String templateUrlPath = path.split('?').first;
    String actualUrlPath = rawActualUrl.split('?').first;

    /// Create a regular expression to find path parameters in the template
    final RegExp pathParamPattern = RegExp(r'{([^}]+)}');

    /// Create a regular expression to capture the corresponding values in the actual URL
    int pIndex = 0;
    String regexPattern = templateUrlPath.replaceAllMapped(pathParamPattern, (
      match,
    ) {
      String content = match.group(1)!;
      String regex = content.contains('|')
          ? content.split('|').skip(1).join('|')
          : r'([^/?]+)';
      return '(?<p${pIndex++}>$regex)';
    });

    /// Add start and end
    /// Same as '^$regexPattern\$' => '^something$'
    regexPattern = r'^' + regexPattern + r'$';

    /// Make .* and .+ non-greedy by default if they are not already.
    /// This allows segments separated by literal slashes to match as expected
    /// when using regex in the path.
    regexPattern = regexPattern
        .replaceAll(RegExp(r'\.\*(?!\?)'), '.*?')
        .replaceAll(RegExp(r'\.\+(?!\?)'), '.+?');

    /// Check if url match
    return RegExp(regexPattern).hasMatch(actualUrlPath);
  }

  @override
  String toString() {
    return 'Route{path: $path, method: $method, handler: $handler, filterConfig: $filterConfig}';
  }
}

String _generateRouteKey(String path, HttpMethod? method, {int length = 12}) {
  String rawKey = '$path${method == null ? '' : '-${method.name}'}';

  var bytes = utf8.encode(rawKey);
  String hash = sha256.convert(bytes).toString();

  return hash.substring(0, min(length, hash.length));
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:winter/src/router/path_template.dart';
import 'package:winter/winter.dart';

abstract class AbstractWinterRouter {
  bool canHandle(RequestEntity request);

  FutureOr<ResponseEntity> handler(RequestEntity request);

  ///Return the [Route] that will handle the request (if any).
  ///The server uses it to apply the route-level filters and the path params,
  ///so any router that works with routes (or wraps other routers) must override it
  Route? resolveRoute(RequestEntity request) => null;
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

///The response when no route can handle a request:
///405 (with the 'Allow' header) if the path exists for other methods, 404 otherwise
ResponseEntity methodNotAllowedOrNotFound(Set<HttpMethod> allowedMethods) {
  if (allowedMethods.isEmpty) {
    return ResponseEntity.notFound();
  }
  return ResponseEntity.methodNotAllowed(
    headers: {
      HttpHeader.allow: allowedMethods
          .map((method) => method.name.toUpperCase())
          .join(', '),
    },
  );
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

  ///Routes that match the path of the request (ignoring the method)
  List<Route> _routesMatchingPath(RequestEntity request) {
    String urlPath = '/${request.url.path}';
    return routes.where((element) => element.match(urlPath)).toList();
  }

  ///Return the route that will handle the request
  ///If a null value is returned, it means that this router can't handle the request with a route
  ///(the handler will return a 404 or 405)
  ///
  ///A static route (without params or regex) has priority over the others, so
  ///`/users/me` wins over `/users/{id}` no matter the declaration order.
  ///Between routes of the same kind, the first declared wins.
  Route? handlerRoute(RequestEntity request) {
    HttpMethod method = HttpMethod(request.method);
    String urlPath = '/${request.url.path}';

    ///Filter by method first, it's much cheaper than matching the path regex
    List<Route> candidates = routes
        .where((element) => element.method == method && element.match(urlPath))
        .toList();

    return candidates.firstWhereOrNull((element) => element.isStatic) ??
        candidates.firstOrNull;
  }

  ///Methods allowed for the path of the request (empty if no route match the path)
  Set<HttpMethod> allowedMethods(RequestEntity request) {
    return _routesMatchingPath(
      request,
    ).map((element) => element.method).nonNulls.toSet();
  }

  @override
  Route? resolveRoute(RequestEntity request) => handlerRoute(request);

  ///Return true or false if this router can successfully process a request
  ///This means if the router if found, and the methods match
  @override
  bool canHandle(RequestEntity request) {
    return handlerRoute(request) != null;
  }

  @override
  FutureOr<ResponseEntity> handler(RequestEntity request) {
    ///The server already resolved the route (see resolveRoute) and saved it in the routing context,
    ///reuse it instead of matching every route again
    Route? finalRoute = _routeFromContext(request) ?? handlerRoute(request);
    if (finalRoute != null) {
      return finalRoute.handler!(request);
    }

    return methodNotAllowedOrNotFound(allowedMethods(request));
  }

  ///The route of this router saved in the routing context of the request (if any)
  Route? _routeFromContext(RequestEntity request) {
    final RequestRoutingContext? context = request.routingContext;
    if (context == null) return null;

    return routes.firstWhereOrNull(
      (route) =>
          route.key == context.key &&
          route.path == context.path &&
          route.method == context.method,
    );
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
      // Not const, so filters can be added later with `FilterConfig.add`
      // ignore: prefer_const_constructors
      filterConfig: filterConfig ?? FilterConfig([]),
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

  ///A static route has no path params nor regex, it only match an exact path
  late final bool isStatic = !_dynamicPathPattern.hasMatch(path);

  static final RegExp _dynamicPathPattern = RegExp(r'[{}*+?()\[\]|\\^$]');

  ///Compiled once and reused for every request
  late final PathTemplate _template = PathTemplate.of(path);

  bool match(String rawActualUrl) => _template.match(rawActualUrl);

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

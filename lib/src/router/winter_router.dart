import 'dart:async';

import 'package:collection/collection.dart';
import 'package:winter/src/router/health.dart' show healthHandler;
import 'package:winter/src/router/path_template.dart';
import 'package:winter/src/utils/valid_url.dart';
import 'package:winter/winter.dart';

abstract class BaseRouter {
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
class ServeRouter extends BaseRouter {
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

///What happens when no route can handle a request: a [MethodNotAllowedException] (405, with the
///`Allow` header) if the path exists for other methods, a [NotFoundException] (404) otherwise.
///They go through the exception handler like any other error.
Never methodNotAllowedOrNotFound(Set<HttpMethod> allowedMethods) {
  if (allowedMethods.isEmpty) throw const NotFoundException();
  throw MethodNotAllowedException(allowedMethods);
}

///The answer of a router for a request without a route: an `OPTIONS` to a path that exists is a
///204 with `Allow` (RFC 9110); anything else is [methodNotAllowedOrNotFound]
ResponseEntity noRouteResponse(
  RequestEntity request,
  Set<HttpMethod> allowedMethods,
) {
  if (request.httpMethod == HttpMethod.options && allowedMethods.isNotEmpty) {
    return ResponseEntity.noContent(
      headers: {HttpHeader.allow: allowHeader(allowedMethods)},
    );
  }
  return methodNotAllowedOrNotFound(allowedMethods);
}

///The value of an `Allow` header: `GET, HEAD, OPTIONS`
String allowHeader(Set<HttpMethod> methods) =>
    methods.map((method) => method.name.toUpperCase()).join(', ');

class WinterRouter extends BaseRouter {
  final RouterConfig config;

  final String basePath;

  final List<Route> _routes;

  ///The routes of this router, flattened (read-only: add them with [addRoute])
  List<Route> get routes => UnmodifiableListView(_routes);

  WinterRouter._({
    required List<Route> routes,
    required this.basePath,
    required this.config,
  }) : _routes = routes; // ignore: prefer_initializing_formals

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
        String fullPath = normalizePath(
          (parentPath + route.path).replaceAll(RegExp(r'/+'), '/'),
        );

        FilterConfig? newParentFilterConfig = parentFilterConfig != null
            ? parentFilterConfig.merge(route.filterConfig)
            : route.filterConfig.merge(parentFilterConfig);

        //if handler & method are null, it's a 'parent route'
        if (route.handler != null && route.method != null) {
          final currentRoute = Route(
            path: fullPath,

            ///A generated key is re-generated with the full path, otherwise two children
            ///with the same relative path (`/users` + `/{id}`, `/items` + `/{id}`) get the same key
            ///and the second one is dropped as duplicated
            key: route._hasCustomKey ? route.key : null,
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
    for (var route in rawResult) {
      if (_isDuplicated(route, result)) {
        config.onDuplicatedRoute(route);
      } else {
        result.add(route);
      }
    }

    return result;
  }

  ///The same key, or the same method and shape (`GET /users/{id}` and `GET /users/{name}`):
  ///the second one could never be reached
  static bool _isDuplicated(Route route, List<Route> routes) => routes.any(
    (other) =>
        other.key == route.key ||
        (other.method == route.method && other._shape == route._shape),
  );

  ///Routes that match the path of the request (ignoring the method)
  List<Route> _routesMatchingPath(RequestEntity request) {
    String urlPath = request.requestedUri.path;
    return routes.where((element) => element.match(urlPath)).toList();
  }

  ///Return the route that will handle the request
  ///If a null value is returned, it means that this router can't handle the request with a route
  ///(the handler will return a 404 or 405)
  ///
  ///A static route (without params or regex) has priority over the others, so
  ///`/users/me` wins over `/users/{id}` no matter the declaration order.
  ///Between routes of the same kind, the first declared wins.
  ///
  ///A HEAD request without a HEAD route is handled by the GET route of the path
  ///(the server sends the headers without the body).
  Route? _handlerRoute(RequestEntity request) {
    HttpMethod method = HttpMethod(request.method);
    String urlPath = request.requestedUri.path;

    return _findRoute(method, urlPath) ??
        (method == HttpMethod.head
            ? _findRoute(HttpMethod.get, urlPath)
            : null);
  }

  Route? _findRoute(HttpMethod method, String urlPath) {
    ///Filter by method first, it's much cheaper than matching the path regex
    List<Route> candidates = routes
        .where((element) => element.method == method && element.match(urlPath))
        .toList();

    return candidates.firstWhereOrNull((element) => element.isStatic) ??
        candidates.firstOrNull;
  }

  ///Methods allowed for the path of the request (empty if no route match the path)
  ///HEAD is allowed wherever GET is, and OPTIONS wherever the path exists
  Set<HttpMethod> allowedMethods(RequestEntity request) {
    Set<HttpMethod> methods = _routesMatchingPath(request)
        .map((element) => element.method)
        .nonNulls
        .toSet();
    if (methods.contains(HttpMethod.get)) {
      methods.add(HttpMethod.head);
    }
    if (methods.isNotEmpty) {
      methods.add(HttpMethod.options);
    }
    return methods;
  }

  @override
  Route? resolveRoute(RequestEntity request) => _handlerRoute(request);

  ///Return true or false if this router can successfully process a request
  ///This means if the router if found, and the methods match
  @override
  bool canHandle(RequestEntity request) {
    return _handlerRoute(request) != null;
  }

  ///In the server it's only called when no route matched (the pipeline calls the handler of the
  ///route itself): a 404, a 405 or an automatic OPTIONS. Called directly, it routes the request.
  @override
  FutureOr<ResponseEntity> handler(RequestEntity request) {
    final Route? route = _handlerRoute(request);
    if (route != null) return route.handler!(request);
    return noRouteResponse(request, allowedMethods(request));
  }

  ///Add a route (and its children) with the same rules as the constructor:
  ///the [basePath] is applied, invalid urls & duplicated routes go to the [config] callbacks
  void addRoute(Route route) {
    for (final newRoute in _flattenRoutes([route], basePath, config)) {
      if (_isDuplicated(newRoute, _routes)) {
        config.onDuplicatedRoute(newRoute);
      } else {
        _routes.add(newRoute);
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
  final HttpMethod? method;
  final RequestHandler? handler;
  final FilterConfig filterConfig;

  final List<Route> routes;

  final String key;

  ///True if the key was provided by the user (not generated from the path & method)
  final bool _hasCustomKey;

  Route._({
    required this.path,
    required this.key,
    required this.method,
    required this.handler,
    required this.filterConfig,
    required this.routes,
    required this._hasCustomKey,
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
      hasCustomKey: key != null,
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

  ///GET (and HEAD) of the files of [directory] under [path]: `/assets/css/site.css` is
  ///`directory/css/site.css`, and `/assets` (or a folder) its [index]. See [StaticFiles] for the
  ///rules (no path traversal, ETag, 304, Range requests).
  ///
  ///It matches every path under [path], so a route declared after it with a param at the same
  ///place (`/assets/{id}`) is never reached: declare those first. [directory] must exist.
  factory Route.static({
    required String path,
    required String directory,
    String? index = 'index.html',
    String? cacheControl,
    Map<String, String> mimeTypes = const {},
    String? key,
    FilterConfig? filterConfig,
  }) {
    final StaticFiles files = StaticFiles(
      directory,
      index: index,
      cacheControl: cacheControl,
      mimeTypes: mimeTypes,
    );
    final String prefix = normalizePath(path);
    return Route.get(
      path: prefix == '/'
          ? '/{$_staticFileParam|.*}'
          : '$prefix{$_staticFileParam|(/.*)?}',
      handler: (request) =>
          files.serve(request, request.pathParams[_staticFileParam] ?? ''),
      key: key,
      filterConfig: filterConfig,
    );
  }

  static const String _staticFileParam = 'staticFile';

  ///GET (and HEAD) [path]: a health check for a load balancer, Docker or Kubernetes.
  ///
  ///Every one of [checks] runs at once, each limited to [timeout]: a 200
  ///`{"status": "UP", "checks": {"database": "UP"}}` when all of them pass, and a 503 with
  ///`"status": "DOWN"` when one returns false, throws or takes too long (the reason is logged,
  ///never sent). Without checks it's a 200 while the server answers. Never cached
  ///(`Cache-Control: no-store`).
  ///
  ///```dart
  ///Route.health(path: '/livez'),                                  // the process is alive
  ///Route.health(path: '/readyz', checks: {'database': db.ping}), // it can serve requests
  ///```
  factory Route.health({
    String path = '/health',
    Map<String, HealthCheck> checks = const {},
    Duration timeout = const Duration(seconds: 5),
    String? key,
    FilterConfig? filterConfig,
  }) => Route.get(
    path: path,
    handler: healthHandler(checks, timeout),
    key: key,
    filterConfig: filterConfig,
  );

  ///A static route has no path params nor regex, it only match an exact path
  late final bool isStatic = !_dynamicPathPattern.hasMatch(path);

  static final RegExp _dynamicPathPattern = RegExp(r'[{}*+?()\[\]|\\^$]');

  ///Compiled once and reused for every request
  late final PathTemplate _template = PathTemplate.of(path);

  bool match(String rawActualUrl) => _template.match(rawActualUrl);

  ///The path without the names of its params (`/users/{id|[0-9]+}` => `/users/{|[0-9]+}`):
  ///two routes with the same method and shape match the same urls
  late final String _shape = path.replaceAllMapped(
    _paramNamePattern,
    (match) => '{${match[1] ?? ''}}',
  );

  static final RegExp _paramNamePattern = RegExp(r'{[^}|]*(\|[^}]*)?}');

  @override
  String toString() {
    return 'Route{key: $key, method: ${method?.name.toUpperCase() ?? 'PARENT'}, path: $path, '
        'filters: ${filterConfig.filters}}';
  }
}

/// The key of a route without one: its method and path (`GET /users/{id}`, `PARENT /users`), unique
/// like them and readable in the logs
String _generateRouteKey(String path, HttpMethod? method) =>
    '${method?.name.toUpperCase() ?? 'PARENT'} $path';

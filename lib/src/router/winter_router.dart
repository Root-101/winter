import 'dart:async';

import 'package:collection/collection.dart';
import 'package:winter/src/openapi/open_api.dart'
    show openApiHandler, swaggerUiHandler;
import 'package:winter/src/router/health.dart' show healthHandler;
import 'package:winter/src/router/path_template.dart';
import 'package:winter/src/websocket.dart' show webSocketRouteHandler;
import 'package:winter/src/utils/valid_url.dart';
import 'package:winter/winter.dart';

/// What every router is: [WinterRouter] (routes), [MultiRouter] (several routers) and
/// [ServeRouter] (one function). Extend it for a router of your own.
///
/// {@category Routing}
abstract class BaseRouter {
  /// Whether this router has a route for [request] (its method and path)
  bool canHandle(RequestEntity request);

  /// Answers [request]. The server only calls it when [resolveRoute] found no route: a 404, a
  /// 405, an automatic `OPTIONS`, or every request of a router without routes.
  FutureOr<ResponseEntity> handler(RequestEntity request);

  ///Return the [Route] that will handle the request (if any).
  ///The server uses it to apply the route-level filters and the path params,
  ///so any router that works with routes (or wraps other routers) must override it
  Route? resolveRoute(RequestEntity request) => null;
}

/// A router of a single function that answers every request (no routes, no 404):
///
/// ```dart
/// await Winter.start(router: ServeRouter((request) => ResponseEntity.ok(body: 'Hello')));
/// ```
///
/// {@category Routing}
class ServeRouter extends BaseRouter {
  /// The function that answers every request
  final RequestHandler function;

  /// A router that answers every request with [function]
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
///
/// {@category Routing}
Never methodNotAllowedOrNotFound(Set<HttpMethod> allowedMethods) {
  if (allowedMethods.isEmpty) throw const NotFoundException();
  throw MethodNotAllowedException(allowedMethods);
}

///The answer of a router for a request without a route: an `OPTIONS` to a path that exists is a
///204 with `Allow` (RFC 9110); anything else is [methodNotAllowedOrNotFound]
///
/// {@category Routing}
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
///
/// {@category Routing}
String allowHeader(Set<HttpMethod> methods) =>
    methods.map((method) => method.name.toUpperCase()).join(', ');

/// The router of an app: a list of [Route]s, nested or not, flattened and checked when it's built.
///
/// ```dart
/// final router = WinterRouter(
///   basePath: '/api',
///   routes: [
///     Route.get(path: '/users/{id}', handler: (request) => users.find(request.pathParam<int>('id'))),
///     Route.parent(
///       path: '/admin',
///       filterConfig: FilterConfig([AuthFilter(rules: hasRole('admin'))]),
///       routes: [Route.delete(path: '/users/{id}', handler: users.delete)],
///     ),
///   ],
/// );
/// ```
///
/// - A static route (`/users/me`) wins over one with params (`/users/{id}`); among the rest, the
///   first declared.
/// - A trailing slash is ignored, `HEAD` uses the `GET` route, and `OPTIONS` is automatic.
/// - No route for the path is a 404; a path with routes for other methods, a 405 with `Allow`.
/// - An invalid or duplicated route fails when the router is built (see [RouterConfig]).
///
/// {@category Routing}
class WinterRouter extends BaseRouter {
  /// What happens with an invalid or a duplicated route, and with the loaded routes
  final RouterConfig config;

  /// The prefix of every route (`/api`), empty by default
  final String basePath;

  final List<Route> _routes;

  ///The routes of this router, flattened (read-only: add them with [addRoute])
  List<Route> get routes => UnmodifiableListView(_routes);

  WinterRouter._({
    required List<Route> routes,
    required this.basePath,
    required this.config,
  }) : _routes = routes; // ignore: prefer_initializing_formals

  /// A router with [routes] under [basePath]: they're flattened (a child joins the path of its
  /// parent and inherits its filters) and checked by [config] now.
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
      List<Route> routes, [
      RouteDocs? parentDocs,
    ]) {
      for (var route in routes) {
        final RouteDocs? docs =
            route.docs?.inheriting(parentDocs) ?? parentDocs;
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
            // A route without docs of its own takes the tags of its parent, not its body
            docs: route.docs == null && parentDocs != null
                ? RouteDocs(tags: parentDocs.tags, hidden: parentDocs.hidden)
                : docs,
          );
          if (isValidUri(fullPath)) {
            rawResult.add(currentRoute);
          } else {
            config.onInvalidUrl(currentRoute);
          }
        }
        if (route.routes.isNotEmpty) {
          flattenRoutes(fullPath, newParentFilterConfig, route.routes, docs);
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

/// A route: a [method], a [path] and the [handler] that answers it, with its [filterConfig].
///
/// ```dart
/// Route.get(path: '/users/{id}', handler: (request) => ...)      // a path param
/// Route.get(path: r'/files/{name|[a-z]+\.pdf}', handler: ...)     // a param with a regex
/// Route.parent(path: '/admin', filterConfig: adminOnly, routes: [...]) // a common prefix
/// Route.static(path: '/assets', directory: 'public')           // the files of a folder
/// Route.health(checks: {'database': db.ping})                   // a health check
/// ```
///
/// A path param is `{name}` or `{name|regex}` (the regex can't contain `{` or `}`), read with
/// `request.pathParam<T>(name)`.
///
/// {@category Routing}
class Route {
  /// The path, from `/` (`/users/{id}`); inside a [WinterRouter], the full one
  final String path;

  /// The method it answers; null for a parent route (only a prefix for its [routes])
  final HttpMethod? method;

  /// The function that answers it; null for a parent route
  final RequestHandler? handler;

  /// The filters of this route (and, for a parent, of its children)
  final FilterConfig filterConfig;

  /// The children of a parent route: their paths are joined to [path]
  final List<Route> routes;

  /// What OpenAPI says about the route (see [RouteDocs]); the children of a parent inherit its
  /// tags
  final RouteDocs? docs;

  /// Recognizes the route (`request.route?.key`): the one given, or its method and path
  /// (`GET /users/{id}`)
  final String key;

  ///True if the key was provided by the user (not generated from the path & method)
  final bool _hasCustomKey;

  Route._({
    required this.docs,
    required this.path,
    required this.key,
    required this.method,
    required this.handler,
    required this.filterConfig,
    required this.routes,
    required this._hasCustomKey,
  });

  /// A route of [method] at [path]. [method] and [handler] go together: without both it's a
  /// parent route. Use the constructors of each method (`Route.get`...) instead.
  factory Route({
    required String path,
    String? key,
    HttpMethod? method,
    RequestHandler? handler,
    FilterConfig? filterConfig,
    List<Route> routes = const [],
    RouteDocs? docs,
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
      docs: docs,
      path: path,
      key: key ?? _generateRouteKey(path, method),
      hasCustomKey: key != null,
      method: method,
      handler: handler,
      filterConfig: filterConfig ?? const FilterConfig([]),
      routes: routes,
    );
  }

  ///A parent route: no method nor handler, only a common [path] and [filterConfig] for its
  ///[routes]
  factory Route.parent({
    required String path,
    String? key,
    FilterConfig? filterConfig,
    RouteDocs? docs,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: null,
      handler: null,
      filterConfig: filterConfig,
      docs: docs,
      routes: routes,
    );
  }

  /// `GET` [path]: read a resource (it answers `HEAD` too)
  factory Route.get({
    required String path,
    required RequestHandler handler,
    String? key,
    FilterConfig? filterConfig,
    RouteDocs? docs,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: HttpMethod.get,
      handler: handler,
      filterConfig: filterConfig,
      docs: docs,
      routes: routes,
    );
  }

  /// `QUERY` [path]: a safe read with a body
  factory Route.query({
    required String path,
    required RequestHandler handler,
    String? key,
    FilterConfig? filterConfig,
    RouteDocs? docs,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: HttpMethod.query,
      handler: handler,
      filterConfig: filterConfig,
      docs: docs,
      routes: routes,
    );
  }

  /// `POST` [path]: create a resource, or run an action
  factory Route.post({
    required String path,
    required RequestHandler handler,
    String? key,
    FilterConfig? filterConfig,
    RouteDocs? docs,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: HttpMethod.post,
      handler: handler,
      filterConfig: filterConfig,
      docs: docs,
      routes: routes,
    );
  }

  /// `PUT` [path]: replace a resource
  factory Route.put({
    required String path,
    required RequestHandler handler,
    String? key,
    FilterConfig? filterConfig,
    RouteDocs? docs,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: HttpMethod.put,
      handler: handler,
      filterConfig: filterConfig,
      docs: docs,
      routes: routes,
    );
  }

  /// `PATCH` [path]: change part of a resource
  factory Route.patch({
    required String path,
    required RequestHandler handler,
    String? key,
    FilterConfig? filterConfig,
    RouteDocs? docs,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: HttpMethod.patch,
      handler: handler,
      filterConfig: filterConfig,
      docs: docs,
      routes: routes,
    );
  }

  /// `DELETE` [path]: remove a resource
  factory Route.delete({
    required String path,
    required RequestHandler handler,
    String? key,
    FilterConfig? filterConfig,
    RouteDocs? docs,
    List<Route> routes = const [],
  }) {
    return Route(
      path: path,
      key: key,
      method: HttpMethod.delete,
      handler: handler,
      filterConfig: filterConfig,
      docs: docs,
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
    RouteDocs? docs,
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
      // A tree of files: not an API operation (give it docs to show it)
      docs: docs ?? RouteDocs.none,
    );
  }

  static const String _staticFileParam = 'staticFile';

  ///GET [path]: the OpenAPI document of the routes, as JSON (built by the first request).
  ///
  ///```dart
  ///router.addRoute(Route.openApi(openApi: OpenApi(title: 'Users API', version: '1.0.0')));
  ///```
  ///
  ///Add it with `addRoute` once the router exists: [OpenApi] documents the router of the running
  ///server (or the one it's given). The route itself is not in the document.
  factory Route.openApi({
    required OpenApi openApi,
    String path = '/openapi.json',
    String? key,
    FilterConfig? filterConfig,
  }) => Route.get(
    path: path,
    handler: openApiHandler(openApi),
    key: key,
    filterConfig: filterConfig,
    docs: RouteDocs.none,
  );

  ///GET [path]: Swagger UI, a page to read and try the API, with the document at [specUrl]
  ///(`Route.openApi`). Swagger UI is loaded from a CDN by the browser: `swagger-ui-dist` 5.17.14
  ///from unpkg, a fixed version (the page never changes by itself); the page allows it in its
  ///`Content-Security-Policy`.
  factory Route.swaggerUi({
    String path = '/docs',
    String specUrl = '/openapi.json',
    String title = 'API',
    String? key,
    FilterConfig? filterConfig,
  }) => Route.get(
    path: path,
    handler: swaggerUiHandler(specUrl: specUrl, title: title),
    key: key,
    filterConfig: filterConfig,
    docs: RouteDocs.none,
  );

  /// `{"status": "UP", "checks": {"database": "UP"}}`
  static JsonSchema _healthSchema(Iterable<String> checks) {
    JsonSchema state() => JsonSchema.string(enumValues: const ['UP', 'DOWN']);
    return JsonSchema.object(
      {
        'status': state(),
        if (checks.isNotEmpty)
          'checks': JsonSchema.object({
            for (final String name in checks) name: state(),
          }),
      },
      required: const ['status'],
    );
  }

  ///A WebSocket at [path]: the handshake (a `GET`) goes through the filters like any request, and
  ///then [handler] gets the socket.
  ///
  ///```dart
  ///Route.websocket(
  ///  path: '/chat/{room}',
  ///  filterConfig: FilterConfig([AuthFilter()]),
  ///  allowedOrigins: ['https://app.example.com'],
  ///  handler: (socket, request) async {
  ///    final String room = request.pathParam<String>('room');
  ///    await for (final message in socket) {
  ///      socket.sendJson({'room': room, 'echo': message});
  ///    }
  ///  },
  ///)
  ///```
  ///
  ///- A request that isn't a WebSocket handshake is a 426 (`Upgrade Required`).
  ///- [allowedOrigins]: the `Origin` a browser may connect from (a 403 otherwise; `'*'` for any).
  ///  Browsers don't apply CORS to WebSockets, so without it any website can open the socket with
  ///  the cookies of its user (cross-site WebSocket hijacking). A client without `Origin` (not a
  ///  browser) is let in.
  ///- [protocols]: the subprotocols spoken, in order of preference; the first one the client
  ///  asks for is chosen, and a client that asks only for others is refused.
  ///- [pingInterval]: a ping every 30 seconds by default, so a dead client is found and closed.
  ///- The handler runs in a request scope of its own (`requestPrincipal`, `requestId`); an error
  ///  in it is logged and closes the socket (1011). The server closes every socket (1001) when it
  ///  shuts down.
  factory Route.websocket({
    required String path,
    required WebSocketHandler handler,
    List<String>? allowedOrigins,
    List<String> protocols = const [],
    Duration? pingInterval = const Duration(seconds: 30),
    String? key,
    FilterConfig? filterConfig,
    RouteDocs? docs,
  }) => Route.get(
    path: path,
    handler: webSocketRouteHandler(
      handler: handler,
      protocols: protocols,
      pingInterval: pingInterval,
      allowedOrigins: allowedOrigins,
    ),
    key: key,
    filterConfig: filterConfig,
    // OpenAPI doesn't describe WebSockets (give it docs to show its handshake)
    docs: docs ?? RouteDocs.none,
  );

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
    RouteDocs? docs,
  }) => Route.get(
    path: path,
    handler: healthHandler(checks, timeout),
    key: key,
    filterConfig: filterConfig,
    docs:
        docs ??
        RouteDocs(
          summary: 'Health check',
          tags: const ['health'],
          response: BodyDocs(
            description: 'Every check is up',
            schema: _healthSchema(checks.keys),
          ),
          responses: {
            503: BodyDocs(
              description: 'A check is down',
              schema: _healthSchema(checks.keys),
            ),
          },
        ),
  );

  ///A static route has no path params nor regex, it only match an exact path
  late final bool isStatic = !_dynamicPathPattern.hasMatch(path);

  static final RegExp _dynamicPathPattern = RegExp(r'[{}*+?()\[\]|\\^$]');

  ///Compiled once and reused for every request
  late final PathTemplate _template = PathTemplate.of(path);

  /// Whether the path of an url (`/users/7`, a query is ignored) matches [path]
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

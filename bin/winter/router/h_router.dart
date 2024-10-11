import '../winter.dart';

class HRouter extends WinterRouter {
  final RouterConfig config;

  HRouter._({
    required this.config,
    required super.routes,
    super.basePath,
  });

  factory HRouter({
    String? basePath,
    List<HRoute> routes = const [],
    RouterConfig? config,
  }) {
    String nonNullBasePath = basePath ?? '';
    RouterConfig nonNullConfig = config ?? RouterConfig();
    HRouter router = HRouter._(
      config: nonNullConfig,
      routes: _flattenRoutes(routes, nonNullBasePath, nonNullConfig),
      basePath: nonNullBasePath,
    );

    nonNullConfig.onLoadedRoutes.afterInit(router.routes);

    return router;
  }

  static List<Route> _flattenRoutes(
    List<HRoute> routes,
    String initialPath,
    RouterConfig config,
  ) {
    List<Route> result = [];

    void flattenRoutes(
      String parentPath,
      FilterConfig? parentFilterConfig,
      List<HRoute> routes,
    ) {
      for (var route in routes) {
        String fullPath =
            (parentPath + route.path).replaceAll(RegExp(r'/+'), '/');

        FilterConfig? newParentFilterConfig = parentFilterConfig != null
            ? parentFilterConfig.merge(route.filterConfig)
            : route.filterConfig.merge(parentFilterConfig);

        if (route is! ParentRoute) {
          final currentRoute = Route(
            path: fullPath,
            method: route.method,
            handler: route.handler,
            filterConfig: newParentFilterConfig,
          );
          if (_isValidUri(fullPath)) {
            result.add(currentRoute);
          } else {
            config.onInvalidUrl.onInvalid(currentRoute);
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

  static bool _isValidUri(String path) {
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

class ParentRoute extends HRoute {
  ParentRoute({
    required super.path,
    required super.routes,
    super.filterConfig,
  }) : super(
          method: const HttpMethod(''),
          handler: (request) => ResponseEntity.ok(),
        );
}

class HRoute extends Route {
  List<HRoute> routes;

  HRoute({
    required super.path,
    required super.method,
    required super.handler,
    super.filterConfig,
    this.routes = const [],
  }) : super.build();
}

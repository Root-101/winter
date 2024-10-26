import '../winter.dart';

class HRouter extends WinterRouter {
  HRouter._({
    required super.config,
    required super.routes,
    required super.basePath,
  }) : super.build();

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

    nonNullConfig.onLoadedRoutes(router.routes);

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

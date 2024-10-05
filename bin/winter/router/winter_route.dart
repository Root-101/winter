import '../winter.dart';

class AbcWinterRouter extends WinterRouter {
  AbcWinterRouter._({
    required super.config,
    required super.routes,
    super.basePath,
  });

  factory AbcWinterRouter({
    String? basePath,
    List<HRoute> routes = const [],
    RouterConfig? config,
  }) {
    String nonNullBasePath = basePath ?? '';
    RouterConfig nonNullConfig = config ?? RouterConfig();
    return AbcWinterRouter._(
      config: nonNullConfig,
      routes: _flattenRoutes(routes, nonNullBasePath, nonNullConfig),
      basePath: nonNullBasePath,
    );
  }

  static List<Route> _flattenRoutes(
    List<HRoute> routes,
    String initialPath,
    RouterConfig config,
  ) {
    List<Route> result = [];

    void flattenRoutes(String parentPath, List<HRoute> routes) {
      for (var route in routes) {
        String fullPath =
            (parentPath + route.path).replaceAll(RegExp(r'/+'), '/');
        if (route is! ParentRoute) {
          final currentRoute = Route(
            path: fullPath,
            method: route.method,
            handler: route.handler,
          );
          if (_isValidUri(fullPath)) {
            result.add(currentRoute);
          } else {
            config.onInvalidUrl.onInvalid(currentRoute);
          }
        }
        if (route.routes.isNotEmpty) {
          flattenRoutes(fullPath, route.routes);
        }
      }
    }

    flattenRoutes(initialPath, routes);

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
  }) : super(
          method: HttpMethod(''),
          handler: (request) => ResponseEntity.ok(),
        );
}

class HRoute extends Route {
  List<HRoute> routes;

  HRoute({
    required super.path,
    required super.method,
    required super.handler,
    this.routes = const [],
  }) : super.build();
}

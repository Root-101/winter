import '../winter.dart';

class BasicRouter extends WinterRouter {
  BasicRouter({
    super.basePath,
    List<Route>? routes,
  }) : super(
          routes: routes ?? [],
        );

  void addRoute(Route route) => routes.add(route);

  void add(
    String path,
    HttpMethod method,
    WinterHandler handler, {
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
    WinterHandler handler, {
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
    WinterHandler handler, {
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
    WinterHandler handler, {
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
    WinterHandler handler, {
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
    WinterHandler handler, {
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
    WinterHandler handler, {
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
    WinterHandler handler, {
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
    WinterHandler handler, {
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
}

import '../winter.dart';

class BasicRouter extends WinterRouter {
  BasicRouter({
    super.basePath,
    List<Route>? routes,
    RouterConfig? config,
  }) : super(
          routes: routes ?? [],
          config: config ?? RouterConfig(),
        );

  void add(String path, HttpMethod method, WinterHandler handler) =>
      routes.add(Route(path: path, method: method, handler: handler));

  void get(String path, WinterHandler handler) =>
      routes.add(Route(path: path, method: HttpMethod.get, handler: handler));

  void query(String path, WinterHandler handler) =>
      routes.add(Route(path: path, method: HttpMethod.query, handler: handler));

  void post(String path, WinterHandler handler) =>
      routes.add(Route(path: path, method: HttpMethod.post, handler: handler));

  void put(String path, WinterHandler handler) =>
      routes.add(Route(path: path, method: HttpMethod.put, handler: handler));

  void patch(String path, WinterHandler handler) =>
      routes.add(Route(path: path, method: HttpMethod.patch, handler: handler));

  void delete(String path, WinterHandler handler) => routes
      .add(Route(path: path, method: HttpMethod.delete, handler: handler));

  void head(String path, WinterHandler handler) =>
      routes.add(Route(path: path, method: HttpMethod.head, handler: handler));

  void options(String path, WinterHandler handler) => routes
      .add(Route(path: path, method: HttpMethod.options, handler: handler));
}

/// The smallest server: one route, and the route table in the logs.
///
/// Run: `dart run lib/hello_world.dart`, then `curl localhost:8080/hello`
library;

import 'package:winter/winter.dart';

WinterRouter router() => WinterRouter(
  // Logs the table of routes when the router is built
  config: RouterConfig(onLoadedRoutes: DefaultOnLoadedRoutes.log()),
  routes: [
    Route.get(
      path: '/hello',
      handler: (request) => ResponseEntity.ok(body: 'Hello World'),
    ),
  ],
);

Future<void> main() async => Winter.start(router: router());

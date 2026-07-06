import 'package:winter/winter.dart';

void main() async {
  await Winter.start(
    config: ServerConfig(port: 8080),
    router: WinterRouter(
      config: RouterConfig(onLoadedRoutes: DefaultOnLoadedRoutes.log()),
      routes: [
        Route.get(
          path: '/hello-wold',
          handler: (request) {
            return ResponseEntity.ok(body: 'Hello World');
          },
        ),
      ],
    ),
  );
}

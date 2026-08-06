import 'package:winter/winter.dart';

void main() async {
  await BasicServer.start();
}

//used in this way to enable it to be started from the tests
class BasicServer {
  static Future start({int port = 8080}) async {
    await Winter.start(
      config: ServerConfig(port: port),
      router: WinterRouter(
        config: RouterConfig(onLoadedRoutes: DefaultOnLoadedRoutes.log()),
        routes: [
          Route.get(
            path: '/hello',
            handler: (request) {
              return ResponseEntity.ok(body: 'Hello World');
            },
          ),
        ],
      ),
    );
  }

  static Future close() async {
    await Winter.close(force: true);
  }
}

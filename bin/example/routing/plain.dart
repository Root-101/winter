import '../../winter/winter.dart';

void main() => WinterServer(
      config: ServerConfig(port: 8080),
      router: WinterRouter(
        routes: [
          Route(
            path: '/test',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(
              body: 'hello-world',
            ),
          ),
        ],
      ),
    ).start();
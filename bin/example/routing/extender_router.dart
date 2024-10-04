import '../../winter/winter.dart';

void main() => WinterServer(
      config: ServerConfig(port: 8080),
      router: WinterRouter(
        routes: [
          Route(
            path: '/user',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(body: 'User route'),
            routes: [
              Route(
                path: '/123456',
                method: HttpMethod.get,
                handler: (request) =>
                    ResponseEntity.ok(body: 'Route: /user/123456'),
              ),
              Route(
                path: '/abcdef',
                method: HttpMethod.get,
                handler: (request) =>
                    ResponseEntity.ok(body: 'Route: /user/abcdef'),
              ),
            ],
          ),
          Route(
            path: '/tables',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(body: 'Tables route'),
          ),
        ],
      ),
    ).start();

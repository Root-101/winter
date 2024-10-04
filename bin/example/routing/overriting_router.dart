import '../../winter/winter.dart';

void main() => WinterServer(
      config: ServerConfig(port: 8080),
      router: WinterRouter(
        routes: [
          ParentRoute(
            path: '/user',
            routes: [
              Route(
                path: '/abcdef',
                method: HttpMethod.get,
                handler: (request) =>
                    ResponseEntity.ok(body: 'Route /user/abcdef'),
              ),
              Route(
                path: '/{user-id}',
                method: HttpMethod.get,
                handler: (request) => ResponseEntity.ok(
                    body: 'Details of user ${request.pathParams['user-id']}'),
              ),
            ],
          ),
        ],
      ),
    ).start();

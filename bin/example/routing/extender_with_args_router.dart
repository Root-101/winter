import '../../winter/winter.dart';

void main() => WinterServer(
      config: ServerConfig(port: 8080),
      router: WinterRouter(
        routes: [
          Route(
            path: '/user/{user-id}',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(body: 'User route'),
            routes: [
              Route(
                path: '/details',
                method: HttpMethod.get,
                handler: (request) => ResponseEntity.ok(
                    body: 'Details of user ${request.pathParams['user-id']}'),
              ),
            ],
          ),
        ],
      ),
    ).start();

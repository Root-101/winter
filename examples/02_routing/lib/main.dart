import 'package:winter/winter.dart';
import 'user_model.dart';
import 'user_service.dart';

export 'user_model.dart';
export 'user_service.dart';

void main() async {
  await RoutingServer.start();
}

class RoutingServer {
  static Future start({int port = 8080}) async {
    // Register the service and deserializer
    final userService = UserService();
    di.put(userService);
    
    Winter.context.objectMapper.addDeserializer(
      Deserializer<User>((json) => User.fromJson(json as Map<String, dynamic>)),
    );

    await Winter.start(
      config: ServerConfig(port: port),
      router: WinterRouter(
        basePath: '/api/v1',
        routes: [
          Route.get(
            path: '/users',
            handler: (request) {
              final service = di.find<UserService>();
              return ResponseEntity.ok(body: service.getAll());
            },
          ),
          Route.get(
            path: '/users/{id}',
            handler: (request) {
              final id = int.tryParse(request.pathParams['id'] ?? '') ?? 0;
              final service = di.find<UserService>();
              return ResponseEntity.ok(body: service.getById(id));
            },
          ),
          Route.post(
            path: '/users',
            handler: (request) async {
              final user = await request.body<User>();

              final service = di.find<UserService>();
              return ResponseEntity.ok(body: service.create(user));
            },
          ),
          Route.put(
            path: '/users/{id}',
            handler: (request) async {
              final id = int.tryParse(request.pathParams['id'] ?? '') ?? 0;
              final userUpdates = await request.body<User>();

              final service = di.find<UserService>();
              return ResponseEntity.ok(body: service.update(id, userUpdates));
            },
          ),
          Route.delete(
            path: '/users/{id}',
            handler: (request) {
              final id = int.tryParse(request.pathParams['id'] ?? '') ?? 0;
              final service = di.find<UserService>();
              return ResponseEntity.ok(body: service.delete(id));
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

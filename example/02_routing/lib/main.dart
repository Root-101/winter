import 'package:winter/winter.dart';
import 'user_model.dart';
import 'user_service.dart';

export 'user_model.dart';
export 'user_service.dart';

void main() async {
  await RoutingServer.start();
}

class RoutingServer {
  /// An example of a user, for the OpenAPI document (its schema is inferred from it)
  static User get _exampleUser => User(id: 1, name: 'Alice', nickname: 'ali');

  /// The routes of the API, documented for OpenAPI (`RouteDocs`), plus the document itself
  /// (`/api/v1/openapi.json`) and Swagger UI (`/api/v1/docs`)
  static WinterRouter router() {
    final router = WinterRouter(
      basePath: '/api/v1',
      routes: [
        Route.parent(
          path: '/users',
          // The children take these tags (a group in Swagger)
          docs: const RouteDocs(tags: ['users']),
          routes: [
            Route.get(
              path: '/',
              docs: RouteDocs(summary: 'Every user', response: [_exampleUser]),
              handler: (request) {
                final service = di.find<UserService>();
                return ResponseEntity.ok(body: service.getAll());
              },
            ),
            // {id|[0-9]+}: an integer in the document, and a 404 for /users/abc
            Route.get(
              path: '/{id|[0-9]+}',
              docs: RouteDocs(summary: 'A user', response: _exampleUser),
              handler: (request) {
                final id = request.pathParam<int>('id');
                final service = di.find<UserService>();
                return ResponseEntity.ok(body: service.getById(id));
              },
            ),
            Route.post(
              path: '/',
              docs: RouteDocs(
                summary: 'Create a user',
                request: _exampleUser,
                response: _exampleUser,
              ),
              handler: (request) async {
                final user = await request.body<User>();

                final service = di.find<UserService>();
                return ResponseEntity.ok(body: service.create(user));
              },
            ),
            Route.put(
              path: '/{id|[0-9]+}',
              docs: RouteDocs(
                summary: 'Replace a user',
                request: _exampleUser,
                response: _exampleUser,
              ),
              handler: (request) async {
                final id = request.pathParam<int>('id');
                final userUpdates = await request.body<User>();

                final service = di.find<UserService>();
                return ResponseEntity.ok(body: service.update(id, userUpdates));
              },
            ),
            // Only the fields sent change: {"nickname": null} clears it, {} changes nothing
            Route.patch(
              path: '/{id|[0-9]+}',
              docs: RouteDocs(
                summary: 'Change some fields of a user',
                description:
                    'A missing field keeps its value; `"nickname": null` clears it.',
                // UserUpdate has no toJson(): its example is the JSON a client sends
                request: BodyDocs(
                  example: {'nickname': null},
                  schema: JsonSchema.object({
                    'name': JsonSchema.string(),
                    'nickname': JsonSchema.string(nullable: true),
                  }),
                ),
                response: _exampleUser,
              ),
              handler: (request) async {
                final id = request.pathParam<int>('id');
                final update = await request.body<UserUpdate>();

                final service = di.find<UserService>();
                return ResponseEntity.ok(body: service.patch(id, update));
              },
            ),
            Route.delete(
              path: '/{id|[0-9]+}',
              docs: RouteDocs(summary: 'Delete a user', response: _exampleUser),
              handler: (request) {
                final id = request.pathParam<int>('id');
                final service = di.find<UserService>();
                return ResponseEntity.ok(body: service.delete(id));
              },
            ),
          ],
        ),
      ],
    );
    return router
      ..addRoute(
        Route.openApi(
          openApi: OpenApi(
            title: 'Users API',
            version: '1.0.0',
            description: 'The CRUD of the routing example',
            router: router,
          ),
        ),
      )
      ..addRoute(
        Route.swaggerUi(specUrl: '/api/v1/openapi.json', title: 'Users API'),
      );
  }

  static Future start({int port = 8080}) async {
    // Register the service and deserializer
    final userService = UserService();
    di.put(userService);

    Winter.context.objectMapper
      ..addDeserializer(Deserializer<User>.json(User.fromJson))
      ..addDeserializer(Deserializer<UserUpdate>.json(UserUpdate.fromJson));

    await Winter.start(
      config: ServerConfig(port: port),
      router: router(),
    );
  }

  static Future close() async {
    await Winter.close(force: true);
  }
}

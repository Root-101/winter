import 'package:auth_security_example/auth_security_example.dart';

void main() async {
  await AuthServer.start();
}

class AuthServer {
  static Future start({int port = 8080}) async {
    // 1. Setup DI
    final userService = UserService();
    di.put(userService);

    final jwtService = JwtService();
    di.put(jwtService);

    final authService = AuthService(di.find(), di.find());
    di.put(authService);

    // 2. Controllers
    final authController = AuthController(authService: authService);
    final userController = UserController(userService: userService);

    // 3. Setup Object Mapping
    om.addDeserializer(
      Deserializer<User>((json) => User.fromJson(json as Map<String, dynamic>)),
    );
    om.addDeserializer(
      Deserializer<RegisterRequest>(
        (json) => RegisterRequest.fromJson(json as Map<String, dynamic>),
      ),
    );
    om.addDeserializer(
      Deserializer<LoginRequest>(
        (json) => LoginRequest.fromJson(json as Map<String, dynamic>),
      ),
    );

    await Winter.start(
      config: ServerConfig(port: port),
      // 4. Global Filter for JWT extraction
      globalFilterConfig: FilterConfig([JwtFilter(jwtService)]),
      router: WinterRouter(
        basePath: '/api/v1',
        routes: [authController.routing, userController.routing],
      ),
    );
  }

  static Future close() async {
    await Winter.close(force: true);
  }
}

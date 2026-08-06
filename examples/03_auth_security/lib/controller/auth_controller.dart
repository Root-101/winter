import 'package:winter/winter.dart';
import '../service/auth_service.dart';
import '../request/auth_requests.dart';

class AuthController {
  final AuthService authService;

  AuthController({required this.authService});

  Route get routing {
    return Route.parent(
      path: '/',
      routes: [
        Route.post(
          path: '/register',
          handler: register,
        ),
        Route.post(
          path: '/login',
          handler: login,
        ),
      ],
    );
  }

  Future<ResponseEntity> register(RequestEntity request) async {
    final registerReq = await request.body<RegisterRequest>();
    
    if (registerReq == null) {
      throw BadRequestException(body: {'error': 'Invalid register data'});
    }

    final user = authService.register(
      registerReq.name,
      registerReq.email,
      registerReq.password,
    );
    return ResponseEntity.ok(body: user);
  }

  Future<ResponseEntity> login(RequestEntity request) async {
    final loginReq = await request.body<LoginRequest>();

    if (loginReq == null) {
      throw BadRequestException(body: {'error': 'Invalid login data'});
    }

    final result = authService.login(loginReq.email, loginReq.password);
    return ResponseEntity.ok(body: result);
  }
}

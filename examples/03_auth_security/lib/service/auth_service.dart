import 'package:auth_security_example/auth_security_example.dart';

class AuthService {
  final UserService userService;
  final JwtService jwtService;

  AuthService(this.userService, this.jwtService);

  Map<String, dynamic> login(String email, String password) {
    final user = userService.getByEmail(email);
    if (user == null || user.password != password) {
      throw UnauthorizedException(body: {'error': 'Invalid credentials'});
    }

    final token = jwtService.generateToken({
      'sub': user.id,
      'email': user.email,
      'roles': user.roles.toList(),
      'permissions': user.permissions.toList(),
    });

    return {
      'token': token,
      'user': {
        'id': user.id,
        'name': user.name,
        'email': user.email,
      }
    };
  }

  User register(String name, String email, String password) {
    if (userService.getByEmail(email) != null) {
      throw ConflictException(body: {'error': 'Email already registered'});
    }
    return userService.create(name, email, password);
  }
}

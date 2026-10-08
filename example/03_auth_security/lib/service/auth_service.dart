import 'package:auth_security_example/auth_security_example.dart';

class AuthService {
  final UserService userService;
  final JwtService jwtService;
  final PasswordHasher passwordHasher;

  ///Used when the email doesn't exist, so the response takes the same time
  ///and doesn't reveal which emails are registered
  late final String _dummyHash = passwordHasher.hash('dummy-password');

  AuthService(this.userService, this.jwtService, this.passwordHasher);

  Map<String, dynamic> login(String email, String password) {
    final user = userService.getByEmail(email);
    final validPassword = passwordHasher.verify(
      password,
      user?.passwordHash ?? _dummyHash,
    );
    if (user == null || !validPassword) {
      throw const UnauthorizedException(detail: 'Invalid credentials');
    }

    final token = jwtService.generateToken({
      'sub': user.id,
      'email': user.email,
      'roles': user.roles.toList(),
      'permissions': user.permissions.toList(),
    });

    return {
      'token': token,
      'user': {'id': user.id, 'name': user.name, 'email': user.email},
    };
  }

  User register(String name, String email, String password) {
    // RegisterRequest already checked it (a 422); this covers two registrations at the same time
    if (userService.getByEmail(email) != null) {
      throw const ConflictException(detail: 'Email already registered');
    }
    return userService.create(name, email, password);
  }
}

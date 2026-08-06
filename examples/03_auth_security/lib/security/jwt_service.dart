import 'package:auth_security_example/auth_security_example.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtService {
  String get _jwtSecret => env.find('JWT_SECRET') ?? 'default_secret_key';

  late final SecretKey _secretKey;

  JwtService() {
    _secretKey = SecretKey(_jwtSecret);
  }

  String generateToken(Map<String, dynamic> payload) {
    final jwt = JWT(payload);
    return jwt.sign(_secretKey);
  }

  Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, _secretKey);
      return jwt.payload as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

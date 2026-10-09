import 'dart:convert';
import 'dart:math';

import 'package:auth_security_example/auth_security_example.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtService {
  /// Tokens expire, so a stolen token is only useful for a limited time
  static const Duration tokenDuration = Duration(hours: 1);

  /// HS256 needs a secret of at least 256 bits (32 bytes)
  static const int _minSecretLength = 32;

  late final SecretKey _secretKey = SecretKey(_loadSecret());

  /// The secret comes from the `JWT_SECRET` env var.
  /// Never hardcode a default secret: anyone reading the code could forge tokens.
  /// Without the env var, a random secret is generated (tokens are invalid after a restart).
  static String _loadSecret() {
    final secret = env.find<String>('JWT_SECRET');
    if (secret != null) {
      if (secret.length < _minSecretLength) {
        throw StateError(
          'JWT_SECRET must have at least $_minSecretLength characters',
        );
      }
      return secret;
    }

    logger.warning(
      'JWT_SECRET is not set, using a random secret. '
      'Tokens will be invalid after a restart, set JWT_SECRET in production.',
    );
    final random = Random.secure();
    return base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
  }

  String generateToken(
    Map<String, dynamic> payload, {
    Duration expiresIn = tokenDuration,
  }) {
    return JWT(payload).sign(_secretKey, expiresIn: expiresIn);
  }

  /// Null if the token is invalid, was not signed with this secret or is expired
  Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, _secretKey);
      return jwt.payload as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

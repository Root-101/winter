import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Hash & verify passwords with PBKDF2-HMAC-SHA256 and a random salt per password.
///
/// Passwords must NEVER be stored in plain text: if the database leaks,
/// the attacker only gets hashes that are slow to brute-force.
///
/// The stored format includes the algorithm and the iterations
/// (`pbkdf2_sha256$<iterations>$<salt>$<hash>`), so they can be increased later
/// without breaking the existing passwords.
class PasswordHasher {
  static const String _algorithm = 'pbkdf2_sha256';
  static const int _saltLength = 16;
  static const int _keyLength = 32;

  /// OWASP recommends 600.000 iterations for PBKDF2-HMAC-SHA256.
  /// This example uses 100.000 because this pure Dart implementation is slow
  /// (~0.4 s per hash in JIT): measure it in your server (AOT is faster) and use
  /// as many as you can afford. Stored hashes keep their iterations, so it can be raised later.
  final int iterations;

  final Random _random = Random.secure();

  PasswordHasher({this.iterations = 100000});

  String hash(String password) {
    final salt = Uint8List.fromList(
      List.generate(_saltLength, (_) => _random.nextInt(256)),
    );
    final key = _derive(password, salt, iterations);
    return '$_algorithm\$$iterations\$${base64Encode(salt)}\$${base64Encode(key)}';
  }

  bool verify(String password, String storedHash) {
    final parts = storedHash.split(r'$');
    if (parts.length != 4 || parts[0] != _algorithm) return false;

    final storedIterations = int.tryParse(parts[1]);
    if (storedIterations == null) return false;

    final salt = base64Decode(parts[2]);
    final expected = base64Decode(parts[3]);
    final actual = _derive(password, salt, storedIterations);
    return _constantTimeEquals(actual, expected);
  }

  Uint8List _derive(String password, Uint8List salt, int iterations) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, _keyLength));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Compare every byte, so the time doesn't reveal how many bytes match
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int difference = 0;
    for (int i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}

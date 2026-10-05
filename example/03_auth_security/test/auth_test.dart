import 'dart:convert';

import 'package:auth_security_example/auth_security_example.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('Auth & Security Example Tests', () {
    const int port = 8083;
    const String baseUrl = 'http://localhost:$port/api/v1';

    setUpAll(() async {
      await AuthServer.start(port: port);
    });

    tearDownAll(() async {
      await AuthServer.close();
    });

    Future<String> login(String email, String password) async {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        body: jsonEncode({'email': email, 'password': password}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw Exception('Login failed for $email');
      }
      return (jsonDecode(response.body) as Map<String, dynamic>)['token']
          as String;
    }

    group('Public Routes', () {
      test('POST /register creates a new user', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/register'),
          body: jsonEncode({
            'name': 'New User',
            'email': 'new@example.com',
            'password': 'password123',
          }),
          headers: {'Content-Type': 'application/json'},
        );

        expect(response.statusCode, equals(200));
        final user = jsonDecode(response.body);
        expect(user['email'], equals('new@example.com'));
      });

      test('POST /register fails with duplicate email', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/register'),
          body: jsonEncode({
            'name': 'Admin Clone',
            'email': 'admin@example.com',
            'password': 'password123',
          }),
          headers: {'Content-Type': 'application/json'},
        );

        expect(response.statusCode, equals(409)); // Conflict
      });

      test('POST /login returns JWT and user info', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/login'),
          body: jsonEncode({
            'email': 'user@example.com',
            'password': 'userpassword',
          }),
          headers: {'Content-Type': 'application/json'},
        );

        expect(response.statusCode, equals(200));
        final result = jsonDecode(response.body);
        expect(result['token'], isNotNull);
        expect(result['user']['email'], equals('user@example.com'));
      });

      test('POST /login fails with wrong password', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/login'),
          body: jsonEncode({
            'email': 'user@example.com',
            'password': 'wrongpassword',
          }),
          headers: {'Content-Type': 'application/json'},
        );

        expect(response.statusCode, equals(401)); // Unauthorized
      });
    });

    group('Authenticated Routes (User)', () {
      test('GET /me works with valid user token', () async {
        final token = await login('user@example.com', 'userpassword');

        final response = await http.get(
          Uri.parse('$baseUrl/me'),
          headers: {'Authorization': 'Bearer $token'},
        );

        expect(response.statusCode, equals(200));
        expect(jsonDecode(response.body)['email'], equals('user@example.com'));
      });

      test('GET /me fails with invalid token format', () async {
        final response = await http.get(
          Uri.parse('$baseUrl/me'),
          headers: {'Authorization': 'Bearer invalid-token'},
        );

        expect(response.statusCode, equals(401));
      });

      test('GET /me fails without token', () async {
        final response = await http.get(Uri.parse('$baseUrl/me'));
        expect(response.statusCode, equals(401));
      });
    });

    group('Authorized Routes (Admin)', () {
      test('GET /users fails for regular user (403)', () async {
        final token = await login('user@example.com', 'userpassword');

        final response = await http.get(
          Uri.parse('$baseUrl/users'),
          headers: {'Authorization': 'Bearer $token'},
        );

        expect(response.statusCode, equals(403));
      });

      test('GET /users succeeds for admin', () async {
        final token = await login('admin@example.com', 'adminpassword');

        final response = await http.get(
          Uri.parse('$baseUrl/users'),
          headers: {'Authorization': 'Bearer $token'},
        );

        expect(response.statusCode, equals(200));
        final List users = jsonDecode(response.body) as List;
        expect(users.length, greaterThanOrEqualTo(2));
      });

      test('DELETE /users/{id} fails for regular user (403)', () async {
        final token = await login('user@example.com', 'userpassword');

        final response = await http.delete(
          Uri.parse('$baseUrl/users/1'),
          headers: {'Authorization': 'Bearer $token'},
        );

        expect(response.statusCode, equals(403));
      });

      test('DELETE /users/{id} succeeds for admin', () async {
        // Delete a user created by this test, so the other tests don't depend on the order
        final registered = await http.post(
          Uri.parse('$baseUrl/register'),
          body: jsonEncode({
            'name': 'To Delete',
            'email': 'to-delete@example.com',
            'password': 'password123',
          }),
        );
        final id = (jsonDecode(registered.body) as Map<String, dynamic>)['id'];
        final token = await login('admin@example.com', 'adminpassword');

        final response = await http.delete(
          Uri.parse('$baseUrl/users/$id'),
          headers: {'Authorization': 'Bearer $token'},
        );

        expect(response.statusCode, equals(200));
        expect(
          jsonDecode(response.body)['email'],
          equals('to-delete@example.com'),
        );
      });

      test('DELETE /users/{id} returns 404 for non-existent user', () async {
        final token = await login('admin@example.com', 'adminpassword');

        final response = await http.delete(
          Uri.parse('$baseUrl/users/999'),
          headers: {'Authorization': 'Bearer $token'},
        );

        expect(response.statusCode, equals(404));
      });
    });

    group('Security Rules Edge Cases', () {
      test(
        'Roles are not hierarchical: an admin without the user role gets 403 on /me',
        () async {
          // /me requires the 'user' role and the admin only has 'admin'
          final token = await login('admin@example.com', 'adminpassword');

          final response = await http.get(
            Uri.parse('$baseUrl/me'),
            headers: {'Authorization': 'Bearer $token'},
          );

          expect(response.statusCode, equals(403));
        },
      );
    });

    group('Password & token security', () {
      test('Passwords are stored hashed, never in plain text', () {
        final admin = di.find<UserService>().getByEmail('admin@example.com')!;

        expect(admin.passwordHash, startsWith(r'pbkdf2_sha256$'));
        expect(admin.passwordHash, isNot(contains('adminpassword')));
        expect(admin.toJson(), isNot(contains('passwordHash')));
      });

      test('Login with an unknown email fails like a wrong password', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/login'),
          body: jsonEncode({'email': 'nobody@example.com', 'password': 'x'}),
        );

        expect(response.statusCode, 401);
      });

      test('Tokens expire after one hour', () async {
        final token = await login('admin@example.com', 'adminpassword');
        final payload = JWT.decode(token).payload as Map<String, dynamic>;

        expect((payload['exp'] as int) - (payload['iat'] as int), 3600);
      });

      test('An expired token is rejected', () async {
        final expiredToken = di.find<JwtService>().generateToken({
          'sub': 1,
          'roles': ['admin'],
          'permissions': ['user.list'],
        }, expiresIn: const Duration(seconds: -1));

        final response = await http.get(
          Uri.parse('$baseUrl/users'),
          headers: {'Authorization': 'Bearer $expiredToken'},
        );

        expect(response.statusCode, 401);
      });
    });

    test('UserService never reuses the id of a deleted user', () {
      final service = UserService(PasswordHasher(iterations: 1000));
      final first = service.create('A', 'a@example.com', 'password');
      service.delete(first.id);

      final second = service.create('B', 'b@example.com', 'password');

      expect(second.id, isNot(first.id));
      expect(service.getAll().map((user) => user.id).toSet(), hasLength(3));
    });

    group('PasswordHasher', () {
      final hasher = PasswordHasher(iterations: 1000);

      test('verify accepts the right password and rejects the wrong one', () {
        final hash = hasher.hash('secret');

        expect(hasher.verify('secret', hash), isTrue);
        expect(hasher.verify('Secret', hash), isFalse);
      });

      test('The same password gets a different hash (random salt)', () {
        expect(hasher.hash('secret'), isNot(hasher.hash('secret')));
      });

      test('Malformed hashes are rejected', () {
        expect(hasher.verify('secret', 'secret'), isFalse);
        expect(hasher.verify('secret', r'md5$1$a$b'), isFalse);
      });
    });

    group('ObjectMapper Tests', () {
      test('POST /login with invalid JSON body returns 400', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/login'),
          body: 'not-a-json',
          headers: {'Content-Type': 'application/json'},
        );
        // The default exception handler maps the JSON parse error to a 400
        expect(response.statusCode, equals(400));
      });
    });
  });
}

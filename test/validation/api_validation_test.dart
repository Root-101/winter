import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

class LoginRequest implements Validatable {
  final String? email;
  final String? password;

  LoginRequest({required this.email, required this.password});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.field('email', email).notNull().notBlank().email();
    cvc.field('password', password).notNull().size(min: 8);
    return cvc;
  }

  Object? toJson() => {'email': email, 'password': password};
}

void main() {
  int port = 9056;
  String localUrl = 'http://localhost:$port';

  ObjectMapper om = ObjectMapper(
    serializers: [Serializer<LoginRequest>((object) => object.toJson())],
    deserializers: [
      Deserializer<LoginRequest>(
        (data) => LoginRequest(
          email: data['email']?.toString(),
          password: data['password']?.toString(),
        ),
      ),
      Deserializer<ConstraintViolation>(
        (data) => ConstraintViolation(
          value: data['value'],
          fieldName: data['fieldName']?.toString() ?? '',
          message: data['message']?.toString() ?? '',
        ),
      ),
    ],
  );

  setUpAll(() async {
    await Winter.start(
      config: ServerConfig(port: port),
      context: BuildContext(objectMapper: om),
      router: WinterRouter(
        routes: [
          Route(
            path: '/login',
            method: HttpMethod.post,
            handler: (request) async {
              // body<T>() validates a Validatable: an invalid one is a 422
              await request.body<LoginRequest>();

              return ResponseEntity.ok(body: 'Login successful');
            },
          ),
        ],
      ),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  group('API Validation Integration Tests', () {
    test('Successful login', () async {
      final response = await http.post(
        url('/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'test@example.com',
          'password': 'password123',
        }),
      );

      expect(response.statusCode, 200);
      expect(response.body, 'Login successful');
    });

    test('Login failure - Invalid email and short password', () async {
      final response = await http.post(
        url('/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': 'invalid-email', 'password': 'short'}),
      );

      expect(response.statusCode, 422);

      final List violationsRaw = jsonDecode(response.body) as List;
      final violations = om.deserialize<List<ConstraintViolation>>(
        violationsRaw,
      );

      expect(violations.length, 2);
      expect(violations.any((v) => v.fieldName == 'email'), isTrue);
      expect(violations.any((v) => v.fieldName == 'password'), isTrue);
    });

    test('Login failure - Missing fields', () async {
      final response = await http.post(
        url('/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );

      expect(response.statusCode, 422);

      final List violationsRaw = jsonDecode(response.body) as List;
      final violations = om.deserialize<List<ConstraintViolation>>(
        violationsRaw,
      );

      expect(violations.length, 2);
      expect(
        violations.any(
          (v) => v.fieldName == 'email' && v.message.contains('cannot be null'),
        ),
        isTrue,
      );
      expect(
        violations.any(
          (v) =>
              v.fieldName == 'password' && v.message.contains('cannot be null'),
        ),
        isTrue,
      );
    });
  });
}

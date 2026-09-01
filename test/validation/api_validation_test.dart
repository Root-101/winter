import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

class LoginRequest implements Validatable, Serializable {
  final String? email;
  final String? password;

  LoginRequest({required this.email, required this.password});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.buildValidator('email').notNull().notBlank().email().validate(email);
    cvc.buildValidator('password').notNull().size(min: 8).validate(password);
    return cvc;
  }

  @override
  Object? toJson() => {'email': email, 'password': password};
}

void main() {
  int port = 9045;
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
      Deserializer<ConstrainViolation>(
        (data) => ConstrainViolation(
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
              final loginRequest = await request.body<LoginRequest>();
              if (loginRequest == null) {
                throw BadRequestException(body: 'Body is required');
              }
              loginRequest.validate().throwOnFailure();

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

      final List violationsRaw = jsonDecode(response.body);
      final violations = om.deserialize<List<ConstrainViolation>>(
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

      final List violationsRaw = jsonDecode(response.body);
      final violations = om.deserialize<List<ConstrainViolation>>(
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

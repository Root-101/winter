import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:routing_example/main.dart';
import 'package:test/test.dart';

void main() {
  group('Routing Examples Tests (with DI and Service)', () {
    const int port = 8082;
    const String baseUrl = 'http://localhost:$port/api/v1';

    setUp(() async {
      await RoutingServer.start(port: port);
    });

    tearDown(() async {
      await RoutingServer.close();
    });

    test('GET /users returns initial list', () async {
      final response = await http.get(Uri.parse('$baseUrl/users'));

      expect(response.statusCode, equals(200));
      final List users = jsonDecode(response.body) as List;
      expect(users, hasLength(2));
    });

    test('GET /users/{id} returns user via service', () async {
      final response = await http.get(Uri.parse('$baseUrl/users/1'));

      expect(response.statusCode, equals(200));
      final user = jsonDecode(response.body);
      expect(user['name'], equals('Alice'));
    });

    test('GET /users/{id} returns 404 via service exception', () async {
      final response = await http.get(Uri.parse('$baseUrl/users/999'));

      expect(response.statusCode, equals(404));
      final error = jsonDecode(response.body);
      // Every error is a Problem Details (application/problem+json)
      expect(error['detail'], contains('not found'));
    });

    test('POST /users creates user and it is stored in service', () async {
      final newUser = {'id': 3, 'name': 'Charlie'};
      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        body: jsonEncode(newUser),
        headers: {'Content-Type': 'application/json'},
      );

      expect(response.statusCode, equals(200));

      // Verify with GET
      final getResponse = await http.get(Uri.parse('$baseUrl/users/3'));
      expect(jsonDecode(getResponse.body)['name'], equals('Charlie'));
    });

    test('PUT /users/{id} updates user via service', () async {
      final updatedUser = {'id': 1, 'name': 'Alice Updated'};
      final response = await http.put(
        Uri.parse('$baseUrl/users/1'),
        body: jsonEncode(updatedUser),
        headers: {'Content-Type': 'application/json'},
      );

      expect(response.statusCode, equals(200));
      expect(jsonDecode(response.body)['name'], equals('Alice Updated'));
    });

    test(
      'PATCH /users/{id}: absent keeps, null clears, a value changes',
      () async {
        Future<Map<String, dynamic>> patch(Map<String, Object?> body) async {
          final response = await http.patch(
            Uri.parse('$baseUrl/users/1'),
            body: jsonEncode(body),
            headers: {'Content-Type': 'application/json'},
          );
          return jsonDecode(response.body) as Map<String, dynamic>;
        }

        expect(await patch({'nickname': 'ali'}), {
          'id': 1,
          'name': 'Alice',
          'nickname': 'ali',
        });
        expect(await patch({'name': 'Alicia'}), {
          'id': 1,
          'name': 'Alicia',
          'nickname': 'ali',
        });
        expect(await patch({'nickname': null}), {
          'id': 1,
          'name': 'Alicia',
          'nickname': null,
        });
        expect(await patch({}), {'id': 1, 'name': 'Alicia', 'nickname': null});
      },
    );

    test('PATCH /users/{id} with a null name is a 400', () async {
      final response = await http.patch(
        Uri.parse('$baseUrl/users/1'),
        body: jsonEncode({'name': null}),
        headers: {'Content-Type': 'application/json'},
      );

      expect(response.statusCode, 400);
      expect(
        jsonDecode(response.body)['detail'],
        r'$.name: expected a string, got null',
      );
    });

    test('DELETE /users/{id} removes user via service', () async {
      final response = await http.delete(Uri.parse('$baseUrl/users/1'));
      expect(response.statusCode, equals(200));

      final getResponse = await http.get(Uri.parse('$baseUrl/users/1'));
      expect(getResponse.statusCode, equals(404));
    });
  });
}

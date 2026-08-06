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
      final List users = jsonDecode(response.body);
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
      expect(error['error'], contains('not found'));
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

    test('DELETE /users/{id} removes user via service', () async {
      final response = await http.delete(Uri.parse('$baseUrl/users/1'));
      expect(response.statusCode, equals(200));

      final getResponse = await http.get(Uri.parse('$baseUrl/users/1'));
      expect(getResponse.statusCode, equals(404));
    });
  });
}

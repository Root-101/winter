@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9063;
  String localUrl = 'http://localhost:$port';

  setUpAll(() async {
    await Winter.start(
      config: ServerConfig(port: port),
      router: WinterRouter(
        routes: [
          Route.post(
            path: '/map',
            handler: (request) async {
              final body = await request.body<Map<String, dynamic>>();
              return ResponseEntity.ok(body: body);
            },
          ),
          Route.post(
            path: '/map-int',
            handler: (request) async {
              final body = await request.body<Map<String, int>>();
              return ResponseEntity.ok(
                body: body.values.fold<int>(0, (a, b) => a + b),
              );
            },
          ),
          Route.post(
            path: '/twice',
            handler: (request) async {
              final raw = await request.body<String>();
              final map = await request.body<Map<String, dynamic>>();
              final again = await request.body<String>();
              return ResponseEntity.ok(body: '${raw == again} ${map['name']}');
            },
          ),
        ],
      ),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test(
    'body<Map<String, dynamic>> works without a custom deserializer',
    () async {
      final requestBody = {
        'name': 'Adam',
        'nested': {'a': 1},
        'list': [1, 2],
      };

      final response = await http.post(
        url('/map'),
        body: jsonEncode(requestBody),
      );

      expect(response.statusCode, 200);
      expect(jsonDecode(response.body), requestBody);
    },
  );

  test('body<Map<String, int>> deserializes the values', () async {
    final response = await http.post(
      url('/map-int'),
      body: jsonEncode({'a': 1, 'b': 2, 'c': 3}),
    );

    expect(response.statusCode, 200);
    expect(response.body, '6');
  });

  test('body<Map> with a JSON array returns 400', () async {
    final response = await http.post(url('/map'), body: jsonEncode([1, 2]));

    expect(response.statusCode, 400);
  });

  test('body<Map> with invalid JSON returns 400', () async {
    final response = await http.post(url('/map'), body: '{not-json');

    expect(response.statusCode, 400);
  });

  test('body() can be called multiple times with different types', () async {
    final response = await http.post(
      url('/twice'),
      body: jsonEncode({'name': 'Adam'}),
    );

    expect(response.statusCode, 200);
    expect(response.body, 'true Adam');
  });
}

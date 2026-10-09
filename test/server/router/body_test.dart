@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// Every shape of a JSON body, there and back through the whole pipeline: `body<T>()` reads it,
/// ResponseEntity writes it, `TestResponse.as<T>()` reads the answer
void main() {
  final ObjectMapper mapper = ObjectMapper(
    deserializers: [Deserializer<_User>.json(_User.fromJson)],
  );

  Route echo<T>(String path, Object? Function(T body) answer) => Route.post(
    path: path,
    handler: (request) async =>
        ResponseEntity.ok(body: answer(await request.body<T>())),
  );

  late WinterTestClient client;

  setUpAll(() {
    Winter.context.setUp(objectMapper: mapper);
    client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          echo<_User>('/user', (user) => user.renamed()),
          echo<List<_User>>(
            '/users',
            (users) => [for (final user in users) user.renamed()],
          ),
          echo<int>('/square', (n) => n * n),
          echo<List<int>>('/squares', (list) => [for (final n in list) n * n]),
          echo<Map<String, dynamic>>('/map', (map) => map),
          echo<DateTime>('/date', (date) => date),
          echo<_Unregistered>('/unregistered', (body) => 'never'),
        ],
      ),
    );
  });

  tearDownAll(() => Winter.context.setUp(objectMapper: ObjectMapper()));

  test('an object and a list of objects', () async {
    final user = await client.post('/user', body: {'email': 'ann@x.com'});
    final users = await client.post(
      '/users',
      body: [
        {'email': 'ann@x.com'},
        {'email': 'bob@x.com'},
      ],
    );

    expect(user.as<_User>(objectMapper: mapper).email, 'ann');
    expect(users.as<List<_User>>(objectMapper: mapper).map((u) => u.email), [
      'ann',
      'bob',
    ]);
  });

  test('a primitive and a list of primitives', () async {
    expect((await client.post('/square', body: '5')).json, 25);
    expect((await client.post('/squares', body: [5, 6, 7])).json, [25, 36, 49]);
  });

  test('a map, kept as it came', () async {
    final Map<String, Object> body = {
      'key': 'value',
      'nested': {'a': 1},
    };

    expect((await client.post('/map', body: body)).json, body);
  });

  test('a DateTime, written back in UTC', () async {
    final DateTime now = DateTime.now();

    final response = await client.post(
      '/date',
      body: jsonEncode(now.toIso8601String()),
    );

    final String echoed = response.json as String;
    expect(echoed, endsWith('Z'));
    expect(DateTime.parse(echoed).isAtSameMomentAs(now), isTrue);
  });

  test('invalid JSON is a 400; a type without deserializer a 500', () async {
    expect((await client.post('/square', body: 'not-json')).statusCode, 400);
    expect(
      (await client.post('/unregistered', body: {'name': 'x'})).statusCode,
      500,
    );
  });
}

class _User {
  final String email;

  _User(this.email);

  factory _User.fromJson(Map<String, dynamic> json) =>
      _User(json['email'] as String);

  /// The name of the email (`ann@x.com` → `ann`), so the answer differs from the request
  _User renamed() => _User(email.split('@').first);

  Map<String, Object> toJson() => {'email': email};
}

class _Unregistered {}

@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9042;
  String localUrl = 'http://localhost:$port';

  DateTime createdAt = DateTime.now();
  ObjectMapper om = ObjectMapper(
    serializers: [
      Serializer<UserRequest>((object) => object.toJson()),
      Serializer<UserResponse>((object) => object.toJson()),
    ],
    deserializers: [
      Deserializer<UserRequest>((data) => UserRequest(email: data['email'])),
      Deserializer<UserResponse>(
        (data) => UserResponse.build(
          username: data['username'],
          createdAt: DateTime.tryParse(data['createdAt']) ?? DateTime.now(),
        ),
      ),
      Deserializer<SerializableUser>(
        (data) => SerializableUser(name: data['name']),
      ),
      Deserializer<Map<String, dynamic>>(
        (data) => {'key': data['key'], 'nested': data['nested']},
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
            path: '/create-user',
            method: HttpMethod.post,
            handler: (request) async {
              UserRequest requestBody = (await request.body<UserRequest>())!;

              ///Username will be the email without the provider
              ///email: `test@test.com` will be username: `test`
              String username = requestBody.email!.split('@')[0];

              UserResponse responseBody = UserResponse.build(
                username: username,
                createdAt: createdAt,
              );

              return ResponseEntity.ok(body: responseBody);
            },
          ),
          Route(
            path: '/create-multiple-users',
            method: HttpMethod.post,
            handler: (request) async {
              ///Note that we use the null operator (!) because its a controlled test
              ///In other test we will validate that this elements are not null to avoid using '!'
              List<UserRequest> requestBody = (await request
                  .body<List<UserRequest>>())!;

              ///Username will be the email without the provider
              ///email: `test@test.com` will be username: `test`
              String username0 = requestBody[0].email!.split('@')[0];
              String username1 = requestBody[1].email!.split('@')[0];

              List<UserResponse> responseBody = [
                UserResponse.build(username: username0, createdAt: createdAt),
                UserResponse.build(username: username1, createdAt: createdAt),
              ];

              return ResponseEntity.ok(body: responseBody);
            },
          ),
          Route(
            path: '/sqrt',
            method: HttpMethod.post,
            handler: (request) async {
              int requestBody = (await request.body<int>())!;

              return ResponseEntity.ok<int>(body: requestBody * requestBody);
            },
          ),
          Route(
            path: '/sqrt-list',
            method: HttpMethod.post,
            handler: (request) async {
              List<int> requestBody = (await request.body<List<int>>())!;

              return ResponseEntity.ok<List<int>>(
                body: requestBody.map((e) => e * e).toList(),
              );
            },
          ),
          Route(
            path: '/echo-map',
            method: HttpMethod.post,
            handler: (request) async {
              var body = await request.body<Map<String, dynamic>>();
              return ResponseEntity.ok(body: body);
            },
          ),
          Route(
            path: '/echo-datetime',
            method: HttpMethod.post,
            handler: (request) async {
              var body = await request.body<DateTime>();
              return ResponseEntity.ok(body: body);
            },
          ),
          Route(
            path: '/serializable',
            method: HttpMethod.post,
            handler: (request) async {
              var body = await request.body<SerializableUser>();
              return ResponseEntity.ok(body: body);
            },
          ),
          Route(
            path: '/serializable-list',
            method: HttpMethod.post,
            handler: (request) async {
              var body = await request.body<List<SerializableUser>>();
              return ResponseEntity.ok(body: body);
            },
          ),
          Route(
            path: '/unregistered',
            method: HttpMethod.post,
            handler: (request) async {
              await request.body<UnregisteredType>();
              return ResponseEntity.ok(body: 'ok');
            },
          ),
        ],
      ),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Send and receive body object', () async {
    String urlToTest = '/create-user';
    UserRequest requestBody = UserRequest(email: 'test@test.com');

    http.Response response = await http.post(
      url(urlToTest),
      body: jsonEncode(om.serialize(requestBody)),
    );

    expect(response.statusCode, 200);

    UserResponse responseBody = om.deserialize(response.body);
    expect(responseBody.username, 'test');
    expect(
      responseBody.createdAt?.toIso8601String(),
      createdAt.toIso8601String(),
    );
  });

  test('Send and receive body List<object>', () async {
    String urlToTest = '/create-multiple-users';
    List<UserRequest> requestBody = [
      UserRequest(email: 'test0@test0.com'),
      UserRequest(email: 'test1@test1.com'),
    ];

    http.Response response = await http.post(
      url(urlToTest),
      body: jsonEncode(om.serialize(requestBody)),
    );

    expect(response.statusCode, 200);

    List<UserResponse> responseBody = om.deserialize<List<UserResponse>>(
      jsonDecode(response.body),
    );
    expect(responseBody[0].username, 'test0');
    expect(responseBody[1].username, 'test1');
    expect(
      responseBody[0].createdAt?.toIso8601String(),
      createdAt.toIso8601String(),
    );
    expect(
      responseBody[1].createdAt?.toIso8601String(),
      createdAt.toIso8601String(),
    );
  });

  test('Send and receive body primitive', () async {
    String urlToTest = '/sqrt';

    http.Response response = await http.post(
      url(urlToTest),
      body: jsonEncode(5),
    );

    expect(response.statusCode, 200);

    int responseBody = om.deserialize(response.body);
    expect(responseBody, 25);
  });

  test('Send and receive body primitive list', () async {
    String urlToTest = '/sqrt-list';

    http.Response response = await http.post(
      url(urlToTest),
      body: jsonEncode([5, 6, 7]),
    );

    expect(response.statusCode, 200);

    List<int> responseBody = om.deserialize(response.body);
    expect(responseBody, [25, 36, 49]);
  });

  test('Send and receive Map body', () async {
    String urlToTest = '/echo-map';
    Map<String, dynamic> requestBody = {
      'key': 'value',
      'nested': {'a': 1},
    };

    http.Response response = await http.post(
      url(urlToTest),
      body: jsonEncode(requestBody),
    );

    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), requestBody);
  });

  test('Send and receive DateTime body', () async {
    String urlToTest = '/echo-datetime';
    DateTime now = DateTime.now();

    http.Response response = await http.post(
      url(urlToTest),
      body: now.toIso8601String(),
    );

    expect(response.statusCode, 200);
    // Use ISO string comparison to avoid precision issues if any
    expect(
      DateTime.parse(jsonDecode(response.body)).toIso8601String(),
      now.toIso8601String(),
    );
  });

  test('Send and receive Serializable body', () async {
    String urlToTest = '/serializable';
    SerializableUser user = SerializableUser(name: 'Adam');

    http.Response response = await http.post(
      url(urlToTest),
      body: jsonEncode(user),
    );

    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), user.toJson());
  });

  test('Send and receive List<Serializable> body', () async {
    String urlToTest = '/serializable-list';
    List<SerializableUser> users = [
      SerializableUser(name: 'Adam'),
      SerializableUser(name: 'Eve'),
    ];

    http.Response response = await http.post(
      url(urlToTest),
      body: jsonEncode(users),
    );

    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), users.map((e) => e.toJson()).toList());
  });

  test('Send invalid JSON throws 500', () async {
    String urlToTest = '/sqrt';

    http.Response response = await http.post(
      url(urlToTest),
      body: 'not-a-json',
    );

    expect(response.statusCode, 500);
  });

  test('Request unregistered type throws 500', () async {
    String urlToTest = '/unregistered';

    http.Response response = await http.post(
      url(urlToTest),
      body: jsonEncode({'name': 'test'}),
    );

    expect(response.statusCode, 500);
  });
}

class UserRequest implements Serializable {
  String? email;

  @override
  Object? toJson() {
    return {'email': email};
  }

  UserRequest({required this.email});
}

class UserResponse implements Serializable {
  String? username;
  DateTime? createdAt;

  UserResponse.build({required this.username, required this.createdAt});

  @override
  Object? toJson() {
    return {'username': username, 'createdAt': createdAt?.toIso8601String()};
  }
}

class SerializableUser implements Serializable {
  final String name;

  SerializableUser({required this.name});

  @override
  Object? toJson() => {'name': name};
}

class UnregisteredType {
  final String name;

  UnregisteredType(this.name);
}

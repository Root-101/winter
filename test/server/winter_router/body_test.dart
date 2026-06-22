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
    deserializers: [
      Deserializer<UserRequest>((data) => UserRequest(email: data['email'])),
      Deserializer<UserResponse>(
        (data) => UserResponse.build(
          username: data['username'],
          createdAt: DateTime.tryParse(data['createdAt']) ?? DateTime.now(),
        ),
      ),
    ],
  );

  setUpAll(() async {
    await Winter.run(
      config: ServerConfig(port: port),
      context: BuildContext(objectMapper: om),
      router: WinterRouter(
        routes: [
          Route(
            path: '/create-user',
            method: HttpMethod.post,
            handler: (request) async {
              ///Note that we use the null operator (!) because its a controlled test
              ///In other test we will validate that this elements are not null to avoid using '!'
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
                  .bodyList<UserRequest>())!;

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

    List<UserResponse> responseBody = om.deserializeList(
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

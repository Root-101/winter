@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../../bin/winter/winter.dart';

void main() {
  int port = 9040;
  String localUrl = 'http://localhost:$port';

  DateTime createdAt = DateTime.now();
  ObjectMapper om = ObjectMapperImpl();

  setUpAll(
    () async {
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

                return ResponseEntity.ok(
                  body: responseBody,
                );
              },
            ),
          ],
        ),
      );
    },
  );

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Send and receive body', () async {
    String urlToTest = '/create-user';
    UserRequest requestBody = UserRequest(email: 'test@test.com');

    http.Response response =
        await http.post(url(urlToTest), body: om.serialize(requestBody));

    expect(response.statusCode, 200);

    UserResponse responseBody = om.deserialize(response.body);
    expect(responseBody.username, 'test');
    expect(
      responseBody.createdAt?.toIso8601String(),
      createdAt.toIso8601String(),
    );
  });
}

class UserRequest {
  String? email;

  UserRequest.empty();///needed constructor for ObjectMapper to work

  UserRequest({
    required this.email,
  });
}

class UserResponse {
  String? username;
  DateTime? createdAt;

  UserResponse();///needed constructor for ObjectMapper to work

  UserResponse.build({
    required this.username,
    required this.createdAt,
  });
}

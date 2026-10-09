import 'package:test/test.dart';
import 'package:validation_examples/async_rules.dart';
import 'package:winter/winter.dart';

void main() {
  late UserRepository users;
  late WinterTestClient client;

  setUpAll(
    () => om.addDeserializer(Deserializer<Register>.json(Register.fromJson)),
  );

  setUp(() {
    users = UserRepository();
    di.put(users);
    client = WinterTestClient.build(router: router());
  });

  List<String> codes(TestResponse response) => [
    for (final v in (response.json as Map)['violations'] as List)
      (v as Map)['code'] as String,
  ];

  test('a new email is registered', () async {
    final response = await client.post(
      '/register',
      body: {'email': 'ann@example.com', 'password': '12345678'},
    );

    expect(response.statusCode, 201);
  });

  test('a registered email is a 422 email.taken', () async {
    final response = await client.post(
      '/register',
      body: {'email': 'taken@example.com', 'password': '12345678'},
    );

    expect(response.statusCode, 422);
    expect(codes(response), ['email.taken']);
  });

  test('a malformed email never reaches the database', () async {
    final response = await client.post(
      '/register',
      body: {'email': 'x', 'password': '123'},
    );

    expect(codes(response), ['email', 'size.min']);
    expect(users.lookups, 0);
  });
}

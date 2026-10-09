import 'package:test/test.dart';
import 'package:validation_examples/basic_rules.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(
    () =>
        om.addDeserializer(Deserializer<CreateUser>.json(CreateUser.fromJson)),
  );

  /// fieldName -> code, in order
  List<(String, String)> violations(TestResponse response) => [
    for (final v in (response.json as Map)['violations'] as List)
      ((v as Map)['fieldName'] as String, v['code'] as String),
  ];

  test('a valid user reaches the handler', () async {
    final response = await client.post(
      '/users',
      body: {'name': 'Ann', 'email': 'ann@example.com', 'password': '12345678'},
    );

    expect(response.statusCode, 201);
  });

  test('an invalid one is a 422 with every violation', () async {
    final response = await client.post(
      '/users',
      body: {
        'name': ' ',
        'email': 'x',
        'password': 'short',
        'age': 16,
        'website': 'not a url',
      },
    );

    expect(response.statusCode, 422);
    expect(violations(response), [
      ('name', 'notBlank'),
      ('email', 'email'),
      ('password', 'size.min'),
      ('age', 'min.inclusive'),
      ('website', 'url'),
    ]);
    expect(response.body, isNot(contains('short')), reason: 'never the value');
  });

  test('missing fields: notNull stops the rules of the field', () async {
    final response = await client.post('/users', body: <String, Object?>{});

    expect(violations(response), [
      ('name', 'notNull'),
      ('email', 'notNull'),
      ('password', 'notNull'),
    ]);
  });

  test('the rules of a model, without a request', () {
    final cvc = CreateUser(
      name: 'Ann',
      email: 'x',
      password: '12345678',
    ).validate();

    expect(cvc.violationsOf('email').single.code, 'email');
    expect(cvc.violationsOf('password'), isEmpty);
  });
}

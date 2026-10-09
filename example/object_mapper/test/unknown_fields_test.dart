import 'package:object_mapper_examples/unknown_fields.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  String? detail(TestResponse response) =>
      (response.json as Map)['detail'] as String?;

  test('a known body passes', () async {
    final response = await client.post(
      '/sign-up',
      body: {'name': 'Ann', 'email': 'ann@example.com'},
    );

    expect(response.json, {'name': 'Ann'});
  });

  test('an unknown field is a 400 that names it', () async {
    final response = await client.post(
      '/sign-up',
      body: {'name': 'Ann', 'email': 'ann@example.com', 'is_admin': true},
    );

    expect(response.statusCode, 400);
    expect(detail(response), r'$.is_admin: unknown field');
  });

  test('the webhook accepts anything', () async {
    final response = await client.post(
      '/webhooks/payments',
      body: {
        'type': 'charge.paid',
        'livemode': false,
        'data': <String, Object>{},
      },
    );

    expect(response.json, {'type': 'charge.paid'});
  });
}

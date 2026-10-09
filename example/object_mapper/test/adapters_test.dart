import 'package:object_mapper_examples/adapters.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  String? detail(TestResponse response) =>
      (response.json as Map)['detail'] as String?;

  test('a list of an adapted type, in and out', () async {
    final response = await client.post(
      '/total',
      body: ['12.50 EUR', '0.75 EUR'],
    );

    expect(response.json, {'total': '13.25 EUR'});
  });

  test('a map of URIs', () async {
    final response = await client.post(
      '/links',
      body: {'docs': 'https://dart.dev/guides', 'home': 'https://example.com'},
    );

    expect(response.json, {'docs': 'dart.dev', 'home': 'example.com'});
  });

  test('an invalid value is a 400 at its path', () async {
    final notText = await client.post('/total', body: ['1.00 EUR', 12]);
    final notMoney = await client.post(
      '/total',
      body: ['1.00 EUR', '12 euros'],
    );

    expect(detail(notText), r'$[1]: expected a string, got an integer');
    expect(detail(notMoney), r'$[1]: invalid value');
  });
}

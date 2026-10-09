import 'package:object_mapper_examples/partial_update.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  String? detail(TestResponse response) =>
      (response.json as Map)['detail'] as String?;

  test('absent keeps, null clears, a value changes', () async {
    expect((await client.patch('/me', body: <String, Object?>{})).json, {
      'name': 'Ann',
      'nickname': 'annie',
      'age': 30,
    });
    expect(
      (await client.patch('/me', body: {'nickname': null, 'age': 31})).json,
      {'name': 'Ann', 'nickname': null, 'age': 31},
    );
  });

  test('null for a field that is not nullable is a 400', () async {
    final response = await client.patch('/me', body: {'name': null});

    expect(response.statusCode, 400);
    expect(detail(response), r'$.name: expected a string, got null');
  });
}

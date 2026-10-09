import 'package:object_mapper_examples/sealed_classes.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  String? detail(TestResponse response) =>
      (response.json as Map)['detail'] as String?;

  test('reads each subtype and writes the largest one', () async {
    final response = await client.post(
      '/shapes/largest',
      body: [
        {'type': 'square', 'side': 3},
        {'type': 'circle', 'radius': 2},
      ],
    );

    expect(response.json, {'type': 'circle', 'radius': 2.0});
  });

  test('an unknown type is a 400 at its position', () async {
    final response = await client.post(
      '/shapes/largest',
      body: [
        {'type': 'triangle'},
      ],
    );

    expect(response.statusCode, 400);
    expect(detail(response), r'$[0]: invalid value');
  });
}

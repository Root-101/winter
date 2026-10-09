import 'package:object_mapper_examples/field_naming.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  test('snake_case, no nulls, UTC, enums by name', () async {
    expect((await client.get('/profile')).json, {
      'full_name': 'Ann Lee',
      'created_at': '2026-03-01T08:00:00.000Z',
      'plan': 'pro',
    });
  });

  test('a Map is never renamed', () async {
    expect((await client.get('/raw')).json, {
      'keepThisName': true,
      'nothing': null,
    });
  });

  test('the responses are indented (prettyPrint is on by default)', () async {
    expect((await client.get('/profile')).body, contains('\n  "full_name"'));
  });
}

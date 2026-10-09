import 'package:bodies_examples/json_body.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  test('a typed object: 200, 400 for its shape, 422 for its rules', () async {
    final ok = await client.post(
      '/notes',
      body: {
        'title': 'Groceries',
        'tags': ['home'],
      },
    );
    final wrong = await client.post('/notes', body: {'title': 12});
    final invalid = await client.post('/notes', body: {'title': ' '});

    expect(ok.json, {
      'title': 'Groceries',
      'tags': ['home'],
    });
    expect(wrong.statusCode, 400);
    expect(
      (wrong.json as Map)['detail'],
      r'$.title: expected a string, got an integer',
    );
    expect(invalid.statusCode, 422);
  });

  test('any object as a map', () async {
    expect((await client.post('/echo', body: {'a': 1, 'b': null})).json, {
      'keys': ['a', 'b'],
    });
  });
}

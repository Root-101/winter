import 'package:api_patterns_examples/prefer_return.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUp(() => client = WinterTestClient.build(router: router()));

  Future<TestResponse> create({String? prefer}) =>
      client.post('/notes', headers: {'prefer': ?prefer}, body: {'text': 'hi'});

  test(
    'return=minimal: the Location without the body, and the preference applied',
    () async {
      final response = await create(prefer: 'return=minimal');

      expect(response.statusCode, 201);
      expect(response.headers['location'], '/notes/1');
      expect(response.body, isEmpty);
      expect(response.headers['preference-applied'], 'return=minimal');
      expect(response.headers['vary'], contains('Prefer'));
    },
  );

  test('without it, or return=representation, the created note', () async {
    final plain = await create();
    final representation = await create(prefer: 'return=representation');

    expect(plain.json, {'id': 1, 'text': 'hi'});
    expect(representation.json, {'id': 2, 'text': 'hi'});
    expect(representation.headers, isNot(contains('preference-applied')));
    // The answer depends on Prefer even when it didn't come: a cache must know it
    expect(plain.headers['vary'], contains('Prefer'));
  });
}

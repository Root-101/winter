import 'package:bodies_examples/graphql.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  setUpAll(() => Winter.context.setUp(objectMapper: objectMapper()));

  test('the query, its variables and the operation', () async {
    final response = await client.post(
      '/graphql',
      body: {
        'query': r'query Me($id: ID!) { user(id: $id) { name } }',
        'variables': {'id': '7'},
        'operationName': 'Me',
      },
    );

    expect(response.json, {
      'operationName': 'Me',
      'query': r'query Me($id: ID!) { user(id: $id) { name } }',
      'variables': {'id': '7'},
    });
  });
}

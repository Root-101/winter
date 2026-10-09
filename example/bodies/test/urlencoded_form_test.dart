import 'package:bodies_examples/urlencoded_form.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  Future<TestResponse> post(String body) => client.post(
    '/subscribe',
    body: body,
    headers: {HttpHeader.contentType: 'application/x-www-form-urlencoded'},
  );

  test('fields, typed and repeated', () async {
    expect(
      (await post('email=ann%40example.com&age=30&topic=dart&topic=web')).json,
      {
        'email': 'ann@example.com',
        'age': 30,
        'topics': ['dart', 'web'],
      },
    );
  });

  test('a field that is not an integer is a 400 that names it', () async {
    final response = await post('email=ann%40example.com&age=old');

    expect(response.statusCode, 400);
    expect((response.json as Map)['detail'], contains('age'));
  });

  test('JSON is not a form: 415', () async {
    expect(
      (await client.post('/subscribe', body: {'email': 'x'})).statusCode,
      415,
    );
  });
}

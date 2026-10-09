import 'package:api_patterns_examples/content_negotiation.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  test('JSON by default, with Vary: Accept', () async {
    final response = await client.get('/sales');

    expect(response.headers['content-type'], startsWith('application/json'));
    expect(response.json, hasLength(2));
    expect(response.headers['vary'], 'Accept');
  });

  test('CSV when the client asks for it', () async {
    final response = await client.get(
      '/sales',
      headers: {'accept': 'text/csv'},
    );

    expect(response.headers['content-type'], 'text/csv; charset=utf-8');
    expect(response.body, 'month,total\r\n2026-01,1200\r\n2026-02,950');
  });

  test('a type the server can not produce is a 406', () async {
    final response = await client.get(
      '/sales',
      headers: {'accept': 'application/xml'},
    );

    expect(response.statusCode, 406);
    expect(response.headers['vary'], 'Accept');
  });

  test('negotiate() follows the q weights and the wildcards', () {
    expect(negotiate('application/json;q=0.5, text/csv'), 'text/csv');
    expect(negotiate('text/*'), 'text/csv');
    expect(negotiate('*/*'), 'application/json');
    expect(negotiate('text/csv;q=0, application/xml'), isNull);
    expect(negotiate(null), 'application/json');
  });
}

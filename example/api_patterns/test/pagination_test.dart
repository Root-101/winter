import 'package:api_patterns_examples/pagination.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  test('a page in the middle: the items, the total and every link', () async {
    final response = await client.get('/articles?page=2&size=5');

    final ids = (response.json as List).map(
      (article) => (article as Map)['id'],
    );

    expect(ids, [6, 7, 8, 9, 10]);
    expect(response.headers['x-total-count'], '23');
    expect(response.headersAll['link'], [
      '</articles?page=1&size=5>; rel="first"',
      '</articles?page=1&size=5>; rel="prev"',
      '</articles?page=3&size=5>; rel="next"',
      '</articles?page=5&size=5>; rel="last"',
    ]);
  });

  test('the first and the last page have no prev and no next', () async {
    final first = await client.get('/articles');
    final last = await client.get('/articles?page=3');

    expect(first.json, hasLength(10));
    expect(first.headersAll['link']!.join(), isNot(contains('prev')));
    expect(last.json, hasLength(3));
    expect(last.headersAll['link']!.join(), isNot(contains('next')));
  });

  test('a size over the limit, or a page under 1, is a 400', () async {
    expect((await client.get('/articles?size=500')).statusCode, 400);
    expect((await client.get('/articles?page=0')).statusCode, 400);
  });
}

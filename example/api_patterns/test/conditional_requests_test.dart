import 'package:api_patterns_examples/conditional_requests.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUp(() => client = WinterTestClient.build(router: router(DocumentStore())));

  test('a GET with the current ETag is a 304 without body', () async {
    final first = await client.get('/documents/1');
    expect(first.statusCode, 200);
    expect(first.headers['etag'], '"1"');

    final again = await client.get(
      '/documents/1',
      headers: {'if-none-match': first.headers['etag']!},
    );
    expect(again.statusCode, 304);
    expect(again.bodyBytes, isEmpty);
    expect(again.headers['etag'], '"1"');
  });

  test('a PUT with the right If-Match saves and gives the new ETag', () async {
    final response = await client.put(
      '/documents/1',
      headers: {'if-match': '"1"'},
      body: {'text': 'v2'},
    );

    expect(response.statusCode, 200);
    expect(response.json, {'id': 1, 'text': 'v2'});
    expect(response.headers['etag'], '"2"');
  });

  test('two edits of the same version: the second one is a 412', () async {
    await client.put(
      '/documents/1',
      headers: {'if-match': '"1"'},
      body: {'text': 'from Ann'},
    );
    final late = await client.put(
      '/documents/1',
      headers: {'if-match': '"1"'},
      body: {'text': 'from Bob'},
    );

    expect(late.statusCode, 412);
    expect((late.json as Map)['currentVersion'], '"2"');
    expect(
      ((await client.get('/documents/1')).json as Map)['text'],
      'from Ann',
    );
  });

  test('a PUT without If-Match is a 428', () async {
    final response = await client.put('/documents/1', body: {'text': 'x'});

    expect(response.statusCode, 428);
  });

  test('etagMatches() understands lists, weak tags and *', () {
    expect(etagMatches('"3", "1"', '"1"'), isTrue);
    expect(etagMatches('W/"1"', '"1"'), isTrue);
    expect(etagMatches('*', '"1"'), isTrue);
    expect(etagMatches('"2"', '"1"'), isFalse);
    expect(etagMatches(null, '"1"'), isFalse);
  });
}

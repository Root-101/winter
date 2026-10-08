import 'dart:convert';
import 'dart:typed_data';

import 'package:request_bodies_example/bodies_example.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  late WinterTestClient client;

  setUpAll(() => Winter.context.setUp(objectMapper: BodiesApp.objectMapper()));

  setUp(() => client = WinterTestClient.build(router: BodiesApp.router()));

  Future<TestResponse> post(String path, {Object? body, String? type}) =>
      client.post(
        '/bodies$path',
        body: body,
        headers: {HttpHeader.contentType: ?type},
      );

  test('none', () async {
    expect((await post('/none')).json, {'received': 'nothing'});
  });

  test('raw > JSON: typed and validated', () async {
    final TestResponse ok = await post(
      '/json',
      body: {
        'title': 'Groceries',
        'tags': ['home'],
      },
    );
    final TestResponse invalid = await post('/json', body: {'title': ' '});
    final TestResponse wrong = await post('/json', body: {'title': 12});

    expect(ok.json, {
      'note': {
        'title': 'Groceries',
        'tags': ['home'],
      },
    });
    expect(invalid.statusCode, 422);
    expect(wrong.statusCode, 400);
    expect(
      (wrong.json as Map)['detail'],
      r'$.title: expected a string, got an integer',
    );
  });

  test('raw > Text, XML, HTML, JavaScript', () async {
    for (final (String type, String text) in [
      ('text/plain', 'line 1\nline 2'),
      ('application/xml', '<note><title>Groceries</title></note>'),
      ('text/html', '<p>Hello</p>'),
      ('application/javascript', 'console.log(1);'),
    ]) {
      final Map<String, Object?> json =
          (await post('/raw', body: text, type: type)).json
              as Map<String, Object?>;

      expect(json['contentType'], type);
      expect(json['text'], text);
      expect(json['characters'], text.length);
    }
  });

  test('x-www-form-urlencoded', () async {
    final TestResponse response = await post(
      '/urlencoded',
      body: 'name=Ann+Lee&age=30&tag=a&tag=b',
      type: 'application/x-www-form-urlencoded',
    );

    expect(response.json, {
      'fields': {'name': 'Ann Lee', 'age': '30', 'tag': 'b'},
      'tags': ['a', 'b'],
      'age': 30,
    });
  });

  test('form-data: fields and files', () async {
    const String boundary = 'example-boundary';
    final String body =
        '--$boundary\r\nContent-Disposition: form-data; name="title"\r\n\r\nHoliday\r\n'
        '--$boundary\r\nContent-Disposition: form-data; name="photos"; filename="a.png"\r\n'
        'Content-Type: image/png\r\n\r\nAAAA\r\n'
        '--$boundary\r\nContent-Disposition: form-data; name="photos"; filename="b.jpg"\r\n'
        'Content-Type: image/jpeg\r\n\r\nBBBBBB\r\n'
        '--$boundary--\r\n';

    final TestResponse response = await post(
      '/form-data',
      body: body,
      type: 'multipart/form-data; boundary=$boundary',
    );

    expect(response.json, {
      'fields': {'title': 'Holiday'},
      'files': [
        {
          'field': 'photos',
          'filename': 'a.png',
          'type': 'image/png',
          'bytes': 4,
        },
        {
          'field': 'photos',
          'filename': 'b.jpg',
          'type': 'image/jpeg',
          'bytes': 6,
        },
      ],
    });
  });

  test('binary', () async {
    final TestResponse response = await post(
      '/binary',
      body: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]),
      type: 'image/png',
    );

    expect(response.json, {
      'contentType': 'image/png',
      'bytes': 6,
      'start': '89 50 4e 47',
    });
  });

  test('GraphQL', () async {
    final TestResponse response = await post(
      '/graphql',
      body: jsonEncode({
        'query': r'query Me($id: ID!) { user(id: $id) { name } }',
        'variables': {'id': '7'},
        'operationName': 'Me',
      }),
      type: 'application/json',
    );

    expect(response.json, {
      'operationName': 'Me',
      'query': r'query Me($id: ID!) { user(id: $id) { name } }',
      'variables': {'id': '7'},
    });
  });
}

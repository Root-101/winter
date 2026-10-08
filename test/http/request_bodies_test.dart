import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// Every kind of body a client (Postman, curl, a browser) can send, and how each one is read
void main() {
  final WinterTestClient client = WinterTestClient.build(
    router: WinterRouter(
      routes: [
        // none
        Route.post(
          path: '/none',
          handler: (request) async => ResponseEntity.ok(
            body: {'body': await request.body<Map<String, dynamic>?>()},
          ),
        ),
        // raw: JSON
        Route.post(
          path: '/json',
          handler: (request) async => ResponseEntity.ok(
            body: await request.body<Map<String, dynamic>>(),
          ),
        ),
        // raw: text, XML, HTML, JavaScript, CSV...
        Route.post(
          path: '/text',
          handler: (request) async =>
              ResponseEntity.ok(body: await request.body<String>()),
        ),
        // x-www-form-urlencoded and form-data
        Route.post(
          path: '/form',
          handler: (request) async {
            final FormData form = await request.formData();
            return ResponseEntity.ok(
              body: {
                'fields': form.fieldsAll,
                'files': {
                  for (final MapEntry(:key, :value) in form.files.entries)
                    key: '${value.filename} (${value.length} bytes)',
                },
              },
            );
          },
        ),
        // binary
        Route.post(
          path: '/binary',
          handler: (request) async {
            final Uint8List bytes = await request.bytes();
            final Uint8List again = await request.body<Uint8List>();
            return ResponseEntity.ok(
              body: {'length': bytes.length, 'same': identical(bytes, again)},
            );
          },
        ),
      ],
    ),
  );

  Future<TestResponse> post(String path, {Object? body, String? type}) =>
      client.post(path, body: body, headers: {HttpHeader.contentType: ?type});

  test(
    'none: no body is null for a nullable type, empty text for a String',
    () async {
      expect((await post('/none')).json, {'body': null});
      expect((await post('/text')).body, '');
    },
  );

  test('raw JSON (and GraphQL, which is JSON)', () async {
    expect(
      (await post(
        '/json',
        body: '{"query": "{ me { id } }", "variables": {"x": 1}}',
        type: 'application/json',
      )).json,
      {
        'query': '{ me { id } }',
        'variables': {'x': 1},
      },
    );
  });

  test('raw text, XML, HTML, JavaScript and CSV are read as text', () async {
    for (final (String type, String text) in [
      ('text/plain', 'Hello'),
      ('application/xml', '<order id="1"/>'),
      ('text/html', '<p>Hi</p>'),
      ('application/javascript', 'alert(1)'),
      ('text/csv', 'a,b\n1,2'),
    ]) {
      expect(
        (await post('/text', body: text, type: type)).body,
        text,
        reason: type,
      );
    }
  });

  test('raw text in another charset', () async {
    final TestResponse response = await post(
      '/text',
      body: latin1.encode('Begoña'),
      type: 'text/plain; charset=iso-8859-1',
    );

    expect(response.body, 'Begoña');
  });

  test('x-www-form-urlencoded', () async {
    expect(
      (await post(
        '/form',
        body: 'name=Ann+Lee&tag=a&tag=b',
        type: 'application/x-www-form-urlencoded',
      )).json,
      {
        'fields': {
          'name': ['Ann Lee'],
          'tag': ['a', 'b'],
        },
        'files': <String, Object?>{},
      },
    );
  });

  test('form-data, with a file', () async {
    const String boundary = 'b0undary';
    final String body =
        '--$boundary\r\nContent-Disposition: form-data; name="title"\r\n\r\nBeach\r\n'
        '--$boundary\r\nContent-Disposition: form-data; name="photo"; filename="a.png"\r\n'
        'Content-Type: image/png\r\n\r\nPNGDATA\r\n--$boundary--\r\n';

    expect(
      (await post(
        '/form',
        body: body,
        type: 'multipart/form-data; boundary=$boundary',
      )).json,
      {
        'fields': {
          'title': ['Beach'],
        },
        'files': {'photo': 'a.png (7 bytes)'},
      },
    );
  });

  test(
    'binary: bytes() and body<Uint8List>(), cached, any Content-Type',
    () async {
      for (final String? type in [
        'application/octet-stream',
        'image/png',
        null,
      ]) {
        expect(
          (await post(
            '/binary',
            body: Uint8List.fromList([0, 255, 7]),
            type: type,
          )).json,
          {'length': 3, 'same': true},
          reason: '$type',
        );
      }
    },
  );

  test('binary read as text is a 400, never a 500', () async {
    final TestResponse response = await post(
      '/text',
      body: Uint8List.fromList([0xff, 0xfe]),
      type: 'application/octet-stream',
    );

    expect(response.statusCode, 400);
    expect(
      (response.json as Map)['detail'],
      'The body is not valid utf-8 text',
    );
  });

  test('readAsString of bytes that are not text is a 400 too', () async {
    final RequestEntity request = RequestEntity(
      'POST',
      Uri.parse('http://localhost/'),
      body: Uint8List.fromList([0xff]),
    );

    await expectLater(
      request.readAsString(),
      throwsA(isA<BadRequestException>()),
    );
  });
}

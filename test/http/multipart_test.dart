import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

const String _boundary = 'XyZ-boundary';
const String _multipart = 'multipart/form-data; boundary=$_boundary';

/// A part of a multipart body: its headers and its content
String _part(Map<String, String> headers, String content) =>
    '--$_boundary\r\n'
    '${headers.entries.map((e) => '${e.key}: ${e.value}\r\n').join()}'
    '\r\n$content\r\n';

String _field(String name, String value) =>
    _part({'Content-Disposition': 'form-data; name="$name"'}, value);

String _file(String name, String filename, String content, [String? type]) =>
    _part({
      'Content-Disposition': 'form-data; name="$name"; filename="$filename"',
      'Content-Type': ?type,
    }, content);

String _body(List<String> parts) => '${parts.join()}--$_boundary--\r\n';

/// [body] in chunks of [size] bytes, so a delimiter is split between chunks
Stream<List<int>> _chunks(List<int> body, int size) async* {
  for (int i = 0; i < body.length; i += size) {
    yield body.sublist(i, i + size > body.length ? body.length : i + size);
  }
}

RequestEntity _request(Object body, {String contentType = _multipart}) =>
    RequestEntity(
      'POST',
      Uri.parse('http://localhost/upload'),
      headers: {HttpHeader.contentType: contentType},
      body: body,
    );

/// Every part as `name|filename|mimeType|content`, read with multipart()
Future<List<String>> _readAll(RequestEntity request) async => [
  await for (final MultipartPart part in request.multipart())
    '${part.name}|${part.filename}|${part.mimeType}|${await part.readAsString()}',
];

Matcher _badRequest(String detail) =>
    isA<BadRequestException>().having((e) => e.detail, 'detail', detail);

const String _malformed = 'The body is not a valid multipart body';

void main() {
  final String body = _body([
    _field('title', 'Holidays'),
    _file('photo', 'beach.png', 'PNG-BYTES', 'image/png'),
    _field('tags', 'sea'),
    _field('tags', 'sun'),
  ]);

  group('formData() of multipart/form-data', () {
    test('splits the fields and the files', () async {
      final FormData form = await _request(body).formData();

      expect(form.fields, {'title': 'Holidays', 'tags': 'sun'});
      expect(form.fieldsAll['tags'], ['sea', 'sun']);
      final UploadedFile photo = form.files['photo']!;
      expect(photo.name, 'photo');
      expect(photo.filename, 'beach.png');
      expect(photo.mimeType, 'image/png');
      expect(utf8.decode(photo.bytes), 'PNG-BYTES');
      expect(photo.length, 9);
      expect(form.field<String>('title'), 'Holidays');
    });

    test('keeps every file of a repeated field', () async {
      final FormData form = await _request(
        _body([_file('docs', 'a.txt', 'A'), _file('docs', 'b.txt', 'B')]),
      ).formData();

      expect(form.filesAll['docs']!.map((file) => file.filename), [
        'a.txt',
        'b.txt',
      ]);
      expect(form.files['docs']!.filename, 'b.txt');
    });

    test('ignores an empty file input and a part without a name', () async {
      final FormData form = await _request(
        _body([
          _file('avatar', '', '', 'application/octet-stream'),
          _part({'Content-Disposition': 'form-data'}, 'nameless'),
          _part({}, 'no headers'),
          _field('kept', 'yes'),
        ]),
      ).formData();

      expect(form.files, isEmpty);
      expect(form.fields, {'kept': 'yes'});
    });

    test('an empty file with a name is kept', () async {
      final FormData form = await _request(
        _body([_file('doc', 'empty.txt', '')]),
      ).formData();

      expect(form.files['doc']!.length, 0);
    });

    test('decodes UTF-8 names, and a field with its charset', () async {
      final List<int> latin = [
        ...utf8.encode(
          '--$_boundary\r\n'
          'Content-Disposition: form-data; name="city"\r\n'
          'Content-Type: text/plain; charset=iso-8859-1\r\n\r\n',
        ),
        ...latin1.encode('Málaga'),
        ...utf8.encode('\r\n'),
      ];
      final FormData form = await _request(<int>[
        ...latin,
        ...utf8.encode(_body([_file('f', 'año 😀.txt', 'x')])),
      ]).formData();

      expect(form['city'], 'Málaga');
      expect(form.files['f']!.filename, 'año 😀.txt');
    });

    test('keeps a backslash and a %22 of a file name as they are', () async {
      final FormData form = await _request(
        _body([_file('f', r'C:\fakepath\a%22b.txt', 'x')]),
      ).formData();

      expect(form.files['f']!.filename, r'C:\fakepath\a%22b.txt');
    });

    test('a field that is not valid UTF-8 is a 400', () async {
      final List<int> invalid = [
        ...utf8.encode(
          '--$_boundary\r\nContent-Disposition: form-data; name="a"\r\n\r\n',
        ),
        0xff,
        ...utf8.encode('\r\n--$_boundary--\r\n'),
      ];

      await expectLater(
        _request(invalid).formData(),
        throwsA(_badRequest(_malformed)),
      );
    });

    test('ignores the preamble, the epilogue and spaces after a delimiter', () async {
      final FormData form = await _request(
        'This is the preamble\r\n'
        '--$_boundary  \r\nContent-Disposition: form-data; name="a"\r\n\r\n1\r\n'
        '--$_boundary--\r\nThis is the epilogue',
      ).formData();

      expect(form.fields, {'a': '1'});
    });

    test('content that looks like the boundary is kept', () async {
      const String content = 'line\r\n--XyZ-other\r\n--XyZ-boundar';
      final FormData form = await _request(_body([_field('a', content)]))
          .formData();

      expect(form['a'], content);
    });

    test('is cached: it can be read again', () async {
      final RequestEntity request = _request(body);

      expect((await request.formData())['title'], 'Holidays');
      expect((await request.copyWith().formData())['title'], 'Holidays');
      expect(await request.body<String>(), body);
    });

    test('toString has no values', () async {
      final FormData form = await _request(body).formData();

      expect(form.toString(), 'FormData{title, tags, photo}');
      expect(
        form.files['photo'].toString(),
        'UploadedFile{name: photo, 9 bytes}',
      );
    });

    test('a malformed body is a 400', () async {
      final Map<String, Object> bodies = {
        'no parts': '',
        'no delimiter': 'just text',
        'no end': _field('a', '1'),
        'cut in the content': _body([_field('a', '1')]).substring(0, 60),
        'cut in the headers': '--$_boundary\r\nContent-Disp',
        'header without a colon': _body([
          _part({'Bad header': 'x'}, '1'),
        ]),
        'header name with spaces':
            '--$_boundary\r\nBad Name: x\r\n\r\n1\r\n--$_boundary--',
        'continuation without a header':
            '--$_boundary\r\n continued\r\n\r\n1\r\n--$_boundary--',
        'no CRLF after the delimiter':
            '--${_boundary}x\r\n\r\n1\r\n--$_boundary--',
        'headers over 16 KB': _body([
          _part({'X-Big': 'a' * (17 * 1024)}, '1'),
        ]),
      };
      for (final MapEntry<String, Object> entry in bodies.entries) {
        await expectLater(
          _request(entry.value).formData(),
          throwsA(_badRequest(_malformed)),
          reason: entry.key,
        );
      }
    });

    test('a missing or invalid boundary is a 400', () async {
      for (final String contentType in [
        'multipart/form-data',
        'multipart/form-data; boundary=',
        'multipart/form-data; boundary="${'a' * 71}"',
        'multipart/form-data; boundary="ends in space "',
        'multipart/form-data; boundary="ñ"',
        'multipart/form-data; =',
      ]) {
        await expectLater(
          _request(body, contentType: contentType).formData(),
          throwsA(
            _badRequest('The multipart Content-Type has no valid boundary'),
          ),
          reason: contentType,
        );
      }
    });

    test('a quoted boundary works', () async {
      final FormData form = await _request(
        body,
        contentType: 'multipart/form-data; boundary="$_boundary"',
      ).formData();

      expect(form['title'], 'Holidays');
    });

    test('through the server: the fields, the files and a 413', () async {
      final WinterTestClient client = WinterTestClient.build(
        maxBodySize: 1000,
        router: WinterRouter(
          routes: [
            Route.post(
              path: '/upload',
              handler: (request) async {
                final FormData form = await request.formData();
                return ResponseEntity.ok(
                  body: {
                    'title': form['title'],
                    'photo': form.files['photo']?.length,
                  },
                );
              },
            ),
          ],
        ),
      );

      final TestResponse ok = await client.post(
        '/upload',
        body: body,
        headers: {HttpHeader.contentType: _multipart},
      );
      final TestResponse tooLarge = await client.post(
        '/upload',
        body: _body([_file('photo', 'big.bin', 'x' * 2000)]),
        headers: {HttpHeader.contentType: _multipart},
      );

      expect(ok.statusCode, 200);
      expect(jsonDecode(ok.body), {'title': 'Holidays', 'photo': 9});
      expect(tooLarge.statusCode, 413);
    });
  });

  group('multipart()', () {
    test(
      'streams the parts in order, whatever the size of the chunks',
      () async {
        final List<int> bytes = utf8.encode(body);
        final List<String> expected = [
          'title|null|null|Holidays',
          'photo|beach.png|image/png|PNG-BYTES',
          'tags|null|null|sea',
          'tags|null|null|sun',
        ];

        for (final int size in [1, 2, 3, 7, 13, 64, bytes.length]) {
          expect(
            await _readAll(_request(_chunks(bytes, size))),
            expected,
            reason: 'chunks of $size bytes',
          );
        }
      },
    );

    test('a file is streamed in chunks, not whole', () async {
      final String big = 'x' * 10000;
      final List<int> sizes = [];
      await for (final MultipartPart part in _request(
        _chunks(utf8.encode(_body([_file('f', 'big.bin', big)])), 1000),
      ).multipart()) {
        await for (final List<int> chunk in part.read()) {
          sizes.add(chunk.length);
        }
      }

      expect(sizes.reduce((a, b) => a + b), 10000);
      expect(sizes.length, greaterThan(1));
      expect(sizes.every((size) => size <= 1000), isTrue);
    });

    test(
      'a part that is skipped is discarded, and can\'t be read later',
      () async {
        final List<MultipartPart> parts = [];
        final List<String> read = [];
        await for (final MultipartPart part in _request(
          _chunks(utf8.encode(body), 5),
        ).multipart()) {
          parts.add(part);
          if (!part.isFile) read.add(await part.readAsString());
        }

        expect(read, ['Holidays', 'sea', 'sun']);
        expect(() => parts[1].read().first, throwsStateError);
      },
    );

    test('a part read halfway: the rest is skipped', () async {
      final List<String> names = [];
      await for (final MultipartPart part in _request(
        _chunks(utf8.encode(body), 3),
      ).multipart()) {
        names.add(part.name!);
        await part.read().first;
      }

      expect(names, ['title', 'photo', 'tags', 'tags']);
    });

    test('the body of a part can be read once', () async {
      await for (final MultipartPart part in _request(body).multipart()) {
        await part.readAsString();
        expect(part.read, throwsStateError);
        break;
      }
    });

    test('the headers and the charset of a part', () async {
      await for (final MultipartPart part in _request(
        _body([
          _part({
            'Content-Disposition':
                'form-data; name=plain; filename = "a b.txt"',
            'Content-Type': 'text/plain; charset=iso-8859-1',
            'X-Folded': 'one',
          }, 'x'),
        ]).replaceFirst('X-Folded: one\r\n', 'X-Folded: one\r\n two\r\n'),
      ).multipart()) {
        expect(part.name, 'plain');
        expect(part.filename, 'a b.txt');
        expect(part.isFile, isTrue);
        expect(part.encoding, latin1);
        expect(part.headers['x-folded'], 'one two');
        expect(() => part.headers['x'] = 'y', throwsUnsupportedError);
        expect(part.toString(), 'MultipartPart{name: plain, file}');
        await part.readAsString();
      }
    });

    test('a repeated header is joined', () async {
      await for (final MultipartPart part in _request(
        '--$_boundary\r\nX-A: 1\r\nx-a: 2\r\n\r\nv\r\n--$_boundary--',
      ).multipart()) {
        expect(part.headers, {'x-a': '1, 2'});
        expect(part.name, isNull);
        expect(part.encoding, isNull);
      }
    });

    test('a malformed Content-Type of a part has no charset', () async {
      await for (final MultipartPart part in _request(
        _body([
          _part({'Content-Type': 'text/plain; charset'}, 'v'),
        ]),
      ).multipart()) {
        expect(part.encoding, isNull);
        expect(await part.readAsString(), 'v');
      }
    });

    test('works with any multipart type', () async {
      expect(
        await _readAll(
          _request(body, contentType: 'multipart/mixed; boundary=$_boundary'),
        ),
        hasLength(4),
      );
    });

    test('another Content-Type, or none, is a 415', () {
      expect(
        () => _request(body, contentType: 'application/json').multipart(),
        throwsA(isA<UnsupportedMediaTypeException>()),
      );
      expect(
        () => RequestEntity(
          'POST',
          Uri.parse('http://localhost/'),
          body: body,
        ).multipart(),
        throwsA(isA<UnsupportedMediaTypeException>()),
      );
    });

    test(
      'a body cut in a part is a 400 for its reader, it never hangs',
      () async {
        final String cut = body.substring(0, body.indexOf('PNG-BYTES') + 3);
        final Future<List<String>> read = _readAll(
          _request(_chunks(utf8.encode(cut), 4)),
        );

        await expectLater(
          read.timeout(const Duration(seconds: 5)),
          throwsA(_badRequest(_malformed)),
        );
      },
    );

    test('an error of the body reaches the reader of the part', () async {
      Stream<List<int>> failing() async* {
        yield utf8.encode(body.substring(0, body.indexOf('PNG-BYTES') + 3));
        throw const PayloadTooLargeException();
      }

      final List<String> names = [];
      final Future<void> read = () async {
        await for (final MultipartPart part in _request(
          failing(),
        ).multipart()) {
          names.add(part.name!);
          await part.readAsBytes();
        }
      }();

      await expectLater(
        read.timeout(const Duration(seconds: 5)),
        throwsA(isA<PayloadTooLargeException>()),
      );
      expect(names, ['title', 'photo']);
    });

    test('through the server: a file is copied as it arrives', () async {
      final WinterTestClient client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.post(
              path: '/upload',
              handler: (request) async {
                final Map<String, int> sizes = {};
                await for (final MultipartPart part in request.multipart()) {
                  final BytesBuilder copy = BytesBuilder();
                  await part.read().forEach(copy.add);
                  sizes[part.filename ?? part.name!] = copy.length;
                }
                return ResponseEntity.ok(body: sizes);
              },
            ),
          ],
        ),
      );

      final TestResponse response = await client.post(
        '/upload',
        body: body,
        headers: {HttpHeader.contentType: _multipart},
      );

      expect(jsonDecode(response.body), {
        'title': 8,
        'beach.png': 9,
        'tags': 3,
      });
    });

    test('through the server: a malformed body is a 400', () async {
      final WinterTestClient client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.post(
              path: '/upload',
              handler: (request) async {
                await request.multipart().drain<void>();
                return ResponseEntity.ok();
              },
            ),
          ],
        ),
      );

      final TestResponse response = await client.post(
        '/upload',
        body: 'not multipart',
        headers: {HttpHeader.contentType: _multipart},
      );

      expect(response.statusCode, 400);
      expect(jsonDecode(response.body)['detail'], _malformed);
    });
  });

  test('UploadedFile can be built for a test', () {
    final UploadedFile file = UploadedFile(
      name: 'f',
      filename: 'a.txt',
      bytes: Uint8List(3),
      headers: {'content-type': 'text/plain'},
    );

    expect(file.mimeType, 'text/plain');
    expect(() => file.headers['x'] = 'y', throwsUnsupportedError);
  });
}

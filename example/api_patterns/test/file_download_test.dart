import 'package:api_patterns_examples/file_download.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router(rows: 3));

  test('the export is a streamed CSV attachment', () async {
    final response = await client.get('/exports/customers');

    expect(response.headers['content-type'], 'text/csv; charset=utf-8');
    // A stream has no Content-Length: it goes chunked
    expect(response.headers['content-length'], isNull);
    expect(
      response.body,
      'id,name,status\r\n'
      '1,Customer 1,blocked\r\n'
      '2,Customer 2,active\r\n'
      '3,Customer 3,blocked\r\n',
    );
  });

  test(
    'a file name with accents goes encoded, with an ASCII fallback',
    () async {
      final response = await client.get('/exports/customers');

      expect(
        response.headers['content-disposition'],
        'attachment; filename="clientes-a_o.csv"; '
        "filename*=UTF-8''clientes-a%C3%B1o.csv",
      );
    },
  );

  test('a file shown inline, with its length', () async {
    final response = await client.get('/receipts/7');

    expect(response.body, 'Receipt 7\n');
    expect(response.headers['content-length'], '10');
    expect(response.headers['content-disposition'], startsWith('inline'));
  });

  test('csvField() quotes commas, quotes and line breaks', () {
    expect(csvField('plain'), 'plain');
    expect(csvField('a,b'), '"a,b"');
    expect(csvField('say "hi"'), '"say ""hi"""');
    expect(csvField('two\nlines'), '"two\nlines"');
  });
}

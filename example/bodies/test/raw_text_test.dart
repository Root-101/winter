import 'package:bodies_examples/raw_text.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  Future<TestResponse> post(String path, String body, String type) =>
      client.post(path, body: body, headers: {HttpHeader.contentType: type});

  test('text, XML, HTML and JavaScript, as they came', () async {
    for (final (String type, String text) in [
      ('text/plain', 'line 1\nline 2'),
      ('application/xml', '<note><title>Groceries</title></note>'),
      ('text/html', '<p>Hello</p>'),
      ('application/javascript', 'console.log(1);'),
    ]) {
      expect((await post('/text', text, type)).json, {
        'contentType': type,
        'characters': text.length,
        'text': text,
      });
    }
  });

  test('a CSV, one object per row', () async {
    final response = await post(
      '/csv',
      'name,age\nAnn,30\nBob,25\n',
      'text/csv',
    );

    expect(response.json, [
      {'name': 'Ann', 'age': '30'},
      {'name': 'Bob', 'age': '25'},
    ]);
  });
}

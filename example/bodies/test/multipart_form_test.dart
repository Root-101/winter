import 'package:bodies_examples/multipart_form.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

import 'multipart_body.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  test('the fields and every file of a field', () async {
    final (String type, String body) = multipartBody(
      fields: {'title': 'Holiday'},
      files: [
        ('photos', 'a.png', 'image/png', 'AAAA'),
        ('photos', 'b.jpg', 'image/jpeg', 'BBBBBB'),
      ],
    );

    final response = await client.post(
      '/albums',
      body: body,
      headers: {HttpHeader.contentType: type},
    );

    expect(response.statusCode, 201);
    expect(response.json, {
      'title': 'Holiday',
      'photos': [
        {'filename': 'a.png', 'type': 'image/png', 'bytes': 4},
        {'filename': 'b.jpg', 'type': 'image/jpeg', 'bytes': 6},
      ],
    });
  });
}

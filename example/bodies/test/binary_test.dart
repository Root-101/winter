import 'dart:typed_data';

import 'package:bodies_examples/binary.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  final client = WinterTestClient.build(router: router());

  Future<TestResponse> put(List<int> bytes, String type) => client.put(
    '/avatar',
    body: Uint8List.fromList(bytes),
    headers: {HttpHeader.contentType: type},
  );

  test('a PNG: the bytes as they came', () async {
    expect(
      (await put([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A], 'image/png')).json,
      {'declared': 'image/png', 'detected': 'image/png', 'bytes': 6},
    );
  });

  test('the content decides, not the declared type', () async {
    // A PDF that says it's a PNG
    final response = await put([0x25, 0x50, 0x44, 0x46, 0x2D], 'image/png');

    expect(response.statusCode, 415);
  });
}

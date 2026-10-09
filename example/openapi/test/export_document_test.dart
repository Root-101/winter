import 'dart:convert';

import 'package:openapi_examples/export_document.dart';
import 'package:test/test.dart';

void main() {
  test('the document without a server', () {
    final json = jsonDecode(document()) as Map<String, dynamic>;

    expect(json['openapi'], '3.1.0');
    expect((json['paths'] as Map).keys, contains('/api/v1/books/{id}'));
  });
}

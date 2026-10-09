/// The document without a server: `OpenApi(...).toJson()` written to `openapi.json`, for a client
/// generator (openapi-generator, orval...) or to check it into the repository.
///
/// Run: `dart run lib/export_document.dart`
library;

import 'dart:convert';
import 'dart:io';

import 'package:winter/winter.dart';

import 'documented_api.dart' as library_api;

/// The document of the library API, as a pretty JSON text
String document() {
  Winter.context.setUp(objectMapper: library_api.objectMapper());
  final Map<String, Object?> json = OpenApi(
    title: 'Library',
    version: '1.0.0',
    router: library_api.router(),
  ).toJson();
  return const JsonEncoder.withIndent('  ').convert(json);
}

Future<void> main() async {
  await File('openapi.json').writeAsString(document());
  stdout.writeln('openapi.json written');
}

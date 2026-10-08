import 'dart:typed_data';

import 'package:winter/winter.dart';

/// A note, sent as raw JSON
class Note implements Validatable {
  final String title;
  final List<String> tags;

  Note(this.title, this.tags);

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    json.field<String>('title'),
    json.field<List<String>?>('tags') ?? const [],
  );

  Map<String, Object?> toJson() => {'title': title, 'tags': tags};

  @override
  ConstraintValidatorContext validate() =>
      ConstraintValidatorContext()..field('title', title).notBlank();
}

/// A GraphQL request: raw JSON with `query`, `variables` and `operationName`
class GraphQLRequest {
  final String query;
  final Map<String, dynamic> variables;
  final String? operationName;

  GraphQLRequest(this.query, this.variables, this.operationName);

  factory GraphQLRequest.fromJson(Map<String, dynamic> json) => GraphQLRequest(
    json.field<String>('query'),
    json.field<Map<String, dynamic>?>('variables') ?? const {},
    json.field<String?>('operationName'),
  );
}

/// One endpoint per kind of body (the tabs of Postman's "Body"): each one reads its body and
/// answers what it got, as JSON
class BodiesApp {
  static ObjectMapper objectMapper() => ObjectMapper(
    deserializers: [
      Deserializer<Note>.json(Note.fromJson),
      Deserializer<GraphQLRequest>.json(GraphQLRequest.fromJson),
    ],
  );

  static WinterRouter router() => WinterRouter(
    basePath: '/bodies',
    routes: [
      /// none: no body at all. A nullable type reads it as null
      Route.post(
        path: '/none',
        handler: (request) async {
          final Map<String, dynamic>? body = await request
              .body<Map<String, dynamic>?>();
          return ResponseEntity.ok(body: {'received': body ?? 'nothing'});
        },
      ),

      /// raw > JSON: a typed (and validated) object
      Route.post(
        path: '/json',
        handler: (request) async {
          final Note note = await request.body<Note>();
          return ResponseEntity.ok(body: {'note': note});
        },
      ),

      /// raw > Text, XML, HTML, JavaScript (or CSV...): the text as it came
      Route.post(
        path: '/raw',
        handler: (request) async {
          final String text = await request.body<String>();
          return ResponseEntity.ok(
            body: {
              'contentType': request.mimeType,
              'characters': text.length,
              'lines': text.isEmpty ? 0 : text.split('\n').length,
              'text': text,
            },
          );
        },
      ),

      /// x-www-form-urlencoded: an HTML form without files
      Route.post(
        path: '/urlencoded',
        handler: (request) async {
          final FormData form = await request.formData();
          return ResponseEntity.ok(
            body: {
              'fields': form.fields,
              'tags': form.fieldsAll['tag'] ?? const [],
              'age': form.field<int>('age'),
            },
          );
        },
      ),

      /// form-data: fields and files (multipart/form-data)
      Route.post(
        path: '/form-data',
        handler: (request) async {
          final FormData form = await request.formData();
          return ResponseEntity.ok(
            body: {
              'fields': form.fields,
              'files': [
                for (final MapEntry(key: field, value: files)
                    in form.filesAll.entries)
                  for (final UploadedFile file in files)
                    {
                      'field': field,
                      'filename': file.filename,
                      'type': file.mimeType,
                      'bytes': file.length,
                    },
              ],
            },
          );
        },
      ),

      /// binary: the bytes as they came (a file, an image), any Content-Type
      Route.post(
        path: '/binary',
        handler: (request) async {
          final Uint8List bytes = await request.bytes();
          return ResponseEntity.ok(
            body: {
              'contentType': request.mimeType,
              'bytes': bytes.length,
              'start': [
                for (final int byte in bytes.take(4))
                  byte.toRadixString(16).padLeft(2, '0'),
              ].join(' '),
            },
          );
        },
      ),

      /// GraphQL: raw JSON with the query and its variables
      Route.post(
        path: '/graphql',
        handler: (request) async {
          final GraphQLRequest graphql = await request.body<GraphQLRequest>();
          return ResponseEntity.ok(
            body: {
              'operationName': graphql.operationName,
              'query': graphql.query,
              'variables': graphql.variables,
            },
          );
        },
      ),
    ],
  );

  static Future<void> start({int port = 8080}) async {
    Winter.context.setUp(objectMapper: objectMapper());
    await Winter.start(
      config: ServerConfig(port: port, maxBodySize: 5 * 1024 * 1024),
      router: router(),
    );
  }
}

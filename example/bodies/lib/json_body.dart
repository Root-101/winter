/// raw > JSON: the body as a typed object, validated (`body<T>()`), or as a plain map.
///
/// Run: `dart run lib/json_body.dart`, then
/// `curl localhost:8080/notes -H 'Content-Type: application/json' -d '{"title": "Groceries"}'`
library;

import 'package:winter/winter.dart';

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

ObjectMapper objectMapper() =>
    ObjectMapper(deserializers: [Deserializer<Note>.json(Note.fromJson)]);

WinterRouter router() => WinterRouter(
  routes: [
    // A typed object: 400 for a wrong shape, 422 for a rule
    Route.post(
      path: '/notes',
      handler: (request) async =>
          ResponseEntity.ok(body: await request.body<Note>()),
    ),
    // Any JSON object, as a map
    Route.post(
      path: '/echo',
      handler: (request) async {
        final Map<String, dynamic> json = await request
            .body<Map<String, dynamic>>();
        return ResponseEntity.ok(body: {'keys': json.keys.toList()});
      },
    ),
  ],
);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}

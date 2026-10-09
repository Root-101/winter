/// `BodyDocs`: a schema and an example at once (the schema wins, the example fills Swagger), the
/// JSON of a model without `toJson()` with the rules of the model (`rulesFrom`), a description and
/// another content type.
///
/// Run: `dart run lib/body_docs.dart`, then open http://localhost:8080/docs
library;

import 'package:winter/winter.dart';

/// A body that is only read: no toJson(), so its example is the JSON a client sends
class ChangePassword implements Validatable {
  final String current;
  final String next;

  ChangePassword(this.current, this.next);

  factory ChangePassword.fromJson(Map<String, dynamic> json) =>
      ChangePassword(json.field<String>('current'), json.field<String>('next'));

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('current', current, sensitive: true).notNull()
    ..field('next', next, sensitive: true).notNull().size(min: 12);
}

WinterRouter router() {
  final router = WinterRouter(
    routes: [
      // A PATCH: every field optional, nickname nullable. The example shows the case that matters
      Route.patch(
        path: '/me',
        docs: RouteDocs(
          summary: 'Change some fields of my profile',
          request: BodyDocs(
            schema: JsonSchema.object({
              'name': JsonSchema.string(minLength: 1),
              'nickname': JsonSchema.string(nullable: true),
            }),
            example: {'nickname': null},
            description:
                'Only the fields sent change; null clears the nickname',
          ),
          response: {'name': 'Ann Lee', 'nickname': null},
        ),
        handler: (request) async =>
            ResponseEntity.ok(body: await request.body<Map<String, dynamic>>()),
      ),
      // The JSON as the example, the model for its rules (required, minLength)
      Route.put(
        path: '/me/password',
        docs: RouteDocs(
          summary: 'Change my password',
          status: 204,
          request: BodyDocs(
            example: {'current': 'old password', 'next': 'a much longer one'},
            rulesFrom: ChangePassword('', ''),
          ),
        ),
        handler: (request) async {
          await request.body<ChangePassword>();
          return ResponseEntity.noContent();
        },
      ),
      // Not JSON: another content type
      Route.put(
        path: '/me/avatar',
        docs: RouteDocs(
          summary: 'Upload my avatar',
          status: 204,
          request: BodyDocs(
            schema: JsonSchema.string(format: 'binary'),
            contentType: 'image/png',
          ),
        ),
        handler: (request) async {
          await request.bytes();
          return ResponseEntity.noContent();
        },
      ),
      // Left out of the document
      Route.get(
        path: '/internal/metrics',
        docs: RouteDocs.none,
        handler: (request) => ResponseEntity.ok(body: {'requests': 0}),
      ),
    ],
  );
  return router
    ..addRoute(
      Route.openApi(
        openApi: OpenApi(title: 'Profile', version: '1.0.0', router: router),
      ),
    )
    ..addRoute(Route.swaggerUi(title: 'Profile'));
}

ObjectMapper objectMapper() => ObjectMapper(
  deserializers: [Deserializer<ChangePassword>.json(ChangePassword.fromJson)],
);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}

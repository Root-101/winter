/// How objects are written: `toJson()` with Dart names, sent as snake_case, without nulls; dates
/// in UTC, enums by name.
///
/// Run: `dart run lib/field_naming.dart`, then `curl localhost:8080/profile`
library;

import 'package:winter/winter.dart';

enum Plan { free, pro }

class Profile {
  final String fullName;
  final DateTime createdAt;
  final Plan plan;
  final String? avatarUrl;

  Profile(this.fullName, this.createdAt, this.plan, [this.avatarUrl]);

  // Dart names: the mapper renames them
  Map<String, Object?> toJson() => {
    'fullName': fullName,
    'createdAt': createdAt,
    'plan': plan,
    'avatarUrl': avatarUrl,
  };
}

ObjectMapper objectMapper() => ObjectMapper(
  fieldNaming: FieldNaming.snakeCase,
  // avatar_url is left out while it's null
  includeNulls: false,
);

WinterRouter router() => WinterRouter(
  routes: [
    Route.get(
      path: '/profile',
      handler: (request) => ResponseEntity.ok(
        // A date with an offset is written in UTC
        body: Profile(
          'Ann Lee',
          DateTime.parse('2026-03-01T10:00:00+02:00'),
          Plan.pro,
        ),
      ),
    ),
    // A Map is written as it is: never renamed, nulls kept
    Route.get(
      path: '/raw',
      handler: (request) =>
          ResponseEntity.ok(body: {'keepThisName': true, 'nothing': null}),
    ),
  ],
);

Future<void> main() async {
  Winter.context.setUp(objectMapper: objectMapper());
  await Winter.start(router: router());
}

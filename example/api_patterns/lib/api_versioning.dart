/// Two versions of an API side by side, by path (`/v1`, `/v2`): each version is a parent route,
/// and the old one announces its end with a `DeprecationFilter` in the parent: the `Deprecation`
/// and `Sunset` headers (RFC 9745, RFC 8594), a `Link` to the migration guide and another to the
/// same resource in v2, on every response of v1 (its errors too), and `deprecated` in OpenAPI.
///
/// Run: `dart run lib/api_versioning.dart`, then
/// `curl -i localhost:8080/v1/users/1` and `curl localhost:8080/v2/users/1`
library;

import 'package:winter/winter.dart';

class User {
  final int id;
  final String firstName;
  final String lastName;

  const User(this.id, this.firstName, this.lastName);
}

const Map<int, User> users = {1: User(1, 'Ann', 'Lee')};

User findUser(RequestEntity request) {
  final int id = request.pathParam<int>('id');
  return users[id] ?? (throw NotFoundException(detail: 'User $id not found'));
}

WinterRouter router() => WinterRouter(
  routes: [
    // v1: the name in one field. Deprecated since 2026-07-01, it ends on 2027-01-01
    Route.parent(
      path: '/v1',
      filterConfig: FilterConfig([
        DeprecationFilter(
          deprecated: DateTime.utc(2026, 7),
          sunset: DateTime.utc(2027),
          link: Uri.parse('https://api.example.com/docs/v2-migration'),
          successor: (request) =>
              request.requestedUri.path.replaceFirst('/v1/', '/v2/'),
        ),
      ]),
      routes: [
        Route.get(
          path: '/users/{id|[0-9]+}',
          handler: (request) {
            final User user = findUser(request);
            return ResponseEntity.ok(
              body: {
                'id': user.id,
                'name': '${user.firstName} ${user.lastName}',
              },
            );
          },
        ),
      ],
    ),
    // v2: the name split in two. Both versions share the domain (findUser)
    Route.parent(
      path: '/v2',
      routes: [
        Route.get(
          path: '/users/{id|[0-9]+}',
          handler: (request) {
            final User user = findUser(request);
            return ResponseEntity.ok(
              body: {
                'id': user.id,
                'firstName': user.firstName,
                'lastName': user.lastName,
              },
            );
          },
        ),
      ],
    ),
  ],
);

Future<void> main() async => Winter.start(router: router());

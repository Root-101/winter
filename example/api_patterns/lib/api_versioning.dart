/// Two versions of an API side by side, by path (`/v1`, `/v2`): each version is a parent route,
/// and the old one announces its end with the `Deprecation` and `Sunset` headers (RFC 9745,
/// RFC 8594) and a `Link` to its successor, added by a filter of the parent.
///
/// Run: `dart run lib/api_versioning.dart`, then
/// `curl -i localhost:8080/v1/users/1` and `curl localhost:8080/v2/users/1`
library;

import 'dart:io' show HttpDate;

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

/// Marks every response of a version as deprecated
class DeprecationFilter extends Filter {
  /// When the version stops answering
  final DateTime sunset;

  /// The same resource in the new version
  final String Function(RequestEntity request) successor;

  DeprecationFilter({required this.sunset, required this.successor});

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final ResponseEntity response = await chain.doFilter(request);
    return response.copyWith(
      headers: {
        'Deprecation': 'true',
        'Sunset': HttpDate.format(sunset),
        HttpHeader.link: '<${successor(request)}>; rel="successor-version"',
      },
    );
  }
}

WinterRouter router() => WinterRouter(
  routes: [
    // v1: the name in one field. Deprecated: it ends on 2027-01-01
    Route.parent(
      path: '/v1',
      filterConfig: FilterConfig([
        DeprecationFilter(
          sunset: DateTime.utc(2027),
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

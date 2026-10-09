/// "Only the author or an admin can edit a post": the most common authorization rule, and the
/// one a role alone can't express. Two places to check it:
///
/// - A **rule** on the route, when the request says who the owner is (`/users/{id}/...`).
/// - The **service**, when only the database knows (the author of post 7): it reads the user of
///   the request with `requestPrincipal` and throws a 403 (or a 404, to hide that it exists).
///
/// Run: `dart run lib/resource_ownership.dart`, then
/// `curl -X PUT localhost:8080/posts/1 -H 'Authorization: Bearer bob'`
library;

import 'package:winter/winter.dart';

class User {
  final String id;
  final bool admin;

  const User(this.id, {this.admin = false});
}

class Post {
  final int id;
  final String authorId;
  String text;

  Post(this.id, this.authorId, this.text);

  Map<String, Object> toJson() => {'id': id, 'author': authorId, 'text': text};
}

class PostService {
  final Map<int, Post> _posts = {1: Post(1, 'ann', 'Hello')};

  Post edit(int id, String text) {
    final Post post =
        _posts[id] ?? (throw NotFoundException(detail: 'Post $id not found'));
    final User user = requestPrincipal<User>();
    if (post.authorId != user.id && !user.admin) {
      throw const ForbiddenException(detail: 'Only the author can edit it');
    }
    return post..text = text;
  }
}

/// The path names the owner: checked before the handler
final RuleBuilder isOwner = rule(
  (auth, request) =>
      request.pathParams['userId'] == (auth.principal as User).id,
  describe: 'isOwner',
);

/// `Authorization: Bearer <user>`; a real app verifies a token here
class BearerFilter extends Filter {
  static const Map<String, User> users = {
    'ann': User('ann'),
    'bob': User('bob'),
    'root': User('root', admin: true),
  };

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String? header = request.headers[HttpHeader.authorization];
    final User? user = users[header?.replaceFirst('Bearer ', '')];
    if (user != null) {
      request.securityContext.setAuthentication(
        Authentication<User>(principal: user, roles: {if (user.admin) 'admin'}),
      );
    }
    return chain.doFilter(request);
  }
}

WinterRouter router(PostService posts) => WinterRouter(
  routes: [
    Route.get(
      path: '/users/{userId}/drafts',
      filterConfig: (hasRole('admin') | isOwner).toFilterConfig(),
      handler: (request) =>
          ResponseEntity.ok(body: ['draft of ${request.pathParams['userId']}']),
    ),
    Route.put(
      path: '/posts/{id|[0-9]+}',
      filterConfig: FilterConfig([AuthFilter()]),
      handler: (request) async => ResponseEntity.ok(
        body: posts.edit(
          request.pathParam<int>('id'),
          await request.body<String>(),
        ),
      ),
    ),
  ],
);

Future<void> main() async => Winter.start(
  globalFilterConfig: FilterConfig([BearerFilter()]),
  router: router(PostService()),
);

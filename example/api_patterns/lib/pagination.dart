/// Pagination of a list: `page` and `size` checked, the total in `X-Total-Count` and the links to
/// the other pages in `Link` (RFC 8288), as GitHub does. `WebLink.pages` builds them from the URL
/// of the request, so the other params (`size`, a filter) stay in every link.
///
/// Run: `dart run lib/pagination.dart`, then `curl -i 'localhost:8080/articles?page=2&size=5'`
library;

import 'package:winter/winter.dart';

final List<Map<String, Object>> articles = [
  for (int id = 1; id <= 23; id++) {'id': id, 'title': 'Article $id'},
];

const int maxSize = 50;

WinterRouter router() => WinterRouter(
  routes: [
    Route.get(
      path: '/articles',
      handler: (request) {
        final int page = request.queryParam<int>('page') ?? 1;
        final int size = request.queryParam<int>('size') ?? 10;
        // A limit on size: a client can't ask for the whole table in one request
        if (page < 1 || size < 1 || size > maxSize) {
          throw const BadRequestException(
            detail: 'page must be at least 1, and size between 1 and $maxSize',
          );
        }

        return ResponseEntity.ok(
          body: articles.skip((page - 1) * size).take(size).toList(),
          headers: {
            'X-Total-Count': '${articles.length}',
            // first, prev, next and last: one value of the header each
            HttpHeader.link: WebLink.pages(
              request,
              page: page,
              last: (articles.length / size).ceil(),
            ),
          },
        );
      },
    ),
  ],
);

Future<void> main() async => Winter.start(
  router: router(),
  // A web client can only read these headers if CORS exposes them
  securityConfig: SecurityConfig(
    cors: const CorsConfig(exposedHeaders: ['X-Total-Count', 'Link']),
  ),
);

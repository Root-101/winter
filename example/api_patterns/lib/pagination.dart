/// Pagination of a list: `page` and `size` checked, the total in `X-Total-Count` and the links to
/// the other pages in `Link` (RFC 8288), as GitHub does.
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

        final int last = (articles.length / size).ceil();
        String link(int page, String rel) =>
            '</articles?page=$page&size=$size>; rel="$rel"';

        return ResponseEntity.ok(
          body: articles.skip((page - 1) * size).take(size).toList(),
          headers: {
            'X-Total-Count': '${articles.length}',
            // Several values of one header: a list
            HttpHeader.link: [
              link(1, 'first'),
              if (page > 1) link(page - 1, 'prev'),
              if (page < last) link(page + 1, 'next'),
              link(last, 'last'),
            ],
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

/// Path params and query params, typed: an invalid value is a 400 that names the param.
///
/// Run: `dart run lib/path_and_query_params.dart`, then
/// `curl localhost:8080/products/7` and `curl 'localhost:8080/products?page=2&sort=price&tag=a&tag=b'`
library;

import 'package:winter/winter.dart';

enum Sort { name, price }

WinterRouter router() => WinterRouter(
  routes: [
    // {id|[0-9]+}: only digits match (/products/abc is a 404), read as an int
    Route.get(
      path: '/products/{id|[0-9]+}',
      handler: (request) =>
          ResponseEntity.ok(body: {'id': request.pathParam<int>('id')}),
    ),
    // {slug}: anything but a slash, URL-decoded (/products/by-slug/red%20shoes)
    Route.get(
      path: '/products/by-slug/{slug}',
      handler: (request) =>
          ResponseEntity.ok(body: {'slug': request.pathParam<String>('slug')}),
    ),
    // Query params: null when missing, a 400 when invalid (`?page=two`)
    Route.get(
      path: '/products',
      handler: (request) => ResponseEntity.ok(
        body: {
          'page': request.queryParam<int>('page') ?? 1,
          'sort':
              (request.queryParam<Sort>('sort', values: Sort.values) ??
                      Sort.name)
                  .name,
          'onlyAvailable': request.queryParam<bool>('available') ?? false,
          // A repeated param: every value
          'tags': request.queryParamsAll['tag'] ?? const <String>[],
        },
      ),
    ),
  ],
);

Future<void> main() async => Winter.start(router: router());

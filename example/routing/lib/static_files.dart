/// The files of a folder (`web/`): ETag, 304, Range requests, the index of a folder, and nothing
/// outside it.
///
/// Run: `dart run lib/static_files.dart`, then open http://localhost:8080
library;

import 'package:winter/winter.dart';

WinterRouter router({String directory = 'web'}) => WinterRouter(
  routes: [
    Route.get(
      path: '/api/time',
      handler: (request) =>
          ResponseEntity.ok(body: {'now': DateTime.now().toUtc()}),
    ),
    // Last: it matches every GET under /
    Route.static(
      path: '/',
      directory: directory,
      cacheControl: 'public, max-age=60',
    ),
  ],
);

Future<void> main() async => Winter.start(router: router());

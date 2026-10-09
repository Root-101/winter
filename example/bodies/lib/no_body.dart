/// none: a request without a body. `body<T?>()` is null, so the same route takes an optional body.
///
/// Run: `dart run lib/no_body.dart`, then `curl -X POST localhost:8080/ping`
library;

import 'package:winter/winter.dart';

WinterRouter router() => WinterRouter(
  routes: [
    Route.post(
      path: '/ping',
      handler: (request) async {
        final Map<String, dynamic>? options = await request
            .body<Map<String, dynamic>?>();
        return ResponseEntity.ok(
          body: {'pong': true, 'options': options ?? 'none'},
        );
      },
    ),
  ],
);

Future<void> main() async => Winter.start(router: router());

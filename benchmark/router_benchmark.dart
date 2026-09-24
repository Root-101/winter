// ignore_for_file: avoid_print

import 'package:winter/winter.dart';

/// In-process benchmark of the routing work done for every request
/// (no network): resolve the route, set the routing context (path params),
/// run the handler and serialize the response body.
///
/// Run with: dart run benchmark/router_benchmark.dart
void main() async {
  const iterations = 200000;

  final router = WinterRouter(
    routes: [
      for (int i = 0; i < 10; i++) ...[
        Route.get(path: '/static-$i', handler: _ok),
        Route.get(path: '/resource-$i/{id}', handler: _ok),
        Route.post(path: '/resource-$i/{id}/items/{itemId}', handler: _ok),
      ],
      Route.get(path: '/users/{id}/details', handler: _user),
    ],
  );

  final uris = [
    Uri.parse('http://localhost/static-9'),
    Uri.parse('http://localhost/resource-5/123'),
    Uri.parse('http://localhost/users/42/details'),
  ];

  Future<void> run(int count) async {
    for (var i = 0; i < count; i++) {
      final request = RequestEntity('GET', uris[i % uris.length]);
      final route = router.resolveRoute(request);
      if (route != null) {
        request.setRoutingContext(
          RequestRoutingContext(
            path: route.path,
            key: route.key,
            method: route.method!,
          ),
        );
      }
      await router.handler(request);
    }
  }

  // Warm up
  await run(20000);

  final stopwatch = Stopwatch()..start();
  await run(iterations);
  stopwatch.stop();

  final perSecond = iterations / stopwatch.elapsedMicroseconds * 1000000;
  print('--- Router benchmark (31 routes, in-process) ---');
  print('Total time: ${stopwatch.elapsedMilliseconds} ms');
  print('Requests per second: ${perSecond.toStringAsFixed(0)}');
}

ResponseEntity _ok(RequestEntity request) => ResponseEntity.ok(body: 'ok');

final DateTime _createdAt = DateTime.utc(2026);

ResponseEntity _user(RequestEntity request) => ResponseEntity.ok(
  body: {
    'id': request.pathParams['id'],
    'createdAt': _createdAt,
    'tags': ['a', 'b'],
  },
);

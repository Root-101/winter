/// Health checks for a load balancer or Kubernetes: liveness (the process answers) and readiness
/// (its dependencies answer), a 503 when one is down.
///
/// Run: `dart run lib/health_check.dart`, then `curl -i localhost:8080/readyz`
library;

import 'package:winter/winter.dart';

/// A stand-in for a database: it can go down
class Database {
  bool up = true;

  Future<bool> ping() async => up;
}

WinterRouter router(Database database) => WinterRouter(
  routes: [
    Route.health(path: '/livez'),
    Route.health(
      path: '/readyz',
      checks: {'database': database.ping},
      timeout: const Duration(seconds: 2),
    ),
  ],
);

Future<void> main() async => Winter.start(router: router(Database()));

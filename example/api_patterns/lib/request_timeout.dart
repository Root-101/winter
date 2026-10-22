/// A time limit for every request: `ServerConfig(requestTimeout:)`. Off by default (`null`), so an
/// app turns it on itself.
///
/// - A request whose filters and handler take longer than [timeout] gets a **503** Problem Details,
///   and a warning is logged. A slow client (that sends its body byte by byte) or a stuck
///   dependency no longer holds the request (nor the graceful shutdown) forever.
/// - Dart can't stop the handler: it goes on in the background and its result is ignored.
/// - Only building the response is timed: a stream that is being sent (Server-Sent Events, a file)
///   goes on.
/// - It's one value for the whole server: give it the time of the slowest route (a large upload may
///   need minutes).
///
/// Run: `dart run lib/request_timeout.dart`, then `curl -i localhost:8080/ping` (200) and
/// `curl -i localhost:8080/report` (a 503 after 5 seconds: the report takes 10).
library;

import 'package:winter/winter.dart';

/// The limit of this app: its slowest route answers well under it
const Duration timeout = Duration(seconds: 5);

/// [buildReport] is the slow work of `/report` (10 seconds by default, a fake in the tests)
WinterRouter router({Future<String> Function()? buildReport}) => WinterRouter(
  routes: [
    Route.get(
      path: '/ping',
      handler: (request) => ResponseEntity.ok(body: 'pong'),
    ),
    Route.get(
      path: '/report',
      handler: (request) async =>
          ResponseEntity.ok(body: await (buildReport ?? _slowReport)()),
    ),
  ],
);

Future<String> _slowReport() async {
  await Future<void>.delayed(const Duration(seconds: 10));
  return 'report';
}

Future<void> main() async => Winter.start(
  config: const ServerConfig(requestTimeout: timeout),
  router: router(),
);

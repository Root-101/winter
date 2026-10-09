/// A task every few minutes: purge the expired sessions. It also runs once at the start
/// (`runOnStart`), and finds its dependency in `di` when it runs.
///
/// Run: `dart run lib/interval_task.dart`, then `curl localhost:8080/sessions`
library;

import 'package:winter/winter.dart';

/// The sessions of the users, each with when it expires
class SessionStore {
  final DateTime Function() _clock;
  final Map<String, DateTime> _expiresAt = {};

  SessionStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  int get count => _expiresAt.length;

  void open(String id, Duration lifetime) =>
      _expiresAt[id] = _clock().add(lifetime);

  /// Removes the expired ones; how many
  int purgeExpired() {
    final DateTime now = _clock();
    final int before = _expiresAt.length;
    _expiresAt.removeWhere((_, expiresAt) => !expiresAt.isAfter(now));
    final int purged = before - _expiresAt.length;
    if (purged > 0) logger.info('Purged $purged expired session(s)');
    return purged;
  }
}

Scheduler scheduler() => Scheduler()
  ..every(
    const Duration(minutes: 5),
    name: 'purge-sessions',
    runOnStart: true,
    // Found when it runs: a test or a restart can replace it
    task: () => di.find<SessionStore>().purgeExpired(),
  );

WinterRouter router() => WinterRouter(
  routes: [
    Route.get(
      path: '/sessions',
      handler: (request) =>
          ResponseEntity.ok(body: {'open': di.find<SessionStore>().count}),
    ),
  ],
);

Future<void> main() async {
  di.put(
    SessionStore()
      ..open('a', const Duration(seconds: 1))
      ..open('b', const Duration(hours: 1)),
  );
  await Winter.start(router: router(), scheduler: scheduler());
}

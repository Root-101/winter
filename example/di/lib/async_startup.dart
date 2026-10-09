/// A dependency that needs `await` to be created (a database pool that connects, a config
/// fetched from a secrets manager): `putLazyAsync` registers it, `Winter.start` awaits it
/// before opening the port (a failure stops the start), and `onDispose` closes it on shutdown.
///
/// Run: `dart run lib/async_startup.dart`, then `curl localhost:8080/health` and Ctrl+C
library;

import 'package:winter/winter.dart';

/// Stands for a connection pool
class Database {
  bool open = true;

  static Future<Database> connect(String url) async {
    await Future<void>.delayed(Duration.zero); // the handshake
    if (!url.startsWith('postgres://')) {
      throw ArgumentError.value(url, 'url', 'Not a postgres url');
    }
    return Database();
  }

  Future<bool> ping() async => open;

  Future<void> close() async => open = false;
}

/// Synchronous, but needs the database: created after it, with di.find
class UserRepository {
  final Database database;

  UserRepository(this.database);
}

void registerDependencies({required String databaseUrl}) {
  di
    ..putLazyAsync<Database>(
      () => Database.connect(databaseUrl),
      onDispose: (database) => database.close(),
    )
    ..putLazy<UserRepository>(() => UserRepository(di.find()));
}

WinterRouter router() => WinterRouter(
  routes: [
    Route.health(
      path: '/health',
      checks: {'database': () => di.find<Database>().ping()},
    ),
  ],
);

Future<void> main() async {
  registerDependencies(databaseUrl: 'postgres://localhost/app');
  // Awaits di.ready(): every putLazyAsync created, in order, before the port opens.
  // Winter.shutdown() (Ctrl+C) runs the onDispose of each one, in reverse order
  await Winter.start(router: router());
}

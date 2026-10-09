import 'package:di_examples/async_startup.dart';
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  setUp(() => Winter.context.setUp(dependencyInjection: DependencyInjection()));

  test('ready() connects; then the sync dependencies find it', () async {
    registerDependencies(databaseUrl: 'postgres://localhost/test');

    // Before ready(), a sync find of an async dependency is a mistake
    expect(() => di.find<Database>(), throwsStateError);

    await di.ready();
    expect(di.find<UserRepository>().database.open, isTrue);

    final client = WinterTestClient.build(router: router());
    expect((await client.get('/health')).statusCode, 200);
  });

  test('a failed connection fails ready(), naming the dependency', () async {
    registerDependencies(databaseUrl: 'mysql://nope');

    await expectLater(
      di.ready(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Database'),
        ),
      ),
    );
  });

  test('disposeAll() closes it, as the shutdown does', () async {
    registerDependencies(databaseUrl: 'postgres://localhost/test');
    await di.ready();
    final Database database = di.find<Database>();

    await di.disposeAll();

    expect(database.open, isFalse);
  });
}

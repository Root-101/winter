@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The behavior decided in the review of the dependency injection (DECISIONS.md §5)
void main() {
  late DependencyInjection di;

  setUp(() => di = DependencyInjection());

  group('A dependency registered from a nullable variable (§5.1)', () {
    test('is found by its non nullable type', () {
      final maybe = _maybeService();
      di.put(maybe); // registered as <_Service?>

      expect(di.tryFind<_Service>(), same(maybe));
      expect(di.find<_Service>(), same(maybe));
    });

    test('and the other way around', () {
      di.put(_Service());

      expect(di.find<_Service?>(), isNotNull);
    });

    test('delete finds it too', () {
      final maybe = _maybeService();
      di.put(maybe);

      expect(di.delete<_Service>(), same(maybe));
      expect(di.tryFind<_Service?>(), isNull);
    });
  });

  group('Exact types (§5.1)', () {
    test('an implementation is not found by its interface', () {
      di.put(_SqlRepository());

      expect(
        () => di.find<_Repository>(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('<_Repository>'), contains('di.put<_Repository>')),
          ),
        ),
      );
    });

    test('registered with the type it is looked up by', () {
      di.put<_Repository>(_SqlRepository());

      expect(di.find<_Repository>(), isA<_SqlRepository>());
    });
  });

  group('putLazy (§5.2)', () {
    test('creates the instance on the first find, once', () {
      var created = 0;
      di.putLazy<_Service>(() {
        created++;
        return _Service();
      });

      expect(created, 0);
      final first = di.find<_Service>();
      expect(di.find<_Service>(), same(first));
      expect(created, 1);
    });

    test('dependencies can be registered in any order', () {
      di
        ..putLazy<_Controller>(() => _Controller(di.find()))
        ..putLazy<_Repository>(_SqlRepository.new);

      expect(di.find<_Controller>().repository, isA<_SqlRepository>());
    });

    test('a cycle is a StateError that shows the chain', () {
      di
        ..putLazy<_A>(() => _A(di.find()))
        ..putLazy<_B>(() => _B(di.find()));

      expect(
        () => di.find<_A>(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Circular dependency: _A -> _B -> _A',
          ),
        ),
      );
      // Nothing is left half created
      di.put<_B>(_B(null));
      expect(di.find<_A>().b, isNotNull);
    });

    test('tryFind creates it too, delete returns it only if created', () {
      di.putLazy<_Service>(_Service.new, tag: 'unused');
      di.putLazy<_Service>(_Service.new, tag: 'used');

      final used = di.tryFind<_Service>(tag: 'used');

      expect(di.delete<_Service>(tag: 'unused'), isNull);
      expect(di.delete<_Service>(tag: 'used'), same(used));
    });
  });

  group('putFactory (§5.2)', () {
    test('creates a new instance on every find', () {
      di.putFactory<_Service>(_Service.new);

      expect(di.find<_Service>(), isNot(same(di.find<_Service>())));
      expect(di.delete<_Service>(), isNull);
    });
  });

  group('putScoped (§5.2, §5.3)', () {
    test('one instance per request, disposed when it ends', () async {
      final disposed = <_UnitOfWork>[];
      Winter.context.setUp(dependencyInjection: di);
      addTearDown(
        () => Winter.context.setUp(dependencyInjection: DependencyInjection()),
      );
      di.putScoped<_UnitOfWork>(_UnitOfWork.new, onDispose: disposed.add);
      final client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/',
              handler: (request) async {
                final first = di.find<_UnitOfWork>();
                await Future<void>.delayed(Duration.zero);
                // The same instance after an await, in the same request
                expect(di.find<_UnitOfWork>(), same(first));
                return ResponseEntity.ok(body: first.id);
              },
            ),
          ],
        ),
      );

      final ids = await Future.wait([
        for (var i = 0; i < 5; i++) client.get('/').then((r) => r.body),
      ]);

      // Concurrent requests never share it
      expect(ids.toSet(), hasLength(5));
      expect(disposed.map((uow) => '${uow.id}').toSet(), ids.toSet());
    });

    test('outside a request it is a StateError', () {
      di.putScoped<_UnitOfWork>(_UnitOfWork.new);

      expect(
        () => di.find<_UnitOfWork>(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('scoped to a request'),
          ),
        ),
      );
    });

    test(
      'RequestScope.run gives it a request, complete() disposes it',
      () async {
        final events = <String>[];
        di
          ..putScoped<_UnitOfWork>(
            _UnitOfWork.new,
            onDispose: (_) => events.add('uow'),
          )
          ..putScoped<_Service>(
            _Service.new,
            onDispose: (_) => events.add('service'),
          );
        final scope = RequestScope();

        RequestScope.run(scope, () {
          di.find<_UnitOfWork>();
          di.find<_Service>();
        });
        await scope.complete();
        await scope.complete(); // only once

        // In reverse order of creation
        expect(events, ['service', 'uow']);
      },
    );
  });

  group('onDispose and disposeAll (§5.3)', () {
    test('in reverse order of registration, only what was created', () async {
      final events = <String>[];
      di
        ..put(_Service(), onDispose: (_) => events.add('service'))
        ..putLazy<_Repository>(
          _SqlRepository.new,
          onDispose: (_) => events.add('repository'),
        )
        ..putLazy<_Controller>(
          () => _Controller(di.find()),
          onDispose: (_) => events.add('never created'),
        )
        ..put<String?>(null, tag: 'null', onDispose: (_) => events.add('null'));
      di.find<_Repository>();

      await di.disposeAll();

      expect(events, ['null', 'repository', 'service']);
      expect(di.isRegistered<_Service>(), isFalse);
    });

    test('a registration again moves it to the end', () async {
      final events = <String>[];
      di
        ..put(_Service(), onDispose: (_) => events.add('first'))
        ..put<_Repository>(
          _SqlRepository(),
          onDispose: (_) => events.add('repo'),
        )
        ..put(_Service(), onDispose: (_) => events.add('second'));

      await di.disposeAll();

      expect(events, ['second', 'repo']);
    });

    test('a failing onDispose is logged and the others still run', () async {
      final logs = <String>[];
      Winter.context.setUp(logger: _MemoryLogger(logs));
      addTearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));
      final events = <String>[];
      di
        ..put(_Service(), onDispose: (_) => events.add('service'))
        ..put<_Repository>(
          _SqlRepository(),
          onDispose: (_) => throw StateError('closed twice'),
        );

      await di.disposeAll();

      expect(events, ['service']);
      expect(logs.single, contains('<_Repository>'));
    });

    test('Winter.shutdown() disposes them after onShutdown', () async {
      final events = <String>[];
      final previous = Winter.context.dependencyInjection;
      Winter.context.setUp(dependencyInjection: di);
      addTearDown(() => Winter.context.setUp(dependencyInjection: previous));
      di.put(_Service(), onDispose: (_) => events.add('dispose'));

      await Winter.start(
        config: ServerConfig(
          port: 9088,
          handleSignals: false,
          onShutdown: () => events.add('onShutdown'),
        ),
        router: WinterRouter(routes: []),
      );
      await Winter.shutdown();

      expect(events, ['onShutdown', 'dispose']);
    });
  });

  group('null values and isRegistered (§5.4)', () {
    test('a null value can be registered and found', () {
      di.put<String?>(null, tag: 'optional');

      expect(di.isRegistered<String>(tag: 'optional'), isTrue);
      expect(di.find<String?>(tag: 'optional'), isNull);
    });

    test('a null value can be deleted', () {
      di.put<String?>(null, tag: 'optional');

      expect(di.delete<String?>(tag: 'optional'), isNull);
      expect(di.isRegistered<String>(tag: 'optional'), isFalse);
      expect(() => di.find<String?>(tag: 'optional'), throwsStateError);
    });
  });

  group('RequestScope.onComplete', () {
    test('a failing callback is logged and the others still run', () async {
      final logs = <String>[];
      Winter.context.setUp(logger: _MemoryLogger(logs));
      addTearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));
      final events = <String>[];
      final scope = RequestScope()
        ..onComplete(() => events.add('first'))
        ..onComplete(() => throw StateError('x'));

      await scope.complete();

      expect(events, ['first']);
      expect(logs, hasLength(1));
    });
  });
}

class _Service {}

/// A `_Service?`, as a variable of a nullable type would be
_Service? _maybeService() => _Service();

abstract class _Repository {}

class _SqlRepository implements _Repository {}

class _Controller {
  final _Repository repository;

  _Controller(this.repository);
}

class _A {
  final _B b;

  _A(this.b);
}

class _B {
  final _A? a;

  _B(this.a);
}

var _nextId = 0;

class _UnitOfWork {
  final int id = _nextId++;
}

class _MemoryLogger extends WinterLogger {
  final List<String> logs;

  _MemoryLogger(this.logs);

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => logs.add(message);
}

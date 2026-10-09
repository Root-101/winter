import 'dart:async';

import 'package:winter/winter.dart';

/// A service locator: dependencies registered and found by their type (and an optional tag).
///
/// ```dart
/// di.put(UserService());                                     // the instance given
/// di.putLazy<Database>(() => Database.connect(url),          // created by the first find
///     onDispose: (db) => db.close());
/// di.putFactory<Clock>(() => SystemClock());                 // a new one by every find
/// di.putScoped<UnitOfWork>(() => UnitOfWork(di.find()));     // one per request
///
/// final users = di.find<UserService>();
/// ```
///
/// A dependency is found by the exact type it was registered with: register an implementation
/// with the type it's looked up by (`di.put<UserRepository>(SqlUserRepository())`). `T` and `T?`
/// are the same key.
///
/// Every instance has its own dependencies; the global one is `di` (from the current
/// `Winter.context`). A [child] falls back to it, so a test can replace some of them.
///
/// {@category Dependency injection}
class DependencyInjection {
  /// The container a [child] falls back to; null for a root one
  final DependencyInjection? parent;

  /// In order of registration (a registration again moves to the end)
  final Map<_Key, _Registration> _registrations = {};

  /// The keys being created right now, to find cycles between lazy ones (`A → B → A`)
  final List<_Key> _creating = [];

  /// The instances of the scoped dependencies of each request
  final Expando<Map<_Key, Object?>> _scopedInstances = Expando();

  /// A root container, without dependencies
  DependencyInjection() : parent = null;

  DependencyInjection._child(DependencyInjection this.parent);

  /// A container that falls back to this one: what it registers wins, and what it doesn't have
  /// comes from here. A test replaces some dependencies without touching the global `di`:
  ///
  /// ```dart
  /// setUp(() => Winter.context.setUp(
  ///   dependencyInjection: di.child()..put<UserRepository>(FakeUserRepository()),
  /// ));
  /// ```
  ///
  /// It takes the *recipes* of this container, not its instances (except those given with
  /// [put]): a [putLazy] of the parent gets its own instance in the child, created when the child
  /// finds it, so it uses the dependencies of the child (the fakes). This container never changes:
  /// [registrations], [delete], [createAll] and [disposeAll] of the child only see what the child
  /// registered or created.
  DependencyInjection child() => DependencyInjection._child(this);

  /// Registers [dependency] (replacing what was registered with the same type and tag).
  /// [onDispose] is called by [disposeAll] (and so by `Winter.shutdown()`).
  void put<S>(
    S dependency, {
    String? tag,
    FutureOr<void> Function(S dependency)? onDispose,
  }) => _register<S>(
    tag,
    _Registration(
      DependencyKind.instance,
      type: S,
      onDispose: _typedDispose(onDispose),
    )..value = dependency,
  );

  /// Registers a singleton created by [create] the first time it's found, so dependencies can be
  /// registered in any order even if one needs another. [create] is synchronous: await an async
  /// initialization before registering.
  void putLazy<S>(
    S Function() create, {
    String? tag,
    FutureOr<void> Function(S dependency)? onDispose,
  }) => _register<S>(
    tag,
    _Registration(
      DependencyKind.lazy,
      type: S,
      create: create,
      onDispose: _typedDispose(onDispose),
    ),
  );

  /// Registers a singleton created by an asynchronous [create] (a connection that must be opened):
  ///
  /// ```dart
  /// di.putLazyAsync<Database>(() => Database.connect(env.require('DATABASE_URL')),
  ///     onDispose: (db) => db.close());
  /// await di.ready();               // Winter.start does it before opening the port
  /// final db = di.find<Database>(); // synchronous from then on
  /// ```
  ///
  /// It's created by [ready] (or by the first [findAsync]); a [find] before that is a
  /// [StateError]. [create] can find the dependencies registered before it with [findAsync].
  void putLazyAsync<S>(
    Future<S> Function() create, {
    String? tag,
    FutureOr<void> Function(S dependency)? onDispose,
  }) => _register<S>(
    tag,
    _Registration(
      DependencyKind.lazyAsync,
      type: S,
      create: create,
      onDispose: _typedDispose(onDispose),
    ),
  );

  /// Registers a factory: every [find] returns a new instance from [create]. They are never
  /// disposed by Winter (whoever finds one owns it).
  void putFactory<S>(S Function() create, {String? tag}) => _register<S>(
    tag,
    _Registration(DependencyKind.factory, type: S, create: create),
  );

  /// Registers a dependency with one instance per request, created by [create] the first time
  /// it's found in the request (like `@RequestScope` of Spring: a transaction, a unit of work).
  /// [onDispose] is called when the request ends (see `RequestScope.onComplete`).
  /// Finding it outside a request is a [StateError].
  void putScoped<S>(
    S Function() create, {
    String? tag,
    FutureOr<void> Function(S dependency)? onDispose,
  }) => _register<S>(
    tag,
    _Registration(
      DependencyKind.scoped,
      type: S,
      create: create,
      onDispose: _typedDispose(onDispose),
    ),
  );

  /// What is registered, in order of registration: the type, tag and kind of each dependency, and
  /// whether its instance was created. A snapshot, read-only:
  ///
  /// ```dart
  /// logger.info('Dependencies:\n${di.registrations.join('\n')}');
  /// // UserService (instance, created)
  /// // Database [main] (lazy, not created)
  /// ```
  List<DependencyRegistration> get registrations => List.unmodifiable([
    for (final MapEntry(key: (_, tag), value: registration)
        in _registrations.entries)
      DependencyRegistration._(
        type: registration.type,
        tag: tag,
        kind: registration.kind,
        created: registration.hasValue,
      ),
  ]);

  /// Whether something (even `null`) is registered for [S] and [tag], here or in a [parent]
  bool isRegistered<S>({String? tag}) => _recipe(_key<S>(tag)) != null;

  /// The dependency of [S] and [tag] (from a [parent] if this container doesn't have it): a
  /// [StateError] if none is registered
  S find<S>({String? tag}) {
    final _Key key = _key<S>(tag);
    final _Registration registration =
        _lookup(key) ?? (throw _notFound('$S', tag));
    return _resolve(key, registration) as S;
  }

  /// The dependency of [S] and [tag], waiting for it if it's created asynchronously
  /// ([putLazyAsync]): the first call creates it, and the calls while it's being created share that
  /// creation. Any other dependency is found as with [find].
  Future<S> findAsync<S>({String? tag}) async {
    final _Key key = _key<S>(tag);
    final _Registration registration =
        _lookup(key) ?? (throw _notFound('$S', tag));
    if (registration.kind != DependencyKind.lazyAsync) {
      return _resolve(key, registration) as S;
    }
    return await _createAsync(key, registration) as S;
  }

  /// Creates every asynchronous dependency ([putLazyAsync]) not created yet, one after the other
  /// in order of registration (each one can use the ones before it). Those of a [parent] are
  /// created in this container. `Winter.start` calls it before opening the port; call it yourself
  /// before using [find] without a server (a test, a script).
  ///
  /// Every one is tried: each failure is logged with its stack trace, and then a [StateError]
  /// names all of them. One that fails stays registered and not created.
  Future<void> ready() async {
    final List<String> failures = [];
    for (final _Key key in _asyncKeys()) {
      final _Registration registration = _lookup(key)!;
      if (registration.hasValue) continue;
      try {
        await _createAsync(key, registration);
      } catch (error, stackTrace) {
        logger.error(
          'The dependency <${registration.name}> could not be created',
          error: error,
          stackTrace: stackTrace,
        );
        failures.add('<${registration.name}>: $error');
      }
    }
    if (failures.isNotEmpty) throw _notCreated(failures);
  }

  /// The keys of the asynchronous dependencies of this container and its parents, the oldest
  /// first, without the ones this container overrides with another kind
  List<_Key> _asyncKeys() => {
    ...?parent?._asyncKeys(),
    for (final MapEntry(:key, :value) in _registrations.entries)
      if (value.kind == DependencyKind.lazyAsync) key,
  }.where((key) => _recipe(key)?.kind == DependencyKind.lazyAsync).toList();

  /// The registration of [key] here, or the one of the closest [parent]
  _Registration? _recipe(_Key key) =>
      _registrations[key] ?? parent?._recipe(key);

  /// The registration that resolves [key] for a find. A lazy one of a [parent] is copied here
  /// (without its instance): its instance belongs to this container, and the parent never
  /// changes. An instance, a factory and a scoped one are used as they are (resolving them
  /// changes nothing in their registration).
  _Registration? _lookup(_Key key) {
    final _Registration? own = _registrations[key];
    if (own != null) return own;
    final _Registration? inherited = parent?._recipe(key);
    if (inherited == null ||
        (inherited.kind != DependencyKind.lazy &&
            inherited.kind != DependencyKind.lazyAsync)) {
      return inherited;
    }
    return _registrations[key] = _Registration(
      inherited.kind,
      type: inherited.type,
      create: inherited.create,
      onDispose: inherited.onDispose,
    );
  }

  /// The dependency of [S] and [tag], or `null` if none is registered
  /// (use [isRegistered] to tell it from a registered `null`)
  S? tryFind<S>({String? tag}) =>
      isRegistered<S>(tag: tag) ? find<S>(tag: tag) : null;

  /// Removes the dependency of [S] and [tag] (a [StateError] if none is registered here; the one of
  /// a [parent] stays) and returns its instance, if it was created (`null` for a lazy one never
  /// found, a factory or a scoped one). It's not disposed.
  S? delete<S>({String? tag}) {
    final _Registration registration =
        _registrations.remove(_key<S>(tag)) ?? (throw _notFound('$S', tag));
    return registration.hasValue ? registration.value as S : null;
  }

  /// Creates now every lazy singleton ([putLazy]) not created yet, in order of registration: call
  /// it after registering everything and before `Winter.start`, so a broken registration (a
  /// missing dependency, a cycle, a constructor that throws) stops the start-up instead of failing
  /// the first request that needs it. Optional: without it they are created by their first find.
  ///
  /// Factories and scoped dependencies are not created (they belong to a find or a request).
  /// Every lazy one is tried: each failure is logged with its stack trace, and then a [StateError]
  /// names all of them. One that fails stays registered and not created.
  void createAll() {
    final List<String> failures = [];
    for (final MapEntry<_Key, _Registration> entry
        in _registrations.entries.toList()) {
      final _Registration registration = entry.value;
      if (registration.kind != DependencyKind.lazy || registration.hasValue) {
        continue;
      }
      try {
        _resolve(entry.key, registration);
      } catch (error, stackTrace) {
        logger.error(
          'The dependency <${registration.name}> could not be created',
          error: error,
          stackTrace: stackTrace,
        );
        failures.add('<${registration.name}>: $error');
      }
    }
    if (failures.isNotEmpty) throw _notCreated(failures);
  }

  static StateError _notCreated(List<String> failures) => StateError(
    '${failures.length == 1 ? 'A dependency' : '${failures.length} dependencies'} '
    'could not be created:\n'
    '${failures.map((failure) => '- $failure').join('\n')}',
  );

  /// Calls the `onDispose` of every created dependency, in reverse order of registration, and
  /// removes all of them. An `onDispose` that fails is logged and the others still run.
  /// `Winter.shutdown()` calls it.
  Future<void> disposeAll() async {
    final registrations = _registrations.values.toList().reversed;
    _registrations.clear();
    for (final registration in registrations) {
      final onDispose = registration.onDispose;
      if (onDispose == null || !registration.hasValue) continue;
      await _dispose(registration.name, onDispose, registration.value);
    }
  }

  void _register<S>(String? tag, _Registration registration) {
    final _Key key = _key<S>(tag);
    _registrations
      ..remove(key)
      ..[key] = registration;
  }

  Object? _resolve(_Key key, _Registration registration) {
    switch (registration.kind) {
      case DependencyKind.instance:
        return registration.value;
      case DependencyKind.lazy:
        if (!registration.hasValue) {
          registration.value = _create(key, registration);
        }
        return registration.value;
      case DependencyKind.lazyAsync:
        if (registration.hasValue) return registration.value;
        throw StateError(
          'The dependency <${registration.name}> is created asynchronously and is not ready: '
          'await di.ready() (Winter.start does it) or di.findAsync<${registration.name}>() first',
        );
      case DependencyKind.factory:
        return _create(key, registration);
      case DependencyKind.scoped:
        // First: it's the real mistake also outside a request (createAll)
        _failOnCaptive(registration.name);
        final RequestScope scope =
            RequestScope.current ??
            (throw StateError(
              'The dependency <${registration.name}> is scoped to a request: find it inside one '
              '(or inside RequestScope.run)',
            ));
        if (scope.isCompleted) {
          throw StateError(
            'The dependency <${registration.name}> is scoped to a request that already ended '
            '(its instance is disposed): find it while the request is in progress',
          );
        }
        final instances = _scopedInstances[scope] ??= {};
        if (instances.containsKey(key)) return instances[key];
        final Object? instance = _create(key, registration);
        instances[key] = instance;
        final onDispose = registration.onDispose;
        if (onDispose != null) {
          scope.onComplete(
            () => _dispose(registration.name, onDispose, instance),
          );
        }
        return instance;
    }
  }

  /// A lazy singleton being created can't depend on a scoped dependency: it would keep the
  /// instance of the first request (disposed when that request ends) forever
  void _failOnCaptive(String scopedName) {
    final List<_Key> creatingAsync =
        (Zone.current[_asyncChainKey] as List<_Key>?) ?? const [];
    for (final creating in [...creatingAsync, ..._creating]) {
      final _Registration? lazy = _registrations[creating];
      if (lazy?.kind != DependencyKind.lazy &&
          lazy?.kind != DependencyKind.lazyAsync) {
        continue;
      }
      throw StateError(
        'The lazy singleton <${lazy!.name}> depends on <$scopedName>, which is scoped to a '
        'request: it would keep the instance of the first request (disposed when it ends) '
        'forever. Register <${lazy.name}> with putFactory or putScoped, or find '
        '<$scopedName> where it is used instead of when <${lazy.name}> is created',
      );
    }
  }

  /// Runs the function of [registration], failing on a cycle (`A → B → A`)
  Object? _create(_Key key, _Registration registration) {
    final int index = _creating.indexOf(key);
    if (index >= 0) {
      final cycle = [
        for (final creating in _creating.sublist(index))
          _registrations[creating]?.name ?? '$creating',
        registration.name,
      ];
      throw StateError('Circular dependency: ${cycle.join(' -> ')}');
    }
    _creating.add(key);
    try {
      return registration.create!();
    } finally {
      _creating.removeLast();
    }
  }

  /// The keys of the asynchronous dependencies being created in this chain of `await`s, in a
  /// [Zone]: a cycle (`A` awaits `B`, which awaits `A`) would otherwise wait forever
  static final Object _asyncChainKey = Object();

  /// Creates an asynchronous dependency once: the calls while it's being created share the same
  /// future, and a failed creation is tried again by the next call
  Future<Object?> _createAsync(_Key key, _Registration registration) {
    if (registration.hasValue) return Future.value(registration.value);
    final List<_Key> chain =
        (Zone.current[_asyncChainKey] as List<_Key>?) ?? const [];
    final int index = chain.indexOf(key);
    if (index >= 0) {
      final cycle = [
        for (final creating in chain.sublist(index))
          _registrations[creating]?.name ?? '$creating',
        registration.name,
      ];
      return Future.error(
        StateError('Circular dependency: ${cycle.join(' -> ')}'),
      );
    }
    final Future<Object?>? pending = registration.pending;
    if (pending != null) return pending;
    final Future<Object?> creation = runZoned(
      () async {
        try {
          final Object? value =
              await (registration.create!() as Future<Object?>);
          registration.value = value;
          return value;
        } finally {
          registration.pending = null;
        }
      },
      zoneValues: {
        _asyncChainKey: [...chain, key],
      },
    );
    registration.pending = creation;
    return creation;
  }

  static Future<void> _dispose(
    String name,
    FutureOr<void> Function(Object? value) onDispose,
    Object? value,
  ) async {
    try {
      await onDispose(value);
    } catch (error, stackTrace) {
      logger.error(
        'The onDispose of <$name> failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static FutureOr<void> Function(Object? value)? _typedDispose<S>(
    FutureOr<void> Function(S dependency)? onDispose,
  ) => onDispose == null ? null : (value) => onDispose(value as S);

  static StateError _notFound(String type, String? tag) => StateError(
    'Dependency of <$type> (with tag: ${tag ?? 'empty'}) not found. Register it with '
    'di.put<$type>(...): a dependency is found by the exact type it was registered with, '
    'not by a supertype or an interface it implements',
  );

  /// `T` and `T?` are the same key, so a dependency registered from a nullable variable
  /// (`di.put(maybeService)`, registered as `<Service?>`) is found as `<Service>` too.
  /// The [Type] itself is used (not its name), so two classes with the same name in different
  /// libraries don't collide.
  static _Key _key<S>(String? tag) => (_typeOf<S?>(), tag);
}

Type _typeOf<T>() => T;

typedef _Key = (Type type, String? tag);

/// How a dependency was registered, which decides how many instances it has
///
/// {@category Dependency injection}
enum DependencyKind {
  /// `put`: the instance given
  instance,

  /// `putLazy`: one instance, created by the first find
  lazy,

  /// `putLazyAsync`: one instance, created asynchronously by `ready` (or the first `findAsync`)
  lazyAsync,

  /// `putFactory`: a new instance by every find
  factory,

  /// `putScoped`: one instance per request
  scoped,
}

/// A registration of a [DependencyInjection], as [DependencyInjection.registrations] lists it
///
/// {@category Dependency injection}
final class DependencyRegistration {
  /// The type it was registered with (`di.put<UserRepository>(...)`: `UserRepository`)
  final Type type;

  /// Its tag, or null
  final String? tag;

  /// How it was registered
  final DependencyKind kind;

  /// Whether its single instance exists: always for an [DependencyKind.instance], after the first
  /// find for a [DependencyKind.lazy] one; never for a factory or a scoped one (they have one per
  /// find, or per request)
  final bool created;

  const DependencyRegistration._({
    required this.type,
    required this.tag,
    required this.kind,
    required this.created,
  });

  @override
  String toString() {
    final String state = switch (kind) {
      DependencyKind.instance ||
      DependencyKind.lazy ||
      DependencyKind.lazyAsync => created ? ', created' : ', not created',
      DependencyKind.factory || DependencyKind.scoped => '',
    };
    return '$type${tag == null ? '' : ' [$tag]'} (${kind.name}$state)';
  }
}

class _Registration {
  final DependencyKind kind;

  /// The type as it was registered
  final Type type;
  final Object? Function()? create;
  final FutureOr<void> Function(Object? value)? onDispose;

  Object? _value;
  bool hasValue = false;

  /// The creation in progress of an asynchronous one
  Future<Object?>? pending;

  _Registration(this.kind, {required this.type, this.create, this.onDispose});

  /// The type as it was registered, for the messages
  String get name => '$type';

  Object? get value => _value;

  set value(Object? value) {
    _value = value;
    hasValue = true;
  }
}

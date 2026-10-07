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
/// `Winter.context`).
class DependencyInjection {
  /// In order of registration (a registration again moves to the end)
  final Map<_Key, _Registration> _registrations = {};

  /// The keys being created right now, to find cycles between lazy ones (`A → B → A`)
  final List<_Key> _creating = [];

  /// The instances of the scoped dependencies of each request
  final Expando<Map<_Key, Object?>> _scopedInstances = Expando();

  /// Registers [dependency] (replacing what was registered with the same type and tag).
  /// [onDispose] is called by [disposeAll] (and so by `Winter.shutdown()`).
  void put<S>(
    S dependency, {
    String? tag,
    FutureOr<void> Function(S dependency)? onDispose,
  }) => _register<S>(
    tag,
    _Registration(
      _Kind.instance,
      name: '$S',
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
      _Kind.lazy,
      name: '$S',
      create: create,
      onDispose: _typedDispose(onDispose),
    ),
  );

  /// Registers a factory: every [find] returns a new instance from [create]. They are never
  /// disposed by Winter (whoever finds one owns it).
  void putFactory<S>(S Function() create, {String? tag}) => _register<S>(
    tag,
    _Registration(_Kind.factory, name: '$S', create: create),
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
      _Kind.scoped,
      name: '$S',
      create: create,
      onDispose: _typedDispose(onDispose),
    ),
  );

  /// Whether something (even `null`) is registered for [S] and [tag]
  bool isRegistered<S>({String? tag}) =>
      _registrations.containsKey(_key<S>(tag));

  /// The dependency of [S] and [tag]: a [StateError] if none is registered
  S find<S>({String? tag}) {
    final _Key key = _key<S>(tag);
    final _Registration registration =
        _registrations[key] ?? (throw _notFound('$S', tag));
    return _resolve(key, registration) as S;
  }

  /// The dependency of [S] and [tag], or `null` if none is registered
  /// (use [isRegistered] to tell it from a registered `null`)
  S? tryFind<S>({String? tag}) =>
      isRegistered<S>(tag: tag) ? find<S>(tag: tag) : null;

  /// Removes the dependency of [S] and [tag] (a [StateError] if none is registered) and returns its
  /// instance, if it was created (`null` for a lazy one never found, a factory or a scoped one).
  /// It's not disposed.
  S? delete<S>({String? tag}) {
    final _Registration registration =
        _registrations.remove(_key<S>(tag)) ?? (throw _notFound('$S', tag));
    return registration.hasValue ? registration.value as S : null;
  }

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
      case _Kind.instance:
        return registration.value;
      case _Kind.lazy:
        if (!registration.hasValue) {
          registration.value = _create(key, registration);
        }
        return registration.value;
      case _Kind.factory:
        return _create(key, registration);
      case _Kind.scoped:
        final RequestScope scope =
            RequestScope.current ??
            (throw StateError(
              'The dependency <${registration.name}> is scoped to a request: find it inside one '
              '(or inside RequestScope.run)',
            ));
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

enum _Kind { instance, lazy, factory, scoped }

class _Registration {
  final _Kind kind;

  /// The type as it was registered, for the messages
  final String name;
  final Object? Function()? create;
  final FutureOr<void> Function(Object? value)? onDispose;

  Object? _value;
  bool hasValue = false;

  _Registration(this.kind, {required this.name, this.create, this.onDispose});

  Object? get value => _value;

  set value(Object? value) {
    _value = value;
    hasValue = true;
  }
}

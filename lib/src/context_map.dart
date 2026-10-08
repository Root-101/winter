/// The key of a value in a [ContextMap], with the type of the value.
///
/// Every key is a different object (there is no `const` constructor), so two packages that both
/// use `'user'` as a name never overwrite each other.
///
/// {@category Requests and responses}
final class ContextKey<T> {
  /// A name for messages and `toString`; it doesn't identify the key
  final String name;

  /// A new key, different from every other one, with [name] for messages
  ContextKey(this.name);

  @override
  String toString() => 'ContextKey<$T>($name)';
}

/// Data attached to a request or a response by the framework and by the app, found by a typed
/// [ContextKey]. The way to extend a request: a key and an extension, like the security context
/// of Winter:
///
/// ```dart
/// final _tenant = ContextKey<Tenant>('tenant');
///
/// extension TenantX on RequestEntity {
///   Tenant? get tenant => context.get(_tenant);
///   set tenant(Tenant? value) => context.set(_tenant, value);
/// }
/// ```
///
/// A copy of a request or a response (`copyWith`) starts with the same values.
///
/// {@category Requests and responses}
final class ContextMap {
  final Map<ContextKey<Object?>, Object?> _values;

  /// An empty context
  ContextMap() : _values = {};

  /// A context with the values of [other]; changing one doesn't change the other
  ContextMap.from(ContextMap other) : _values = Map.of(other._values);

  /// The value of [key], or null
  T? get<T>(ContextKey<T> key) => _values[key] as T?;

  /// Sets the value of [key]; `null` removes it
  void set<T>(ContextKey<T> key, T? value) {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  /// The value of [key], created with [create] the first time
  T putIfAbsent<T>(ContextKey<T> key, T Function() create) =>
      _values.putIfAbsent(key, create) as T;

  /// Whether [key] has a value
  bool contains(ContextKey<Object?> key) => _values.containsKey(key);

  /// The keys with a value
  Iterable<ContextKey<Object?>> get keys => _values.keys;

  @override
  String toString() => 'ContextMap$_values';
}

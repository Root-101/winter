class DependencyInjection {
  StateError notFound(Type S, String? tag) => StateError(
    'Dependency of <${S.toString()}> (with tag: ${tag ?? 'empty'}) not found',
  );

  ///Every instance has its own dependencies,
  ///the global one is accessible with `di` (from the current `Winter.context`)
  final Map<_DependencyKey, dynamic> _singl = {};

  void put<S>(S dependency, {String? tag}) {
    final key = _getKey(S, tag);

    _singl[key] = dependency;
  }

  S find<S>({String? tag}) {
    final key = _getKey(S, tag);

    if (_singl[key] != null) {
      return _singl[key] as S;
    } else {
      throw notFound(S, tag);
    }
  }

  S? tryFind<S>({String? tag}) {
    final key = _getKey(S, tag);

    if (_singl[key] != null) {
      return _singl[key] as S;
    } else {
      return null;
    }
  }

  S delete<S>({String? tag}) {
    final key = _getKey(S, tag);

    if (_singl[key] != null) {
      S dependency = _singl[key] as S;
      _singl.remove(key);
      return dependency;
    } else {
      throw notFound(S, tag);
    }
  }

  /// Generates the key based on [type] (and optionally a [tag])
  /// to register an Instance in the hashmap.
  /// The [Type] itself is used (not its name), so two classes with the same name
  /// in different libraries don't collide.
  _DependencyKey _getKey(Type type, String? tag) => (type, tag);
}

typedef _DependencyKey = (Type type, String? tag);

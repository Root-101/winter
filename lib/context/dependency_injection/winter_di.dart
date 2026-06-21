class DependencyInjection {
  StateError notFound(Type S, String? tag) => StateError(
    'Dependency of <${S.toString()}> (with tag: ${tag ?? 'empty'}) not found',
  );

  static final Map<String, dynamic> _singl = {};

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
  String _getKey(Type type, String? tag) {
    return tag == null ? type.toString() : '${type.toString()}-$tag';
  }
}

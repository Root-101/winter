abstract class DependencyInjection {
  static final _WinterDIImpl _diImpl = _WinterDIImpl(); //singleton instance

  static DependencyInjection get instance => _diImpl;

  S put<S>(S dependency, {String? tag});

  S find<S>({String? tag});

  S delete<S>({String? tag});
}

class _WinterDIImpl extends DependencyInjection {
  StateError notFound(Type S, String? tag) => StateError(
        'Dependency of <${S.toString()}> (with tag: ${tag ?? 'empty'}) not found',
      );

  static final _WinterDIImpl _singleton = _WinterDIImpl._internal();

  _WinterDIImpl._internal();

  factory _WinterDIImpl() {
    return _singleton;
  }

  static final Map<String, dynamic> _singl = {};

  @override
  S put<S>(S dependency, {String? tag}) {
    final key = _getKey(S, tag);

    _singl[key] = dependency;

    return find<S>(tag: tag);
  }

  @override
  S find<S>({String? tag}) {
    final key = _getKey(S, tag);

    if (_singl[key] != null) {
      return _singl[key] as S;
    } else {
      throw notFound(S, tag);
    }
  }

  @override
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

  /// Generates the key based on [type] (and optionally a [name])
  /// to register an Instance Builder in the hashmap.
  String _getKey(Type type, String? name) {
    return name == null ? type.toString() : type.toString() + name;
  }
}

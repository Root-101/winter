import 'dart:mirrors';

abstract class DependencyInjection {
  static DependencyInjection build() => _DependencyInjectionImpl();

  void put(dynamic dependency, {String? tag});

  S find<S>({String? tag});

  ///NOTE: this could return null if the element is not found
  dynamic findByType(Type type, {String? tag});

  S delete<S>({String? tag});
}

class _DependencyInjectionImpl extends DependencyInjection {
  StateError notFound(Type S, String? tag) => StateError(
        'Dependency of <${S.toString()}> (with tag: ${tag ?? 'empty'}) not found',
      );

  static final Map<String, dynamic> _singl = {};

  @override
  void put(dynamic dependency, {String? tag}) {
    Type type = reflect(dependency).type.reflectedType;

    final key = _getKey(type, tag);

    _singl[key] = dependency;
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
  dynamic findByType(Type type, {String? tag}) {
    final key = _getKey(type, tag);

    if (_singl[key] != null) {
      return _singl[key];
    } else {
      return null;
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

  /// Generates the key based on [type] (and optionally a [tag])
  /// to register an Instance Builder in the hashmap.
  String _getKey(Type type, String? tag) {
    return tag == null ? type.toString() : '${type.toString()}-$tag';
  }
}

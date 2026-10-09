import 'dart:collection';
import 'dart:io' show HttpHeaders;

import 'package:http_parser/http_parser.dart' show CaseInsensitiveMap;

/// The headers of a request or a response, every value of each one: case insensitive and
/// unmodifiable. [headers] maps a name to a `String` or a `List<String>` (several values, like
/// `Set-Cookie`).
///
/// {@category HTTP}
Map<String, List<String>> headersAllOf(Map<String, Object?>? headers) =>
    mergeHeaders(const {}, headers);

/// The headers of a request of `dart:io`, read without copying them (they are already case
/// insensitive)
///
/// {@category HTTP}
Map<String, List<String>> ioHeaders(HttpHeaders headers) => _IoHeaders(headers);

/// [current] with [changes] on top: a value replaces the one of the same name (any case), and
/// `null` removes it
///
/// {@category HTTP}
Map<String, List<String>> mergeHeaders(
  Map<String, List<String>> current,
  Map<String, Object?>? changes,
) {
  if (changes == null || changes.isEmpty) {
    return current is _Unmodifiable || current is _IoHeaders
        ? current
        : _Unmodifiable.copy(current);
  }
  final CaseInsensitiveMap<List<String>> merged = CaseInsensitiveMap.from(
    current,
  );
  for (final MapEntry(:key, :value) in changes.entries) {
    if (value == null) {
      merged.remove(key);
    } else {
      merged[key] = List.unmodifiable(_values(key, value));
    }
  }
  return _Unmodifiable(merged);
}

/// One value per header (several are joined with `, `): a view of [headersAll], case insensitive
/// and unmodifiable
///
/// {@category HTTP}
Map<String, String> joinHeaders(Map<String, List<String>> headersAll) =>
    _Joined(headersAll);

List<String> _values(String name, Object value) => switch (value) {
  final String single => [single],
  final Iterable<Object?> many => [for (final item in many) '$item'],
  _ => throw ArgumentError.value(
    value,
    name,
    'A header is a String or a List<String>',
  ),
};

/// A case insensitive map of headers that can't be changed
class _Unmodifiable extends UnmodifiableMapView<String, List<String>> {
  _Unmodifiable(CaseInsensitiveMap<List<String>> super.map);

  _Unmodifiable.copy(Map<String, List<String>> headers)
    : super(CaseInsensitiveMap.from(headers));
}

/// The headers of `dart:io`, as a map
class _IoHeaders extends UnmodifiableMapBase<String, List<String>> {
  final HttpHeaders _headers;

  _IoHeaders(this._headers);

  @override
  List<String>? operator [](Object? key) =>
      key is String ? _headers[key] : null;

  @override
  bool containsKey(Object? key) => key is String && _headers[key] != null;

  @override
  Iterable<String> get keys {
    final List<String> names = [];
    _headers.forEach((name, _) => names.add(name));
    return names;
  }
}

/// One value per header, read from the list of every value
class _Joined extends UnmodifiableMapBase<String, String> {
  final Map<String, List<String>> _all;

  _Joined(this._all);

  @override
  String? operator [](Object? key) {
    final List<String>? values = _all[key];
    if (values == null) return null;
    return values.length == 1 ? values.first : values.join(', ');
  }

  @override
  bool containsKey(Object? key) => _all.containsKey(key);

  @override
  Iterable<String> get keys => _all.keys;

  @override
  int get length => _all.length;
}

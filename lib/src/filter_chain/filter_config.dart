import 'package:winter/winter.dart';

import 'package:collection/collection.dart';

/// The filters of a route (or the global ones). Immutable: combine them with [merge].
///
/// {@category Filters}
class FilterConfig {
  final List<Filter> _filters;

  /// The configuration of these filters
  const FilterConfig(this._filters);

  /// The filters, read-only
  List<Filter> get filters => UnmodifiableListView(_filters);

  /// A new config with these filters followed by the ones of [other]
  FilterConfig merge(FilterConfig? other) {
    return FilterConfig([..._filters, ...?other?._filters]);
  }

  @override
  String toString() {
    if (filters.isEmpty) return '[]';
    return filters.map((f) => ' - $f').join('\n');
  }
}

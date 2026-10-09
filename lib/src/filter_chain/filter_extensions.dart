import 'package:winter/winter.dart';

/// A filter as the [FilterConfig] of a route: `filterConfig: LoggingFilter().toFilterConfig()`
///
/// {@category Filters}
extension FilterConfigFromFilter on Filter {
  /// A [FilterConfig] with only this filter
  FilterConfig toFilterConfig() => FilterConfig([this]);
}

/// A list of filters as a [FilterConfig]: `[AuthFilter(), LoggingFilter()].toFilterConfig()`
///
/// {@category Filters}
extension FilterConfigFromListFilter on List<Filter> {
  /// A [FilterConfig] with these filters
  FilterConfig toFilterConfig() => FilterConfig(this);
}

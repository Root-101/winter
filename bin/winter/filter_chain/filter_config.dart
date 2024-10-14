import 'filter.dart';

class FilterConfig {
  final List<Filter> filters;

  const FilterConfig(this.filters);

  FilterConfig merge(FilterConfig? other) {
    return FilterConfig([...filters, ...(other?.filters ?? [])]);
  }

  void add(Filter filter) {
    filters.add(filter);
  }
  
  @override
  String toString() {
    return '$filters';
  }
}

import 'package:winter/winter.dart';

extension FilterConfigFromFilter on Filter {
  FilterConfig toFilterConfig() => FilterConfig([this]);
}

extension FilterConfigFromListFilter on List<Filter> {
  FilterConfig toFilterConfig() => FilterConfig(this);
}

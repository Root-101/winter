import 'package:winter/winter.dart';

extension AuthFilterFromRuleBuilder on RuleBuilder {
  AuthFilter toFilter({bool authenticated = true}) =>
      AuthFilter(authenticated: authenticated, rules: this);
}

extension FilterConfigFromRuleBuilder on RuleBuilder {
  FilterConfig toFilterConfig({bool authenticated = true}) =>
      FilterConfig([toFilter(authenticated: authenticated)]);
}

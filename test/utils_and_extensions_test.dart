import 'dart:async';

import 'package:test/test.dart';
import 'package:winter/src/utils/console_style.dart';
import 'package:winter/winter.dart';

class _NoopFilter extends Filter {
  @override
  FutureOr<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) =>
      chain.doFilter(request);

  @override
  String toString() => 'NoopFilter';
}

void main() {
  group('Filter extensions', () {
    test('a filter & a list of filters to FilterConfig', () {
      final filter = _NoopFilter();

      expect(filter.toFilterConfig().filters, [filter]);
      expect([filter, filter].toFilterConfig().filters, hasLength(2));
    });

    test('FilterConfig.toString lists the filters', () {
      expect(const FilterConfig([]).toString(), '[]');
      expect(FilterConfig([_NoopFilter()]).toString(), ' - NoopFilter');
    });

    test('FilterConfig.merge keeps the order', () {
      final first = _NoopFilter();
      final second = _NoopFilter();

      final merged = FilterConfig([first]).merge(FilterConfig([second]));

      expect(merged.filters, [first, second]);
      expect(FilterConfig([first]).merge(null).filters, [first]);
    });
  });

  group('Security extensions', () {
    test('a rule to an AuthFilter / FilterConfig', () {
      final rule = hasRole('admin');

      final filter = rule.toFilter(authenticated: false);
      expect(filter.rules, same(rule));
      expect(filter.authenticated, isFalse);

      final config = rule.toFilterConfig();
      expect((config.filters.single as AuthFilter).authenticated, isTrue);
    });
  });

  group('Console style', () {
    test('stylize adds the ANSI codes', () {
      expect('text'.stylize(), 'text');
      expect('text'.stylize(bold: true), '\x1B[1mtext\x1B[0m');
      expect(
        'text'.stylize(bold: true, color: ConsoleColor.red),
        '\x1B[1;31mtext\x1B[0m',
      );
      expect('text'.stylize(color: ConsoleColor.green), '\x1B[32mtext\x1B[0m');
    });
  });
}

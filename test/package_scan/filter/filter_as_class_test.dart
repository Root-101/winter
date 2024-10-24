@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

@GlobalFilter()
class TestFilter2 implements Filter {
  const TestFilter2();

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    return await chain.doFilter(
      request,
    );
  }
}

void main() {
  //TODO: add test for fails (class that dont extends Filter...)
  test('@GlobalFilter on class', () async {
    PackageScanner scanner = PackageScanner();
    FilterConfig config = const FilterConfig([
      TestFilter2(),
    ]);

    expect(scanner.filterConfig.filters.length, config.filters.length);
    for (int i = 0; i < config.filters.length; i++) {
      expect(
        scanner.filterConfig.filters[i].runtimeType,
        config.filters[i].runtimeType,
      );
    }
  });
}

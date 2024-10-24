@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';

import '../../../bin/winter.dart';

@GlobalFilter()
FutureOr<ResponseEntity> testFilter(
  RequestEntity request,
  FilterChain chain,
) async {
  return await chain.doFilter(request);
}

void main() {
  //TODO: add test for fails (method with different signature, not returning response-entity...)
  test('@GlobalFilter on method', () async {
    PackageScanner scanner = PackageScanner();
    FilterConfig config = const FilterConfig([
      FunctionAsFilter(functionFilter: testFilter),
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

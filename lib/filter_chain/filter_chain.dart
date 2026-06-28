import 'dart:async';

import 'package:winter/winter.dart';

class FilterChain {
  int _currentFilterIndex = 0;
  final List<Filter> _filters;

  FilterChain(List<Filter> filters, RequestHandler requestHandler)
    : _filters = List.of([...filters, _RequestHandlerFilter(requestHandler)]);

  FutureOr<ResponseEntity> doFilter(RequestEntity request) async {
    if (_currentFilterIndex < _filters.length) {
      final filter = _filters[_currentFilterIndex];
      _currentFilterIndex++;

      if (filter.shouldFilter(request)) {
        return await filter.doFilter(request, this);
      } else {
        return await doFilter(request);
      }
    } else {
      return ResponseEntity.internalServerError(
        body: 'Filter chain ended without a response',
      );
    }
  }
}

abstract class Filter {
  FutureOr<ResponseEntity> doFilter(RequestEntity request, FilterChain chain);

  bool shouldFilter(RequestEntity request) {
    return true;
  }
}

class _RequestHandlerFilter extends Filter {
  final RequestHandler _handler;

  _RequestHandlerFilter(this._handler);

  @override
  FutureOr<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    return await _handler(request);
  }
}

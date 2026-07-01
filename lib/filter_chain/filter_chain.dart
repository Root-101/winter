import 'dart:async';

import 'package:winter/winter.dart';

class FilterChain {
  final int _currentFilterIndex;
  final List<Filter> _filters;

  FilterChain(List<Filter> filters, RequestHandler requestHandler)
    : _currentFilterIndex = 0,
      _filters = List.unmodifiable([
        ...List.of(filters)..sort((a, b) => a.order.compareTo(b.order)),
        _RequestHandlerFilter(requestHandler),
      ]);

  FilterChain._(this._filters, this._currentFilterIndex);

  FutureOr<ResponseEntity> doFilter(RequestEntity request) async {
    if (_currentFilterIndex < _filters.length) {
      final filter = _filters[_currentFilterIndex];
      final nextChain = FilterChain._(_filters, _currentFilterIndex + 1);

      if (filter.shouldFilter(request)) {
        return await filter.doFilter(request, nextChain);
      } else {
        return await nextChain.doFilter(request);
      }
    } else {
      return ResponseEntity.internalServerError(
        body: 'Filter chain ended without a response',
      );
    }
  }
}

abstract class Filter {
  final int order;

  Filter({this.order = 0});

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

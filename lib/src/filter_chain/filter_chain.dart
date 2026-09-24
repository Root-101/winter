import 'dart:async';

import 'package:collection/collection.dart';
import 'package:winter/winter.dart';

class FilterChain {
  final int _currentFilterIndex;
  final List<Filter> _filters;

  ///If provided, any [Exception] thrown by a filter or by the handler is converted
  ///into a response right where it happens, so every outer filter receives a
  ///response instead of the exception.
  ///If null, the exception is propagated to the caller.
  final ExceptionHandler? _exceptionHandler;

  FilterChain(
    List<Filter> filters,
    RequestHandler requestHandler, {
    this._exceptionHandler,
  }) : _currentFilterIndex = 0,
       _filters = List.unmodifiable([
         ..._sortByOrder(filters),
         _RequestHandlerFilter(requestHandler),
       ]);

  FilterChain._(
    this._filters,
    this._currentFilterIndex,
    this._exceptionHandler,
  );

  FutureOr<ResponseEntity> doFilter(RequestEntity request) async {
    if (_currentFilterIndex < _filters.length) {
      final filter = _filters[_currentFilterIndex];
      final nextChain = FilterChain._(
        _filters,
        _currentFilterIndex + 1,
        _exceptionHandler,
      );

      try {
        if (filter.shouldFilter(request)) {
          return await filter.doFilter(request, nextChain);
        } else {
          return await nextChain.doFilter(request);
        }
      } on Exception catch (error, stackTrace) {
        final exceptionHandler = _exceptionHandler;
        if (exceptionHandler == null) rethrow;
        return await exceptionHandler(request, error, stackTrace);
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

///Stable sort (List.sort is not guaranteed to be stable): filters with the same order
///keep their declaration order (global filters first, then the route filters)
List<Filter> _sortByOrder(List<Filter> filters) {
  final sorted = List.of(filters);
  mergeSort(sorted, compare: (a, b) => a.order.compareTo(b.order));
  return sorted;
}

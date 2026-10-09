import 'dart:async';

import 'package:collection/collection.dart';
import 'package:winter/winter.dart';

/// The filters of a request, in order, ending in its handler. A [Filter] continues it with
/// [doFilter]; the server builds one per request (global filters, then those of the route).
///
/// {@category Filters}
class FilterChain {
  final int _currentFilterIndex;
  final List<Filter> _filters;

  ///If provided, anything thrown by a filter or by the handler ([Exception]s and [Error]s) is
  ///converted into a response right where it happens, so every outer filter (CORS, logs...)
  ///receives a response instead of the error.
  ///If null, the error is propagated to the caller.
  final ExceptionHandler? _exceptionHandler;

  /// A chain of [filters], sorted by [Filter.order] (stable), that ends in [requestHandler]
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

  /// Runs the rest of the chain with [request] (a filter may pass a copy, `request.copyWith`)
  /// and returns its response. With an exception handler, an error is already a response here.
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
      } catch (error, stackTrace) {
        final exceptionHandler = _exceptionHandler;
        if (exceptionHandler == null) rethrow;
        return await exceptionHandler(request, error, stackTrace);
      }
    } else {
      // The last link is always the handler, which never calls the chain
      throw StateError('The filter chain ended without a response');
    }
  }
}

/// Code that runs around the handler of a request: authentication, logs, CORS, limits...
///
/// ```dart
/// class TimingFilter extends Filter {
///   @override
///   Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) async {
///     final watch = Stopwatch()..start();
///     final response = await chain.doFilter(request); // the rest of the chain
///     return response.copyWith(headers: {'Server-Timing': 'app;dur=${watch.elapsedMilliseconds}'});
///   }
/// }
/// ```
///
/// Return a response without calling `chain.doFilter` to stop the request there. An error
/// thrown inside the chain reaches a filter as a response, never as an exception.
///
/// {@category Filters}
abstract class Filter {
  /// Where the filter runs: lower first (CORS is -100, the security headers -99, the default 0)
  final int order;

  /// A filter at [order]
  Filter({this.order = 0});

  /// Handles [request]: call `chain.doFilter` to go on, or return a response to stop
  FutureOr<ResponseEntity> doFilter(RequestEntity request, FilterChain chain);

  /// Whether this filter runs for [request] (true by default); when it's false the request
  /// goes straight to the next one
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

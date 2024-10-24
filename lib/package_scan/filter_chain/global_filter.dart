import 'dart:async';

import '../../winter.dart';

class GlobalFilter extends ScanComponent {
  const GlobalFilter({super.order});
}

typedef FunctionFilter = FutureOr<ResponseEntity> Function(
  RequestEntity request,
  FilterChain chain,
);

class FunctionAsFilter implements Filter {
  final FunctionFilter functionFilter;

  const FunctionAsFilter({
    required this.functionFilter,
  });

  @override
  FutureOr<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    return await functionFilter(request, chain);
  }
}

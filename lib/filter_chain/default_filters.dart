import 'dart:async';
import 'dart:io';

import 'package:winter/winter.dart';

void defaultLogRequest(RequestEntity request) {
  stdout.writeln('REQUEST: Method: ${request.method} => URL: ${request.url}');
}

void defaultLogResponse(ResponseEntity response) {
  stdout.writeln(
    'RESPONSE: Status code: ${response.statusCode} => Body: ${response.body()?.toString()}',
  );
}

void defaultLogErrorResponse(Exception exception) {
  stdout.writeln('ERROR in RESPONSE: ${exception.toString()}');
}

class LogsFilter extends Filter {
  final void Function(RequestEntity request) logRequest;
  final void Function(ResponseEntity response) logResponse;
  final void Function(Exception exception) logErrorResponse;

  LogsFilter({
    void Function(RequestEntity request)? logRequest,
    void Function(ResponseEntity response)? logResponse,
    void Function(Exception exception)? logErrorResponse,
  }) : logRequest = logRequest ?? defaultLogRequest,
       logResponse = logResponse ?? defaultLogResponse,
       logErrorResponse = logErrorResponse ?? defaultLogErrorResponse;

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    logRequest(request);

    try {
      ResponseEntity response = await chain.doFilter(request);
      logResponse(response);
      return response;
    } on Exception catch (exception) {
      logErrorResponse(exception);
      rethrow;
    }
  }
}

void defaultLogRateLimiter(dynamic request, dynamic requestId) {
  stdout.writeln(
    'Rate limiter fail for id: $requestId in request: ${request.url}',
  );
}

class RateLimiterFilter extends Filter {
  final RateLimiter rateLimiter;
  final FutureOr<String> Function(RequestEntity request) onRequest;
  final void Function(RequestEntity request, String requestId)? log;

  RateLimiterFilter({
    required this.onRequest,
    required this.rateLimiter,
    this.log = defaultLogRateLimiter,
  });

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    String requestId = await onRequest(request);
    if (rateLimiter.allowRequest(requestId)) {
      return await chain.doFilter(request);
    } else {
      if (log != null) {
        log!(request, requestId);
      }
      return ResponseEntity.tooManyRequests(
        retryAfter: rateLimiter.window.inSeconds,
      );
    }
  }
}

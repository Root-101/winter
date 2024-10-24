import 'dart:async';

import 'request_entity.dart';
import 'response_entity.dart';

/// A function which handles a [RequestEntity].
///
/// For example a static file handler may read the requested URI from the
/// filesystem and return it as the body of the [Response].
///
/// A [RequestHandler] which wraps one or more other handlers to perform pre or post
/// processing is known as a "middleware".
///
/// A [RequestHandler] may receive a request directly from an HTTP server or it
/// may have been touched by other middleware. Similarly the response may be
/// directly returned by an HTTP server or have further processing done by other
/// middleware.
typedef RequestHandler = FutureOr<ResponseEntity> Function(
  RequestEntity request,
);

///ExceptionHandler
typedef ExcHandler = FutureOr<ResponseEntity> Function(
  RequestEntity request,
  Exception error,
  StackTrace stackTrac,
);

import 'package:winter/winter.dart';

abstract class ExceptionHandler {
  Future<ResponseEntity> call(
    RequestEntity request,
    Exception exception,
    StackTrace stackTrace,
  );
}

/// Log an unexpected error (the ones that end in a 500) with its stack trace.
/// The details are only logged, never sent to the client.
void defaultLogUnhandledError(
  RequestEntity request,
  Object error,
  StackTrace stackTrace,
) {
  logger.error(
    'Unhandled error in ${request.method} ${request.requestedUri.path}',
    error: error,
    stackTrace: stackTrace,
  );
}

/// Generic body for a 500, without any internal detail of the error
ResponseEntity internalServerErrorResponse() =>
    ResponseEntity.internalServerError(
      body: StatusCode.internalServerError.reasonPhrase,
    );

class SimpleExceptionHandler extends ExceptionHandler {
  final void Function(
    RequestEntity request,
    Object error,
    StackTrace stackTrace,
  )
  logUnhandledError;

  SimpleExceptionHandler({this.logUnhandledError = defaultLogUnhandledError});

  @override
  Future<ResponseEntity> call(
    RequestEntity request,
    Exception exception,
    StackTrace stackTrace,
  ) async {
    if (exception is DeserializationException) {
      ///The client sent a body that can't be parsed: 400 with the reason
      return ResponseEntity.badRequest(body: exception.message);
    } else if (exception is ResponseException) {
      return exception.responseEntity;
    } else if (exception is ValidationException) {
      ///The messages are in the language of the request, so caches must vary on it
      ///(only if the app answers in more than one language)
      final bool translated = Winter.context.localeConfig.supported.length > 1;
      return ResponseEntity(
        exception.statusCode,
        body: om.serialize(exception.violations),
        headers: {
          ...?exception.headers,
          if (translated) HttpHeader.vary: HttpHeader.acceptLanguage,
        },
      );
    } else if (exception is ApiException) {
      return ResponseEntity(
        exception.statusCode,
        body: exception.body,
        headers: exception.headers,
      );
    }

    ///Any other exception (including a failed serialization of a response) is a server error:
    ///log it and don't expose its details
    logUnhandledError(request, exception, stackTrace);
    return internalServerErrorResponse();
  }
}

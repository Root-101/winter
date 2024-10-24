import 'package:winter/winter.dart';

abstract class ExceptionHandler {
  Future<ResponseEntity> call(
    RequestEntity request,
    Exception exception,
    StackTrace stackTrace,
  );
}

class SimpleExceptionHandler extends ExceptionHandler {
  @override
  Future<ResponseEntity> call(
    RequestEntity request,
    Exception exception,
    StackTrace stackTrace,
  ) async {
    if (exception is ResponseException) {
      return exception.responseEntity;
    } else if (exception is ValidationException) {
      return ResponseEntity(
        exception.statusCode,
        body: om.serialize(exception.violations),
      );
    } else if (exception is ApiException) {
      return ResponseEntity(
        exception.statusCode,
        body: exception.body,
        headers: exception.headers,
      );
    }
    return ResponseEntity.internalServerError(body: exception.toString());
  }
}

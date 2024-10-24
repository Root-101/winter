import '../../winter.dart';

///Special exception to break up any current flow and return this instead
class ResponseException implements Exception {
  ResponseEntity responseEntity;

  ResponseException(this.responseEntity);
}

///Base exception
class ApiException implements Exception {
  final int statusCode;
  final Object? body;
  final Map<String, Object>? headers;

  ApiException({
    required this.statusCode,
    this.body,
    this.headers,
  });
}

/// exception for 400
class BadRequestException extends ApiException {
  static final HttpStatus status = HttpStatus.BAD_REQUEST;

  BadRequestException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// exception for 401
class ForbiddenException extends ApiException {
  static final HttpStatus status = HttpStatus.UNAUTHORIZED;

  ForbiddenException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// exception for 402
class PaymentRequiredException extends ApiException {
  static final HttpStatus status = HttpStatus.PAYMENT_REQUIRED;

  PaymentRequiredException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// exception for 403
class UnauthorizedException extends ApiException {
  static final HttpStatus status = HttpStatus.FORBIDDEN;

  UnauthorizedException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// exception for 404
class NotFoundException extends ApiException {
  static final HttpStatus status = HttpStatus.NOT_FOUND;

  NotFoundException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// exception for 409
class ConflictException extends ApiException {
  static final HttpStatus status = HttpStatus.CONFLICT;

  ConflictException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// exception for 500
class InternalServerErrorException extends ApiException {
  static final HttpStatus status = HttpStatus.INTERNAL_SERVER_ERROR;

  InternalServerErrorException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// Validation exception 422
class UnprocessableEntityException extends ApiException {
  static final HttpStatus status = HttpStatus.UNPROCESSABLE_ENTITY;

  UnprocessableEntityException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

class ValidationException extends UnprocessableEntityException {
  final List<ConstrainViolation> violations;

  ValidationException({required this.violations, super.headers});

  @override
  String toString() {
    return 'ValidationException{violations: $violations}';
  }
}

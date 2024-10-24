import 'package:winter/winter.dart';

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
  static final HttpStatus status = HttpStatus.badRequest;

  BadRequestException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// exception for 401
class ForbiddenException extends ApiException {
  static final HttpStatus status = HttpStatus.unauthorized;

  ForbiddenException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// exception for 402
class PaymentRequiredException extends ApiException {
  static final HttpStatus status = HttpStatus.paymentRequired;

  PaymentRequiredException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// exception for 403
class UnauthorizedException extends ApiException {
  static final HttpStatus status = HttpStatus.forbidden;

  UnauthorizedException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// exception for 404
class NotFoundException extends ApiException {
  static final HttpStatus status = HttpStatus.notFound;

  NotFoundException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// exception for 409
class ConflictException extends ApiException {
  static final HttpStatus status = HttpStatus.conflict;

  ConflictException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// exception for 500
class InternalServerErrorException extends ApiException {
  static final HttpStatus status = HttpStatus.internalServerError;

  InternalServerErrorException({Object? body, super.headers})
      : super(
          body: body ?? status.reasonPhrase,
          statusCode: status.value,
        );
}

/// Validation exception 422
class UnprocessableEntityException extends ApiException {
  static final HttpStatus status = HttpStatus.unprocessableEntity;

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

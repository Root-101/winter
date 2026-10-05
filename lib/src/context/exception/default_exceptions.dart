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

  ApiException({required this.statusCode, this.body, this.headers});

  @override
  String toString() {
    return '$runtimeType{statusCode: $statusCode, body: $body}';
  }
}

/// exception for 400
class BadRequestException extends ApiException {
  static final StatusCode status = StatusCode.badRequest;

  BadRequestException({Object? body, super.headers})
    : super(body: body ?? status.reasonPhrase, statusCode: status.value);
}

/// exception for 401
class UnauthorizedException extends ApiException {
  static final StatusCode status = StatusCode.unauthorized;

  UnauthorizedException({Object? body, super.headers})
    : super(body: body ?? status.reasonPhrase, statusCode: status.value);
}

/// exception for 402
class PaymentRequiredException extends ApiException {
  static final StatusCode status = StatusCode.paymentRequired;

  PaymentRequiredException({Object? body, super.headers})
    : super(body: body ?? status.reasonPhrase, statusCode: status.value);
}

/// exception for 403
class ForbiddenException extends ApiException {
  static final StatusCode status = StatusCode.forbidden;

  ForbiddenException({Object? body, super.headers})
    : super(body: body ?? status.reasonPhrase, statusCode: status.value);
}

/// exception for 404
class NotFoundException extends ApiException {
  static final StatusCode status = StatusCode.notFound;

  NotFoundException({Object? body, super.headers})
    : super(body: body ?? status.reasonPhrase, statusCode: status.value);
}

/// exception for 409
class ConflictException extends ApiException {
  static final StatusCode status = StatusCode.conflict;

  ConflictException({Object? body, super.headers})
    : super(body: body ?? status.reasonPhrase, statusCode: status.value);
}

/// exception for 413
class PayloadTooLargeException extends ApiException {
  static final StatusCode status = StatusCode.payloadTooLarge;

  PayloadTooLargeException({Object? body, super.headers})
    : super(body: body ?? status.reasonPhrase, statusCode: status.value);
}

/// exception for 500
class InternalServerErrorException extends ApiException {
  static final StatusCode status = StatusCode.internalServerError;

  InternalServerErrorException({Object? body, super.headers})
    : super(body: body ?? status.reasonPhrase, statusCode: status.value);
}

/// Validation exception 422
class UnprocessableEntityException extends ApiException {
  static final StatusCode status = StatusCode.unprocessableEntity;

  UnprocessableEntityException({Object? body, super.headers})
    : super(body: body ?? status.reasonPhrase, statusCode: status.value);
}

class ValidationException extends UnprocessableEntityException {
  final List<ConstrainViolation> violations;

  ValidationException({required this.violations, super.headers});

  @override
  String toString() {
    return 'ValidationException{violations: $violations}';
  }
}

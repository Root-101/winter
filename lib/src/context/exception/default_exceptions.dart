import 'package:winter/winter.dart';

/// The body of every error response: a Problem Details (RFC 9457), sent as
/// `application/problem+json`:
///
/// ```json
/// { "type": "about:blank", "title": "Not Found", "status": 404, "detail": "User 42 not found" }
/// ```
///
/// The [extensions] are added as members of their own (`"violations": [...]` in a 422).
class ProblemDetails {
  /// A URI reference that identifies the kind of problem; `about:blank` when it's just the status
  final String type;

  /// A short summary of the kind of problem: the reason phrase of the status by default
  final String title;

  /// The status code of the response
  final int status;

  /// What happened in this occurrence, for the client (never internal details)
  final String? detail;

  /// More members of the problem. They never replace `type`, `title`, `status` nor `detail`.
  final Map<String, Object?> extensions;

  /// A problem with all its members
  const ProblemDetails({
    required this.status,
    required this.title,
    this.type = 'about:blank',
    this.detail,
    this.extensions = const {},
  });

  /// The problem of [status], with its reason phrase as the title
  ProblemDetails.of(
    StatusCode status, {
    String? type,
    String? title,
    this.detail,
    this.extensions = const {},
  }) : status = status.value,
       title = title ?? status.reasonPhrase,
       type = type ?? 'about:blank';

  /// The JSON of the problem: the [extensions], then the standard members
  Map<String, Object?> toJson() => {
    ...extensions,
    'type': type,
    'title': title,
    'status': status,
    if (detail != null) 'detail': detail,
  };

  /// A response with this problem as the body (`application/problem+json`)
  ResponseEntity<ProblemDetails> toResponse({Map<String, Object>? headers}) =>
      ResponseEntity(status, body: this, headers: headers);

  @override
  String toString() => 'ProblemDetails${toJson()}';
}

/// Ends the request with [responseEntity] as it is, when an error needs a response of its own
/// (not a Problem Details)
class ResponseException implements Exception {
  /// The response sent to the client
  final ResponseEntity responseEntity;

  /// An exception that answers [responseEntity]
  const ResponseException(this.responseEntity);
}

/// An error that the client must know about, answered as a [ProblemDetails]:
///
/// ```dart
/// throw NotFoundException(detail: 'User 42 not found');
/// throw ApiException(StatusCode.conflict, detail: 'The email is already registered');
/// ```
///
/// The subclasses are shortcuts for the common statuses. The [detail] is sent to the client, so
/// it must never contain internal details; write it in the language of the request (`t(...)`).
class ApiException implements Exception {
  /// The status of the response
  final StatusCode status;

  /// What happened, for the client
  final String? detail;

  /// The URI reference of the kind of problem (`about:blank` when null)
  final String? type;

  /// The summary of the kind of problem (the reason phrase of [status] when null)
  final String? title;

  /// More members of the problem (`{'email': email}`)
  final Map<String, Object?> extensions;

  /// Headers of the response (`Allow`, `Retry-After`...)
  final Map<String, Object>? headers;

  /// An error of [status]
  const ApiException(
    this.status, {
    this.detail,
    this.type,
    this.title,
    this.extensions = const {},
    this.headers,
  });

  /// The status code of the response
  int get statusCode => status.value;

  /// The body of the response
  ProblemDetails toProblemDetails() => ProblemDetails.of(
    status,
    type: type,
    title: title,
    detail: detail,
    extensions: extensions,
  );

  @override
  String toString() {
    return '$runtimeType{status: ${status.value}, detail: $detail}';
  }
}

/// 400: the request is malformed
class BadRequestException extends ApiException {
  /// A 400
  const BadRequestException({
    super.detail,
    super.type,
    super.title,
    super.extensions,
    super.headers,
  }) : super(StatusCode.badRequest);
}

/// 401: nobody is authenticated (or the credentials are invalid)
class UnauthorizedException extends ApiException {
  /// A 401
  const UnauthorizedException({
    super.detail,
    super.type,
    super.title,
    super.extensions,
    super.headers,
  }) : super(StatusCode.unauthorized);
}

/// 403: the authenticated user can't do this
class ForbiddenException extends ApiException {
  /// A 403
  const ForbiddenException({
    super.detail,
    super.type,
    super.title,
    super.extensions,
    super.headers,
  }) : super(StatusCode.forbidden);
}

/// 404: the resource doesn't exist
class NotFoundException extends ApiException {
  /// A 404
  const NotFoundException({
    super.detail,
    super.type,
    super.title,
    super.extensions,
    super.headers,
  }) : super(StatusCode.notFound);
}

/// 405: the path exists, but not for this method. The `Allow` header lists the [allowedMethods].
class MethodNotAllowedException extends ApiException {
  /// The methods allowed for the path
  final Set<HttpMethod> allowedMethods;

  /// A 405 with the `Allow` header
  MethodNotAllowedException(
    this.allowedMethods, {
    super.detail,
    super.type,
    super.title,
    super.extensions,
    Map<String, Object>? headers,
  }) : super(
         StatusCode.methodNotAllowed,
         headers: {
           ...?headers,
           HttpHeader.allow: allowedMethods
               .map((method) => method.name.toUpperCase())
               .join(', '),
         },
       );
}

/// 409: the request conflicts with the current state (ex: the email is already registered)
class ConflictException extends ApiException {
  /// A 409
  const ConflictException({
    super.detail,
    super.type,
    super.title,
    super.extensions,
    super.headers,
  }) : super(StatusCode.conflict);
}

/// 413: the body is bigger than `ServerConfig.maxBodySize`
class PayloadTooLargeException extends ApiException {
  /// A 413
  const PayloadTooLargeException({
    super.detail,
    super.type,
    super.title,
    super.extensions,
    super.headers,
  }) : super(StatusCode.payloadTooLarge);
}

/// 415: the body is not in a format the endpoint understands
class UnsupportedMediaTypeException extends ApiException {
  /// A 415
  const UnsupportedMediaTypeException({
    super.detail,
    super.type,
    super.title,
    super.extensions,
    super.headers,
  }) : super(StatusCode.unsupportedMediaType);
}

/// 422: the body has the right shape, but invalid values
class UnprocessableEntityException extends ApiException {
  /// A 422
  const UnprocessableEntityException({
    super.detail,
    super.type,
    super.title,
    super.extensions,
    super.headers,
  }) : super(StatusCode.unprocessableEntity);
}

/// 422 with the [violations] of a validation, sent as the `violations` member of the problem
class ValidationException extends UnprocessableEntityException {
  /// What failed, field by field
  final List<ConstraintViolation> violations;

  /// A 422 with [violations]
  const ValidationException({
    required this.violations,
    super.detail,
    super.headers,
  });

  @override
  String toString() {
    return 'ValidationException{violations: $violations}';
  }
}

/// 429: too many requests. [retryAfter] (seconds) is sent as the `Retry-After` header.
class TooManyRequestsException extends ApiException {
  /// A 429
  TooManyRequestsException({
    int? retryAfter,
    super.detail,
    super.type,
    super.title,
    super.extensions,
    Map<String, Object>? headers,
  }) : super(
         StatusCode.tooManyRequests,
         headers: {
           ...?headers,
           if (retryAfter != null) HttpHeader.retryAfter: '$retryAfter',
         },
       );
}

/// 500: an error of the server. Unexpected errors become a 500 by themselves; throw it only
/// to answer one on purpose.
class InternalServerErrorException extends ApiException {
  /// A 500
  const InternalServerErrorException({
    super.detail,
    super.type,
    super.title,
    super.extensions,
    super.headers,
  }) : super(StatusCode.internalServerError);
}

/// 503: the server can't answer now (maintenance, a dependency is down). [retryAfter] (seconds)
/// is sent as the `Retry-After` header.
class ServiceUnavailableException extends ApiException {
  /// A 503
  ServiceUnavailableException({
    int? retryAfter,
    super.detail,
    super.type,
    super.title,
    super.extensions,
    Map<String, Object>? headers,
  }) : super(
         StatusCode.serviceUnavailable,
         headers: {
           ...?headers,
           if (retryAfter != null) HttpHeader.retryAfter: '$retryAfter',
         },
       );
}

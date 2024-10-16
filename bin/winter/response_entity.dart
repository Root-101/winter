import 'package:shelf/shelf.dart';

import 'winter.dart';

class ResponseEntity extends Response {
  Object? _body;

  ResponseEntity(
    super.statusCode, {
    Object? body,
    ObjectMapper? objectMapper,
    super.headers,
    super.encoding,
    super.context,
  })  : _body = body,
        super(
          body: body is! Stream
              ? body != null
                  ? (objectMapper ?? Winter.instance.context.objectMapper)
                      .serialize(body)
                  : ''
              : body,
        );

  T body<T>() {
    return _body as T;
  }

  ResponseEntity.ok({
    Object? body,
  }) : this(
          HttpStatus.OK.value,
          body: body,
        );

  ResponseEntity.internalServerError({
    Object? body,
  }) : this(
          HttpStatus.INTERNAL_SERVER_ERROR.value,
          body: body ?? 'Internal Server Error',
        );

  ResponseEntity.badRequest({
    Object? body,
  }) : this(
          HttpStatus.BAD_REQUEST.value,
          body: body ?? 'Bad Request',
        );

  ResponseEntity.notFound({
    Object? body,
  }) : this(
          HttpStatus.NOT_FOUND.value,
          body: body ?? 'Not found',
        );

  ResponseEntity.methodNotAllowed({
    Object? body,
  }) : this(
          HttpStatus.METHOD_NOT_ALLOWED.value,
          body: body ?? 'Method not allowed',
        );

  ResponseEntity.tooManyRequests({
    Object? body,
    int? retryAfter,
  }) : this(
          HttpStatus.TOO_MANY_REQUESTS.value,
          body: body ??
              'Too many requests.${retryAfter != null ? ' Please try again in $retryAfter seconds.' : ''}',
          headers: {
            if (retryAfter != null) HttpHeaders.RETRY_AFTER: '$retryAfter',
          },
        );
}

import 'dart:convert';

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
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
          HttpStatus.OK.value,
          body: body,
          headers: headers,
        );

  ResponseEntity.internalServerError({
    Object? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
          HttpStatus.INTERNAL_SERVER_ERROR.value,
          body: body ?? 'Internal Server Error',
          headers: headers,
        );

  ResponseEntity.badRequest({
    Object? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
          HttpStatus.BAD_REQUEST.value,
          body: body ?? 'Bad Request',
          headers: headers,
        );

  ResponseEntity.notFound({
    Object? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
          HttpStatus.NOT_FOUND.value,
          body: body ?? 'Not found',
          headers: headers,
        );

  ResponseEntity.methodNotAllowed({
    Object? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
          HttpStatus.METHOD_NOT_ALLOWED.value,
          body: body ?? 'Method not allowed',
          headers: headers,
        );

  ResponseEntity.tooManyRequests({
    Object? body,
    int? retryAfter,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
          HttpStatus.TOO_MANY_REQUESTS.value,
          body: body ??
              'Too many requests.${retryAfter != null ? ' Please try again in $retryAfter seconds.' : ''}',
          headers: {
            if (headers != null) ...headers,
            if (retryAfter != null) HttpHeaders.RETRY_AFTER: '$retryAfter',
          },
        );

  ResponseEntity copyWith({
    int? statusCode,
    Object? body,
    Map<String, /* String | List<String> */ Object>? headers,
    Encoding? encoding,
    Map<String, Object>? context,
  }) {
    return ResponseEntity(
      statusCode ?? this.statusCode,
      body: body ?? _body,
      headers: headers ?? this.headers,
      encoding: encoding ?? this.encoding,
      context: context ?? this.context,
    );
  }
}

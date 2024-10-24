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
          HttpStatus.ok.value,
          body: body,
          headers: headers,
        );

  ResponseEntity.internalServerError({
    Object? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
          HttpStatus.internalServerError.value,
          body: body ?? 'Internal Server Error',
          headers: headers,
        );

  ResponseEntity.badRequest({
    Object? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
          HttpStatus.badRequest.value,
          body: body ?? 'Bad Request',
          headers: headers,
        );

  ResponseEntity.notFound({
    Object? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
          HttpStatus.notFound.value,
          body: body ?? 'Not found',
          headers: headers,
        );

  ResponseEntity.methodNotAllowed({
    Object? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
          HttpStatus.methodNotAllowed.value,
          body: body ?? 'Method not allowed',
          headers: headers,
        );

  ResponseEntity.tooManyRequests({
    Object? body,
    int? retryAfter,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
          HttpStatus.tooManyRequests.value,
          body: body ??
              'Too many requests.${retryAfter != null ? ' Please try again in $retryAfter seconds.' : ''}',
          headers: {
            if (headers != null) ...headers,
            if (retryAfter != null) HttpHeaders.retryAfter: '$retryAfter',
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

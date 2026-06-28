import 'dart:convert';

import 'package:winter/winter.dart';

class ResponseEntity<T> extends Response {
  T? _body;

  ResponseEntity(
    super.statusCode, {
    T? body,
    ObjectMapper? objectMapper,
    super.headers,
    super.encoding,
    super.context,
  }) : _body = body,
       super(
         body: body == null
             ? null
             : body is String || body is Stream
             ? body
             : jsonEncode(
                 (objectMapper ?? Winter.context.objectMapper).serialize(body),
               ),
       );

  T body() {
    return _body as T;
  }

  static ResponseEntity ok<T>({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) {
    return ResponseEntity<T>(HttpStatus.ok.value, body: body, headers: headers);
  }

  ResponseEntity.badRequest({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(HttpStatus.badRequest.value, body: body, headers: headers);

  ResponseEntity.unauthorized({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(HttpStatus.unauthorized.value, body: body, headers: headers);

  ResponseEntity.forbidden({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(HttpStatus.forbidden.value, body: body, headers: headers);

  ResponseEntity.notFound({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(HttpStatus.notFound.value, body: body, headers: headers);

  ResponseEntity.methodNotAllowed({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(HttpStatus.methodNotAllowed.value, body: body, headers: headers);

  ResponseEntity.tooManyRequests({
    T? body,
    int? retryAfter,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
         HttpStatus.tooManyRequests.value,
         body: body,
         headers: {
           if (headers != null) ...headers,
           if (retryAfter != null) HttpHeaders.retryAfter: '$retryAfter',
         },
       );

  ResponseEntity.internalServerError({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(HttpStatus.internalServerError.value, body: body, headers: headers);

  ResponseEntity<T> copyWith({
    int? statusCode,
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
    Encoding? encoding,
    Map<String, Object>? context,
  }) {
    return ResponseEntity<T>(
      statusCode ?? this.statusCode,
      body: body ?? _body,
      headers: headers ?? this.headers,
      encoding: encoding ?? this.encoding,
      context: context ?? this.context,
    );
  }
}

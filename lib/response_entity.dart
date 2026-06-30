import 'dart:convert';

import 'package:winter/winter.dart';

class ResponseEntity<T> extends Response {
  final T? _bodyValue;

  ResponseEntity(
    int statusCode, {
    T? body,
    ObjectMapper? objectMapper,
    Map<String, /* String | List<String> */ Object>? headers,
    Encoding? encoding,
    Map<String, Object>? context,
  }) : this._(
         statusCode,
         body,
         _resolveBody(body, objectMapper),
         headers,
         encoding,
         context,
       );

  ResponseEntity._(
    super.statusCode,
    this._bodyValue,
    Object? resolvedBody,
    Map<String, /* String | List<String> */ Object>? headers,
    Encoding? encoding,
    Map<String, Object>? context,
  ) : super(
        body: resolvedBody,
        headers: _resolveHeaders(
          statusCode,
          _bodyValue,
          resolvedBody,
          headers,
          encoding: encoding,
        ),
        encoding: encoding,
        context: context,
      );

  /// Resuelve el cuerpo de la respuesta según su tipo.
  static Object? _resolveBody(Object? body, ObjectMapper? objectMapper) {
    if (body == null || body is String || body is Stream) return body;

    final mapper = objectMapper ?? Winter.context.objectMapper;
    return jsonEncode(mapper.serialize(body));
  }

  /// Resuelve los encabezados, aplicando Content-Type y Content-Length automáticos si corresponde.
  static Map<String, Object>? _resolveHeaders(
    int statusCode,
    Object? originalBody,
    Object? resolvedBody,
    Map<String, /* String | List<String> */ Object>? headers, {
    Encoding? encoding,
  }) {
    final Map<String, Object> resolved = {...?headers};

    if (resolvedBody == null) {
      return resolved.isEmpty ? null : resolved;
    }

    final hasContentType = resolved.keys.any(
      (k) => k.toLowerCase() == HttpHeaders.contentType.toLowerCase(),
    );

    if (!hasContentType) {
      if (originalBody is Stream) {
        resolved[HttpHeaders.contentType] =
            MediaType.applicationOctetStream.mimeType;
      } else if (originalBody is String) {
        resolved[HttpHeaders.contentType] = MediaType.textPlain.mimeType;
      } else {
        resolved[HttpHeaders.contentType] = (statusCode >= 400)
            ? MediaType.applicationProblemJson.mimeType
            : MediaType.applicationJson.mimeType;
      }
    }

    final hasContentLength = resolved.keys.any(
      (k) => k.toLowerCase() == HttpHeaders.contentLength.toLowerCase(),
    );

    if (!hasContentLength) {
      if (resolvedBody is String) {
        resolved[HttpHeaders.contentLength] = (encoding ?? utf8)
            .encode(resolvedBody)
            .length
            .toString();
      }
    }

    return resolved;
  }

  T body() => _bodyValue as T;

  static ResponseEntity<T> ok<T>({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) => ResponseEntity<T>(HttpStatus.ok.value, body: body, headers: headers);

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
           ...?headers,
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
      body: body ?? _bodyValue,
      headers: headers ?? this.headers,
      encoding: encoding ?? this.encoding,
      context: context ?? this.context,
    );
  }

  @override
  Response change({
    Map<String, /* String | List<String> */ Object?>? headers,
    Map<String, Object?>? context,
    Object? body,
  }) {
    throw UnimplementedError();
  }
}

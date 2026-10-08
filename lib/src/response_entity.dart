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
         _contentTypeOfValue(statusCode, body),
         headers,
         encoding,
         context,
       );

  ///[contentType] is added when [headers] have none (null: don't add any)
  ResponseEntity._(
    super.statusCode,
    this._bodyValue,
    Object? resolvedBody,
    String? contentType,
    Map<String, /* String | List<String> */ Object>? headers,
    Encoding? encoding,
    Map<String, Object>? context,
  ) : super(
        body: resolvedBody,
        headers: _resolveHeaders(
          contentType,
          resolvedBody,
          headers,
          encoding: encoding,
        ),
        encoding: encoding,
        context: context,
      );

  /// Resolve the body of the response according to its type.
  static Object? _resolveBody(Object? body, ObjectMapper? objectMapper) {
    if (body == null || body is String || body is Stream) return body;

    return (objectMapper ?? Winter.context.objectMapper).encode(body);
  }

  /// Content-Type of a value given to the constructor: a String is text, a Stream is binary,
  /// anything else is serialized as JSON (`application/problem+json` for errors)
  static String? _contentTypeOfValue(int statusCode, Object? body) {
    if (body == null) return null;
    if (body is Stream) return MediaType.applicationOctetStream.mimeType;
    if (body is String) return MediaType.textPlain.mimeType;
    return statusCode >= 400
        ? MediaType.applicationProblemJson.mimeType
        : MediaType.applicationJson.mimeType;
  }

  /// Content-Type of a body given to [change], which is used as it is (never serialized):
  /// a String is text, bytes or a Stream are binary
  static String? _contentTypeOfRawBody(Object? body) {
    if (body == null) return null;
    if (body is String) return MediaType.textPlain.mimeType;
    return MediaType.applicationOctetStream.mimeType;
  }

  /// Resolve the headers, adding [contentType] and the Content-Length when needed.
  static Map<String, Object>? _resolveHeaders(
    String? contentType,
    Object? resolvedBody,
    Map<String, /* String | List<String> */ Object>? headers, {
    Encoding? encoding,
  }) {
    final Map<String, Object> resolved = {...?headers};

    if (contentType != null && !_hasHeader(resolved, HttpHeader.contentType)) {
      resolved[HttpHeader.contentType] = contentType;
    }

    if (resolvedBody is String &&
        !_hasHeader(resolved, HttpHeader.contentLength)) {
      resolved[HttpHeader.contentLength] = (encoding ?? utf8)
          .encode(resolvedBody)
          .length
          .toString();
    }

    return resolved.isEmpty ? null : resolved;
  }

  static bool _hasHeader(Map<String, Object> headers, String name) =>
      headers.keys.any((k) => k.toLowerCase() == name.toLowerCase());

  T body() => _bodyValue as T;

  ResponseEntity.ok({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(StatusCode.ok.value, body: body, headers: headers);

  ///201: [body] was created at [location] (the `Location` header)
  ResponseEntity.created({
    String? location,
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
         StatusCode.created.value,
         body: body,
         headers: {...?headers, HttpHeader.location: ?location},
       );

  ///202: the request was accepted, and will be processed later
  ResponseEntity.accepted({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(StatusCode.accepted.value, body: body, headers: headers);

  ///204: done, without a body
  ResponseEntity.noContent({
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(StatusCode.noContent.value, headers: headers);

  ResponseEntity.badRequest({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(StatusCode.badRequest.value, body: body, headers: headers);

  ResponseEntity.unauthorized({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(StatusCode.unauthorized.value, body: body, headers: headers);

  ResponseEntity.forbidden({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(StatusCode.forbidden.value, body: body, headers: headers);

  ResponseEntity.notFound({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(StatusCode.notFound.value, body: body, headers: headers);

  ResponseEntity.methodNotAllowed({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(StatusCode.methodNotAllowed.value, body: body, headers: headers);

  ResponseEntity.tooManyRequests({
    T? body,
    int? retryAfter,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(
         StatusCode.tooManyRequests.value,
         body: body,
         headers: {
           ...?headers,
           if (retryAfter != null) HttpHeader.retryAfter: '$retryAfter',
         },
       );

  ResponseEntity.internalServerError({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this(StatusCode.internalServerError.value, body: body, headers: headers);

  ///A copy with the given values. [headers] replace all the headers (to add some, use [change]).
  ///
  ///Without a new [body], the copy keeps the body already resolved (serialized, bytes or stream)
  ///as it is: it's never serialized again, and a body set with [change] is kept.
  ///Like [change], it reads this response, so use the copy from then on.
  ResponseEntity<T> copyWith({
    int? statusCode,
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
    Encoding? encoding,
    Map<String, Object>? context,
  }) {
    if (body != null) {
      return ResponseEntity<T>(
        statusCode ?? this.statusCode,
        body: body,
        headers: headers ?? this.headers,
        encoding: encoding ?? this.encoding,
        context: context ?? this.context,
      );
    }
    return ResponseEntity<T>._(
      statusCode ?? this.statusCode,
      _bodyValue,
      read(),
      null,
      headers ?? headersAll,
      encoding ?? this.encoding,
      context ?? this.context,
    );
  }

  ///Same as [Response.change] (used by shelf middlewares) but returns a [ResponseEntity].
  ///A new [body] is used as it is (String, bytes or Stream), like shelf does.
  ///The [headers] are added to the current ones (`null` removes one).
  @override
  ResponseEntity<T> change({
    Map<String, /* String | List<String> */ Object?>? headers,
    Map<String, Object?>? context,
    Object? body,
  }) {
    final Response changed = super.change(
      headers: headers,
      context: context,
      body: body,
    );
    return ResponseEntity<T>._(
      changed.statusCode,
      body == null ? _bodyValue : (body is T ? body as T : null),
      changed.read(),
      _contentTypeOfRawBody(body),
      changed.headersAll,
      changed.encoding,
      changed.context,
    );
  }
}

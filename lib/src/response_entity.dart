import 'dart:async';
import 'dart:convert';
import 'dart:io' show Cookie, HttpDate, HttpResponse;
import 'dart:typed_data';

import 'package:winter/src/http/headers.dart';
import 'package:winter/winter.dart';

/// An HTTP response: what a handler returns, and what every filter can change with [copyWith].
///
/// The [body] is a value of the app: a `String` is sent as text, a `Uint8List` as bytes, a
/// `Stream<List<int>>` as a stream (Server-Sent Events, files), and anything else is serialized
/// as JSON with the object mapper. The `Content-Type` and the `Content-Length` are added when the
/// [headers] don't have them.
///
/// ```dart
/// ResponseEntity.ok(body: user)                                  // 200, JSON
/// ResponseEntity.created(location: '/users/7', body: user)       // 201 + Location
/// ResponseEntity.seeOther('/orders/7')                            // 303 after a form
/// ResponseEntity(200, body: File('report.pdf').openRead(), headers: {
///   HttpHeader.contentType: 'application/pdf',
/// })
/// ```
///
/// For an error, throw an [ApiException] instead: it becomes a Problem Details.
///
/// {@category Requests and responses}
class ResponseEntity<T> {
  /// The status code (`200`)
  final int statusCode;

  /// Every value of each header, case insensitive (several `Set-Cookie`). Read-only.
  final Map<String, List<String>> headersAll;

  /// The encoding of a text body (UTF-8 by default), and the charset of its `Content-Type`
  final Encoding? encoding;

  /// Data attached to this response for the outer filters, found by a typed [ContextKey] (see
  /// [ContextMap]). The copies of [copyWith] start with the same values.
  final ContextMap context;

  final T? _bodyValue;

  /// The bytes (or the stream) that are sent, shared by the copies of this response
  final _ResponseBody _body;

  /// A response with [statusCode].
  ///
  /// - [headers]: a `String` or a `List<String>` (several values) per name.
  /// - [cookies]: one `Set-Cookie` each.
  /// - [objectMapper]: the one that serializes the [body] (default: the global `om`).
  factory ResponseEntity(
    int statusCode, {
    T? body,
    ObjectMapper? objectMapper,
    Map<String, /* String | List<String> */ Object>? headers,
    List<Cookie>? cookies,
    Encoding? encoding,
  }) {
    final (_ResponseBody resolved, String? contentType) = _resolve(
      statusCode,
      body,
      objectMapper,
      encoding,
    );
    return ResponseEntity<T>._(
      statusCode: statusCode,
      bodyValue: body,
      body: resolved,
      headersAll: _withDefaults(
        mergeHeaders(headersAllOf(headers), _cookieHeaders(const {}, cookies)),
        contentType,
        resolved,
      ),
      encoding: encoding,
      context: ContextMap(),
    );
  }

  ResponseEntity._({
    required this.statusCode,
    required this._bodyValue,
    required this._body,
    required this.headersAll,
    required this.encoding,
    required this.context,
  });

  ///200: [body], as JSON for an object (see the class)
  ResponseEntity.ok({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
    List<Cookie>? cookies,
  }) : this._from(
         ResponseEntity<T>(
           StatusCode.ok.value,
           body: body,
           headers: headers,
           cookies: cookies,
         ),
       );

  ///201: [body] was created at [location] (the `Location` header)
  ResponseEntity.created({
    String? location,
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
    List<Cookie>? cookies,
  }) : this._from(
         ResponseEntity<T>(
           StatusCode.created.value,
           body: body,
           headers: {...?headers, HttpHeader.location: ?location},
           cookies: cookies,
         ),
       );

  ///202: the request was accepted, and will be processed later
  ResponseEntity.accepted({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
    List<Cookie>? cookies,
  }) : this._from(
         ResponseEntity<T>(
           StatusCode.accepted.value,
           body: body,
           headers: headers,
           cookies: cookies,
         ),
       );

  ///204: done, without a body
  ResponseEntity.noContent({
    Map<String, /* String | List<String> */ Object>? headers,
    List<Cookie>? cookies,
  }) : this._from(
         ResponseEntity<T>(
           StatusCode.noContent.value,
           headers: headers,
           cookies: cookies,
         ),
       );

  ///302: the resource is temporarily at [location]. A browser follows it with a `GET`, even
  ///after a `POST`: use [ResponseEntity.temporaryRedirect] to keep the method.
  ResponseEntity.redirect(
    String location, {
    Map<String, /* String | List<String> */ Object>? headers,
    List<Cookie>? cookies,
  }) : this._from(_redirect<T>(StatusCode.found, location, headers, cookies));

  ///303: the result is at [location], read it with a `GET` (the answer to a form sent with `POST`)
  ResponseEntity.seeOther(
    String location, {
    Map<String, /* String | List<String> */ Object>? headers,
    List<Cookie>? cookies,
  }) : this._from(
         _redirect<T>(StatusCode.seeOther, location, headers, cookies),
       );

  ///307: the resource is temporarily at [location], requested again with the same method and body
  ResponseEntity.temporaryRedirect(
    String location, {
    Map<String, /* String | List<String> */ Object>? headers,
    List<Cookie>? cookies,
  }) : this._from(
         _redirect<T>(StatusCode.temporaryRedirect, location, headers, cookies),
       );

  ///308: the resource moved to [location] for good, requested again with the same method and body
  ResponseEntity.permanentRedirect(
    String location, {
    Map<String, /* String | List<String> */ Object>? headers,
    List<Cookie>? cookies,
  }) : this._from(
         _redirect<T>(StatusCode.permanentRedirect, location, headers, cookies),
       );

  ///400: the request is invalid.
  ///
  ///For an error, throwing an [ApiException] (`throw const BadRequestException()`) gives a
  ///Problem Details; this and the other error shortcuts build the response by hand.
  ResponseEntity.badRequest({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this._from(_status<T>(StatusCode.badRequest, body, headers));

  ///401: nobody is authenticated
  ResponseEntity.unauthorized({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this._from(_status<T>(StatusCode.unauthorized, body, headers));

  ///403: authenticated, but not allowed
  ResponseEntity.forbidden({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this._from(_status<T>(StatusCode.forbidden, body, headers));

  ///404: the resource doesn't exist
  ResponseEntity.notFound({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this._from(_status<T>(StatusCode.notFound, body, headers));

  ///405: the path exists, but not for this method
  ResponseEntity.methodNotAllowed({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this._from(_status<T>(StatusCode.methodNotAllowed, body, headers));

  ///409: the request conflicts with the state of the resource
  ResponseEntity.conflict({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this._from(_status<T>(StatusCode.conflict, body, headers));

  ///422: the body is well formed, but invalid
  ResponseEntity.unprocessableEntity({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this._from(_status<T>(StatusCode.unprocessableEntity, body, headers));

  ///429: too many requests; [retryAfter] is in seconds (`Retry-After`)
  ResponseEntity.tooManyRequests({
    T? body,
    int? retryAfter,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this._from(
         _status<T>(StatusCode.tooManyRequests, body, {
           ...?headers,
           if (retryAfter != null) HttpHeader.retryAfter: '$retryAfter',
         }),
       );

  ///500: the server failed
  ResponseEntity.internalServerError({
    T? body,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this._from(_status<T>(StatusCode.internalServerError, body, headers));

  ///503: the server can't answer now; [retryAfter] is in seconds (`Retry-After`)
  ResponseEntity.serviceUnavailable({
    T? body,
    int? retryAfter,
    Map<String, /* String | List<String> */ Object>? headers,
  }) : this._from(
         _status<T>(StatusCode.serviceUnavailable, body, {
           ...?headers,
           if (retryAfter != null) HttpHeader.retryAfter: '$retryAfter',
         }),
       );

  ResponseEntity._from(ResponseEntity<T> response)
    : this._(
        statusCode: response.statusCode,
        bodyValue: response._bodyValue,
        body: response._body,
        headersAll: response.headersAll,
        encoding: response.encoding,
        context: response.context,
      );

  static ResponseEntity<T> _status<T>(
    StatusCode status,
    T? body,
    Map<String, Object>? headers,
  ) => ResponseEntity<T>(status.value, body: body, headers: headers);

  static ResponseEntity<T> _redirect<T>(
    StatusCode status,
    String location,
    Map<String, Object>? headers,
    List<Cookie>? cookies,
  ) => ResponseEntity<T>(
    status.value,
    headers: {...?headers, HttpHeader.location: location},
    cookies: cookies,
  );

  /// One value per header, case insensitive (several values are joined with `, `). Read-only.
  late final Map<String, String> headers = joinHeaders(headersAll);

  /// The body given to the response, as a value of the app (not serialized)
  T body() => _bodyValue as T;

  /// The `Content-Length`, if it's known (a stream has none)
  int? get contentLength {
    final String? header = headers[HttpHeader.contentLength];
    return header == null ? _body.length : int.tryParse(header);
  }

  /// Whether the body is a stream (sent as it's produced, without a `Content-Length`)
  bool get isStreamed => _body.length == null;

  /// The bytes that are sent. A body of text or bytes can be read any number of times (a filter can
  /// look at it); a stream only once (the server reads it to send the response).
  Stream<List<int>> read() => _body.read();

  /// The bytes that are sent, as text (see [read])
  Future<String> readAsString([Encoding? encoding]) =>
      (encoding ?? this.encoding ?? utf8).decodeStream(read());

  /// A copy of this response:
  ///
  /// - [headers] are added to the current ones (a `String` or a `List<String>`; `null` removes
  ///   one), and every cookie of [cookies] adds a `Set-Cookie`.
  /// - A new [body] is resolved like in the constructor, with its own `Content-Type` and
  ///   `Content-Length` (unless [headers] give them). Without it, the copy shares the body of this
  ///   response, which is never serialized again: use the copy from then on.
  ResponseEntity<T> copyWith({
    int? statusCode,
    T? body,
    Map<String, /* String | List<String> */ Object?>? headers,
    List<Cookie>? cookies,
    Encoding? encoding,
  }) {
    final int status = statusCode ?? this.statusCode;
    final Encoding? newEncoding = encoding ?? this.encoding;
    Map<String, List<String>> newHeaders = headersAll;
    _ResponseBody newBody = _body;
    String? contentType;
    if (body != null) {
      (newBody, contentType) = _resolve(status, body, null, newEncoding);
      newHeaders = mergeHeaders(newHeaders, {
        HttpHeader.contentType: null,
        HttpHeader.contentLength: null,
      });
    }
    newHeaders = mergeHeaders(
      mergeHeaders(newHeaders, headers),
      _cookieHeaders(newHeaders, cookies),
    );
    return ResponseEntity<T>._(
      statusCode: status,
      bodyValue: body ?? _bodyValue,
      body: newBody,
      headersAll: body == null
          ? newHeaders
          : _withDefaults(newHeaders, contentType, newBody),
      encoding: newEncoding,
      context: ContextMap.from(context),
    );
  }

  /// The bytes (or stream) of [body] and its `Content-Type`: a String is text, a `Uint8List`
  /// bytes, a Stream a stream, anything else JSON (`application/problem+json` for errors)
  static (_ResponseBody, String?) _resolve(
    int statusCode,
    Object? body,
    ObjectMapper? objectMapper,
    Encoding? encoding,
  ) {
    final Encoding textEncoding = encoding ?? utf8;
    String text(MediaType type) =>
        '${type.mimeType}; charset=${textEncoding.name}';
    return switch (body) {
      null => (_ResponseBody.bytes(const []), null),
      final String value => (
        _ResponseBody.bytes(textEncoding.encode(value)),
        text(MediaType.textPlain),
      ),
      final Uint8List bytes => (
        _ResponseBody.bytes(bytes),
        MediaType.applicationOctetStream.mimeType,
      ),
      final Stream<List<int>> stream => (
        _ResponseBody(stream),
        MediaType.applicationOctetStream.mimeType,
      ),
      _ => (
        _ResponseBody.bytes(
          textEncoding.encode(
            (objectMapper ?? Winter.context.objectMapper).encode(body),
          ),
        ),
        text(
          statusCode >= 400
              ? MediaType.applicationProblemJson
              : MediaType.applicationJson,
        ),
      ),
    };
  }

  /// [contentType] and the `Content-Length` of [body], unless [headers] have them
  static Map<String, List<String>> _withDefaults(
    Map<String, List<String>> headers,
    String? contentType,
    _ResponseBody body,
  ) {
    final int? length = body.length;
    return mergeHeaders(headers, {
      if (contentType != null && !headers.containsKey(HttpHeader.contentType))
        HttpHeader.contentType: contentType,
      if (length != null &&
          length > 0 &&
          !headers.containsKey(HttpHeader.contentLength))
        HttpHeader.contentLength: '$length',
    });
  }

  /// A `Set-Cookie` per cookie, after the ones of [headers]
  static Map<String, Object?>? _cookieHeaders(
    Map<String, List<String>> headers,
    List<Cookie>? cookies,
  ) {
    if (cookies == null || cookies.isEmpty) return null;
    return {
      HttpHeader.setCookie: [
        ...?headers[HttpHeader.setCookie],
        for (final cookie in cookies) cookie.toString(),
      ],
    };
  }

  @override
  String toString() => 'ResponseEntity{$statusCode}';
}

/// The bytes of a response (with their length), read any number of times, or a stream, read once
class _ResponseBody {
  final Stream<List<int>>? _stream;

  /// Null for a stream
  final List<int>? _bytes;

  bool _read = false;

  _ResponseBody(Stream<List<int>> this._stream) : _bytes = null;

  _ResponseBody.bytes(List<int> this._bytes) : _stream = null;

  /// Null for a stream
  int? get length => _bytes?.length;

  Stream<List<int>> read() {
    final List<int>? bytes = _bytes;
    if (bytes != null) return Stream.value(bytes);
    if (_read) {
      throw StateError('The stream body of the response was already read');
    }
    _read = true;
    return _stream!;
  }
}

/// Write [response] to the [HttpResponse] of `dart:io` (what the server does with every
/// response; internal, not exported by `winter.dart`): its status with the reason phrase of [StatusCode] (`422 Unprocessable Entity`;
/// `dart:io` alone sends `422 Status 422`), its headers, a `Date`, and its body, with a `Content-Length` or
/// chunked for a stream (sent as it's produced, for Server-Sent Events). A HEAD request, a 204
/// and a 304 get no body.
///
/// With [compress] (`ServerConfig.autoCompress` and a client that accepts gzip) the length is
/// left out, so `dart:io` can gzip the body. A stream is never compressed: it's sent as it's
/// produced.
///
/// A client that disconnects in the middle, or a stream body that fails, is logged at debug and
/// the connection is closed: it never fails the server.
///
/// {@category Requests and responses}
Future<void> writeResponse(
  ResponseEntity response,
  HttpResponse output, {
  required String method,
  bool compress = false,
}) async {
  final int status = response.statusCode;
  final bool withBody =
      method.toUpperCase() != 'HEAD' &&
      status != 204 &&
      status != 304 &&
      status >= 200;
  final _ResponseBody body = response._body;
  try {
    output.statusCode = status;
    final String? reasonPhrase = StatusCode.resolve(status)?.reasonPhrase;
    if (reasonPhrase != null) output.reasonPhrase = reasonPhrase;
    response.headersAll.forEach(output.headers.set);
    if (!response.headersAll.containsKey(HttpHeader.date)) {
      output.headers.set(HttpHeader.date, _HttpDateCache.now());
    }
    if (status != 204 && status != 304) {
      output.contentLength = compress && withBody
          ? -1
          : response.contentLength ?? -1;
    }

    final List<int>? bytes = body._bytes;
    if (!withBody || bytes != null) {
      if (withBody) output.add(bytes!);
      await output.close();
      return;
    }

    ///Every chunk is sent as it's produced. dart:io sends the headers with the first chunk, so
    ///a stream of events usually starts with one (or a comment, `: ok`)
    output.bufferOutput = false;
    await output.addStream(body.read());
    await output.close();
  } catch (error) {
    logger.debug('The response of $method could not be sent', error: error);
    try {
      await output.close();
    } catch (_) {
      ///The connection is already gone
    }
  }
}

/// The `Date` of the responses, formatted once per second
class _HttpDateCache {
  static int _second = -1;
  static String _value = '';

  static String now() {
    final DateTime now = DateTime.now();
    final int second = now.millisecondsSinceEpoch ~/ 1000;
    if (second != _second) {
      _second = second;
      _value = HttpDate.format(now);
    }
    return _value;
  }
}

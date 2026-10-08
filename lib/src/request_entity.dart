import 'dart:async';
import 'dart:convert';
import 'dart:io' show Cookie, HttpConnectionInfo, HttpRequest;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:winter/src/http/headers.dart';
import 'package:winter/src/router/path_template.dart';
import 'package:winter/winter.dart';

/// An HTTP request: what a handler and every filter receive.
///
/// The server builds it from the `HttpRequest` of `dart:io`, and a test builds it in memory:
///
/// ```dart
/// final request = RequestEntity(
///   'POST',
///   Uri.parse('http://localhost/users'),
///   headers: {'content-type': 'application/json'},
///   body: '{"name": "Ann"}',
/// );
/// ```
class RequestEntity {
  /// The method, in upper case (`GET`, `POST`...)
  final String method;

  /// The absolute URI of the request, with its query
  final Uri requestedUri;

  /// The HTTP version (`1.1`)
  final String protocolVersion;

  /// Every value of each header, case insensitive (`headersAll['set-cookie']`). Read-only.
  final Map<String, List<String>> headersAll;

  /// Data attached to this request by the framework and the app (the security context, the
  /// language...), found by a typed [ContextKey]: the way to extend a request (see [ContextMap]).
  /// The copies of [copyWith] start with the same values.
  final ContextMap context;

  /// The connection of the client (null in memory), used by [clientIp]
  final HttpConnectionInfo? connectionInfo;

  /// The body, shared by the copies of this request: it's read once
  final _RequestBody _body;

  Route? _route;

  Map<String, String>? _pathParams;

  /// A request in memory (tests, or a request built by the app).
  ///
  /// - [headers]: a `String` or a `List<String>` (several values) per name.
  /// - [body]: a `String` (encoded with [encoding], UTF-8 by default), bytes (`List<int>`), a
  ///   `Stream<List<int>>`, or null.
  RequestEntity(
    String method,
    this.requestedUri, {
    Map<String, Object>? headers,
    Object? body,
    Encoding? encoding,
    this.protocolVersion = '1.1',
    this.connectionInfo,
  }) : method = method.toUpperCase(),
       headersAll = headersAllOf(headers),
       context = ContextMap(),
       _body = _RequestBody.of(body, encoding ?? utf8);

  RequestEntity._copy({
    required this.method,
    required this.requestedUri,
    required this.protocolVersion,
    required this.headersAll,
    required this.context,
    required this.connectionInfo,
    required this._body,
    Route? route,
  }) {
    if (route != null) _attach(route);
  }

  /// One value per header, case insensitive (several values are joined with `, `). Read-only.
  late final Map<String, String> headers = joinHeaders(headersAll);

  /// The cookies sent by the client (`Cookie` header). An invalid one is skipped.
  late final List<Cookie> cookies = List.unmodifiable(_parseCookies());

  List<Cookie> _parseCookies() => [
    for (final header in headersAll[HttpHeader.cookie] ?? const <String>[])
      for (final pair in header.split(';'))
        if (pair.contains('='))
          ?_cookie(
            pair.substring(0, pair.indexOf('=')).trim(),
            pair.substring(pair.indexOf('=') + 1).trim(),
          ),
  ];

  static Cookie? _cookie(String name, String value) {
    try {
      return Cookie(name, value);
    } on FormatException {
      return null;
    }
  }

  /// The cookie [name], or null
  Cookie? cookie(String name) =>
      cookies.firstWhereOrNull((cookie) => cookie.name == name);

  HttpMethod get httpMethod => HttpMethod(method);

  /// The MIME type of the `Content-Type` (`application/json`), without its parameters
  String? get mimeType {
    final String? contentType = headers[HttpHeader.contentType];
    if (contentType == null) return null;
    return contentType.split(';').first.trim().toLowerCase();
  }

  /// The charset of the `Content-Type`, or null without one (the body is read as UTF-8)
  Encoding? get encoding {
    final String? contentType = headers[HttpHeader.contentType];
    if (contentType == null) return null;
    for (final parameter in contentType.split(';').skip(1)) {
      final int equals = parameter.indexOf('=');
      if (equals < 0) continue;
      if (parameter.substring(0, equals).trim().toLowerCase() == 'charset') {
        return Encoding.getByName(
          parameter.substring(equals + 1).trim().replaceAll('"', ''),
        );
      }
    }
    return null;
  }

  /// The `Content-Length` of the body, if it's known
  int? get contentLength {
    final String? header = headers[HttpHeader.contentLength];
    return header == null ? _body.length : int.tryParse(header);
  }

  /// The route that answers this request, or null when no route matches (a 404, a 405, an
  /// `OPTIONS`) or the router has no routes. A filter can recognize it by its key
  /// (`request.route?.key == 'health'`).
  Route? get route => _route;

  ///IP address of the client (null if unknown, ex: a request built in a test).
  ///
  ///By default it's the address of the connection, `X-Forwarded-For` is ignored because
  ///any client can send it with a fake IP (ex: to bypass a rate limiter).
  ///Behind proxies, set [trustedProxies] to how many proxies (that you control) add
  ///their entry to `X-Forwarded-For`: the entry added by the last of them is the client.
  String? clientIp({int trustedProxies = 0}) {
    final String? connectionIp = connectionInfo?.remoteAddress.address;
    if (trustedProxies <= 0) return connectionIp;

    final forwardedFor = headers[HttpHeader.xForwardedFor];
    if (forwardedFor == null) return connectionIp;

    final ips = forwardedFor
        .split(',')
        .map((ip) => ip.trim())
        .where((ip) => ip.isNotEmpty)
        .toList();
    final index = ips.length - trustedProxies;
    return index >= 0 ? ips[index] : connectionIp;
  }

  ///The query params, with the last value of a repeated param (`?tag=a&tag=b` => `{tag: b}`).
  ///Use [queryParamsAll] to get every value.
  late final Map<String, String> queryParams = Map.unmodifiable(
    requestedUri.queryParameters,
  );

  ///Every value of each query param, in order (`?tag=a&tag=b` => `{tag: [a, b]}`)
  late final Map<String, List<String>> queryParamsAll = Map.unmodifiable({
    for (final entry in requestedUri.queryParametersAll.entries)
      entry.key: List<String>.unmodifiable(entry.value),
  });

  Map<String, String> get pathParams => _pathParams ?? const {};

  /// The path param [name] as a [T]: `String`, `int`, `double`, `num`, `bool`, `DateTime`
  /// (ISO 8601), or one of [values] (by name for an enum: `values: Status.values`).
  ///
  /// A value that isn't a [T] is a [BadRequestException] (400). A [name] that isn't in the path
  /// of the route is a [StateError] (a bug of the app).
  T pathParam<T extends Object>(String name, {List<T>? values}) {
    final String raw =
        pathParams[name] ??
        (throw StateError('The route has no path param $name'));
    return _parseParam<T>('path param', name, raw, values);
  }

  /// The query param [name] as a [T] (see [pathParam]), or null if it's missing or empty.
  /// Of a repeated param, the last value.
  T? queryParam<T extends Object>(String name, {List<T>? values}) {
    final String? raw = queryParams[name];
    if (raw == null || raw.isEmpty) return null;
    return _parseParam<T>('query param', name, raw, values);
  }

  static T _parseParam<T extends Object>(
    String kind,
    String name,
    String raw,
    List<T>? values,
  ) {
    if (values != null) {
      return values.firstWhereOrNull((value) => _nameOf(value) == raw) ??
          values.firstWhereOrNull(
            (value) => _nameOf(value).toLowerCase() == raw.toLowerCase(),
          ) ??
          (throw BadRequestException(
            detail:
                'The $kind $name must be one of: ${values.map(_nameOf).join(', ')}',
          ));
    }
    final (String expected, Object? Function(String) parse) = switch (T) {
      const (String) => ('a string', (String value) => value),
      const (int) => ('an integer', int.tryParse),
      const (double) => ('a number', double.tryParse),
      const (num) => ('a number', num.tryParse),
      const (bool) => ('true or false', _parseBool),
      const (DateTime) => ('an ISO 8601 date', DateTime.tryParse),
      _ => throw ArgumentError.value(
        T,
        'T',
        'Unsupported type of a param, use String, int, double, num, bool, DateTime or values:',
      ),
    };
    final Object? value = parse(raw);
    if (value is T) return value;
    throw BadRequestException(detail: 'The $kind $name must be $expected');
  }

  static String _nameOf(Object value) =>
      value is Enum ? value.name : value.toString();

  static bool? _parseBool(String value) => switch (value.toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  /// The route of this request and its path params
  void _attach(Route route) {
    _route = route;
    _pathParams = Map.unmodifiable(
      _extractPathParams(route.path, requestedUri.path),
    );
  }

  /// The body as a stream of bytes. It can be read once: after it (or after [readAsString] or
  /// [body]) only [body] works, from its cache.
  Stream<List<int>> read() => _body.read();

  /// The body as text, decoded with [encoding] (default: the charset of the `Content-Type`, or
  /// UTF-8). Like [read], it can be called once.
  Future<String> readAsString([Encoding? encoding]) =>
      (encoding ?? this.encoding ?? utf8).decodeStream(read());

  /// Get the body of the request, decoded as JSON with [objectMapper] (default: the global `om`,
  /// see [ObjectMapper.decode]).
  ///
  /// - The `Content-Type` must be JSON (`application/json` or `*/*+json`), `text/plain` or none:
  ///   any other is a 415 ([UnsupportedMediaTypeException]). `text/plain` is accepted because
  ///   `package:http` and `fetch()` send it for a String body when no header is given.
  /// - `body<String>()` decodes a JSON string (`"hello"` → `hello`) when the `Content-Type` is
  ///   JSON, and returns the text as it is otherwise.
  /// - With [validate] (the default), a [Validatable] body, or a list of them, is validated: a
  ///   failure throws a [ValidationException] (422). Use `validate: false` to read it without
  ///   validating (ex: a partial update).
  ///
  /// The raw body is cached (and shared with the copies of [copyWith]), so this method can be
  /// called multiple times, even with different types. After it, [read] and [readAsString] fail:
  /// the stream is already consumed.
  Future<T> body<T>({ObjectMapper? objectMapper, bool validate = true}) async {
    final ObjectMapper mapper = objectMapper ?? Winter.context.objectMapper;
    final String raw = await _body.text(encoding ?? utf8);
    final bool json = _isJson(mimeType);
    if (T == String || T == _typeOf<String?>()) {
      return json ? mapper.decode<T>(raw) : raw as T;
    }
    if (mimeType != null && !json && mimeType != MediaType.textPlain.mimeType) {
      throw UnsupportedMediaTypeException(
        detail:
            'Unsupported Content-Type $mimeType, '
            'expected ${MediaType.applicationJson.mimeType}',
      );
    }
    final T body = mapper.decode<T>(raw);
    if (validate) _validate(body);
    return body;
  }

  /// Validates a [Validatable] body, or every one in a list (prefixed with its index: `[0].email`)
  static void _validate(Object? body) {
    if (body is Validatable) {
      body.validate().throwOnFailure();
    } else if (body is Iterable<Object?>) {
      final cvc = ConstraintValidatorContext();
      var index = 0;
      for (final element in body) {
        if (element is Validatable) {
          cvc.merge(element.validate(), prefix: '[$index]');
        }
        index++;
      }
      cvc.throwOnFailure();
    }
  }

  /// The fields of a form sent as `application/x-www-form-urlencoded` (an HTML `<form>`).
  ///
  /// Any other `Content-Type` is a 415 ([UnsupportedMediaTypeException]), and a body that isn't
  /// valid URL-encoded text a 400. The raw body is cached like in [body], so it can be called
  /// multiple times; after it, [read] and [readAsString] fail.
  Future<FormData> formData() async {
    final String expected = MediaType.applicationFormUrlencoded.mimeType;
    if (mimeType != expected) {
      throw UnsupportedMediaTypeException(
        detail: mimeType == null
            ? 'Missing Content-Type, expected $expected'
            : 'Unsupported Content-Type $mimeType, expected $expected',
      );
    }
    final Encoding encoding = this.encoding ?? utf8;
    try {
      return FormData._parse(await _body.text(encoding), encoding);
    } on FormatException {
      throw const BadRequestException(detail: _invalidForm);
    } on ArgumentError {
      // Uri.decodeQueryComponent throws it for a bad percent-encoding (`%zz`)
      throw const BadRequestException(detail: _invalidForm);
    }
  }

  static const String _invalidForm =
      'The body is not a valid application/x-www-form-urlencoded form';

  static bool _isJson(String? mimeType) =>
      mimeType == MediaType.applicationJson.mimeType ||
      (mimeType != null && mimeType.endsWith('+json'));

  static Type _typeOf<X>() => X;

  /// A copy of this request for the next filters:
  ///
  /// - [headers] are added to the current ones (a `String` or a `List<String>`; `null` removes
  ///   one).
  /// - The [context] starts with the values of this one (the security context, the language), and
  ///   the [route] is the same.
  /// - Without a [body], the copy shares the body of this request (it's read once, and [body] is
  ///   cached for both). A new [body] is a `String`, bytes or a `Stream<List<int>>`.
  RequestEntity copyWith({
    Map<String, Object?>? headers,
    Object? body,
    Uri? requestedUri,
  }) => RequestEntity._copy(
    method: method,
    requestedUri: requestedUri ?? this.requestedUri,
    protocolVersion: protocolVersion,
    headersAll: mergeHeaders(headersAll, headers),
    context: ContextMap.from(context),
    connectionInfo: connectionInfo,
    body: body == null ? _body : _RequestBody.of(body, encoding ?? utf8),
    route: _route,
  );

  @override
  String toString() => 'RequestEntity{$method ${requestedUri.path}}';
}

/// The fields of a form sent as `application/x-www-form-urlencoded`, read with
/// [RequestEntity.formData]
final class FormData {
  /// Every value of each field, in order (`tag=a&tag=b` => `{tag: [a, b]}`, as several
  /// checkboxes with the same name send). Read-only.
  final Map<String, List<String>> fieldsAll;

  /// The fields, with the last value of a repeated one (`tag=a&tag=b` => `{tag: b}`). Read-only.
  late final Map<String, String> fields = Map.unmodifiable({
    for (final entry in fieldsAll.entries) entry.key: entry.value.last,
  });

  FormData._(this.fieldsAll);

  /// [raw] is `name=Ann+Lee&age=30`: `+` is a space, and the percent-encoded bytes are decoded
  /// with [encoding]. A field without `=` has an empty value.
  factory FormData._parse(String raw, Encoding encoding) {
    final Map<String, List<String>> fields = {};
    for (final String pair in raw.split('&')) {
      if (pair.isEmpty) continue;
      final int equals = pair.indexOf('=');
      final String name = equals < 0 ? pair : pair.substring(0, equals);
      final String value = equals < 0 ? '' : pair.substring(equals + 1);
      (fields[Uri.decodeQueryComponent(name, encoding: encoding)] ??= []).add(
        Uri.decodeQueryComponent(value, encoding: encoding),
      );
    }
    return FormData._(
      Map.unmodifiable({
        for (final entry in fields.entries)
          entry.key: List<String>.unmodifiable(entry.value),
      }),
    );
  }

  /// The field [name] (its last value), or null
  String? operator [](String name) => fields[name];

  /// The field [name] as a [T], or null if it's missing or empty. The types and the errors are
  /// those of [RequestEntity.pathParam] (a value that isn't a [T] is a 400).
  T? field<T extends Object>(String name, {List<T>? values}) {
    final String? raw = fields[name];
    if (raw == null || raw.isEmpty) return null;
    return RequestEntity._parseParam<T>('form field', name, raw, values);
  }

  @override
  String toString() => 'FormData{${fieldsAll.keys.join(', ')}}';
}

/// The body of a request: a stream that is read once, and the bytes cached when they are read
/// whole (by `body<T>()`), shared by the copies of the request
class _RequestBody {
  Stream<List<int>> _stream;

  /// The length, when the body was given whole (bytes or a String)
  final int? length;

  bool _read = false;
  Future<List<int>>? _bytes;
  String? _text;

  _RequestBody(this._stream, {this.length});

  factory _RequestBody.of(Object? body, Encoding encoding) {
    final List<int>? bytes = switch (body) {
      null => const [],
      final String text => encoding.encode(text),
      final List<int> raw => raw,
      _ => null,
    };
    if (bytes != null) {
      return _RequestBody(Stream.value(bytes), length: bytes.length);
    }
    if (body is Stream<List<int>>) return _RequestBody(body);
    throw ArgumentError.value(
      body,
      'body',
      'A request body is a String, a List<int> or a Stream<List<int>>',
    );
  }

  Stream<List<int>> read() {
    if (_read) {
      throw StateError(
        'The body of the request was already read: use `body<T>()`, which caches it',
      );
    }
    _read = true;
    return _stream;
  }

  Future<String> text(Encoding encoding) async {
    _bytes ??= _collect();
    return _text ??= encoding.decode(await _bytes!);
  }

  Future<List<int>> _collect() async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    await for (final chunk in read()) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}

/// The values of the params of [templateUrl] (`/user/{name}`) in [urlPath] (`/user/adam`),
/// URL-decoded: `{name: adam}`
Map<String, String> _extractPathParams(String templateUrl, String urlPath) =>
    PathTemplate.of(templateUrl)
        .extract(urlPath)
        .map((key, value) => MapEntry(key, _decodePathParam(value)));

/// Decode the percent-encoding of a path param (`John%20Doe` => `John Doe`)
/// If the value is not a valid encoding, it's returned as it is
String _decodePathParam(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

/// The request of `dart:io` that the server received, its headers read without copying them.
/// The server limits the size of its body (`ServerConfig.maxBodySize`) in the pipeline, like for a
/// request built in memory. Internal: not exported by `winter.dart`.
RequestEntity requestFromHttpRequest(HttpRequest request) =>
    RequestEntity._copy(
      method: request.method.toUpperCase(),
      requestedUri: request.requestedUri,
      protocolVersion: request.protocolVersion,
      headersAll: ioHeaders(request.headers),
      context: ContextMap(),
      connectionInfo: request.connectionInfo,
      body: _RequestBody(request),
    );

/// Sets the route that answers [request] (the server does it once it's resolved). Internal: not
/// exported by `winter.dart`.
void attachRoute(RequestEntity request, Route route) {
  if (request._route != null) {
    throw StateError('The route of $request is already ${request._route}');
  }
  request._attach(route);
}

/// Limits the body of [request] to [maxBytes] (`ServerConfig.maxBodySize`): reading a bigger one is
/// a [PayloadTooLargeException] (413); a body nobody reads is never rejected. Internal.
void limitRequestBody(RequestEntity request, int maxBytes) {
  final _RequestBody body = request._body;
  body._stream = limitBodySize(
    body._stream,
    maxBytes: maxBytes,
    contentLength: request.contentLength,
  );
}

/// Fail (with a [PayloadTooLargeException], a 413) when the body is bigger than [maxBytes].
///
/// The check is done while the body is read, so a request is only rejected if its body is used,
/// and the body is never fully loaded in memory:
/// - if the `Content-Length` header is bigger than the limit, it fails before reading anything
/// - otherwise (ex: chunked requests) it fails as soon as the read bytes exceed the limit
Stream<List<int>> limitBodySize(
  Stream<List<int>> body, {
  required int maxBytes,
  int? contentLength,
}) async* {
  if (contentLength != null && contentLength > maxBytes) {
    throw const PayloadTooLargeException();
  }

  int readBytes = 0;
  await for (final chunk in body) {
    readBytes += chunk.length;
    if (readBytes > maxBytes) {
      throw const PayloadTooLargeException();
    }
    yield chunk;
  }
}

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
/// The server builds it from the `HttpRequest` of `dart:io` ([RequestEntity.fromHttpRequest]),
/// and a test builds it in memory:
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
  static const String _routingContextKey = 'winter.context.route';

  /// The method, in upper case (`GET`, `POST`...)
  final String method;

  /// The absolute URI of the request, with its query
  final Uri requestedUri;

  /// The HTTP version (`1.1`)
  final String protocolVersion;

  /// Every value of each header, case insensitive (`headersAll['set-cookie']`). Read-only.
  final Map<String, List<String>> headersAll;

  /// Data of this request for the filters and the handler (the security context, the route...).
  /// The copies of [copyWith] start with the same entries.
  final Map<String, Object> context;

  /// The connection of the client (null in memory), used by [clientIp]
  final HttpConnectionInfo? connectionInfo;

  /// The body, shared by the copies of this request: it's read once
  final _RequestBody _body;

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
    Map<String, Object>? context,
    this.protocolVersion = '1.1',
    this.connectionInfo,
  }) : method = method.toUpperCase(),
       headersAll = headersAllOf(headers),
       context = {...?context},
       _body = _RequestBody.of(body, encoding ?? utf8) {
    _restorePathParams();
  }

  RequestEntity._copy({
    required this.method,
    required this.requestedUri,
    required this.protocolVersion,
    required this.headersAll,
    required this.context,
    required this.connectionInfo,
    required this._body,
  }) {
    _restorePathParams();
  }

  /// The request of `dart:io` that the server received. The server limits the size of its body
  /// (`ServerConfig.maxBodySize`) in the pipeline, like for a request built in memory.
  factory RequestEntity.fromHttpRequest(HttpRequest request) =>
      RequestEntity._copy(
        method: request.method.toUpperCase(),
        requestedUri: request.requestedUri,
        protocolVersion: request.protocolVersion,
        headersAll: ioHeaders(request.headers),
        context: {},
        connectionInfo: request.connectionInfo,
        body: _RequestBody(request),
      );

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

  RequestRoutingContext? get routingContext =>
      context[_routingContextKey] as RequestRoutingContext?;

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

  void setRoutingContext(RequestRoutingContext requestRoutingContext) {
    if (routingContext != null) {
      throw StateError(
        'A routing context already configured for this request. Old: Key: ${routingContext!.key} Method: ${routingContext?.method.name ?? 'PARENT'} Path: ${routingContext!.path}. NEW: Key: ${requestRoutingContext.key} Method: ${requestRoutingContext.method.name} Path: ${requestRoutingContext.path}',
      );
    }

    context[_routingContextKey] = requestRoutingContext;
    _restorePathParams();
  }

  ///A copy (or a request with a routing context) has the path params of its route
  void _restorePathParams() {
    final RequestRoutingContext? routing = routingContext;
    if (routing != null) {
      _pathParams = Map.unmodifiable(
        _extractPathParams(routing.path, requestedUri.path),
      );
    }
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

  static bool _isJson(String? mimeType) =>
      mimeType == MediaType.applicationJson.mimeType ||
      (mimeType != null && mimeType.endsWith('+json'));

  static Type _typeOf<X>() => X;

  /// A copy of this request for the next filters:
  ///
  /// - [headers] are added to the current ones (a `String` or a `List<String>`; `null` removes
  ///   one).
  /// - [context] entries are added to the current ones (the security context and the route are
  ///   kept).
  /// - Without a [body], the copy shares the body of this request (it's read once, and [body] is
  ///   cached for both). A new [body] is a `String`, bytes or a `Stream<List<int>>`.
  RequestEntity copyWith({
    Map<String, Object?>? headers,
    Map<String, Object>? context,
    Object? body,
    Uri? requestedUri,
  }) => RequestEntity._copy(
    method: method,
    requestedUri: requestedUri ?? this.requestedUri,
    protocolVersion: protocolVersion,
    headersAll: mergeHeaders(headersAll, headers),
    context: {...this.context, ...?context},
    connectionInfo: connectionInfo,
    body: body == null ? _body : _RequestBody.of(body, encoding ?? utf8),
  );

  @override
  String toString() => 'RequestEntity{$method ${requestedUri.path}}';
}

/// The body of a request: a stream that is read once, and the bytes cached when they are read
/// whole (by `body<T>()`), shared by the copies of the request
class _RequestBody {
  final Stream<List<int>> _stream;

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

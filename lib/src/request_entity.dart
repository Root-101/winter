import 'dart:convert';
import 'dart:io' show HttpConnectionInfo;

import 'package:winter/src/router/path_template.dart';
import 'package:winter/winter.dart';

class RequestEntity extends Request {
  static const String _routingContextKey = 'winter.context.route';

  Map<String, String>? _pathParams;
  Map<String, String>? _queryParams;

  ///Override default implementation of context since the default is an unmodified map and we are gonna use it for adding info like security, routing...
  final Map<String, Object> _context = {};

  @override
  Map<String, Object> get context => _context;

  RequestRoutingContext? get routingContext =>
      context[_routingContextKey] as RequestRoutingContext?;

  RequestEntity(
    super.method,
    super.requestedUri, {
    super.protocolVersion,
    super.headers,
    super.handlerPath,
    super.url,
    super.body,
    super.encoding,
    Map<String, Object>? context,
  }) {
    this.context.addAll(context ?? {});

    //if this context include the routing, we re-extract the params
    RequestRoutingContext? newRoutingContext =
        this.context[_routingContextKey] as RequestRoutingContext?;
    if (newRoutingContext != null) {
      _pathParams = _extractPathParams(
        routingContext!.path,
        requestedUri.toString(),
      );
    }

    _queryParams = _extractQueryParams(requestedUri.toString());
  }

  HttpMethod get httpMethod => HttpMethod(method);

  ///IP address of the client (null if unknown, ex: a request built in a test).
  ///
  ///By default it's the address of the connection, `X-Forwarded-For` is ignored because
  ///any client can send it with a fake IP (ex: to bypass a rate limiter).
  ///Behind proxies, set [trustedProxies] to how many proxies (that you control) add
  ///their entry to `X-Forwarded-For`: the entry added by the last of them is the client.
  String? clientIp({int trustedProxies = 0}) {
    final connectionIp =
        (context['shelf.io.connection_info'] as HttpConnectionInfo?)
            ?.remoteAddress
            .address;
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

  Map<String, String> get queryParams => _queryParams ?? {};

  Map<String, String> get pathParams => _pathParams ?? {};

  void setRoutingContext(RequestRoutingContext requestRoutingContext) {
    if (routingContext != null) {
      throw StateError(
        'A routing context already configured for this request. Old: Key: ${routingContext!.key} Method: ${routingContext?.method.name ?? 'PARENT'} Path: ${routingContext!.path}. NEW: Key: ${requestRoutingContext.key} Method: ${requestRoutingContext.method.name} Path: ${requestRoutingContext.path}',
      );
    }

    context[_routingContextKey] = requestRoutingContext;

    _pathParams = _extractPathParams(
      routingContext!.path,
      requestedUri.toString(),
    );
  }

  ///Cached raw body, the request stream can only be read once.
  ///It's a Future (not a String) so concurrent calls share the same read
  Future<String>? _rawBody;

  ///The raw body once it's read, needed by [change] (which is sync)
  String? _rawBodyValue;

  Future<String> _readRawBody() =>
      _rawBody ??= readAsString(encoding)
          .then((value) => _rawBodyValue = value);

  /// Get the body of the request, it's get parsed with the ObjectMapper in the process
  /// The raw body is cached, so this method can be called multiple times (even with different types)
  /// Note: after calling it, [read] & [readAsString] can't be used (the stream is already consumed)
  Future<T> body<T>({ObjectMapper? om}) async {
    String rawString = await _readRawBody();
    return (om ?? Winter.context.objectMapper).deserialize<T>(rawString);
  }

  ///The copy with needs to be async because if the body is not passed,
  ///we need to read the body from the request
  Future<RequestEntity> copyWith({
    Map<String, /* String | List<String> */ Object>? headers,
    Object? body,
    Encoding? encoding,
    Map<String, Object>? context,
  }) async {
    return RequestEntity(
      method,
      requestedUri,
      url: url,
      protocolVersion: protocolVersion,
      handlerPath: handlerPath,
      body: body ?? (await _readRawBody()),
      headers: headers ?? this.headers,
      encoding: encoding ?? this.encoding,
      context: context ?? this.context,
    );
  }

  ///Same as [Request.change] (used by shelf middlewares) but returns a [RequestEntity].
  ///If the body was already read with [body], the new request reuses it.
  @override
  RequestEntity change({
    Map<String, /* String | List<String> */ Object?>? headers,
    Map<String, Object?>? context,
    String? path,
    Object? body,
  }) {
    final Request changed = super.change(
      headers: headers,
      context: context,
      path: path,
      body: body ?? _rawBodyValue,
    );
    return RequestEntity(
      changed.method,
      changed.requestedUri,
      protocolVersion: changed.protocolVersion,
      headers: changed.headersAll,
      handlerPath: changed.handlerPath,
      url: changed.url,
      body: changed.read(),
      encoding: changed.encoding,
      context: changed.context,
    );
  }
}

///The path params need to be initialized with a 'template'
///For the url:
///   /user/adam/details
///
///A possible template could be:
///   /user/{name}/details
///
/// With this set-up the path params will be: {name: adam}
///
/// But the same url (/user/adam/details), with the template:
///   /user/adam/{action}
///
/// Will give the params: {action: details}
///
/// Or with the template:
///   /user/{name}/{action}
///
/// Will give the params: {name: adam, action: details}
///
/// Basically at the time of the request is first made, this template is not available,
/// only after the route is selected with the template o is manually configured,
/// only after this the path params are configured, any other case the params will be an empty map
Map<String, String> _extractPathParams(String templateUrl, String actualUrl) {
  actualUrl = Uri.parse(actualUrl).path; //remove http(s)://domain.com

  return PathTemplate.of(templateUrl)
      .extract(actualUrl)
      .map((key, value) => MapEntry(key, _decodePathParam(value)));
}

/// Decode the percent-encoding of a path param (`John%20Doe` => `John Doe`)
/// If the value is not a valid encoding, it's returned as it is
String _decodePathParam(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

/// Extract query params from the url
///
/// In the case of the url:
/// http(s)://domain.com/some-url?id=5&name=adam
///
/// The query params will be:
/// { id: 5, name: adam}
Map<String, String> _extractQueryParams(String actualUrl) {
  Uri uri = Uri.parse(actualUrl);

  ///wrapped in a Map.of to avoid unmodifiable map
  return Map.of(uri.queryParameters);
}

import 'dart:convert';

import 'package:winter/winter.dart';

class RequestRoutingContext {
  final String path;
  final String key;
  final HttpMethod method;

  RequestRoutingContext({
    required this.path,
    required this.key,
    required this.method,
  });
}

class RequestEntity extends Request {
  static const String _routingContextKey = 'winter.route.context';

  Map<String, String>? _pathParams;
  Map<String, String>? _queryParams;

  ///Override default implementation of context since the default one is an unmodified map and we are gonna use it for adding info in security, routing...
  @override
  Map<String, Object> context = {};

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

  /// Get the body of the request, it's get parsed with the ObjectMapper in the process
  /// It's also get cached in case the method is called multiple times
  Future<T?> body<T>({ObjectMapper? om}) async {
    if (_cachedBody == null || _cachedBody is! T) {
      String rawString = await readAsString(encoding);
      _cachedBody = (om ?? Winter.context.objectMapper).deserialize<T>(
        rawString,
      );
    }
    return _cachedBody as T;
  }

  ///Cached body (if any)
  Object? _cachedBody;

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
      body: body ?? _cachedBody ?? (await this.body()),
      headers: headers ?? this.headers,
      encoding: encoding ?? this.encoding,
      context: context ?? this.context,
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

  /// Separate the part of the URL that contains the query parameters (if any)
  String templateUrlPath = templateUrl.split('?').first;
  String actualUrlPath = actualUrl.split('?').first;

  /// Create a regular expression to find path parameters in the template
  final RegExp pathParamPattern = RegExp(r'{([^}]+)}');

  /// Create a regular expression to capture the corresponding values in the actual URL
  int pIndex = 0;
  String regexPattern = templateUrlPath.replaceAllMapped(pathParamPattern, (
    match,
  ) {
    String content = match.group(1)!;
    String regex = content.contains('|')
        ? content.split('|').skip(1).join('|')
        : r'([^/?]+)';
    return '(?<p${pIndex++}>$regex)';
  });

  /// Add the start (^) and optional end ($) to ensure a complete match
  regexPattern = '^$regexPattern\$';

  /// Make .* and .+ non-greedy by default if they are not already.
  /// This allows segments separated by literal slashes to match as expected
  /// when using regex in the path.
  regexPattern = regexPattern
      .replaceAll(RegExp(r'\.\*(?!\?)'), '.*?')
      .replaceAll(RegExp(r'\.\+(?!\?)'), '.+?');

  /// Finding the values of the route parameters in the actual URL
  final RegExpMatch? matchUrl = RegExp(regexPattern).firstMatch(actualUrlPath);

  /// Create empty map to storage possible values
  Map<String, String> pathParam = {};

  if (matchUrl == null) return pathParam;

  /// Get all matches
  Iterable<RegExpMatch> matches = pathParamPattern.allMatches(templateUrlPath);

  /// Get every path-param for every match
  pIndex = 0;
  for (final RegExpMatch match in matches) {
    String content = match.group(1)!;
    String paramName = content.split('|').first;
    String groupName = 'p${pIndex++}';
    String paramValue = matchUrl.namedGroup(groupName) ?? '';
    pathParam[paramName] = paramValue;
  }

  ///return founded params
  return pathParam;
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

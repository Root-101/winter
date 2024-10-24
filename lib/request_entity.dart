import 'dart:convert';

import 'winter.dart';

class RequestEntity extends Request {
  Map<String, String>? _pathParams;
  Map<String, String>? _queryParams;
  String? _pathTemplate;

  RequestEntity(
    super.method,
    super.requestedUri, {
    super.protocolVersion,
    super.headers,
    super.handlerPath,
    super.url,
    super.body,
    super.encoding,
    super.context,
    String? pathTemplate,
  }) {
    _queryParams = _extractQueryParams(requestedUri.toString());
    if (pathTemplate != null) {
      setUpPathParams(pathTemplate);
    }
  }

  HttpMethod get httpMethod => HttpMethod(method);

  Map<String, String> get queryParams => _queryParams ?? {};

  Map<String, String> get pathParams => _pathParams ?? {};

  String? get pathTemplate => _pathTemplate;

  ///The path params need to be initialized with a template
  ///For the url:
  ///   /user/adam/details
  ///
  ///A possible template could be:
  ///   /user/{name}/details
  ///
  /// With this set-up the path params will be: {id: 1234}
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
  void setUpPathParams(String template) {
    _pathTemplate = template;
    _pathParams = _extractPathParams(
      template,
      requestedUri.toString(),
    );
  }

  /// Get the body of the request, it's get parsed with the ObjectMapper in the process
  /// It's algo get cached in case the method is called multiple times
  Future<T?> body<T>({ObjectMapper? om}) async {
    if (_cachedBody == null || _cachedBody is! T) {
      String rawString = await readAsString(encoding);
      _cachedBody = (om ?? Winter.instance.context.objectMapper)
          .deserialize<T>(rawString);
    }
    return _cachedBody as T;
  }

  ///Cached body (if any)
  Object? _cachedBody;

  RequestEntity copyWith({
    Map<String, /* String | List<String> */ Object>? headers,
    Object? body,
    Encoding? encoding,
    Map<String, Object>? context,
  }) {
    return RequestEntity(
      method,
      requestedUri,
      url: url,
      protocolVersion: protocolVersion,
      pathTemplate: pathTemplate,
      handlerPath: handlerPath,
      body: body ?? _cachedBody ?? read(),
      headers: headers ?? this.headers,
      encoding: encoding ?? this.encoding,
      context: context ?? this.context,
    );
  }
}

Map<String, String> _extractPathParams(String templateUrl, String actualUrl) {
  actualUrl = Uri.parse(actualUrl).path; //remove http(s)://domain.com

  /// Separate the part of the URL that contains the query parameters (if any)
  String templateUrlPath = templateUrl.split('?').first;
  String actualUrlPath = actualUrl.split('?').first;

  /// Create a regular expression to find path parameters in the template
  final RegExp pathParamPattern = RegExp(r'{([^}]+)}');

  /// Create a regular expression to capture the corresponding values in the actual URL
  String regexPattern = templateUrlPath.replaceAllMapped(
    pathParamPattern,
    (match) => r'([^/?]+)',
  );

  /// Add the start (^) and optional end ($) to ensure a complete match
  regexPattern = '^$regexPattern';

  /// Finding the values of the route parameters in the actual URL
  final RegExpMatch? matchUrl = RegExp(regexPattern).firstMatch(actualUrlPath);

  /// Create empty map to storage possible values
  Map<String, String> pathParam = {};

  /// Get all matches
  Iterable<RegExpMatch> matches = pathParamPattern.allMatches(templateUrlPath);

  /// Get every path-param for every match
  int index = 1;
  for (final RegExpMatch match in matches) {
    String paramName = match.group(1)!;
    String paramValue = matchUrl?.group(index++) ?? '';
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

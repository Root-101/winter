import 'dart:convert';

import 'package:winter/src/context/validation/validation.dart'
    show validationRulesOf;
import 'package:winter/src/request_entity.dart' show attachRoute;
import 'package:winter/winter.dart';

/// The OpenAPI 3.1 document of the routes of a router: serve it with `Route.openApi`, and show
/// it with `Route.swaggerUi`.
///
/// ```dart
/// final router = WinterRouter(routes: [...]);
/// router
///   ..addRoute(Route.openApi(openApi: OpenApi(title: 'Users API', version: '1.0.0')))
///   ..addRoute(Route.swaggerUi()); // GET /docs
/// ```
///
/// What it finds by itself, for every route with a handler:
///
/// - the path and the method, and the path params (`{id|[0-9]+}` is an integer, another regex a
///   `pattern`). A path with a regex outside a param can't be written in OpenAPI and is left out.
/// - the security of the `AuthFilter`s that run for the route (global or its own): a Bearer, a
///   Basic or a cookie scheme from its `challenge`, with its 401 (and its 403 when it has rules).
/// - the errors, as Problem Details: a 400 and a 415 for a body, a 404 for a path param, a 422 for
///   a validated body, a 429 for a `RateLimiterFilter`.
///
/// The rest comes from the `RouteDocs` of each route: its summary and tags, its query params,
/// and its bodies (examples and schemas). A route with `RouteDocs.none` is left out.
///
/// {@category OpenAPI}
final class OpenApi {
  /// The title of the API
  final String title;

  /// The version of the API (not of OpenAPI)
  final String version;

  /// What the API does (Markdown)
  final String? description;

  /// The base URLs of the API (`https://api.example.com`); none means the same as the document
  final List<String> servers;

  /// The router to document; null finds the one of the running server (`di`)
  final BaseRouter? router;

  /// The global filters (for their `AuthFilter`s); null takes the ones of the running server
  final FilterConfig? globalFilterConfig;

  /// The mapper that writes the examples; null is the global `om`
  final ObjectMapper? objectMapper;

  /// The document of [router] (or of the running server)
  OpenApi({
    required this.title,
    required this.version,
    this.description,
    this.servers = const [],
    this.router,
    this.globalFilterConfig,
    this.objectMapper,
  });

  /// The document, as JSON. A [StateError] when an example can't be written by the mapper.
  Map<String, Object?> toJson() => _OpenApiBuilder(
    this,
    objectMapper ?? Winter.context.objectMapper,
  ).build();
}

class _OpenApiBuilder {
  final OpenApi api;
  final ObjectMapper mapper;
  final Map<String, Object?> securitySchemes = {};

  _OpenApiBuilder(this.api, this.mapper);

  Map<String, Object?> build() {
    final BaseRouter router =
        api.router ??
        di.tryFind<BaseRouter>() ??
        (throw StateError(
          'OpenApi has no router: give it one, or start the server first',
        ));
    final List<Filter> globalFilters =
        (api.globalFilterConfig ??
                (Winter.isRunning ? Winter.server.globalFilterConfig : null))
            ?.filters ??
        const [];

    final Map<String, Map<String, Object?>> paths = {};
    final Set<String> tags = {};
    for (final Route route in _routesOf(router)) {
      final RouteDocs docs = route.docs ?? const RouteDocs();
      final HttpMethod? method = route.method;
      if (docs.hidden || method == null) continue;
      final String? path = _openApiPath(route.path);
      if (path == null) continue;
      tags.addAll(docs.tags);
      (paths[path] ??= {})[method.name.toLowerCase()] = _operation(
        route,
        docs,
        globalFilters,
      );
    }

    return {
      'openapi': '3.1.0',
      'info': {
        'title': api.title,
        'version': api.version,
        'description': ?api.description,
      },
      if (api.servers.isNotEmpty)
        'servers': [
          for (final String url in api.servers) {'url': url},
        ],
      if (tags.isNotEmpty)
        'tags': [
          for (final String tag in tags) {'name': tag},
        ],
      'paths': paths,
      'components': {
        'schemas': _problemSchemas,
        'responses': _problemResponses,
        if (securitySchemes.isNotEmpty) 'securitySchemes': securitySchemes,
      },
    };
  }

  static Iterable<Route> _routesOf(BaseRouter router) sync* {
    switch (router) {
      case WinterRouter():
        yield* router.routes;
      case MultiRouter():
        for (final BaseRouter inner in router.routers) {
          yield* _routesOf(inner);
        }
    }
  }

  static final RegExp _param = RegExp(r'{([^}|]+)(?:\|([^}]*))?}');
  static final RegExp _regexChars = RegExp(r'[*+?()\[\]|\\^$]');

  /// `ApiKey header="X-API-Key"` (or `query="key"`, `cookie="key"`): where the key goes
  static final RegExp _apiKeyIn = RegExp(r'(header|query|cookie)="([^"]*)"');

  /// `/users/{id|[0-9]+}` → `/users/{id}`; null when a regex is outside a param (`/files/.*`)
  static String? _openApiPath(String path) {
    final String openApiPath = path.replaceAllMapped(
      _param,
      (m) => '{${m[1]}}',
    );
    return openApiPath.replaceAll(_param, '').contains(_regexChars)
        ? null
        : openApiPath;
  }

  Map<String, Object?> _operation(
    Route route,
    RouteDocs docs,
    List<Filter> globalFilters,
  ) {
    final _Protection protection = _protection(route, globalFilters);
    final List<Map<String, Object?>> pathParams = [
      for (final Match param in _param.allMatches(route.path))
        {
          'name': param[1],
          'in': 'path',
          'required': true,
          'schema': _paramSchema(param[2]),
        },
    ];
    final _Body? request = docs.request == null ? null : _body(docs.request);
    final bool validated =
        docs.request is Validatable ||
        docs.request is AsyncValidatable ||
        (docs.request is BodyDocs &&
            (docs.request! as BodyDocs).rulesFrom != null);

    final Map<String, Object?> responses = {
      '${docs.status}': _response(
        docs.status,
        docs.status == 204 || docs.response == null
            ? null
            : _body(docs.response),
      ),
      for (final MapEntry(key: status, value: body) in docs.responses.entries)
        '$status': _response(status, body is String ? null : _body(body), body),
    };
    void error(int status, String component) => responses.putIfAbsent(
      '$status',
      () => {r'$ref': '#/components/responses/$component'},
    );
    if (request != null || pathParams.isNotEmpty || docs.query.isNotEmpty) {
      error(400, 'BadRequest');
    }
    if (protection.authenticated) error(401, 'Unauthorized');
    if (protection.rules) error(403, 'Forbidden');
    if (pathParams.isNotEmpty) error(404, 'NotFound');
    if (request != null) error(415, 'UnsupportedMediaType');
    if (validated) error(422, 'ValidationFailed');
    if (protection.rateLimited) error(429, 'TooManyRequests');

    return {
      'summary': ?docs.summary,
      'description': ?docs.description,
      'operationId': ?docs.operationId,
      if (docs.tags.isNotEmpty) 'tags': docs.tags,
      if (docs.deprecated) 'deprecated': true,
      if (pathParams.isNotEmpty || docs.query.isNotEmpty)
        'parameters': [
          ...pathParams,
          for (final QueryParam param in docs.query)
            {
              'name': param.name,
              'in': 'query',
              'required': param.required,
              'description': ?param.description,
              'schema': param.schema.toJson(),
            },
        ],
      if (request != null)
        'requestBody': {
          'required': true,
          'description': ?request.description,
          'content': request.content,
        },
      'responses': responses,
      if (protection.scheme != null)
        'security': [
          {protection.scheme: <String>[]},
        ],
    };
  }

  static Map<String, Object?> _response(
    int status,
    _Body? body, [
    Object? docs,
  ]) => {
    'description':
        (docs is String ? docs : null) ??
        body?.description ??
        StatusCode.resolve(status)?.reasonPhrase ??
        'Response',
    if (body != null) 'content': body.content,
  };

  /// `[0-9]+` or `\d+` is an integer; another regex a string with that pattern
  static Map<String, Object?> _paramSchema(String? regex) {
    if (regex == null) return {'type': 'string'};
    if (RegExp(r'^(\[0-9\]|\\d)(\+|\*|\{\d+(,\d*)?\})?$').hasMatch(regex)) {
      return {'type': 'integer'};
    }
    return {'type': 'string', 'pattern': '^$regex\$'};
  }

  /// A body of [RouteDocs]: an example, a [JsonSchema] or a [BodyDocs]
  _Body _body(Object? docs) {
    final BodyDocs body = switch (docs) {
      final BodyDocs body => body,
      final JsonSchema schema => BodyDocs(schema: schema),
      _ => BodyDocs(example: docs),
    };
    final Object? example = body.example;
    final Object? json = example == null ? null : _write(example);
    JsonSchema? schema = body.schema;
    if (schema == null && json != null) {
      schema = JsonSchema.fromExample(json);
      final Validatable? model =
          body.rulesFrom ?? (example is Validatable ? example : null);
      if (model != null) {
        schema = schema.withRules(validationRulesOf(model), mapper);
      }
    }
    return _Body(
      description: body.description,
      content: {
        body.contentType: {
          if (schema != null) 'schema': schema.toJson(),
          'example': ?json,
        },
      },
    );
  }

  Object? _write(Object example) {
    try {
      return mapper.serialize(example);
    } on MissingSerializerError {
      throw StateError(
        'The example ${example.runtimeType} of the OpenAPI docs has no toJson() nor serializer: '
        'give its JSON in BodyDocs(example: {...}, rulesFrom: model)',
      );
    }
  }

  /// The `AuthFilter`s and `RateLimiterFilter`s that run for [route], found by running their
  /// `shouldFilter` with a request to it
  _Protection _protection(Route route, List<Filter> globalFilters) {
    final RequestEntity request = RequestEntity(
      route.method?.name.toUpperCase() ?? 'GET',
      Uri.parse(
        'http://localhost${route.path.replaceAllMapped(_param, (_) => '1')}',
      ),
    );
    attachRoute(request, route);
    _Protection protection = const _Protection();
    for (final Filter filter in [
      ...globalFilters,
      ...route.filterConfig.filters,
    ]) {
      final bool runs;
      try {
        runs = filter.shouldFilter(request);
      } catch (_) {
        continue;
      }
      if (!runs) continue;
      if (filter is AuthFilter &&
          (filter.authenticated || filter.rules != null)) {
        protection = protection.copyWith(
          authenticated: true,
          rules: filter.rules != null,
          scheme: _scheme(filter.challenge),
        );
      } else if (filter is RateLimiterFilter) {
        protection = protection.copyWith(rateLimited: true);
      }
    }
    return protection;
  }

  /// The security scheme of a `WWW-Authenticate` challenge (`Bearer`, `Basic realm="api"`,
  /// `Cookie name="session"`, `ApiKey header="X-API-Key"`, any other HTTP scheme), added to the
  /// components; its name
  String _scheme(String challenge) {
    final String type = challenge.split(' ').first.toLowerCase();
    final (String name, Map<String, Object?> scheme) = switch (type) {
      'bearer' => ('bearerAuth', {'type': 'http', 'scheme': 'bearer'}),
      'basic' => ('basicAuth', {'type': 'http', 'scheme': 'basic'}),
      'cookie' => (
        'cookieAuth',
        {
          'type': 'apiKey',
          'in': 'cookie',
          'name':
              RegExp(r'name="([^"]*)"').firstMatch(challenge)?[1] ?? 'session',
        },
      ),
      'apikey' => (
        'apiKeyAuth',
        {
          'type': 'apiKey',
          'in': _apiKeyIn.firstMatch(challenge)?[1] ?? 'header',
          'name': _apiKeyIn.firstMatch(challenge)?[2] ?? 'X-API-Key',
        },
      ),
      _ => ('${type}Auth', {'type': 'http', 'scheme': type}),
    };
    securitySchemes[name] = scheme;
    return name;
  }

  static final Map<String, Object?> _problemSchemas = {
    'ProblemDetails': {
      'type': 'object',
      'description': 'An error (RFC 9457)',
      'properties': {
        'type': {'type': 'string', 'example': 'about:blank'},
        'title': {'type': 'string', 'example': 'Not Found'},
        'status': {'type': 'integer', 'example': 404},
        'detail': {'type': 'string'},
        'requestId': {'type': 'string'},
      },
      'required': ['type', 'title', 'status'],
    },
    'ValidationProblem': {
      'allOf': [
        {r'$ref': '#/components/schemas/ProblemDetails'},
        {
          'type': 'object',
          'properties': {
            'violations': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'fieldName': {'type': 'string', 'example': 'email'},
                  'message': {'type': 'string'},
                  'code': {'type': 'string', 'example': 'email'},
                  'params': {'type': 'object'},
                },
                'required': ['fieldName', 'message'],
              },
            },
          },
        },
      ],
    },
  };

  static Map<String, Object?> _problem(String description, [String? schema]) =>
      {
        'description': description,
        'content': {
          'application/problem+json': {
            'schema': {
              r'$ref': '#/components/schemas/${schema ?? 'ProblemDetails'}',
            },
          },
        },
      };

  static final Map<String, Object?> _problemResponses = {
    'BadRequest': _problem(
      'A param or the body is not valid (JSON, a type, a field)',
    ),
    'Unauthorized': _problem('Nobody is authenticated'),
    'Forbidden': _problem('Authenticated, but not allowed'),
    'NotFound': _problem('Not found'),
    'UnsupportedMediaType': _problem(
      'The Content-Type of the body is not JSON',
    ),
    'ValidationFailed': _problem(
      'The body has invalid fields',
      'ValidationProblem',
    ),
    'TooManyRequests': _problem('Too many requests: wait for Retry-After'),
  };
}

class _Body {
  final String? description;
  final Map<String, Object?> content;

  _Body({required this.description, required this.content});
}

class _Protection {
  final bool authenticated;
  final bool rules;
  final bool rateLimited;
  final String? scheme;

  const _Protection({
    this.authenticated = false,
    this.rules = false,
    this.rateLimited = false,
    this.scheme,
  });

  _Protection copyWith({
    bool? authenticated,
    bool? rules,
    bool? rateLimited,
    String? scheme,
  }) => _Protection(
    authenticated: authenticated ?? this.authenticated,
    rules: (rules ?? false) || this.rules,
    rateLimited: rateLimited ?? this.rateLimited,
    scheme: scheme ?? this.scheme,
  );
}

/// The handler of `Route.openApi`: the document, built by the first request. Internal.
RequestHandler openApiHandler(OpenApi openApi) {
  Map<String, Object?>? document;
  return (request) => ResponseEntity.ok(body: document ??= openApi.toJson());
}

/// The handler of `Route.swaggerUi`: a page of Swagger UI that reads [specUrl]. Internal.
RequestHandler swaggerUiHandler({
  required String specUrl,
  required String title,
}) {
  final String page = _swaggerPage(specUrl, title);
  return (request) => ResponseEntity.ok(
    body: page,
    headers: {
      HttpHeader.contentType: 'text/html; charset=utf-8',
      // Swagger UI comes from a CDN and starts with an inline script
      HttpHeader.contentSecurityPolicy:
          "default-src 'none'; script-src 'unsafe-inline' https://unpkg.com; "
          "style-src 'unsafe-inline' https://unpkg.com; img-src 'self' data: https://unpkg.com; "
          "connect-src 'self'",
      HttpHeader.xFrameOptions: 'DENY',
    },
  );
}

/// The version of Swagger UI of the page (pinned, so the page never changes by itself)
const String _swaggerUiVersion = '5.17.14';

String _swaggerPage(String specUrl, String title) =>
    '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${const HtmlEscape().convert(title)}</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@$_swaggerUiVersion/swagger-ui.css">
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@$_swaggerUiVersion/swagger-ui-bundle.js"></script>
  <script>
    SwaggerUIBundle({url: ${jsonEncode(specUrl)}, dom_id: '#swagger-ui', deepLinking: true});
  </script>
</body>
</html>
''';

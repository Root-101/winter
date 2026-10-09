import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

enum _Plan { free, pro }

class _Address implements Validatable {
  final String zip;

  _Address(this.zip);

  Map<String, Object?> toJson() => {'zipCode': zip};

  @override
  ConstraintValidatorContext validate() =>
      ConstraintValidatorContext()
        ..field('zipCode', zip).notNull().pattern(RegExp(r'^\d{5}$'));
}

class _Item implements Validatable {
  final int quantity;

  _Item(this.quantity);

  Map<String, Object?> toJson() => {'quantity': quantity};

  @override
  ConstraintValidatorContext validate() =>
      ConstraintValidatorContext()..field('quantity', quantity).positive();
}

class _CreateUser implements Validatable {
  final String name;
  final String email;
  final int age;
  final String plan;
  final String website;
  final _Address address;
  final List<_Item> items;

  _CreateUser(
    this.name,
    this.email,
    this.age,
    this.plan,
    this.website,
    this.address,
    this.items,
  );

  Map<String, Object?> toJson() => {
    'fullName': name,
    'email': email,
    'age': age,
    'plan': plan,
    'website': website,
    'address': address,
    'items': items,
  };

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('fullName', name).notNull().notBlank().size(max: 80)
    ..field('email', email).notNull().email()
    ..field('age', age).min(18).max(120, inclusive: false)
    ..field('plan', plan).isEnum(_Plan.values)
    ..field('website', website).url()
    ..field('address', address).notNull().valid()
    ..field('items', items).notEmpty().size(max: 10).validEach()
    // A custom rule is never run while describing
    ..field('email', email).custom((_) => throw StateError('never run'));
}

class _NoJson {}

class _HeaderAuth extends Filter {
  @override
  Future<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) =>
      Future.value(chain.doFilter(request));
}

_CreateUser _example() => _CreateUser(
  'Ann Lee',
  'ann@example.com',
  30,
  'pro',
  'https://ann.dev',
  _Address('28001'),
  [_Item(2)],
);

Future<ResponseEntity> _ok(RequestEntity request) async => ResponseEntity.ok();

void main() {
  group('JsonSchema', () {
    test('the constructors write JSON Schema, a nullable type as a list', () {
      expect(
        JsonSchema.object(
          {
            'amount': JsonSchema.number(minimum: 0.01),
            'currency': JsonSchema.string(enumValues: ['EUR', 'USD']),
            'note': JsonSchema.string(maxLength: 200, nullable: true),
            'tags': JsonSchema.array(JsonSchema.string(), uniqueItems: true),
            'prices': JsonSchema.map(JsonSchema.integer()),
          },
          required: ['amount', 'currency'],
        ).toJson(),
        {
          'type': 'object',
          'properties': {
            'amount': {'type': 'number', 'minimum': 0.01},
            'currency': {
              'type': 'string',
              'enum': ['EUR', 'USD'],
            },
            'note': {
              'type': ['string', 'null'],
              'maxLength': 200,
            },
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
              'uniqueItems': true,
            },
            'prices': {
              'type': 'object',
              'additionalProperties': {'type': 'integer'},
            },
          },
          'required': ['amount', 'currency'],
        },
      );
      expect(JsonSchema.any().toJson(), isEmpty);
      expect(JsonSchema.raw({r'$ref': '#/x'}).toJson(), {r'$ref': '#/x'});
      expect(JsonSchema.boolean().toJson(), {'type': 'boolean'});
    });

    test('fromExample infers types, objects, arrays and date-times', () {
      expect(
        JsonSchema.fromExample({
          'id': 7,
          'price': 1.5,
          'paid': true,
          'at': '2026-01-02T00:00:00.000Z',
          'note': null,
          'tags': ['a'],
          'empty': <Object?>[],
        }).toJson(),
        {
          'type': 'object',
          'properties': {
            'id': {'type': 'integer'},
            'price': {'type': 'number'},
            'paid': {'type': 'boolean'},
            'at': {'type': 'string', 'format': 'date-time'},
            'note': <String, Object?>{},
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'empty': {'type': 'array', 'items': <String, Object?>{}},
          },
        },
      );
    });
  });

  group('A document from a router', () {
    late Map<String, Object?> document;
    late WinterRouter router;

    Map<String, Object?> operation(String path, String method) =>
        ((document['paths'] as Map)[path] as Map)[method]
            as Map<String, Object?>;

    setUpAll(() {
      router = WinterRouter(
        routes: [
          Route.post(
            path: '/users',
            handler: _ok,
            filterConfig: FilterConfig([AuthFilter(rules: hasRole('admin'))]),
            docs: RouteDocs(
              summary: 'Create a user',
              tags: ['users'],
              status: 201,
              operationId: 'createUser',
              request: _example(),
              // A JSON example is written as the client sees it: the JSON names
              response: {'id': 7, 'full_name': 'Ann Lee'},
              responses: {
                409: 'The email is already registered',
                418: JsonSchema.object({'tea': JsonSchema.string()}),
              },
            ),
          ),
          Route.parent(
            path: '/orders',
            docs: const RouteDocs(tags: ['orders']),
            routes: [
              Route.get(
                path: '/{id|[0-9]+}',
                handler: _ok,
                docs: const RouteDocs(summary: 'An order'),
              ),
              Route.get(path: '/by-code/{code|[A-Z][A-Z][A-Z]}', handler: _ok),
              Route.get(
                path: '/',
                handler: _ok,
                docs: RouteDocs(
                  query: [
                    QueryParam(
                      'page',
                      JsonSchema.integer(minimum: 1),
                      description: 'The page',
                    ),
                  ],
                ),
              ),
            ],
          ),
          Route.put(
            path: '/raw',
            handler: _ok,
            docs: RouteDocs(
              request: BodyDocs(
                example: {'full_name': 'Ann', 'email': 'ann@example.com'},
                rulesFrom: _example(),
                description: 'A user, as JSON',
              ),
              response: BodyDocs(
                schema: JsonSchema.object({'ok': JsonSchema.boolean()}),
                example: {'ok': true},
              ),
            ),
          ),
          Route.get(path: '/hidden', handler: _ok, docs: RouteDocs.none),
          Route.get(path: '/files/.*', handler: _ok),
          Route.health(checks: {'database': () => true}),
          Route.websocket(path: '/ws', handler: (socket, request) {}),
          Route.get(
            path: '/limited',
            handler: _ok,
            filterConfig: FilterConfig([
              RateLimiterFilter(
                maxRequests: 10,
                window: const Duration(minutes: 1),
              ),
            ]),
          ),
          Route.get(path: '/public', handler: _ok),
        ],
      );
      document = OpenApi(
        title: 'Test API',
        version: '1.2.3',
        description: 'For the tests',
        servers: ['https://api.example.com'],
        router: router,
        globalFilterConfig: FilterConfig([
          _HeaderAuth(),
          AuthFilter(
            challenge: 'Cookie name="sid"',
            shouldFilter: (request) =>
                !request.requestedUri.path.startsWith('/public'),
          ),
        ]),
        objectMapper: ObjectMapper(fieldNaming: FieldNaming.snakeCase),
      ).toJson();
    });

    test('the info, the servers, the tags and the paths', () {
      expect(document['openapi'], '3.1.0');
      expect(document['info'], {
        'title': 'Test API',
        'version': '1.2.3',
        'description': 'For the tests',
      });
      expect(document['servers'], [
        {'url': 'https://api.example.com'},
      ]);
      expect(
        (document['paths'] as Map).keys,
        unorderedEquals([
          '/users',
          '/orders/{id}',
          '/orders/by-code/{code}',
          '/orders',
          '/raw',
          '/health',
          '/limited',
          '/public',
        ]),
      );
      expect(
        (document['tags'] as List).map((tag) => (tag as Map)['name']),
        containsAll(['users', 'orders', 'health']),
      );
    });

    test('the request schema comes from the example and its validate()', () {
      final Map body =
          (((operation('/users', 'post')['requestBody'] as Map)['content']
                  as Map)['application/json']
              as Map);
      final Map schema = body['schema'] as Map;
      final Map properties = schema['properties'] as Map;

      expect(body['example'], containsPair('full_name', 'Ann Lee'));
      expect(schema['required'], ['full_name', 'email', 'address']);
      expect(properties['full_name'], {
        'type': 'string',
        'minLength': 1,
        'maxLength': 80,
      });
      expect(properties['email'], {'type': 'string', 'format': 'email'});
      expect(properties['age'], {
        'type': 'integer',
        'minimum': 18,
        'exclusiveMaximum': 120,
      });
      expect(properties['plan'], {
        'type': 'string',
        'enum': ['free', 'pro'],
      });
      expect(properties['website'], {'type': 'string', 'format': 'uri'});
      expect(properties['address'], {
        'type': 'object',
        'properties': {
          'zip_code': {'type': 'string', 'pattern': r'^\d{5}$'},
        },
        'required': ['zip_code'],
      });
      expect(properties['items'], {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'quantity': {'type': 'integer', 'exclusiveMinimum': 0},
          },
        },
        'minItems': 1,
        'maxItems': 10,
      });
    });

    test('the responses: success, the docs, and the errors found', () {
      final Map responses = operation('/users', 'post')['responses'] as Map;

      expect(responses.keys, [
        '201',
        '409',
        '418',
        '400',
        '401',
        '403',
        '415',
        '422',
      ]);
      expect((responses['201'] as Map)['description'], 'Created');
      expect(
        ((responses['201'] as Map)['content'] as Map)['application/json'],
        {
          'schema': {
            'type': 'object',
            'properties': {
              'id': {'type': 'integer'},
              'full_name': {'type': 'string'},
            },
          },
          'example': {'id': 7, 'full_name': 'Ann Lee'},
        },
      );
      expect(responses['409'], {
        'description': 'The email is already registered',
      });
      expect(
        (((responses['418'] as Map)['content'] as Map)['application/json']
            as Map)['schema'],
        {
          'type': 'object',
          'properties': {
            'tea': {'type': 'string'},
          },
        },
      );
      expect(responses['422'], {
        r'$ref': '#/components/responses/ValidationFailed',
      });
      expect(operation('/users', 'post')['operationId'], 'createUser');
    });

    test('security: the AuthFilter that runs for each route', () {
      expect(operation('/users', 'post')['security'], [
        {'bearerAuth': <String>[]},
      ]);
      expect(operation('/orders/{id}', 'get')['security'], [
        {'cookieAuth': <String>[]},
      ]);
      expect(operation('/public', 'get'), isNot(contains('security')));
      expect((operation('/public', 'get')['responses'] as Map).keys, ['200']);
      final Map schemes =
          (document['components'] as Map)['securitySchemes'] as Map;
      expect(schemes['bearerAuth'], {'type': 'http', 'scheme': 'bearer'});
      expect(schemes['cookieAuth'], {
        'type': 'apiKey',
        'in': 'cookie',
        'name': 'sid',
      });
    });

    test('path and query params, with their types', () {
      expect(operation('/orders/{id}', 'get')['parameters'], [
        {
          'name': 'id',
          'in': 'path',
          'required': true,
          'schema': {'type': 'integer'},
        },
      ]);
      expect(operation('/orders/by-code/{code}', 'get')['parameters'], [
        {
          'name': 'code',
          'in': 'path',
          'required': true,
          'schema': {'type': 'string', 'pattern': r'^[A-Z][A-Z][A-Z]$'},
        },
      ]);
      expect(operation('/orders', 'get')['parameters'], [
        {
          'name': 'page',
          'in': 'query',
          'required': false,
          'description': 'The page',
          'schema': {'type': 'integer', 'minimum': 1},
        },
      ]);
      expect(
        (operation('/orders/{id}', 'get')['responses'] as Map).keys,
        containsAll(['400', '401', '404']),
      );
    });

    test('a child takes the tags of its parent', () {
      expect(operation('/orders/{id}', 'get')['tags'], ['orders']);
      expect(operation('/orders/{id}', 'get')['summary'], 'An order');
      expect(operation('/orders/by-code/{code}', 'get')['tags'], ['orders']);
    });

    test(
      'BodyDocs: a JSON example with the rules of a model, a schema that wins',
      () {
        final Map request =
            ((operation('/raw', 'put')['requestBody'] as Map)['content']
                    as Map)['application/json']
                as Map;
        final Map response =
            (((operation('/raw', 'put')['responses'] as Map)['200']
                        as Map)['content']
                    as Map)['application/json']
                as Map;

        expect(
          (operation('/raw', 'put')['requestBody'] as Map)['description'],
          'A user, as JSON',
        );
        expect((request['schema'] as Map)['required'], ['full_name', 'email']);
        expect(response, {
          'schema': {
            'type': 'object',
            'properties': {
              'ok': {'type': 'boolean'},
            },
          },
          'example': {'ok': true},
        });
      },
    );

    test('health is documented, WebSockets and hidden routes are not', () {
      expect(operation('/health', 'get')['summary'], 'Health check');
      expect(
        (operation('/health', 'get')['responses'] as Map).keys,
        containsAll(['200', '503']),
      );
      expect((document['paths'] as Map), isNot(contains('/ws')));
      expect((document['paths'] as Map), isNot(contains('/hidden')));
    });

    test('a RateLimiterFilter adds a 429', () {
      expect((operation('/limited', 'get')['responses'] as Map)['429'], {
        r'$ref': '#/components/responses/TooManyRequests',
      });
    });

    test('the errors are Problem Details components', () {
      final Map components = document['components'] as Map;

      expect((components['schemas'] as Map).keys, [
        'ProblemDetails',
        'ValidationProblem',
      ]);
      expect(((components['responses'] as Map)['NotFound'] as Map)['content'], {
        'application/problem+json': {
          'schema': {r'$ref': '#/components/schemas/ProblemDetails'},
        },
      });
    });
  });

  group('Serving it', () {
    test(
      'Route.openApi serves the document; Route.swaggerUi the page',
      () async {
        final router = WinterRouter(
          routes: [Route.get(path: '/ping', handler: _ok)],
        );
        router
          ..addRoute(
            Route.openApi(
              openApi: OpenApi(title: 'Ping', version: '1', router: router),
            ),
          )
          ..addRoute(Route.swaggerUi(title: 'Ping <docs>'));
        final client = WinterTestClient.build(router: router);

        final TestResponse spec = await client.get('/openapi.json');
        final TestResponse page = await client.get('/docs');

        expect(spec.statusCode, 200);
        expect(((spec.json as Map)['paths'] as Map).keys, ['/ping']);
        expect(page.headers['content-type'], 'text/html; charset=utf-8');
        expect(page.body, contains('swagger-ui-bundle.js'));
        expect(page.body, contains('url: "/openapi.json"'));
        expect(page.body, contains('Ping &lt;docs&gt;'));
        expect(
          page.headers['content-security-policy'],
          contains('https://unpkg.com'),
        );
      },
    );

    test('a MultiRouter documents the routes of every router', () {
      final Map paths =
          OpenApi(
                title: 'Multi',
                version: '1',
                router: MultiRouter([
                  WinterRouter(
                    basePath: '/v1',
                    routes: [Route.get(path: '/a', handler: _ok)],
                  ),
                  WinterRouter(
                    basePath: '/v2',
                    routes: [Route.get(path: '/b', handler: _ok)],
                  ),
                ]),
              ).toJson()['paths']
              as Map;

      expect(paths.keys, ['/v1/a', '/v2/b']);
    });

    test('an example the mapper can not write says what to do', () {
      expect(
        () => OpenApi(
          title: 'X',
          version: '1',
          router: WinterRouter(
            routes: [
              Route.post(
                path: '/x',
                handler: _ok,
                docs: RouteDocs(request: _NoJson()),
              ),
            ],
          ),
        ).toJson(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('BodyDocs(example: {...}, rulesFrom: model)'),
          ),
        ),
      );
    });

    test('without a router nor a server it is a StateError', () {
      expect(
        () => OpenApi(title: 'X', version: '1').toJson(),
        throwsStateError,
      );
    });

    test('the document is valid JSON', () {
      expect(
        () => jsonEncode(
          OpenApi(
            title: 'X',
            version: '1',
            router: WinterRouter(routes: [Route.health()]),
          ).toJson(),
        ),
        returnsNormally,
      );
    });
  });
}

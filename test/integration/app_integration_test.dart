@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// A whole app, with every system of the framework working together: configuration from the
/// environment, DI (a scoped service), authentication and rules, CORS and security headers, the
/// rate limiter, the object mapper (snake_case), validation that depends on the configuration,
/// messages in the language of the request, Problem Details and logs with the request id.
void main() {
  late List<_Log> logs;
  late List<String> disposed;
  late WinterTestClient client;

  setUp(() {
    logs = [];
    disposed = [];
    final env = Env(env: {'MAX_QUANTITY': '5', 'RATE_LIMIT': '50'});
    final di = DependencyInjection()
      ..put(OrderRepository())
      ..putScoped<OrderService>(
        () => OrderService(Winter.context.dependencyInjection.find()),
        onDispose: (service) => disposed.add(service.user),
      );
    Winter.context.setUp(
      env: env,
      dependencyInjection: di,
      logger: _MemoryLogger(logs),
      objectMapper: ObjectMapper(
        fieldNaming: FieldNaming.snakeCase,
        prettyPrint: false,
        deserializers: [
          Deserializer<CreateOrder>.json(CreateOrder.fromJson),
          Deserializer<OrderItem>.json(OrderItem.fromJson),
        ],
      ),
      localeConfig: LocaleConfig(
        supported: const [WinterLocale.english, WinterLocale.spanish],
      ),
    );

    client = WinterTestClient.build(
      maxBodySize: 2048,
      securityConfig: SecurityConfig(
        cors: const CorsConfig(
          allowedOrigins: ['https://shop.example'],
          allowCredentials: true,
        ),
        securityHeaders: const SecurityHeaders(),
      ),
      globalFilterConfig: FilterConfig([
        LogsFilter(),
        BearerFilter(),
        RateLimiterFilter(
          maxRequests: env.require<int>('RATE_LIMIT'),
          window: const Duration(minutes: 1),
          onRequest: (request) =>
              requestPrincipalOrNull<User>()?.name ?? 'anonymous',
        ),
      ]),
      router: WinterRouter(
        basePath: '/api',
        routes: [
          Route.parent(
            path: '/orders',
            filterConfig: FilterConfig([AuthFilter()]),
            routes: [
              Route.post(
                path: '/',
                filterConfig: hasPermission('orders.create').toFilterConfig(),
                handler: (request) async {
                  final CreateOrder order = await request.body<CreateOrder>();
                  final Order created = await di.find<OrderService>().create(
                    order,
                  );
                  return ResponseEntity.created(
                    location: '/api/orders/${created.id}',
                    body: created,
                  );
                },
              ),
              Route.get(
                path: '/{id}',
                handler: (request) async => ResponseEntity.ok(
                  body: await di.find<OrderService>().find(
                    request.pathParam<int>('id'),
                  ),
                ),
              ),
            ],
          ),
          Route.get(
            path: '/boom',
            handler: (request) => throw StateError('a bug with a secret'),
          ),
        ],
      ),
    );
  });

  tearDown(() {
    Winter.context.setUp(
      env: Env(),
      dependencyInjection: DependencyInjection(),
      logger: const ConsoleLogger(),
      objectMapper: ObjectMapper(),
      localeConfig: LocaleConfig(),
    );
  });

  const origin = {'origin': 'https://shop.example'};
  const ann = {...origin, 'authorization': 'Bearer ann'};
  const bob = {...origin, 'authorization': 'Bearer bob'};
  const json = {'content-type': 'application/json'};

  Map<String, Object?> decode(TestResponse response) =>
      jsonDecode(response.body) as Map<String, Object?>;

  void expectCommonHeaders(TestResponse response) {
    expect(
      response.headers['access-control-allow-origin'],
      'https://shop.example',
    );
    expect(response.headers['access-control-allow-credentials'], 'true');
    expect(response.headers['vary'], contains('Origin'));
    expect(response.headers['x-request-id'], isNotEmpty);
    expect(response.headers['x-content-type-options'], 'nosniff');
    expect(response.headers['x-frame-options'], 'DENY');
    expect(response.headers['referrer-policy'], 'no-referrer');
  }

  group('A valid order', () {
    test('is created, in snake_case, with every header', () async {
      final response = await client.post(
        '/api/orders',
        headers: {...ann, ...json},
        body: {
          'customer_name': 'Ann',
          'items': [
            {'product_id': 'p-1', 'quantity': 2},
          ],
        },
      );

      expect(response.statusCode, 201);
      expect(response.headers['location'], '/api/orders/1');
      expect(decode(response), {
        'id': 1,
        'customer_name': 'Ann',
        'created_by': 'ann',
        'items': [
          {'product_id': 'p-1', 'quantity': 2},
        ],
      });
      expectCommonHeaders(response);
      expect(response.headers['x-ratelimit-limit'], '50');
      // Nothing read the language: the response doesn't depend on it
      expect(response.headers['vary'], isNot(contains('Accept-Language')));
    });

    test(
      'the scoped service is created and disposed once per request',
      () async {
        await client.post(
          '/api/orders',
          headers: {...ann, ...json},
          body: {
            'customer_name': 'Ann',
            'items': [
              {'product_id': 'p-1', 'quantity': 1},
            ],
          },
        );
        final response = await client.get('/api/orders/1', headers: bob);

        expect(response.statusCode, 200);
        expect(decode(response)['created_by'], 'ann');
        expect(disposed, ['ann', 'bob']);
      },
    );
  });

  group('An invalid order', () {
    test(
      'is a 422 in the language of the request, with the JSON names',
      () async {
        final response = await client.post(
          '/api/orders',
          headers: {...ann, ...json, 'accept-language': 'es'},
          body: {
            'customer_name': ' ',
            'items': [
              {'product_id': 'p-1', 'quantity': 9},
            ],
          },
        );

        expect(response.statusCode, 422);
        expect(
          response.headers['content-type'],
          'application/problem+json; charset=utf-8',
        );
        final violations = (decode(response)['violations'] as List)
            .cast<Map<String, Object?>>();
        expect(
          {for (final v in violations) v['fieldName']: v['message']},
          {
            'customer_name': 'El campo no puede estar vacío',
            'items[0].quantity': 'El máximo es 5',
          },
        );
        expectCommonHeaders(response);
        expect(response.headers['vary'], contains('Accept-Language'));
        expect(disposed, isEmpty, reason: 'the service was never found');
      },
    );

    test('a value of the wrong type is a 400 with the JSON path', () async {
      final response = await client.post(
        '/api/orders',
        headers: {...ann, ...json},
        body: '[5]',
      );

      expect(response.statusCode, 400);
      expect(
        decode(response)['detail'],
        r'$: expected an object, got an array',
      );
      expectCommonHeaders(response);
    });

    test('another Content-Type is a 415, a big body a 413', () async {
      final xml = await client.post(
        '/api/orders',
        headers: {...ann, 'content-type': 'application/xml'},
        body: '<order/>',
      );
      final big = await client.post(
        '/api/orders',
        headers: {...ann, ...json},
        body: {'customer_name': 'x' * 4000, 'items': <Object>[]},
      );

      expect(xml.statusCode, 415);
      expect(big.statusCode, 413);
      expectCommonHeaders(xml);
      expectCommonHeaders(big);
    });
  });

  group('Security', () {
    test(
      'nobody is a 401 with a challenge, the service is never created',
      () async {
        final response = await client.post(
          '/api/orders',
          headers: {...origin, ...json},
          body: {'customer_name': 'Ann', 'items': <Object>[]},
        );

        expect(response.statusCode, 401);
        expect(response.headers['www-authenticate'], 'Bearer');
        expect(
          response.headers['content-type'],
          'application/problem+json; charset=utf-8',
        );
        expectCommonHeaders(response);
        expect(disposed, isEmpty);
      },
    );

    test('a user without the permission is a 403', () async {
      final response = await client.post(
        '/api/orders',
        headers: {...bob, ...json},
        body: {'customer_name': 'Bob', 'items': <Object>[]},
      );

      expect(response.statusCode, 403);
      expectCommonHeaders(response);
    });

    test('the rate limit is per user, and the 429 keeps CORS', () async {
      for (var i = 0; i < 50; i++) {
        await client.get('/api/orders/1', headers: bob);
      }
      final limited = await client.get('/api/orders/1', headers: bob);
      final other = await client.get('/api/orders/1', headers: ann);

      expect(limited.statusCode, 429);
      expect(limited.headers['retry-after'], isNotNull);
      expect(limited.headers['x-ratelimit-remaining'], '0');
      expectCommonHeaders(limited);
      expect(other.statusCode, 404);
    });

    test('an OPTIONS that is not a preflight is a 204 with CORS', () async {
      final response = await client.request(
        'OPTIONS',
        '/api/orders/1',
        headers: ann,
      );

      expect(response.statusCode, 204);
      expect(response.headers['allow'], 'GET, HEAD, OPTIONS');
      expectCommonHeaders(response);
    });
  });

  group('Errors and logs', () {
    test('a typed path param of another type is a 400', () async {
      final response = await client.get('/api/orders/abc', headers: ann);

      expect(response.statusCode, 400);
      expect(
        decode(response)['detail'],
        'The path param id must be an integer',
      );
    });

    test(
      'a 500 has the request id, and its log the error, never the client',
      () async {
        final response = await client.get(
          '/api/boom',
          headers: {...ann, 'x-request-id': 'req-123'},
        );

        expect(response.statusCode, 500);
        expect(response.headers['x-request-id'], 'req-123');
        expect(decode(response)['requestId'], 'req-123');
        expect(response.body, isNot(contains('secret')));
        expectCommonHeaders(response);

        final requestLogs = logs.where((log) => log.requestId == 'req-123');
        expect(requestLogs.map((log) => log.level), [
          LogLevel.info,
          LogLevel.error,
          LogLevel.info,
        ]);
        expect(
          requestLogs.map((log) => log.message).join('\n'),
          allOf(contains('GET /api/boom'), contains('=> 500')),
        );
        expect(requestLogs.elementAt(1).error, isA<StateError>());
      },
    );

    test('every log of a request has its id, and no body', () async {
      await client.post(
        '/api/orders',
        headers: {...ann, ...json, 'x-request-id': 'req-1'},
        body: {
          'customer_name': 'Secret Name',
          'items': [
            {'product_id': 'p-1', 'quantity': 1},
          ],
        },
      );

      expect(logs, isNotEmpty);
      expect(logs.every((log) => log.requestId == 'req-1'), isTrue);
      expect(logs.map((log) => log.message).join(), isNot(contains('Secret')));
    });
  });

  test(
    'concurrent requests never mix their user, language nor scope',
    () async {
      Future<TestResponse> create(Map<String, String> user, String language) =>
          client.post(
            '/api/orders',
            headers: {...user, ...json, 'accept-language': language},
            body: {'customer_name': '', 'items': <Object>[]},
          );

      final responses = await Future.wait([
        for (var i = 0; i < 10; i++) ...[create(ann, 'es'), create(bob, 'en')],
      ]);

      for (var i = 0; i < responses.length; i++) {
        final response = responses[i];
        if (i.isEven) {
          expect(response.statusCode, 422);
          expect(response.body, contains('El campo no puede estar vacío'));
        } else {
          expect(response.statusCode, 403);
        }
      }
    },
  );
}

class User {
  final String name;
  final Set<String> permissions;

  const User(this.name, this.permissions);
}

/// `Bearer <name>`: ann can create orders, bob can only read them
class BearerFilter extends Filter {
  static const Map<String, User> _users = {
    'ann': User('ann', {'orders.create'}),
    'bob': User('bob', {}),
  };

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final String? header = request.headers[HttpHeader.authorization];
    final User? user = header == null ? null : _users[header.substring(7)];
    if (user != null) {
      request.securityContext.setAuthentication(
        Authentication<User>(principal: user, permissions: user.permissions),
      );
    }
    return chain.doFilter(request);
  }
}

class CreateOrder implements Validatable {
  final String customerName;
  final List<OrderItem> items;

  const CreateOrder(this.customerName, this.items);

  factory CreateOrder.fromJson(Map<String, Object?> json) => CreateOrder(
    json['customerName'] as String,
    Winter.context.objectMapper.deserialize<List<OrderItem>>(json['items']),
  );

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.field('customerName', customerName).notBlank();
    cvc.field('items', items).validEach();
    return cvc;
  }
}

class OrderItem implements Validatable {
  final String productId;
  final int quantity;

  const OrderItem(this.productId, this.quantity);

  factory OrderItem.fromJson(Map<String, Object?> json) =>
      OrderItem(json['productId'] as String, json['quantity'] as int);

  Map<String, Object?> toJson() => {
    'productId': productId,
    'quantity': quantity,
  };

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc
        .field('quantity', quantity)
        .positive()
        .max(env.require<int>('MAX_QUANTITY'));
    return cvc;
  }
}

class Order {
  final int id;
  final String customerName;
  final String createdBy;
  final List<OrderItem> items;

  const Order(this.id, this.customerName, this.createdBy, this.items);

  Map<String, Object?> toJson() => {
    'id': id,
    'customerName': customerName,
    'createdBy': createdBy,
    'items': items,
  };
}

class OrderRepository {
  final Map<int, Order> _orders = {};

  Future<Order> save(CreateOrder order, String user) async {
    await Future<void>.delayed(Duration.zero);
    final saved = Order(
      _orders.length + 1,
      order.customerName,
      user,
      order.items,
    );
    return _orders[saved.id] = saved;
  }

  Future<Order?> find(int id) async => _orders[id];
}

/// One per request: it reads the user of the request from the scope
class OrderService {
  final OrderRepository repository;
  final String user = requestPrincipal<User>().name;

  OrderService(this.repository);

  Future<Order> create(CreateOrder order) => repository.save(order, user);

  Future<Order> find(int id) async =>
      await repository.find(id) ??
      (throw NotFoundException(detail: 'Order $id not found'));
}

class _Log {
  final LogLevel level;
  final String message;
  final String? requestId;
  final Object? error;

  _Log(this.level, this.message, this.requestId, this.error);
}

class _MemoryLogger extends WinterLogger {
  final List<_Log> logs;

  _MemoryLogger(this.logs);

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => logs.add(_Log(level, message, requestId, error));
}

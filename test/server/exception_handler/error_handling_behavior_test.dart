@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The behavior decided in the review of the error handling (DECISIONS.md §4)
void main() {
  group('An Error (a bug) inside the chain (§4.3)', () {
    late List<int> seenByFilter;
    late WinterTestClient client;

    setUp(() {
      seenByFilter = [];
      client = WinterTestClient.build(
        securityConfig: SecurityConfig(cors: const CorsConfig()),
        globalFilterConfig: FilterConfig([_Spy(seenByFilter)]),
        router: WinterRouter(
          routes: [
            Route.get(path: '/error', handler: (r) => throw StateError('bug')),
          ],
        ),
      );
    });

    test('the 500 keeps the CORS headers', () async {
      final response = await client.get(
        '/error',
        headers: {'origin': 'https://app.example'},
      );

      expect(response.statusCode, 500);
      // Without them a browser shows a CORS error instead of the 500
      expect(response.headers['access-control-allow-origin'], '*');
    });

    test('the filters see the 500 (LoggingFilter logs it)', () async {
      await client.get('/error');

      expect(seenByFilter, [500]);
    });
  });

  group('A custom ExceptionHandler (§4.3)', () {
    test('also handles the Errors, not only the Exceptions', () async {
      Winter.context.setUp(exceptionHandler: _AlwaysTeapot());
      addTearDown(
        () => Winter.context.setUp(exceptionHandler: SimpleExceptionHandler()),
      );
      final client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.get(path: '/error', handler: (r) => throw StateError('bug')),
          ],
        ),
      );

      final response = await client.get('/error');

      expect(response.statusCode, 418);
    });
  });

  group('Every error is a Problem Details (§4.1, §4.5)', () {
    late WinterTestClient client;

    setUp(() {
      om.addDeserializer(Deserializer<_Item>.json(_Item.fromJson));
      addTearDown(() => om.removeDeserializer<_Item>());
      client = WinterTestClient.build(
        maxBodySize: 20,
        router: WinterRouter(
          routes: [
            Route.get(path: '/only-get', handler: (r) => ResponseEntity.ok()),
            Route.post(
              path: '/item',
              handler: (r) async {
                await r.body<_Item>();
                return ResponseEntity.ok();
              },
            ),
            Route.get(
              path: '/not-found',
              handler: (r) =>
                  throw const NotFoundException(detail: 'User 42 not found'),
            ),
            Route.get(
              path: '/conflict',
              handler: (r) => throw const ConflictException(),
            ),
            Route.get(
              path: '/exception',
              handler: (r) => throw Exception('db down'),
            ),
            Route.get(path: '/error', handler: (r) => throw StateError('bug')),
            Route.get(
              path: '/secret',
              handler: (r) => ResponseEntity.ok(),
              filterConfig: FilterConfig([AuthFilter()]),
            ),
            Route.get(
              path: '/limited',
              handler: (r) => ResponseEntity.ok(),
              filterConfig: FilterConfig([
                RateLimiterFilter(
                  maxRequests: 1,
                  window: const Duration(minutes: 1),
                  clientId: (_) => 'id',
                ),
              ]),
            ),
          ],
        ),
      );
    });

    final json = {HttpHeader.contentType: 'application/json'};

    test('404 and 405 of the router', () async {
      _expectProblem(await client.get('/nope'), 404);
      _expectProblem(await client.post('/only-get'), 405);
    });

    test('400 of the object mapper, with its message as the detail', () async {
      _expectProblem(
        await client.post('/item', body: '{x', headers: json),
        400,
        detail: 'The body is not valid JSON',
      );
    });

    test('415 and 413 of the body', () async {
      _expectProblem(
        await client.post(
          '/item',
          body: 'n=1',
          headers: {
            HttpHeader.contentType: 'application/x-www-form-urlencoded',
          },
        ),
        415,
        detail:
            'Unsupported Content-Type application/x-www-form-urlencoded, '
            'expected application/json',
      );
      _expectProblem(
        await client.post(
          '/item',
          body: '{"n": 12345678901234567890}',
          headers: json,
        ),
        413,
      );
    });

    test('422 of the validation, with the violations', () async {
      final response = await client.post('/item', body: '{}', headers: json);

      _expectProblem(response, 422);
      expect((response.json as Map)['violations'], [
        {
          'fieldName': 'n',
          'message': 'The field cannot be null',
          'code': 'notNull',
        },
      ]);
    });

    test('an ApiException: its body is the detail', () async {
      _expectProblem(
        await client.get('/not-found'),
        404,
        detail: 'User 42 not found',
      );
      _expectProblem(await client.get('/conflict'), 409);
    });

    test('401 of AuthFilter and 429 of the rate limiter', () async {
      _expectProblem(await client.get('/secret'), 401);
      await client.get('/limited');
      _expectProblem(await client.get('/limited'), 429);
    });

    test('500, without any detail of the error', () async {
      for (final path in ['/exception', '/error']) {
        final response = await client.get(path);

        _expectProblem(response, 500);
        expect(response.body, isNot(contains('db down')));
        expect(response.body, isNot(contains('bug')));
      }
    });
  });

  group('ApiException (§4.2)', () {
    late WinterTestClient client;

    WinterTestClient clientThrowing(Object error) => WinterTestClient.build(
      router: WinterRouter(
        routes: [Route.get(path: '/', handler: (r) => throw error)],
      ),
    );

    test('any status, with type, title, detail and extensions', () async {
      client = clientThrowing(
        const ApiException(
          StatusCode.conflict,
          detail: 'The email is already registered',
          type: 'https://api.example.com/errors/email-taken',
          title: 'Email taken',
          extensions: {'email': 'a@b.co'},
        ),
      );

      final response = await client.get('/');

      expect(response.statusCode, 409);
      expect(response.json, {
        'email': 'a@b.co',
        'type': 'https://api.example.com/errors/email-taken',
        'title': 'Email taken',
        'status': 409,
        'detail': 'The email is already registered',
      });
    });

    test('an extension never replaces a standard member', () async {
      client = clientThrowing(
        const NotFoundException(extensions: {'status': 200, 'title': 'OK'}),
      );

      final body = (await client.get('/')).json as Map;

      expect(body['status'], 404);
      expect(body['title'], 'Not Found');
    });

    test('405 has the Allow header', () async {
      client = clientThrowing(
        MethodNotAllowedException({HttpMethod.get, HttpMethod.post}),
      );

      final response = await client.get('/');

      expect(response.statusCode, 405);
      expect(response.headers[HttpHeader.allow.toLowerCase()], 'GET, POST');
    });

    test('429 and 503 have the Retry-After header', () async {
      for (final (exception, status) in [
        (TooManyRequestsException(retryAfter: 30), 429),
        (ServiceUnavailableException(retryAfter: 60), 503),
      ]) {
        final response = await clientThrowing(exception).get('/');

        expect(response.statusCode, status);
        expect(
          response.headers[HttpHeader.retryAfter.toLowerCase()],
          status == 429 ? '30' : '60',
        );
        _expectProblem(response, status);
      }
    });

    test('the headers of the exception are sent', () async {
      client = clientThrowing(
        const UnauthorizedException(headers: {'WWW-Authenticate': 'Bearer'}),
      );

      final response = await client.get('/');

      expect(response.headers['www-authenticate'], 'Bearer');
    });

    test('every shortcut has its status', () {
      final shortcuts = <ApiException, int>{
        const BadRequestException(): 400,
        const UnauthorizedException(): 401,
        const ForbiddenException(): 403,
        const NotFoundException(): 404,
        MethodNotAllowedException({}): 405,
        const ConflictException(): 409,
        const PayloadTooLargeException(): 413,
        const UnsupportedMediaTypeException(): 415,
        const UnprocessableEntityException(): 422,
        const ValidationException(violations: []): 422,
        TooManyRequestsException(): 429,
        const InternalServerErrorException(): 500,
        ServiceUnavailableException(): 503,
      };
      for (final MapEntry(key: exception, value: status) in shortcuts.entries) {
        expect(exception.statusCode, status, reason: '$exception');
        expect(exception.toProblemDetails().status, status);
      }
      expect(
        const NotFoundException(detail: 'x').toString(),
        'NotFoundException{status: 404, detail: x}',
      );
    });

    test('the headers given to 405 and 503 are kept with theirs', () {
      final methodNotAllowed = MethodNotAllowedException(
        {HttpMethod.get},
        headers: {'X-Trace': '1'},
      );
      final unavailable = ServiceUnavailableException(
        retryAfter: 5,
        headers: {'X-Trace': '1'},
      );

      expect(methodNotAllowed.headers, {
        'X-Trace': '1',
        HttpHeader.allow: 'GET',
      });
      expect(unavailable.headers, {'X-Trace': '1', HttpHeader.retryAfter: '5'});
    });

    test('a ProblemDetails can be built by hand', () async {
      const problem = ProblemDetails(
        status: 402,
        title: 'Payment Required',
        type: 'https://api.example.com/errors/payment',
        detail: 'Card declined',
      );

      expect(problem.toString(), contains('Card declined'));
      final response = problem.toResponse(headers: {'X-Trace': '1'});
      expect(response.statusCode, 402);
      expect(
        response.headers['content-type'],
        'application/problem+json; charset=utf-8',
      );
      expect(response.headers['x-trace'], '1');
    });

    test('ResponseException answers its own response as it is', () async {
      client = clientThrowing(
        ResponseException(ResponseEntity(402, body: 'Pay first')),
      );

      final response = await client.get('/');

      expect(response.statusCode, 402);
      expect(response.body, 'Pay first');
    });

    test(
      'a status that is not in StatusCode goes in a ResponseException',
      () async {
        client = clientThrowing(
          ResponseException(
            ResponseEntity(700, body: 'Custom', headers: {'x-custom': '1'}),
          ),
        );

        final response = await client.get('/');

        expect(response.statusCode, 700);
        expect(response.body, 'Custom');
        expect(response.headers['x-custom'], '1');
      },
    );
  });

  group('on<T>() (§4.4)', () {
    late SimpleExceptionHandler handler;

    setUp(() {
      handler = SimpleExceptionHandler();
      Winter.context.setUp(exceptionHandler: handler);
      addTearDown(
        () => Winter.context.setUp(exceptionHandler: SimpleExceptionHandler()),
      );
    });

    Future<TestResponse> requestThrowing(Object error) =>
        WinterTestClient.build(
          router: WinterRouter(
            routes: [Route.get(path: '/', handler: (r) => throw error)],
          ),
        ).get('/');

    test(
      'an ApiException returned by the mapping is a Problem Details',
      () async {
        handler.on<_EmailTaken>(
          (request, e) => ConflictException(detail: 'Email ${e.email} taken'),
        );

        final response = await requestThrowing(_EmailTaken('a@b.co'));

        _expectProblem(response, 409, detail: 'Email a@b.co taken');
      },
    );

    test('a ResponseEntity or a ProblemDetails is used as it is', () async {
      handler
        ..on<_EmailTaken>((request, e) => ResponseEntity(402, body: 'pay'))
        ..on<_PaymentFailed>(
          (request, e) => ProblemDetails.of(
            StatusCode.paymentRequired,
            detail: 'Card declined',
          ),
        );

      expect((await requestThrowing(_EmailTaken('x'))).body, 'pay');
      _expectProblem(
        await requestThrowing(_PaymentFailed()),
        402,
        detail: 'Card declined',
      );
    });

    test('the most specific type wins, whatever the order', () async {
      handler
        ..on<Exception>((request, e) => ResponseEntity(500, body: 'any'))
        ..on<_DomainException>(
          (request, e) => ResponseEntity(400, body: 'domain'),
        )
        ..on<_EmailTaken>((request, e) => ResponseEntity(409, body: 'email'));

      expect((await requestThrowing(_EmailTaken('x'))).body, 'email');
      expect((await requestThrowing(_PaymentFailed())).body, 'domain');
      expect((await requestThrowing(Exception('x'))).body, 'any');
    });

    test(
      'it also changes the errors of Winter (the 404 of the router)',
      () async {
        handler.on<NotFoundException>(
          (request, e) => NotFoundException(
            detail: 'No route for ${request.requestedUri.path}',
          ),
        );
        final client = WinterTestClient.build(router: WinterRouter(routes: []));

        _expectProblem(
          await client.get('/nope'),
          404,
          detail: 'No route for /nope',
        );
      },
    );

    test('registering a type again replaces it', () async {
      handler
        ..on<_EmailTaken>((request, e) => ResponseEntity(400, body: 'first'))
        ..on<_EmailTaken>((request, e) => ResponseEntity(400, body: 'second'));

      expect((await requestThrowing(_EmailTaken('x'))).body, 'second');
    });

    test('a mapping that throws is answered by the default rules', () async {
      handler
        ..on<_EmailTaken>((request, e) => throw const ConflictException())
        ..on<_PaymentFailed>((request, e) => throw StateError('bug'))
        ..on<ConflictException>(
          (request, e) => ResponseEntity(400, body: 'never used'),
        );

      _expectProblem(await requestThrowing(_EmailTaken('x')), 409);
      _expectProblem(await requestThrowing(_PaymentFailed()), 500);
    });

    test('a mapping that returns something else is a 500', () async {
      handler.on<_EmailTaken>((request, e) => 'not a response');

      _expectProblem(await requestThrowing(_EmailTaken('x')), 500);
    });

    test('inheritance still works: override handle() and keep on()', () async {
      final custom = _TeapotForStateErrors()
        ..on<_EmailTaken>((request, e) => const ConflictException());
      Winter.context.setUp(exceptionHandler: custom);

      expect((await requestThrowing(StateError('x'))).statusCode, 418);
      expect((await requestThrowing(_EmailTaken('x'))).statusCode, 409);
      expect(
        (await requestThrowing(const NotFoundException())).statusCode,
        404,
      );
    });
  });

  group('A broken ExceptionHandler', () {
    test('a handler that throws still gives a generic 500', () async {
      final logs = <String>[];
      Winter.context.setUp(
        exceptionHandler: _Broken(),
        logger: _MemoryLogger(logs),
      );
      addTearDown(
        () => Winter.context.setUp(
          exceptionHandler: SimpleExceptionHandler(),
          logger: const ConsoleLogger(),
        ),
      );
      final client = WinterTestClient.build(
        router: WinterRouter(
          routes: [Route.get(path: '/', handler: (r) => throw Exception('x'))],
        ),
      );

      _expectProblem(await client.get('/'), 500);
      // The original error and the one of the handler
      expect(logs, hasLength(2));
    });
  });
}

/// The response is a Problem Details of [status]: `type`, `title` (the reason phrase) and
/// `status`, and `detail` only when there is one
void _expectProblem(TestResponse response, int status, {String? detail}) {
  expect(response.statusCode, status);
  expect(
    response.headers[HttpHeader.contentType.toLowerCase()],
    startsWith('application/problem+json'),
    reason: 'status $status: ${response.body}',
  );
  final body = response.json as Map;
  expect(body['type'], 'about:blank');
  expect(
    body['title'],
    StatusCode.values.firstWhere((s) => s.value == status).reasonPhrase,
  );
  expect(body['status'], status);
  if (detail == null) {
    expect(body, isNot(contains('detail')));
  } else {
    expect(body['detail'], detail);
  }
}

class _Item implements Validatable {
  final int? n;

  _Item(this.n);

  factory _Item.fromJson(Map<String, dynamic> json) => _Item(json['n'] as int?);

  @override
  ConstraintValidatorContext validate() =>
      ConstraintValidatorContext()..field('n', n).notNull();
}

/// Records the status of the responses that go through it
class _Spy extends Filter {
  final List<int> seen;

  _Spy(this.seen);

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final response = await chain.doFilter(request);
    seen.add(response.statusCode);
    return response;
  }
}

class _AlwaysTeapot extends ExceptionHandler {
  @override
  Future<ResponseEntity> call(
    RequestEntity request,
    Object error,
    StackTrace stackTrace,
  ) async => ResponseEntity(418);
}

class _DomainException implements Exception {}

class _EmailTaken extends _DomainException {
  final String email;

  _EmailTaken(this.email);
}

class _PaymentFailed extends _DomainException {}

class _TeapotForStateErrors extends SimpleExceptionHandler {
  @override
  Future<ResponseEntity> handle(
    RequestEntity request,
    Object error,
    StackTrace stackTrace,
  ) async => error is StateError
      ? ResponseEntity(418)
      : super.handle(request, error, stackTrace);
}

class _Broken extends ExceptionHandler {
  @override
  Future<ResponseEntity> call(
    RequestEntity request,
    Object error,
    StackTrace stackTrace,
  ) => throw StateError('broken handler');
}

class _MemoryLogger extends WinterLogger {
  final List<String> logs;

  _MemoryLogger(this.logs);

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => logs.add(message);
}

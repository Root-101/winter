@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// An ExceptionHandler written from zero (not a SimpleExceptionHandler): it answers every
/// exception its own way, Problem Details or not
void main() {
  late WinterTestClient client;

  setUpAll(() {
    Winter.context.setUp(exceptionHandler: _TextExceptionHandler());
    client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route.get(path: '/ok', handler: (request) => ResponseEntity.ok()),
          Route.get(
            path: '/app',
            handler: (request) => throw _AppException('Error from GET'),
          ),
          Route.post(
            path: '/app',
            handler: (request) => throw _AppException('Error from POST'),
          ),
          Route.get(
            path: '/generic',
            handler: (request) => throw Exception('Generic exception'),
          ),
          Route.get(
            path: '/teapot',
            handler: (request) => throw _StatusException(418),
          ),
          Route.get(
            path: '/path',
            handler: (request) => throw _PathException(),
          ),
        ],
      ),
    );
  });

  tearDownAll(
    () => Winter.context.setUp(exceptionHandler: SimpleExceptionHandler()),
  );

  test('every exception gets its answer, whatever the method', () async {
    expect((await client.get('/app')).body, 'Error from GET');
    expect((await client.post('/app')).body, 'Error from POST');
    expect((await client.get('/generic')).body, 'Exception: Generic exception');
    expect((await client.get('/generic')).statusCode, 400);
  });

  test('any status, and the request is available', () async {
    final teapot = await client.get('/teapot');

    expect(teapot.statusCode, 418);
    expect(teapot.body, 'Custom code: 418');
    expect((await client.get('/path')).body, 'Path: /path');
  });

  test('a request without errors never reaches it', () async {
    expect((await client.get('/ok')).statusCode, 200);
  });
}

class _AppException implements Exception {
  final String message;

  _AppException(this.message);

  @override
  String toString() => message;
}

class _StatusException implements Exception {
  final int code;

  _StatusException(this.code);
}

class _PathException implements Exception {}

/// Text bodies instead of Problem Details
class _TextExceptionHandler extends ExceptionHandler {
  @override
  Future<ResponseEntity> call(
    RequestEntity request,
    Object error,
    StackTrace stackTrace,
  ) async => switch (error) {
    _StatusException(:final code) => ResponseEntity(
      code,
      body: 'Custom code: $code',
    ),
    _PathException() => ResponseEntity.ok(
      body: 'Path: ${request.requestedUri.path}',
    ),
    _ => ResponseEntity.badRequest(body: error.toString()),
  };
}

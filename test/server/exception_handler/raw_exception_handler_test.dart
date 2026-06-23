@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9011;
  String localUrl = 'http://localhost:$port';

  ExceptionHandler exc = TestExceptionHandler();

  setUpAll(() async {
    await Winter.run(
      config: ServerConfig(port: port),
      context: BuildContext(exceptionHandler: exc),
      router: WinterRouter(
        routes: [
          Route(
            path: '/exception/1',
            method: HttpMethod.get,
            handler: (request) =>
                throw TestException(message: 'Error from /exception'),
          ),
          Route(
            path: '/exception/2',
            method: HttpMethod.get,
            handler: (request) => ResponseEntity.ok(body: 'Hello world!!!'),
          ),
          Route(
            path: '/exception/3',
            method: HttpMethod.get,
            handler: (request) => throw Exception('Generic exception'),
          ),
          Route(
            path: '/exception/post',
            method: HttpMethod.post,
            handler: (request) =>
                throw TestException(message: 'Error from POST'),
          ),
          Route(
            path: '/exception/custom-status',
            method: HttpMethod.get,
            handler: (request) => throw CustomStatusException(418),
          ),
          Route(
            path: '/exception/path-check',
            method: HttpMethod.get,
            handler: (request) => throw PathCheckException(),
          ),
        ],
      ),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test Exception #1', () async {
    String urlToTest = '/exception/1';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 400);
    expect(response.body, 'Error from /exception');
  });

  test('Test Exception #2', () async {
    String urlToTest = '/exception/2';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 200);
    expect(response.body, 'Hello world!!!');
  });

  test('Test Exception #3 - Generic', () async {
    String urlToTest = '/exception/3';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 400);
    expect(response.body, 'Exception: Generic exception');
  });

  test('Test Exception #4 - POST', () async {
    String urlToTest = '/exception/post';
    http.Response response = await http.post(url(urlToTest));
    expect(response.statusCode, 400);
    expect(response.body, 'Error from POST');
  });

  test('Test Exception #5 - Custom Status', () async {
    String urlToTest = '/exception/custom-status';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 418);
    expect(response.body, 'Custom code: 418');
  });

  test('Test Exception #6 - Request Info in Handler', () async {
    String urlToTest = '/exception/path-check';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 200);
    expect(response.body, 'Path: /exception/path-check');
  });
}

class TestException implements Exception {
  final String message;

  TestException({required this.message});

  @override
  String toString() {
    return message;
  }
}

class CustomStatusException implements Exception {
  final int code;

  CustomStatusException(this.code);
}

class PathCheckException implements Exception {}

class TestExceptionHandler extends ExceptionHandler {
  @override
  Future<ResponseEntity> call(
    RequestEntity request,
    Exception exception,
    StackTrace stackTrac,
  ) async {
    if (exception is CustomStatusException) {
      return ResponseEntity(
        exception.code,
        body: 'Custom code: ${exception.code}',
      );
    }
    if (exception is PathCheckException) {
      return ResponseEntity.ok(body: 'Path: ${request.requestedUri.path}');
    }
    return ResponseEntity.badRequest(body: exception.toString());
  }
}

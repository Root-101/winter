@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9011;
  String localUrl = 'http://localhost:$port';

  ExceptionHandler exc = TestExceptionHandler();

  setUpAll(
    () async {
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
              handler: (request) => ResponseEntity.ok(
                body: 'Hello world!!!',
              ),
            ),
          ],
        ),
      );
    },
  );

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
}

class TestException implements Exception {
  final String message;

  TestException({
    required this.message,
  });

  @override
  String toString() {
    return message;
  }
}

class TestExceptionHandler extends ExceptionHandler {
  @override
  Future<ResponseEntity> call(
    RequestEntity request,
    Exception exception,
    StackTrace stackTrac,
  ) async {
    return ResponseEntity.badRequest(body: exception.toString());
  }
}

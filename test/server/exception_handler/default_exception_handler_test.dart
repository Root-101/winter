@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import '../../../bin/winter.dart';

void main() {
  int port = 9010;
  String localUrl = 'http://localhost:$port';

  setUpAll(
    () async {
      await Winter.run(
        config: ServerConfig(port: port),
        router: WinterRouter(
          routes: [
            ///All should work oka, give a 200 response
            Route(
              path: '/no-exception',
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(
                body: 'Hello world!!!',
              ),
            ),

            ///Exception is thrown and because is a custom exception the response will be a 500 with the message of the exception
            Route(
              path: '/custom-exception',
              method: HttpMethod.get,
              handler: (request) =>
                  throw TestException(message: 'Handler for custom exception'),
            ),
            Route(
              path: '/generic-exception',
              method: HttpMethod.get,
              handler: (request) =>
                  throw Exception('Handler for generic exception'),
            ),

            ///The thrown exception is 'ResponseException', it's processed as a normal response but in the flow of exception
            ///This allow to stop the flow at ANY point and return a normal response
            Route(
              path: '/response-exception/ok',
              method: HttpMethod.get,
              handler: (request) => throw ResponseException(
                ResponseEntity.ok(
                  body: 'Response from exception',
                ),
              ),
            ),

            ///Same as /response-exception/ok but with a different status code
            Route(
              path: '/response-exception/bad-request',
              method: HttpMethod.get,
              handler: (request) => throw ResponseException(
                ResponseEntity.badRequest(
                  body: 'Bad Request response from exception',
                ),
              ),
            ),

            ///Return an exception that is converted to a ResponseEntity
            Route(
              path: '/api-exception/700',
              method: HttpMethod.get,
              handler: (request) => throw ApiException(
                statusCode: 700,
                body: 'Generic api exception',
                headers: {
                  'exception-header': '123456789',
                },
              ),
            ),

            ///Test all the pre-implemented exceptions
            Route(
              path: '/api-exception/bad-request',
              method: HttpMethod.get,
              handler: (request) => throw BadRequestException(),
            ),
            Route(
              path: '/api-exception/forbidden',
              method: HttpMethod.get,
              handler: (request) => throw ForbiddenException(),
            ),
            Route(
              path: '/api-exception/payment-required',
              method: HttpMethod.get,
              handler: (request) => throw PaymentRequiredException(),
            ),
            Route(
              path: '/api-exception/unauthorized',
              method: HttpMethod.get,
              handler: (request) => throw UnauthorizedException(),
            ),
            Route(
              path: '/api-exception/not-found',
              method: HttpMethod.get,
              handler: (request) => throw NotFoundException(),
            ),
            Route(
              path: '/api-exception/conflict',
              method: HttpMethod.get,
              handler: (request) => throw ConflictException(),
            ),
            Route(
              path: '/api-exception/unprocessable',
              method: HttpMethod.get,
              handler: (request) => throw UnprocessableEntityException(),
            ),
            Route(
              ///ise = Internal Server Error
              path: '/api-exception/ise',
              method: HttpMethod.get,
              handler: (request) => throw InternalServerErrorException(),
            ),
          ],
        ),
      );
    },
  );

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test Exception: no-exception', () async {
    String urlToTest = '/no-exception';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 200);
    expect(response.body, 'Hello world!!!');
  });

  test('Test Exception: custom-exception', () async {
    String urlToTest = '/custom-exception';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 500);
    expect(response.body, 'Handler for custom exception');
  });

  test('Test Exception: generic-exception', () async {
    String urlToTest = '/generic-exception';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 500);
    expect(response.body, 'Exception: Handler for generic exception');
  });

  test('Test Exception: response-exception/ok', () async {
    String urlToTest = '/response-exception/ok';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 200);
    expect(response.body, 'Response from exception');
  });

  test('Test Exception: /api-exception/700', () async {
    String urlToTest = '/api-exception/700';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 700);
    expect(response.body, 'Generic api exception');
    expect(response.headers['exception-header'], '123456789');
  });

  test('Test Exception: /api-exception/bad-request', () async {
    String urlToTest = '/api-exception/bad-request';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 400);
  });

  test('Test Exception: /api-exception/forbidden', () async {
    String urlToTest = '/api-exception/forbidden';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 401);
  });

  test('Test Exception: /api-exception/unauthorized', () async {
    String urlToTest = '/api-exception/unauthorized';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 403);
  });

  test('Test Exception: /api-exception/not-found', () async {
    String urlToTest = '/api-exception/not-found';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 404);
  });

  test('Test Exception: /api-exception/conflict', () async {
    String urlToTest = '/api-exception/conflict';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 409);
  });

  test('Test Exception: /api-exception/unprocessable', () async {
    String urlToTest = '/api-exception/unprocessable';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 422);
  });

  test('Test Exception: /api-exception/ise', () async {
    String urlToTest = '/api-exception/ise';
    http.Response response = await http.get(url(urlToTest));
    expect(response.statusCode, 500);
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

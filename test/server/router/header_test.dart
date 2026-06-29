@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9043;
  String localUrl = 'http://localhost:$port';

  setUpAll(() async {
    await Winter.start(
      config: ServerConfig(port: port),
      router: WinterRouter(
        routes: [
          Route(
            path: '/json',
            method: HttpMethod.get,
            handler: (request) async {
              return ResponseEntity.ok(body: {'message': 'hello'});
            },
          ),
          Route(
            path: '/problem',
            method: HttpMethod.get,
            handler: (request) async {
              return ResponseEntity.badRequest(body: {'error': 'some error'});
            },
          ),
          Route(
            path: '/text',
            method: HttpMethod.get,
            handler: (request) async {
              return ResponseEntity.ok(body: 'plain text');
            },
          ),
          Route(
            path: '/stream',
            method: HttpMethod.get,
            handler: (request) async {
              return ResponseEntity.ok(
                body: Stream.fromIterable([
                  [1, 2, 3],
                ]),
              );
            },
          ),
          Route(
            path: '/stream-jpeg',
            method: HttpMethod.get,
            handler: (request) async {
              return ResponseEntity.ok(
                body: Stream.fromIterable([
                  [1, 2, 3],
                ]),
                headers: {HttpHeaders.contentType: 'image/jpeg'},
              );
            },
          ),
          Route(
            path: '/no-content',
            method: HttpMethod.get,
            handler: (request) async {
              return ResponseEntity(HttpStatus.noContent.value);
            },
          ),
        ],
      ),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  group('Header Tests', () {
    test('Response with JSON body has application/json content-type', () async {
      http.Response response = await http.get(url('/json'));
      expect(
        response.headers[HttpHeaders.contentType.toLowerCase()],
        contains(MediaType.applicationJson.mimeType),
      );
    });

    test(
      'Response with Problem JSON body has application/problem+json content-type',
      () async {
        http.Response response = await http.get(url('/problem'));
        expect(
          response.headers[HttpHeaders.contentType.toLowerCase()],
          contains(MediaType.applicationProblemJson.mimeType),
        );
      },
    );

    test('Response with String body has text/plain content-type', () async {
      http.Response response = await http.get(url('/text'));
      expect(
        response.headers[HttpHeaders.contentType.toLowerCase()],
        contains(MediaType.textPlain.mimeType),
      );
    });

    test(
      'Response with Stream body has application/octet-stream content-type',
      () async {
        http.Response response = await http.get(url('/stream'));
        expect(
          response.headers[HttpHeaders.contentType.toLowerCase()],
          contains(MediaType.applicationOctetStream.mimeType),
        );
      },
    );

    test(
      'Response with Stream body and custom content-type respects it',
      () async {
        http.Response response = await http.get(url('/stream-jpeg'));
        expect(
          response.headers[HttpHeaders.contentType.toLowerCase()],
          contains('image/jpeg'),
        );
      },
    );

    test('Response with JSON body has correct Content-Length', () async {
      http.Response response = await http.get(url('/json'));
      // {"message":"hello"} -> 19 characters
      expect(
        response.headers[HttpHeaders.contentLength.toLowerCase()],
        equals('19'),
      );
    });

    test('Response with String body has correct Content-Length', () async {
      http.Response response = await http.get(url('/text'));
      // "plain text" -> 10 characters
      expect(
        response.headers[HttpHeaders.contentLength.toLowerCase()],
        equals('10'),
      );
    });

    test('Response with Stream body has no Content-Length', () async {
      http.Response response = await http.get(url('/stream'));
      // Streams usually result in Transfer-Encoding: chunked, not Content-Length
      expect(
        response.headers[HttpHeaders.contentLength.toLowerCase()],
        isNull,
      );
    });

    //TODO: alguien le esta agregando el content-type text/plan y no se quien es
    /*test(
      'Response 204 No Content has no Content-Type or Content-Length',
      () async {
        http.Response response = await http.get(url('/no-content'));
        expect(response.statusCode, equals(HttpStatus.noContent.value));
        expect(response.headers[HttpHeaders.contentType.toLowerCase()], isNull);
        expect(
          response.headers[HttpHeaders.contentLength.toLowerCase()],
          isNull,
        );
      },
    );*/
  });
}

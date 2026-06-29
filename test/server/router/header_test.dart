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
                  [1, 2, 3]
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
                  [1, 2, 3]
                ]),
                headers: {HttpHeaders.contentType: 'image/jpeg'},
              );
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

    test('Response with Stream body has application/octet-stream content-type',
        () async {
      http.Response response = await http.get(url('/stream'));
      expect(
        response.headers[HttpHeaders.contentType.toLowerCase()],
        contains(MediaType.applicationOctetStream.mimeType),
      );
    });

    test('Response with Stream body and custom content-type respects it',
        () async {
      http.Response response = await http.get(url('/stream-jpeg'));
      expect(
        response.headers[HttpHeaders.contentType.toLowerCase()],
        contains('image/jpeg'),
      );
    });
  });
}

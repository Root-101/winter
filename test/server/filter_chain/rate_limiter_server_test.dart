@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('Rate Limiter Server Tests', () {
    const int port = 9026;
    const String localUrl = 'http://localhost:$port';

    setUpAll(() async {
      await Winter.start(
        config: ServerConfig(port: port),
        router: WinterRouter(
          routes: [
            Route(
              path: '/limited',
              filterConfig: FilterConfig([
                RateLimiterFilter(
                  maxRequests: 2,
                  window: const Duration(seconds: 2),
                  onRequest: (request) =>
                      request.headers['x-client-id'] ?? 'default',
                ),
              ]),
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(body: 'Success'),
            ),
            Route(
              path: '/unlimited',
              method: HttpMethod.get,
              handler: (request) => ResponseEntity.ok(body: 'Success'),
            ),
          ],
        ),
      );
    });

    tearDownAll(() => Winter.close(force: true));

    Uri url(String path) => Uri.parse(localUrl + path);

    test('should allow requests within limit and return headers',
        () async {
      final response1 = await http
          .get(url('/limited'), headers: {'x-client-id': 'test-client-1'});
      expect(response1.statusCode, 200);
      expect(response1.headers['x-ratelimit-limit'], '2');
      expect(response1.headers['x-ratelimit-remaining'], '1');

      final response2 = await http
          .get(url('/limited'), headers: {'x-client-id': 'test-client-1'});
      expect(response2.statusCode, 200);
      expect(response2.headers['x-ratelimit-remaining'], '0');
    });

    test('should block requests exceeding limit with 429', () async {
      final clientId = 'test-client-2';

      // Agotar el límite
      await http.get(url('/limited'), headers: {'x-client-id': clientId});
      await http.get(url('/limited'), headers: {'x-client-id': clientId});

      // Tercera petición bloqueada
      final response =
          await http.get(url('/limited'), headers: {'x-client-id': clientId});
      expect(response.statusCode, 429);
      expect(response.headers['retry-after'], isNotNull);
      expect(response.headers['x-ratelimit-remaining'], '0');
    });

    test('should handle independent clients based on header',
        () async {
      final clientA = 'client-a';
      final clientB = 'client-b';

      // Agotar cliente A
      await http.get(url('/limited'), headers: {'x-client-id': clientA});
      await http.get(url('/limited'), headers: {'x-client-id': clientA});
      final resA =
          await http.get(url('/limited'), headers: {'x-client-id': clientA});
      expect(resA.statusCode, 429);

      // Cliente B debe seguir teniendo acceso
      final resB =
          await http.get(url('/limited'), headers: {'x-client-id': clientB});
      expect(resB.statusCode, 200);
      expect(resB.headers['x-ratelimit-remaining'], '1');
    });

    test('routes without filter should not be limited', () async {
      for (var i = 0; i < 5; i++) {
        final response = await http.get(url('/unlimited'));
        expect(response.statusCode, 200);
        expect(response.headers.containsKey('x-ratelimit-limit'), isFalse);
      }
    });

    test('should allow requests again after window expires',
        () async {
      final clientId = 'test-client-3';

      // Agotar el límite
      await http.get(url('/limited'), headers: {'x-client-id': clientId});
      await http.get(url('/limited'), headers: {'x-client-id': clientId});

      // Esperar a que expire la ventana (configurada a 2 segundos)
      await Future.delayed(const Duration(milliseconds: 2100));

      final response =
          await http.get(url('/limited'), headers: {'x-client-id': clientId});
      expect(response.statusCode, 200);
      expect(response.headers['x-ratelimit-remaining'], '1');
    });
  });
}

@TestOn('vm')
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

class _FakeConnectionInfo implements HttpConnectionInfo {
  @override
  final InternetAddress remoteAddress;

  _FakeConnectionInfo(String ip) : remoteAddress = InternetAddress(ip);

  @override
  int get localPort => 8080;

  @override
  int get remotePort => 50000;
}

RequestEntity _request({String? forwardedFor}) => RequestEntity(
  'GET',
  Uri.parse('http://localhost/'),
  headers: {'X-Forwarded-For': ?forwardedFor},
  connectionInfo: _FakeConnectionInfo('10.0.0.1'),
);

void main() {
  group('clientIp', () {
    test('is the address of the connection', () {
      expect(_request().clientIp(), '10.0.0.1');
    });

    test('X-Forwarded-For is ignored by default (it can be faked)', () {
      expect(_request(forwardedFor: '1.1.1.1').clientIp(), '10.0.0.1');
    });

    test('with 1 trusted proxy, the last entry is the client', () {
      final request = _request(forwardedFor: 'fake-by-client, 203.0.113.7');

      expect(request.clientIp(trustedProxies: 1), '203.0.113.7');
    });

    test('with 2 trusted proxies, the entry added by the outer proxy', () {
      final request = _request(forwardedFor: '203.0.113.7, 192.168.0.5');

      expect(request.clientIp(trustedProxies: 2), '203.0.113.7');
    });

    test('without X-Forwarded-For, the address of the connection', () {
      expect(_request().clientIp(trustedProxies: 1), '10.0.0.1');
    });

    test('null when the connection is unknown', () {
      expect(RequestEntity('GET', Uri.parse('http://x/')).clientIp(), isNull);
    });
  });

  group('Real server', () {
    int port = 9073;

    setUpAll(() async {
      await Winter.start(
        config: ServerConfig(port: port),
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/ip',
              handler: (request) =>
                  ResponseEntity.ok(body: request.clientIp() ?? 'unknown'),
              filterConfig: FilterConfig([
                RateLimiterFilter(
                  maxRequests: 2,
                  window: const Duration(minutes: 1),
                  onLimited: null,
                ),
              ]),
            ),
          ],
        ),
      );
    });

    tearDownAll(() => Winter.close(force: true));

    test(
      'clientIp & the default RateLimiterFilter id use the real IP',
      () async {
        final uri = Uri.parse('http://localhost:$port/ip');

        final first = await http.get(uri);
        expect(InternetAddress(first.body).isLoopback, isTrue);

        await http.get(uri);
        final third = await http.get(
          uri,
          headers: {'X-Forwarded-For': '1.2.3.4'},
        );

        ///A fake X-Forwarded-For doesn't bypass the limit
        expect(third.statusCode, 429);
      },
    );
  });
}

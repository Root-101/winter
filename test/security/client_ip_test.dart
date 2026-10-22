@TestOn('vm')
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/src/trusted_proxies.dart' show applyTrustedProxies;
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

const String _uri = 'http://localhost:8080/orders?page=2';

RequestEntity _request({
  Map<String, Object> headers = const {},
  String uri = _uri,
}) => RequestEntity(
  'GET',
  Uri.parse(uri),
  headers: headers,
  connectionInfo: _FakeConnectionInfo('10.0.0.1'),
);

/// [headers] as the server sees them behind [proxies]
RequestEntity _behind(
  TrustedProxies proxies,
  Map<String, Object> headers, {
  String uri = _uri,
}) => applyTrustedProxies(_request(headers: headers, uri: uri), proxies);

void main() {
  const one = TrustedProxies(1);
  const forwarded = TrustedProxies(1, headers: ForwardedHeaders.forwarded);

  group('clientIp without trusted proxies', () {
    test('is the address of the connection', () {
      expect(_request().clientIp, '10.0.0.1');
    });

    test('X-Forwarded-For and Forwarded are ignored (they can be faked)', () {
      final request = _request(
        headers: {'X-Forwarded-For': '1.1.1.1', 'Forwarded': 'for=1.1.1.1'},
      );

      expect(request.clientIp, '10.0.0.1');
    });

    test('null when the connection is unknown', () {
      expect(RequestEntity('GET', Uri.parse('http://x/')).clientIp, isNull);
    });
  });

  group('X-Forwarded-* (§8)', () {
    test('with 1 proxy, the last entry is the client', () {
      final request = _behind(one, {
        'X-Forwarded-For': 'fake-by-client, 203.0.113.7',
      });

      expect(request.clientIp, '203.0.113.7');
    });

    test('with 2 proxies, the entry added by the outer one, on any line', () {
      final request = _behind(const TrustedProxies(2), {
        'X-Forwarded-For': ['198.51.100.1, 203.0.113.7', '192.168.0.5'],
      });

      expect(request.clientIp, '203.0.113.7');
    });

    test('fewer entries than proxies, or not an IP: the connection', () {
      expect(
        _behind(const TrustedProxies(2), {
          'X-Forwarded-For': '203.0.113.7',
        }).clientIp,
        '10.0.0.1',
      );
      expect(
        _behind(one, {'X-Forwarded-For': 'not-an-ip'}).clientIp,
        '10.0.0.1',
      );
      expect(_behind(one, {}).clientIp, '10.0.0.1');
    });

    test('the scheme and the host of the client in requestedUri', () {
      final request = _behind(one, {
        'X-Forwarded-Proto': 'https',
        'X-Forwarded-Host': 'api.example.com',
      });

      expect(
        '${request.requestedUri}',
        'https://api.example.com/orders?page=2',
      );
      expect(
        '${_behind(one, {'X-Forwarded-Host': 'api.example.com:8443'}).requestedUri}',
        'http://api.example.com:8443/orders?page=2',
      );
    });

    test('only the scheme: the host stays, a default port follows it', () {
      expect(
        '${_behind(one, {'X-Forwarded-Proto': 'HTTPS'}, uri: 'http://api.example.com/x').requestedUri}',
        'https://api.example.com/x',
      );
      // A port of its own is kept
      expect(
        '${_behind(one, {'X-Forwarded-Proto': 'https'}).requestedUri}',
        'https://localhost:8080/orders?page=2',
      );
    });

    test('a scheme or a host that is not valid is ignored', () {
      for (final headers in [
        {'X-Forwarded-Proto': 'javascript'},
        {'X-Forwarded-Host': 'evil.com/path'},
        {'X-Forwarded-Host': 'user@evil.com'},
        {'X-Forwarded-Host': 'evil.com?x=1'},
        {'X-Forwarded-Host': ' '},
      ]) {
        expect(
          '${_behind(one, headers).requestedUri}',
          _uri,
          reason: '$headers',
        );
      }
    });

    test('Forwarded is ignored: the proxies write X-Forwarded-*', () {
      final request = _behind(one, {'Forwarded': 'for=1.1.1.1;host=evil.com'});

      expect(request.clientIp, '10.0.0.1');
      expect(request.requestedUri.host, 'localhost');
    });
  });

  group('Forwarded, RFC 7239 (§8)', () {
    test('the for, proto and host of the element of the proxy', () {
      final request = _behind(forwarded, {
        'Forwarded': 'for=203.0.113.7;proto=https;host=api.example.com',
      });

      expect(request.clientIp, '203.0.113.7');
      expect(
        '${request.requestedUri}',
        'https://api.example.com/orders?page=2',
      );
    });

    test('one element per proxy: quoted values, IPv6 and ports', () {
      final request = _behind(
        const TrustedProxies(2, headers: ForwardedHeaders.forwarded),
        {
          'Forwarded': [
            'for=198.51.100.1',
            'for="[2001:db8:cafe::17]:4711";proto=https;host="api.example.com", '
                'for=192.0.2.43:47011',
          ],
        },
      );

      expect(request.clientIp, '2001:db8:cafe::17');
      expect(request.requestedUri.host, 'api.example.com');
      expect(
        _behind(forwarded, {'Forwarded': 'for=192.0.2.43:47011'}).clientIp,
        '192.0.2.43',
      );
      expect(
        _behind(forwarded, {'Forwarded': r'for="\203.0.113.7"'}).clientIp,
        '203.0.113.7',
      );
    });

    test('unknown or an obfuscated node is not an IP: the connection', () {
      for (final node in ['unknown', '_hidden', '"[2001:db8::1"']) {
        expect(
          _behind(forwarded, {'Forwarded': 'for=$node'}).clientIp,
          '10.0.0.1',
          reason: node,
        );
      }
    });

    test('a quoted string never closed ignores the header', () {
      // The client's unclosed quote would swallow the element the proxy appends
      final request = _behind(forwarded, {
        'Forwarded':
            'for=6.6.6.6;host=evil.example;x="'
            ', for=203.0.113.7;host=api.example.com;proto=https',
      });

      expect(request.clientIp, '10.0.0.1');
      expect(request.requestedUri.host, isNot('evil.example'));
    });

    test('X-Forwarded-For is ignored: the proxies write Forwarded', () {
      expect(
        _behind(forwarded, {'X-Forwarded-For': '1.1.1.1'}).clientIp,
        '10.0.0.1',
      );
    });
  });

  test('the default id of the rate limiter groups IPv6 by its /64', () {
    String idOf(String ip) => defaultClientId(
      RequestEntity(
        'GET',
        Uri.parse(_uri),
        connectionInfo: _FakeConnectionInfo(ip),
      ),
    );

    // Two addresses of the same /64 are one client: it can't rotate them to get past the limit
    expect(idOf('2001:db8:0:1::5'), '2001:db8:0:1::/64');
    expect(idOf('2001:db8:0:1:ffff::9'), '2001:db8:0:1::/64');
    expect(idOf('2001:db8:0:2::5'), '2001:db8:0:2::/64');
    expect(idOf('203.0.113.7'), '203.0.113.7');
    expect(idOf('::ffff:203.0.113.7'), '::ffff:203.0.113.7');
  });

  test('fewer than one proxy is an ArgumentError', () {
    expect(
      () => const ServerConfig(trustedProxies: TrustedProxies(0)).validate(),
      throwsArgumentError,
    );
    expect(
      () => WinterTestClient.build(
        router: WinterRouter(routes: []),
        trustedProxies: const TrustedProxies(0),
      ),
      throwsArgumentError,
    );
  });

  test(
    'in the pipeline, the handler and the rate limiter see the client',
    () async {
      final client = WinterTestClient.build(
        trustedProxies: one,
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/whoami',
              handler: (request) => ResponseEntity.ok(
                body: {
                  'ip': request.clientIp,
                  'uri': '${request.requestedUri}',
                },
              ),
              filterConfig: FilterConfig([
                RateLimiterFilter(
                  maxRequests: 1,
                  window: const Duration(minutes: 1),
                  onLimited: null,
                ),
              ]),
            ),
          ],
        ),
      );
      Future<TestResponse> from(String ip) => client.get(
        '/whoami',
        headers: {
          'X-Forwarded-For': ip,
          'X-Forwarded-Proto': 'https',
          'X-Forwarded-Host': 'api.example.com',
        },
      );

      expect((await from('203.0.113.7')).json, {
        'ip': '203.0.113.7',
        'uri': 'https://api.example.com/whoami',
      });
      // One limit per client, not one for everybody behind the proxy
      expect((await from('203.0.113.8')).statusCode, 200);
      expect((await from('203.0.113.7')).statusCode, 429);
    },
  );

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
                  ResponseEntity.ok(body: request.clientIp ?? 'unknown'),
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

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../winter/winter.dart';

void main() => WinterServer(
      config: ServerConfig(port: 9090),
      router: ProxyRouter([
        GatewayRoute(
          gatewayName: 'local',
          path: '/local',
          uri: 'http://localhost:8080',
          replaceFrom: '/local',
          replaceTo: '/api/v1',
        ),
        GatewayRoute(
          gatewayName: 'stories-dev',
          path: '/stories',
          uri: 'https://api.example.com',
          replaceFrom: '/stories',
          replaceTo: '',
        ),
      ]),
    ).start();

class ProxyRouter extends AbstractWinterRouter {
  List<GatewayRoute> services;

  ProxyRouter(this.services);

  @override
  WinterHandler call(RequestEntity request) {
    String requestedUrl = '/${request.url.toString()}';
    for (var single in services) {
      if (requestedUrl.startsWith(single.path)) {
        return (request1) => gatewayHandler(
              request1,
              single,
            );
      }
    }
    return (_) => ResponseEntity.notFound();
  }
}

class GatewayRoute {
  String gatewayName;
  String path;
  String uri;
  String replaceFrom;
  String replaceTo;

  GatewayRoute({
    required this.gatewayName,
    required this.path,
    required this.uri,
    required this.replaceFrom,
    required this.replaceTo,
  });
}

Future<ResponseEntity> gatewayHandler(
  RequestEntity serverRequest,
  GatewayRoute gatewayRoute, {
  String? apiGatewayName,
}) async {
  Uri uri = Uri.parse(gatewayRoute.uri);
  final nonNullClient = http.Client();
  apiGatewayName ??= 'winter_api_gateway';

  // http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.8
  final requestUrl = uri.resolve(
    '/${serverRequest.url.toString()}'
        .replaceFirst(gatewayRoute.replaceFrom, gatewayRoute.replaceTo),
  );
  final clientRequest = http.StreamedRequest(serverRequest.method, requestUrl)
    ..followRedirects = false
    ..headers.addAll(serverRequest.headers)
    ..headers['Host'] = uri.authority;

  // Add a Via header. See
  // http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.45
  _addHeader(
    clientRequest.headers,
    'via',
    '${serverRequest.protocolVersion} $apiGatewayName',
  );

  serverRequest
      .read()
      .forEach(clientRequest.sink.add)
      .catchError(clientRequest.sink.addError)
      .whenComplete(clientRequest.sink.close)
      .ignore();

  final clientResponse = await nonNullClient.send(clientRequest);

  // Add a Via header. See
  // http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.45
  _addHeader(clientResponse.headers, 'via', '1.1 $apiGatewayName');

  // Remove the transfer-encoding since the body has already been decoded by
  // [client].
  clientResponse.headers.remove('transfer-encoding');

  // If the original response was gzipped, it will be decoded by [client]
  // and we'll have no way of knowing its actual content-length.
  if (clientResponse.headers['content-encoding'] == 'gzip') {
    clientResponse.headers.remove('content-encoding');
    clientResponse.headers.remove('content-length');

    // Add a Warning header. See
    // http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.5.2
    _addHeader(
      clientResponse.headers,
      'warning',
      '214 $apiGatewayName "GZIP decoded"',
    );
  }

  // Make sure the Location header is pointing to the proxy server rather
  // than the destination server, if possible.
  if (clientResponse.isRedirect &&
      clientResponse.headers.containsKey('location')) {
    final location =
        requestUrl.resolve(clientResponse.headers['location']!).toString();
    if (p.url.isWithin(uri.toString(), location)) {
      clientResponse.headers['location'] =
          '/${p.url.relative(location, from: uri.toString())}';
    } else {
      clientResponse.headers['location'] = location;
    }
  }

  return ResponseEntity(
    clientResponse.statusCode,
    body: clientResponse.stream,
    headers: clientResponse.headers,
  );
}

/// Add a header with [name] and [value] to [headers], handling existing headers
/// gracefully.
void _addHeader(Map<String, String> headers, String name, String value) {
  final existing = headers[name];
  headers[name] = existing == null ? value : '$existing, $value';
}

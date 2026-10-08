import 'dart:convert';
import 'dart:io' show HttpConnectionInfo;
import 'dart:typed_data';

import 'package:winter/winter.dart';

/// Send requests to a Winter pipeline in memory: no port, no network, no global server.
///
/// It runs exactly the same code as a real server (see [Winter.buildHandler]),
/// so tests are fast, can run in parallel and never collide on a port:
///
/// ```dart
/// final client = WinterTestClient.build(
///   router: WinterRouter(routes: [Route.get(path: '/hello', handler: hello)]),
/// );
///
/// final response = await client.get('/hello');
/// expect(response.statusCode, 200);
/// ```
///
/// {@category Testing}
class WinterTestClient {
  /// The pipeline the requests go to
  final RequestHandler handler;

  /// A client of [handler] (usually built with [WinterTestClient.build])
  WinterTestClient(this.handler);

  /// Build the client with the same parameters as [Winter.buildHandler]
  factory WinterTestClient.build({
    required BaseRouter router,
    FilterConfig? globalFilterConfig,
    SecurityConfig? securityConfig,
    int? maxBodySize = defaultMaxBodySize,
    Duration? requestTimeout,
  }) => WinterTestClient(
    Winter.buildHandler(
      router: router,
      globalFilterConfig: globalFilterConfig,
      securityConfig: securityConfig,
      maxBodySize: maxBodySize,
      requestTimeout: requestTimeout,
    ),
  );

  /// Send a request with any method. [body] can be a String, bytes or any object
  /// (serialized as JSON with the object mapper, with `Content-Type: application/json`).
  /// [headers] take a `String` or a `List<String>` per name.
  Future<TestResponse> request(
    String method,
    String path, {
    Map<String, Object>? headers,
    Object? body,
    HttpConnectionInfo? connectionInfo,
  }) async {
    final Map<String, Object> requestHeaders = {...?headers};
    Object? requestBody = body;
    if (body != null && body is! String && body is! List<int>) {
      requestBody = om.encode(body);
      requestHeaders.putIfAbsent(
        HttpHeader.contentType,
        () => MediaType.applicationJson.mimeType,
      );
    }

    final ResponseEntity response = await handler(
      RequestEntity(
        method,
        Uri.parse('http://localhost$path'),
        headers: requestHeaders,
        body: requestBody,
        connectionInfo: connectionInfo,
      ),
    );

    ///Like a real server: the body of a HEAD response is never sent
    final BytesBuilder bytes = BytesBuilder(copy: false);
    if (method.toUpperCase() != 'HEAD') {
      await response.read().forEach(bytes.add);
    }

    return TestResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      headersAll: response.headersAll,
      bodyBytes: bytes.takeBytes(),
      encoding: response.encoding,
    );
  }

  /// A `GET` of [path] (with its query: `/users?page=2`)
  Future<TestResponse> get(String path, {Map<String, Object>? headers}) =>
      request('GET', path, headers: headers);

  /// A `HEAD` of [path]: the headers, without a body
  Future<TestResponse> head(String path, {Map<String, Object>? headers}) =>
      request('HEAD', path, headers: headers);

  /// A `DELETE` of [path]
  Future<TestResponse> delete(String path, {Map<String, Object>? headers}) =>
      request('DELETE', path, headers: headers);

  /// A `POST` of [path] with [body] (see [request])
  Future<TestResponse> post(
    String path, {
    Map<String, Object>? headers,
    Object? body,
  }) => request('POST', path, headers: headers, body: body);

  /// A `PUT` of [path] with [body] (see [request])
  Future<TestResponse> put(
    String path, {
    Map<String, Object>? headers,
    Object? body,
  }) => request('PUT', path, headers: headers, body: body);

  /// A `PATCH` of [path] with [body] (see [request])
  Future<TestResponse> patch(
    String path, {
    Map<String, Object>? headers,
    Object? body,
  }) => request('PATCH', path, headers: headers, body: body);
}

/// A response of the [WinterTestClient], with the body already read
///
/// {@category Testing}
class TestResponse {
  /// The status code (`200`)
  final int statusCode;

  /// One value per header, case insensitive (several values joined with `, `)
  final Map<String, String> headers;

  /// Every value of each header, case insensitive (several `Set-Cookie`)
  final Map<String, List<String>> headersAll;

  /// The body as it was sent (an image, a file)
  final Uint8List bodyBytes;

  final Encoding? _encoding;

  /// A response read by the client
  TestResponse({
    required this.statusCode,
    required this.headers,
    required this.headersAll,
    required this.bodyBytes,
    this._encoding,
  });

  /// The body as text, decoded with the encoding of the response (UTF-8 by default). Only when
  /// it's read, so a binary body (see [bodyBytes]) never fails.
  late final String body = (_encoding ?? utf8).decode(bodyBytes);

  /// The body decoded as JSON
  dynamic get json => jsonDecode(body);
}

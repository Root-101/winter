import 'dart:convert';

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
class WinterTestClient {
  final Handler handler;

  WinterTestClient(this.handler);

  /// Build the client with the same parameters as [Winter.buildHandler]
  factory WinterTestClient.build({
    required AbstractWinterRouter router,
    FilterConfig? globalFilterConfig,
    SecurityConfig? securityConfig,
    int? maxBodySize = defaultMaxBodySize,
  }) => WinterTestClient(
    Winter.buildHandler(
      router: router,
      globalFilterConfig: globalFilterConfig,
      securityConfig: securityConfig,
      maxBodySize: maxBodySize,
    ),
  );

  /// Send a request with any method. [body] can be a String, bytes or any object
  /// (serialized as JSON with the object mapper, with `Content-Type: application/json`).
  Future<TestResponse> request(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final Map<String, String> requestHeaders = {...?headers};
    Object? requestBody = body;
    if (body != null && body is! String && body is! List<int>) {
      requestBody = om.encode(body);
      requestHeaders.putIfAbsent(
        HttpHeader.contentType,
        () => MediaType.applicationJson.mimeType,
      );
    }

    final Response response = await handler(
      Request(
        method.toUpperCase(),
        Uri.parse('http://localhost$path'),
        headers: requestHeaders,
        body: requestBody,
      ),
    );

    ///Like a real server: the body of a HEAD response is never sent
    final String responseBody = method.toUpperCase() == 'HEAD'
        ? ''
        : await response.readAsString();

    return TestResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: responseBody,
    );
  }

  Future<TestResponse> get(String path, {Map<String, String>? headers}) =>
      request('GET', path, headers: headers);

  Future<TestResponse> head(String path, {Map<String, String>? headers}) =>
      request('HEAD', path, headers: headers);

  Future<TestResponse> delete(String path, {Map<String, String>? headers}) =>
      request('DELETE', path, headers: headers);

  Future<TestResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => request('POST', path, headers: headers, body: body);

  Future<TestResponse> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => request('PUT', path, headers: headers, body: body);

  Future<TestResponse> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => request('PATCH', path, headers: headers, body: body);
}

/// A response of the [WinterTestClient], with the body already read
class TestResponse {
  final int statusCode;

  /// Case insensitive, like the headers of a shelf response
  final Map<String, String> headers;

  final String body;

  TestResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  /// The body decoded as JSON
  dynamic get json => jsonDecode(body);
}

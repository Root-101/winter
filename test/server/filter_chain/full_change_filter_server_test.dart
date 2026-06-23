@TestOn('vm')
library;

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  int port = 9020;
  String localUrl = 'http://localhost:$port';

  setUpAll(() async {
    await Winter.start(
      config: ServerConfig(port: port),
      globalFilterConfig: FilterConfig([FullChangeFilterFilter()]),
      router: WinterRouter(
        routes: [
          Route(
            path: '/full-change-filter',
            method: HttpMethod.post,
            handler: (request) async {
              String? body = await request.body<String>();
              return ResponseEntity.ok(
                body: body,
                headers: {
                  'before-request-header':
                      request.headers['before-request-header'] ?? '',
                },
              );
            },
          ),
          Route(
            path: '/body-change',
            method: HttpMethod.post,
            filterConfig: FilterConfig([BodyChangeFilter()]),
            handler: (request) async {
              String? body = await request.body<String>();
              return ResponseEntity.ok(body: body);
            },
          ),
          Route(
            path: '/early-response',
            method: HttpMethod.get,
            filterConfig: FilterConfig([EarlyResponseFilter()]),
            handler: (request) async {
              return ResponseEntity.ok(body: 'Handler response');
            },
          ),
          Route(
            path: '/response-body-change',
            method: HttpMethod.get,
            filterConfig: FilterConfig([ResponseBodyChangeFilter()]),
            handler: (request) async {
              return ResponseEntity.ok(body: 'Original');
            },
          ),
          Route(
            path: '/multiple-filters',
            method: HttpMethod.post,
            filterConfig:
                FilterConfig([BodyChangeFilter(), ResponseBodyChangeFilter()]),
            handler: (request) async {
              String? body = await request.body<String>();
              return ResponseEntity.ok(body: 'Handler received: $body');
            },
          ),
          Route(
            path: '/exception',
            method: HttpMethod.get,
            filterConfig: FilterConfig([ExceptionFilter()]),
            handler: (request) async => ResponseEntity.ok(),
          ),
          Route(
            path: '/double-call',
            method: HttpMethod.get,
            filterConfig: FilterConfig([DoubleCallFilter()]),
            handler: (request) async => ResponseEntity.ok(body: 'Success'),
          ),
          Route(
            path: '/params/{id}',
            method: HttpMethod.get,
            filterConfig: FilterConfig([ParamCheckFilter()]),
            handler: (request) async => ResponseEntity.ok(body: 'Success'),
          ),
        ],
      ),
    );
  });

  tearDownAll(() => Winter.close(force: true));

  Uri url(String path) => Uri.parse(localUrl + path);

  test('Test Full Change Filter', () async {
    String urlToTest = '/full-change-filter';

    String body = 'Hello world!!!';
    http.Response response = await http.post(url(urlToTest), body: body);

    expect(response.statusCode, 200);
    expect(response.body, body);
    expect(response.headers['before-request-header'], 'before-request');
    expect(response.headers['after-request-header'], 'after-request');
  });

  test('Test Body Change Filter', () async {
    String urlToTest = '/body-change';

    String body = 'Hello';
    http.Response response = await http.post(url(urlToTest), body: body);

    expect(response.statusCode, 200);
    expect(response.body, 'Hello modified');
    expect(response.headers['after-request-header'], 'after-request');
  });

  test('Test Early Response Filter', () async {
    String urlToTest = '/early-response';

    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Early response');
    expect(response.headers['after-request-header'], 'after-request');
  });

  test('Test Response Body Change Filter', () async {
    String urlToTest = '/response-body-change';

    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Original modified');
    expect(response.headers['after-request-header'], 'after-request');
  });

  test('Test Multiple Filters Interaction', () async {
    String urlToTest = '/multiple-filters';

    String body = 'Start';
    http.Response response = await http.post(url(urlToTest), body: body);

    expect(response.statusCode, 200);
    expect(response.body, 'Handler received: Start modified modified');
    expect(response.headers['after-request-header'], 'after-request');
  });

  test('Test Exception in Filter', () async {
    String urlToTest = '/exception';

    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 500);
    expect(response.body, contains('Exception: Filter error'));
  });

  test('Test Filter Chain ended without response', () async {
    String urlToTest = '/double-call';

    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 500);
    expect(response.body, 'Filter chain ended without a response');
  });

  test('Test Params in Filter', () async {
    String urlToTest = '/params/123?query=abc';

    http.Response response = await http.get(url(urlToTest));

    expect(response.statusCode, 200);
    expect(response.body, 'Success');

    urlToTest = '/params/456?query=abc';
    response = await http.get(url(urlToTest));
    expect(response.statusCode, 400);
    expect(response.body, 'Invalid params');
  });
}

class FullChangeFilterFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    RequestEntity newRequestEntity = await request.copyWith(
      headers: {...request.headers, 'before-request-header': 'before-request'},
    );

    ResponseEntity newResponseEntity = await chain.doFilter(newRequestEntity);

    newResponseEntity = newResponseEntity.copyWith(
      headers: {
        ...newResponseEntity.headers,
        'after-request-header': 'after-request',
      },
    );

    return newResponseEntity;
  }
}

class BodyChangeFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    String? body = await request.body<String>();
    RequestEntity newRequest =
        await request.copyWith(body: '${body ?? ''} modified');
    return await chain.doFilter(newRequest);
  }
}

class EarlyResponseFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    return ResponseEntity.ok(body: 'Early response');
  }
}

class ResponseBodyChangeFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    ResponseEntity response = await chain.doFilter(request);
    return response.copyWith(body: '${response.body()} modified');
  }
}

class ExceptionFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    throw Exception('Filter error');
  }
}

class DoubleCallFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    await chain.doFilter(request);
    return await chain.doFilter(request);
  }
}

class ParamCheckFilter implements Filter {
  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    if (request.pathParams['id'] == '123' &&
        request.queryParams['query'] == 'abc') {
      return await chain.doFilter(request);
    }
    return ResponseEntity.badRequest(body: 'Invalid params');
  }
}

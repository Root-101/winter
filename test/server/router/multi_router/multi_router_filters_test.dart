@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

///Global filter that authenticates the request when the header 'X-User' is present
class HeaderAuthFilter extends Filter {
  @override
  FutureOr<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) {
    final user = request.headers['X-User'];
    if (user != null) {
      request.securityContext.setAuthentication(
        Authentication(principal: user),
      );
    }
    return chain.doFilter(request);
  }
}

///Route filter that marks the response, to check it was applied
class MarkerFilter extends Filter {
  @override
  FutureOr<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final response = await chain.doFilter(request);
    return response.copyWith(
      headers: {...response.headers, 'X-Marker': 'applied'},
    );
  }
}

void main() {
  late WinterTestClient client;

  setUpAll(() async {
    client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([HeaderAuthFilter()]),
      router: MultiRouter([
        WinterRouter(
          routes: [
            Route.get(
              path: '/secret',
              handler: (request) => ResponseEntity.ok(body: 'secret data'),
              filterConfig: FilterConfig([AuthFilter()]),
            ),
          ],
        ),
        WinterRouter(
          routes: [
            Route.get(
              path: '/items/{id}',
              handler: (request) =>
                  ResponseEntity.ok(body: 'item ${request.pathParams['id']}'),
            ),
          ],
        ),
        MultiRouter([
          WinterRouter(
            routes: [
              Route.get(
                path: '/nested',
                handler: (request) => ResponseEntity.ok(body: 'nested'),
                filterConfig: FilterConfig([MarkerFilter()]),
              ),
            ],
          ),
        ]),
        ServeRouter((request) => ResponseEntity.ok(body: 'fallback')),
      ]),
    );
  });

  test('Route AuthFilter is applied inside a MultiRouter', () async {
    final response = await client.get('/secret');

    expect(response.statusCode, 401);
    expect(response.body, isNot(contains('secret data')));
  });

  test('Authenticated request passes the route AuthFilter', () async {
    final response = await client.get('/secret', headers: {'X-User': 'adam'});

    expect(response.statusCode, 200);
    expect(response.body, 'secret data');
  });

  test('Path params are resolved inside a MultiRouter', () async {
    final response = await client.get('/items/42');

    expect(response.statusCode, 200);
    expect(response.body, 'item 42');
  });

  test('Route filters are applied in nested MultiRouters', () async {
    final response = await client.get('/nested');

    expect(response.statusCode, 200);
    expect(response.body, 'nested');
    expect(response.headers['x-marker'], 'applied');
  });

  test('ServeRouter inside a MultiRouter still works', () async {
    final response = await client.get('/anything-else');

    expect(response.statusCode, 200);
    expect(response.body, 'fallback');
    expect(response.headers.containsKey('x-marker'), isFalse);
  });
}

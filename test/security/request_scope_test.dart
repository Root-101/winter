import 'dart:async';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// Authenticates the request when the header 'X-User' is present
class _HeaderAuthFilter extends Filter {
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

/// Passes a changed copy of the request to the chain and, after it, reads the user of the original
class _ChangeRequestFilter extends Filter {
  String? userSeenAfterChain;

  @override
  Future<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final response = await chain.doFilter(
      request.change(headers: {'X-Changed': 'true'}),
    );
    userSeenAfterChain = request.securityContext.authentication?.name;
    return response;
  }
}

/// Like a service of the app: it doesn't receive the request
String currentUserName() => requestAuthentication?.name ?? 'anonymous';

void main() {
  test('There is no scope outside a request', () {
    expect(RequestScope.current, isNull);
    expect(requestSecurityContext, isNull);
    expect(requestAuthentication, isNull);
  });

  test(
    'A service reads the user of the request without receiving it',
    () async {
      final client = WinterTestClient.build(
        globalFilterConfig: FilterConfig([_HeaderAuthFilter()]),
        router: ServeRouter(
          (request) => ResponseEntity.ok(body: currentUserName()),
        ),
      );

      expect((await client.get('/', headers: {'X-User': 'adam'})).body, 'adam');
      expect((await client.get('/')).body, 'anonymous');
    },
  );

  test('The scope has the same security context as the request', () async {
    final client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([_HeaderAuthFilter()]),
      router: ServeRouter(
        (request) => ResponseEntity.ok(
          body: identical(request.securityContext, requestSecurityContext),
        ),
      ),
    );

    expect((await client.get('/', headers: {'X-User': 'adam'})).body, 'true');
  });

  test(
    'A user set on a changed request is seen by the original one and the scope',
    () async {
      final changeFilter = _ChangeRequestFilter();
      final client = WinterTestClient.build(
        ///The request is changed before anybody reads its security context
        globalFilterConfig: FilterConfig([changeFilter, _HeaderAuthFilter()]),
        router: ServeRouter((request) {
          expect(request.headers['X-Changed'], 'true');
          return ResponseEntity.ok(body: currentUserName());
        }),
      );

      final response = await client.get('/', headers: {'X-User': 'adam'});

      expect(response.body, 'adam');
      expect(changeFilter.userSeenAfterChain, 'adam');
    },
  );

  test('Concurrent requests never see the user of another one', () async {
    const int requests = 50;
    int arrived = 0;
    final gate = Completer<void>();

    final client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([_HeaderAuthFilter()]),
      router: ServeRouter((request) async {
        final before = currentUserName();

        ///Every request waits here until all of them are in progress
        if (++arrived == requests) gate.complete();
        await gate.future;

        return ResponseEntity.ok(body: '$before:${currentUserName()}');
      }),
    );

    final responses = await Future.wait([
      for (int i = 0; i < requests; i++)
        client.get('/', headers: {'X-User': 'user$i'}),
    ]);

    for (int i = 0; i < requests; i++) {
      expect(responses[i].body, 'user$i:user$i');
    }
  });

  test('Work started by a request keeps its user after the response', () async {
    final release = Completer<void>();
    final seen = Completer<String>();

    final client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([_HeaderAuthFilter()]),
      router: ServeRouter((request) {
        if (request.headers['X-User'] == 'adam') {
          unawaited(() async {
            await release.future;
            seen.complete(currentUserName());
          }());
        }
        return ResponseEntity.ok(body: currentUserName());
      }),
    );

    expect((await client.get('/', headers: {'X-User': 'adam'})).body, 'adam');

    ///Another request in the meantime doesn't change it
    expect((await client.get('/', headers: {'X-User': 'eve'})).body, 'eve');
    release.complete();

    expect(await seen.future, 'adam');
  });

  test('A timer started by a request keeps its user', () async {
    final seen = Completer<String>();
    final client = WinterTestClient.build(
      globalFilterConfig: FilterConfig([_HeaderAuthFilter()]),
      router: ServeRouter((request) {
        Timer(Duration.zero, () => seen.complete(currentUserName()));
        return ResponseEntity.ok();
      }),
    );

    await client.get('/', headers: {'X-User': 'adam'});

    expect(await seen.future, 'adam');
  });

  test('RequestScope.run gives a scope to code outside the server', () async {
    final securityContext = RequestSecurityContext<String>.empty()
      ..setAuthentication(Authentication(principal: 'adam'));

    final String name = await RequestScope.run(
      RequestScope(securityContext: securityContext),
      () async {
        await Future<void>.delayed(Duration.zero);
        return currentUserName();
      },
    );

    expect(name, 'adam');
    expect(requestAuthentication, isNull);
  });
}

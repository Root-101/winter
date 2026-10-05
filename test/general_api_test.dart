import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

class _NamedFilter extends Filter {
  final String name;
  final List<String> log;

  _NamedFilter(this.name, this.log, {super.order});

  @override
  FutureOr<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) {
    log.add(name);
    return chain.doFilter(request);
  }
}

void main() {
  test('Filters with the same order keep their order (stable sort)', () async {
    final log = <String>[];
    final filters = [
      for (int i = 0; i < 100; i++) _NamedFilter('$i', log, order: i % 2),
    ];

    await FilterChain(
      filters,
      (request) => ResponseEntity.ok(),
    ).doFilter(RequestEntity('GET', Uri.parse('http://localhost/')));

    expect(log, [
      for (int i = 0; i < 100; i += 2) '$i',
      for (int i = 1; i < 100; i += 2) '$i',
    ]);
  });

  test('Filters can be added to the default FilterConfig of a Route', () {
    final route = Route.get(path: '/a', handler: (r) => ResponseEntity.ok());

    route.filterConfig.add(_NamedFilter('added', []));

    expect(route.filterConfig.filters, hasLength(1));
  });

  test('MediaType values are constants', () {
    const json = MediaType.applicationJson;
    expect(json.mimeType, 'application/json');
  });

  test(
    'HttpHeader & StatusCode do not shadow dart:io HttpHeaders & HttpStatus',
    () {
      ///Both libraries are imported in this file: this only compiles if the names don't collide
      expect(HttpHeaders.contentTypeHeader, 'content-type');
      expect(HttpStatus.notFound, 404);
      expect(HttpHeader.contentType, 'Content-Type');
      expect(StatusCode.notFound.value, 404);
    },
  );

  test('MediaType.parse', () {
    final mediaType = MediaType.parse(
      'application/json; charset=utf-8; name="my file"',
    );

    expect(mediaType.type, 'application');
    expect(mediaType.subtype, 'json');
    expect(mediaType.parameters, {'charset': 'utf-8', 'name': 'my file'});
    expect(() => MediaType.parse('not a media type'), throwsFormatException);
  });

  test(
    'ResponseEntity with DateTime & enums inside toJson is valid JSON',
    () async {
      final response = ResponseEntity.ok(body: _Order());

      expect(response.headers['content-type'], 'application/json');
      expect(
        await response.readAsString(),
        '{"at":"2026-01-01T00:00:00.000Z","status":"paid","tags":["a"]}',
      );
    },
  );

  test('ApiException has a readable toString', () {
    final exception = NotFoundException(body: 'User not found');

    expect(exception.toString(), contains('NotFoundException'));
    expect(exception.toString(), contains('404'));
    expect(exception.toString(), contains('User not found'));
  });

  test('Winter.close calls onNotRunning when no server is running', () async {
    bool called = false;
    await Winter.close(onNotRunning: () => called = true);

    expect(called, isTrue);
  });
}

enum _Status { paid }

class _Order implements Serializable {
  @override
  Object? toJson() => {
    'at': DateTime.utc(2026),
    'status': _Status.paid,
    'tags': {'a'},
  };
}

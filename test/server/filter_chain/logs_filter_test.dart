import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// Captures everything written to stdout
class _CapturedStdout implements Stdout {
  final StringBuffer buffer = StringBuffer();

  @override
  void writeln([Object? object = '']) => buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  RequestEntity request() => RequestEntity(
    'POST',
    Uri.parse('http://localhost/login?token=secret-query'),
  );

  test(
    'Default logs include method, path & status, but not body nor query',
    () async {
      final captured = _CapturedStdout();

      await IOOverrides.runZoned(() async {
        final chain = FilterChain([
          LogsFilter(),
        ], (request) => ResponseEntity.ok(body: {'token': 'secret-body'}));
        await chain.doFilter(request());
      }, stdout: () => captured);

      final output = captured.buffer.toString();
      expect(output, contains('REQUEST: POST /login'));
      expect(output, contains('RESPONSE: POST /login => 200'));
      expect(output, isNot(contains('secret-body')));
      expect(output, isNot(contains('secret-query')));
    },
  );

  test('Error responses are logged as responses (with their status)', () async {
    final logged = <int>[];
    final chain = FilterChain(
      [
        LogsFilter(
          logResponse: (req, res, duration) => logged.add(res.statusCode),
        ),
      ],
      (request) => throw const NotFoundException(),
      exceptionHandler: SimpleExceptionHandler(),
    );

    final response = await chain.doFilter(request());

    expect(response.statusCode, 404);
    expect(logged, [404]);
  });

  test('The duration of the request is logged', () async {
    Duration? loggedDuration;
    final chain = FilterChain(
      [
        LogsFilter(
          logResponse: (req, res, duration) => loggedDuration = duration,
        ),
      ],
      (request) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return ResponseEntity.ok();
      },
    );

    await chain.doFilter(request());

    expect(
      loggedDuration,
      greaterThanOrEqualTo(const Duration(milliseconds: 20)),
    );
  });
}

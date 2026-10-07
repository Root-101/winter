@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The behavior decided in the review of the logging (DECISIONS.md §7)
void main() {
  late _MemoryLogger memory;

  setUp(() {
    memory = _MemoryLogger();
    Winter.context.setUp(logger: memory);
    addTearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));
  });

  group('The logs never contain the data of a request (§7.1)', () {
    final mapper = ObjectMapper(
      deserializers: [
        Deserializer<Duration>(
          (data) => Duration(seconds: int.parse(data as String)),
        ),
      ],
    );

    test(
      'a failed deserialization logs the type of the error, never its message',
      () {
        expect(
          () => mapper.decode<Duration>(jsonEncode('card-4111111111111111')),
          throwsA(isA<DeserializationException>()),
        );

        expect(
          memory.messages.single,
          'Invalid value for <Duration> (FormatException)',
        );
      },
    );

    test('nothing is logged when debug is off', () {
      memory.enabled = false;

      expect(() => mapper.decode<Duration>('"x"'), throwsA(anything));
      expect(memory.messages, isEmpty);
    });
  });

  group('WinterLogger (§7.2)', () {
    test('every level takes an error, a stack trace and fields', () {
      final error = StateError('x');
      final stackTrace = StackTrace.current;

      memory
        ..debug('d', error: error, stackTrace: stackTrace, fields: {'a': 1})
        ..info('i', error: error, fields: {'b': 2})
        ..warning('w', stackTrace: stackTrace)
        ..error('e', error: error);

      expect(memory.entries.map((entry) => entry.level), LogLevel.values);
      expect(memory.entries[0].error, same(error));
      expect(memory.entries[0].stackTrace, same(stackTrace));
      expect(memory.entries[0].fields, {'a': 1});
      expect(memory.entries[1].fields, {'b': 2});
    });

    test('isEnabled is true by default, and follows minLevel', () {
      expect(memory.isEnabled(LogLevel.debug), isTrue);
      expect(const ConsoleLogger().isEnabled(LogLevel.debug), isFalse);
      expect(const ConsoleLogger().isEnabled(LogLevel.info), isTrue);
      expect(
        const JsonLogger(minLevel: LogLevel.warning).isEnabled(LogLevel.info),
        isFalse,
      );
    });

    test('the debug log of the rate limiter is skipped when debug is off', () {
      final request = RequestEntity('GET', Uri.parse('http://x/limited'));

      memory.enabled = false;
      defaultLogRateLimiter(request, 'client');
      expect(memory.messages, isEmpty);

      memory.enabled = true;
      defaultLogRateLimiter(request, 'client');
      expect(memory.messages.single, contains('Rate limit exceeded'));
    });
  });

  group('ConsoleLogger (§7.3)', () {
    test('a line with the time in UTC, the level and the fields', () {
      final out = _capture(
        () => const ConsoleLogger().info(
          'Order created',
          fields: {'orderId': 42},
        ),
      );

      expect(
        out.stdout,
        matches(
          RegExp(
            r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z \[INFO\] Order created orderId=42\n$',
          ),
        ),
      );
    });

    test('the request id inside a request', () {
      final out = _capture(
        () => RequestScope.run(
          RequestScope(requestId: 'req-1'),
          () => const ConsoleLogger().info('hello'),
        ),
      );

      expect(out.stdout, contains('[INFO] [req-1] hello'));
    });

    test('warning and error to stderr, with the error and the stack trace', () {
      final out = _capture(() {
        const ConsoleLogger().error(
          'failed',
          error: StateError('boom'),
          stackTrace: StackTrace.fromString('#0 main'),
        );
        const ConsoleLogger().warning('careful');
      });

      expect(out.stdout, isEmpty);
      expect(
        out.stderr,
        contains('[ERROR] failed\nBad state: boom\n#0 main\n'),
      );
      expect(out.stderr, contains('[WARNING] careful'));
    });

    test('below minLevel nothing is written', () {
      final out = _capture(() => const ConsoleLogger().debug('hidden'));

      expect(out.stdout, isEmpty);
    });
  });

  group('JsonLogger (§7.3)', () {
    Map<String, Object?> line(String output) =>
        jsonDecode(output.trim()) as Map<String, Object?>;

    test('one JSON object per line, with time, severity and message', () {
      final out = _capture(() => const JsonLogger().info('Order created'));

      final json = line(out.stdout);
      expect(out.stdout.trim().split('\n'), hasLength(1));
      expect(json['severity'], 'INFO');
      expect(json['message'], 'Order created');
      expect(json['time'] as String, endsWith('Z'));
      expect(json, isNot(contains('requestId')));
    });

    test('the request id, the error and the stack trace as strings', () {
      final out = _capture(
        () => RequestScope.run(
          RequestScope(requestId: 'req-1'),
          () => const JsonLogger().error(
            'failed',
            error: StateError('boom'),
            stackTrace: StackTrace.fromString('#0 main\n#1 run'),
          ),
        ),
      );

      final json = line(out.stdout);
      expect(json['requestId'], 'req-1');
      expect(json['error'], 'Bad state: boom');
      expect(json['stackTrace'], '#0 main\n#1 run');
      expect(out.stderr, isEmpty);
    });

    test(
      'the fields are members of their own, never replacing the standard ones',
      () {
        final out = _capture(
          () => const JsonLogger().info(
            'Order created',
            fields: {
              'orderId': 42,
              'tags': ['a'],
              'at': DateTime.utc(2026),
              'message': 'replaced?',
              'severity': 'DEBUG',
            },
          ),
        );

        expect(line(out.stdout), {
          'orderId': 42,
          'tags': ['a'],
          'at': DateTime.utc(2026).toString(),
          'time': isA<String>(),
          'severity': 'INFO',
          'message': 'Order created',
        });
      },
    );

    test('below minLevel nothing is written', () {
      final out = _capture(
        () => const JsonLogger(minLevel: LogLevel.error).warning('hidden'),
      );

      expect(out.stdout, isEmpty);
    });
  });

  group('The request id (§7.4)', () {
    String? seenInHandler;
    late WinterTestClient client;

    setUp(() {
      seenInHandler = null;
      client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/',
              handler: (request) {
                seenInHandler = requestId;
                return ResponseEntity.ok();
              },
            ),
            Route.get(path: '/error', handler: (r) => throw StateError('bug')),
          ],
        ),
      );
    });

    test(
      'a new one when the request has none, in the response and the scope',
      () async {
        final response = await client.get('/');

        final String id = response.headers['x-request-id']!;
        expect(
          id,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        expect(seenInHandler, id);
      },
    );

    test('the one of the request when it is valid', () async {
      final response = await client.get(
        '/',
        headers: {'X-Request-Id': 'gw-12.ab:cd_ef'},
      );

      expect(response.headers['x-request-id'], 'gw-12.ab:cd_ef');
      expect(seenInHandler, 'gw-12.ab:cd_ef');
    });

    test('a new one when the one of the request is not valid', () async {
      for (final invalid in [
        'with space',
        'a' * 129,
        'line\rbreak',
        '{json}',
      ]) {
        final response = await client.get(
          '/',
          headers: {'X-Request-Id': invalid},
        );

        expect(
          response.headers['x-request-id'],
          isNot(invalid),
          reason: invalid,
        );
      }
    });

    test('every request gets its own', () async {
      final responses = await Future.wait([
        for (var i = 0; i < 10; i++) client.get('/'),
      ]);

      expect(
        responses.map((r) => r.headers['x-request-id']).toSet(),
        hasLength(10),
      );
    });

    test('the 500 has it, and its log too', () async {
      final response = await client.get('/error');

      final String id = response.headers['x-request-id']!;
      expect((response.json as Map)['requestId'], id);
      expect(memory.entries.single.requestId, id);
    });

    test('LogsFilter writes its two lines with it', () async {
      final logged = WinterTestClient.build(
        globalFilterConfig: FilterConfig([LogsFilter()]),
        router: WinterRouter(
          routes: [
            Route.get(path: '/users/1', handler: (r) => ResponseEntity.ok()),
          ],
        ),
      );

      final response = await logged.get('/users/1');

      final String id = response.headers['x-request-id']!;
      expect(memory.messages, [
        'REQUEST: GET /users/1',
        startsWith('RESPONSE: GET /users/1 => 200'),
      ]);
      expect(memory.entries.map((entry) => entry.requestId), [id, id]);
    });

    test('outside a request there is none', () {
      expect(requestId, isNull);
      expect(RequestScope().requestId, isNotEmpty);
      expect(RequestScope.newRequestId(), isNot(RequestScope.newRequestId()));
      expect(RequestScope.isValidRequestId(null), isFalse);
      expect(RequestScope.isValidRequestId(''), isFalse);
    });
  });
}

class _Entry {
  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, Object?> fields;

  /// The request id when it was logged
  final String? requestId;

  _Entry(
    this.level,
    this.message,
    this.error,
    this.stackTrace,
    this.fields,
    this.requestId,
  );
}

class _MemoryLogger extends WinterLogger {
  final List<_Entry> entries = [];
  bool enabled = true;

  List<String> get messages => [for (final entry in entries) entry.message];

  @override
  bool isEnabled(LogLevel level) => enabled;

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    if (!enabled) return;
    entries.add(_Entry(level, message, error, stackTrace, fields, requestId));
  }
}

class _Output {
  final _FakeStdout _out = _FakeStdout();
  final _FakeStdout _err = _FakeStdout();

  String get stdout => _out.buffer.toString();

  String get stderr => _err.buffer.toString();
}

/// What [body] writes to stdout and stderr
_Output _capture(void Function() body) {
  final output = _Output();
  IOOverrides.runZoned(
    body,
    stdout: () => output._out,
    stderr: () => output._err,
  );
  return output;
}

class _FakeStdout implements Stdout {
  final StringBuffer buffer = StringBuffer();

  @override
  void writeln([Object? object = '']) => buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

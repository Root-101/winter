import 'dart:io';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// Captures everything written to stdout or stderr
class _CapturedOutput implements Stdout {
  final StringBuffer buffer = StringBuffer();

  @override
  void writeln([Object? object = '']) => buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MemoryLogger extends WinterLogger {
  final List<String> logs = [];

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) => logs.add('${level.name}: $message${error == null ? '' : ' ($error)'}');
}

void main() {
  group('ConsoleLogger', () {
    test(
      'info to stdout, warning & error to stderr, debug ignored by default',
      () {
        final out = _CapturedOutput();
        final err = _CapturedOutput();

        IOOverrides.runZoned(
          () {
            const logger = ConsoleLogger();
            logger.debug('debug message');
            logger.info('info message');
            logger.warning('warning message');
            logger.error('error message', error: StateError('boom'));
          },
          stdout: () => out,
          stderr: () => err,
        );

        expect(out.buffer.toString(), contains('[INFO] info message'));
        expect(out.buffer.toString(), isNot(contains('debug message')));
        expect(err.buffer.toString(), contains('[WARNING] warning message'));
        expect(err.buffer.toString(), contains('[ERROR] error message'));
        expect(err.buffer.toString(), contains('Bad state: boom'));
      },
    );

    test('minLevel filters the less important logs', () {
      final out = _CapturedOutput();
      final err = _CapturedOutput();

      IOOverrides.runZoned(
        () {
          const logger = ConsoleLogger(minLevel: LogLevel.error);
          logger.info('info message');
          logger.warning('warning message');
          logger.error('error message');
        },
        stdout: () => out,
        stderr: () => err,
      );

      expect(out.buffer.toString(), isEmpty);
      expect(err.buffer.toString(), isNot(contains('warning message')));
      expect(err.buffer.toString(), contains('error message'));
    });
  });

  group('Framework logs go through the logger of the context', () {
    late _MemoryLogger memoryLogger;

    setUp(() {
      memoryLogger = _MemoryLogger();
      Winter.context.setUp(logger: memoryLogger);
    });

    tearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));

    test('Unhandled errors are logged as errors', () async {
      final chain = FilterChain(
        [],
        (request) => throw Exception('internal detail'),
        exceptionHandler: SimpleExceptionHandler(),
      );

      await chain.doFilter(RequestEntity('GET', Uri.parse('http://x/fail')));

      expect(
        memoryLogger.logs.single,
        startsWith('error: Unhandled error in GET /fail'),
      );
      expect(memoryLogger.logs.single, contains('internal detail'));
    });

    test('Router warnings (duplicated routes) are logged as warnings', () {
      WinterRouter(
        config: RouterConfig(
          onDuplicatedRoute: DefaultOnDuplicatedRoute.ignore(),
        ),
        routes: [
          Route.get(path: '/a', handler: (r) => ResponseEntity.ok()),
          Route.get(path: '/a', handler: (r) => ResponseEntity.ok()),
        ],
      );

      expect(memoryLogger.logs.single, startsWith('warning: '));
      expect(memoryLogger.logs.single, contains('duplicated route'));
    });

    test('Rate limited requests are logged at debug level', () async {
      final filter = RateLimiterFilter(
        maxRequests: 1,
        window: const Duration(minutes: 1),
        onRequest: (request) => 'client',
      );
      final chain = FilterChain(
        [filter],
        (request) => ResponseEntity.ok(),
        exceptionHandler: SimpleExceptionHandler(),
      );
      RequestEntity request() => RequestEntity('GET', Uri.parse('http://x/'));

      await chain.doFilter(request());
      await chain.doFilter(request());

      expect(
        memoryLogger.logs.single,
        startsWith('debug: Rate limit exceeded'),
      );
    });
  });
}

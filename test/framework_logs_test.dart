import 'package:test/test.dart';
import 'package:winter/winter.dart';

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

/// The logs that the framework writes go through the logger of the context (the loggers
/// themselves are in `logging_behavior_test.dart`)
void main() {
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
        clientId: (request) => 'client',
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

import 'dart:convert';

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
  }) => logs.add('${level.name}: $message');
}

/// A response header that `dart:io` refuses is a 500 (DECISIONS.md §8): never a header injection,
/// and never a response sent broken without a trace
void main() {
  late _MemoryLogger memoryLogger;

  setUp(() {
    memoryLogger = _MemoryLogger();
    Winter.context.setUp(logger: memoryLogger);
  });

  tearDown(() => Winter.context.setUp(logger: const ConsoleLogger()));

  final WinterTestClient client = WinterTestClient.build(
    router: WinterRouter(
      routes: [
        Route.get(
          path: '/go',
          handler: (request) =>
              ResponseEntity.seeOther(request.queryParam<String>('to') ?? '/'),
        ),
        Route.get(
          path: '/download',
          handler: (request) => ResponseEntity.ok(
            body: 'pdf',
            headers: {
              'Content-Disposition':
                  'attachment; filename="${request.queryParam<String>('name')}"',
            },
          ),
        ),
        Route.get(
          path: '/name',
          handler: (request) => ResponseEntity.ok(
            body: 'x',
            headers: {request.queryParam<String>('header')!: 'v'},
          ),
        ),
        Route.post(
          path: '/json',
          handler: (request) async => ResponseEntity.ok(
            body: await request.body<Map<String, dynamic>>(),
          ),
        ),
      ],
    ),
  );

  test(
    'a line break from the request is a 500, not a header injection',
    () async {
      final TestResponse response = await client.get(
        '/go?to=%2Fhome%0D%0ASet-Cookie:%20session=stolen',
      );

      expect(response.statusCode, 500);
      expect(response.headers, isNot(contains('location')));
      expect(response.headers, isNot(contains('set-cookie')));
      expect(response.headers['x-request-id'], isNotEmpty);
      expect(memoryLogger.logs, [
        'error: The response of GET /go has an invalid value in the header Location (a line '
            'break, a control character or a character that is not ASCII): answered with a 500',
      ]);
      expect(memoryLogger.logs.single, isNot(contains('stolen')));
    },
  );

  test('a value that is not ASCII is a 500 (dart:io refuses it)', () async {
    final TestResponse response = await client.get(
      '/download?name=a%C3%B1o.pdf',
    );

    expect(response.statusCode, 500);
    expect(
      memoryLogger.logs.single,
      contains('the header Content-Disposition'),
    );
  });

  test('an invalid name is a 500, and the name is not logged', () async {
    final TestResponse response = await client.get(
      '/name?header=X-A%0D%0AX-Evil',
    );

    expect(response.statusCode, 500);
    expect(memoryLogger.logs.single, contains('a header with an invalid name'));
    expect(memoryLogger.logs.single, isNot(contains('Evil')));
  });

  test('a tab and every visible ASCII character are valid', () async {
    final TestResponse response = await client.get(
      '/download?name=${Uri.encodeQueryComponent('a\tb !~.pdf')}',
    );

    expect(response.statusCode, 200);
    expect(
      response.headers['content-disposition'],
      'attachment; filename="a\tb !~.pdf"',
    );
    expect(memoryLogger.logs, isEmpty);
  });

  test('a 415 shows at most 100 characters of the Content-Type', () async {
    final TestResponse response = await client.post(
      '/json',
      body: '{}',
      headers: {'content-type': 'text/${'x' * 5000}'},
    );

    expect(response.statusCode, 415);
    final String detail =
        (jsonDecode(response.body) as Map)['detail'] as String;
    expect(
      detail,
      'Unsupported Content-Type text/${'x' * 95}..., expected application/json',
    );
  });
}

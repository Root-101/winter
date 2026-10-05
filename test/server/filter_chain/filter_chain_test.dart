import 'dart:async';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('FilterChain Ordering Tests', () {
    test(
      'Filters should execute in ascending order of their order property',
      () async {
        final log = <String>[];
        final filters = [
          LoggingFilter('second', log, order: 10),
          LoggingFilter('first', log, order: 5),
          LoggingFilter('third', log, order: 20),
        ];

        ResponseEntity<String> requestHandler(RequestEntity request) {
          return ResponseEntity.ok(body: 'Handler reached');
        }

        final chain = FilterChain(filters, requestHandler);

        final request = RequestEntity('GET', Uri.parse('http://localhost/'));

        await chain.doFilter(request);

        expect(log, equals(['first', 'second', 'third']));
      },
    );

    test(
      'Filters with same order should maintain their relative input order',
      () async {
        final log = <String>[];
        final filters = [
          LoggingFilter('A', log, order: 0),
          LoggingFilter('B', log, order: 0),
        ];

        ResponseEntity<dynamic> requestHandler(RequestEntity request) =>
            ResponseEntity.ok();
        final chain = FilterChain(filters, requestHandler);

        final request = RequestEntity('GET', Uri.parse('http://localhost/'));
        await chain.doFilter(request);

        expect(log, equals(['A', 'B']));
      },
    );

    test('Filter should be able to stop the chain', () async {
      final log = <String>[];
      final filters = [
        LoggingFilter('first', log, order: 1),
        StoppingFilter('stopper', log, order: 2),
        LoggingFilter('third', log, order: 3),
      ];

      ResponseEntity<String> requestHandler(RequestEntity request) =>
          ResponseEntity.ok(body: 'Handler');
      final chain = FilterChain(filters, requestHandler);

      final request = RequestEntity('GET', Uri.parse('http://localhost/'));
      final response = await chain.doFilter(request);

      expect(log, equals(['first', 'stopper']));
      expect(await response.readAsString(), contains('Stopped by filter'));
    });
  });

  group('FilterChain Exception Handling Tests', () {
    test('Exception thrown by the handler is converted before reaching the outer filters', () async {
      final seenStatus = <int>[];
      final chain = FilterChain(
        [StatusRecordingFilter(seenStatus)],
        (request) => throw NotFoundException(),
        exceptionHandler: SimpleExceptionHandler(),
      );

      final request = RequestEntity('GET', Uri.parse('http://localhost/'));
      final response = await chain.doFilter(request);

      expect(response.statusCode, 404);
      expect(seenStatus, equals([404]));
    });

    test('Exception thrown by a filter is converted before reaching the outer filters', () async {
      final log = <String>[];
      final seenStatus = <int>[];
      final chain = FilterChain(
        [
          StatusRecordingFilter(seenStatus, order: 1),
          ThrowingFilter(order: 2),
          LoggingFilter('after-throwing', log, order: 3),
        ],
        (request) {
          log.add('handler');
          return ResponseEntity.ok();
        },
        exceptionHandler: SimpleExceptionHandler(),
      );

      final request = RequestEntity('GET', Uri.parse('http://localhost/'));
      final response = await chain.doFilter(request);

      expect(response.statusCode, 401);
      expect(seenStatus, equals([401]));
      expect(log, isEmpty);
    });

    test('Without exception handler the exception is propagated', () async {
      final seenStatus = <int>[];
      final chain = FilterChain([
        StatusRecordingFilter(seenStatus),
      ], (request) => throw NotFoundException());

      final request = RequestEntity('GET', Uri.parse('http://localhost/'));

      await expectLater(
        () async => await chain.doFilter(request),
        throwsA(isA<NotFoundException>()),
      );
      expect(seenStatus, isEmpty);
    });
  });
}

class StatusRecordingFilter extends Filter {
  final List<int> seenStatus;

  StatusRecordingFilter(this.seenStatus, {super.order});

  @override
  FutureOr<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    final response = await chain.doFilter(request);
    seenStatus.add(response.statusCode);
    return response;
  }
}

class ThrowingFilter extends Filter {
  ThrowingFilter({super.order});

  @override
  FutureOr<ResponseEntity> doFilter(RequestEntity request, FilterChain chain) {
    throw UnauthorizedException();
  }
}

class StoppingFilter extends Filter {
  final String name;
  final List<String> log;

  StoppingFilter(this.name, this.log, {super.order});

  @override
  FutureOr<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    log.add(name);
    return ResponseEntity.ok(body: 'Stopped by filter');
  }
}

class LoggingFilter extends Filter {
  final String name;
  final List<String> log;

  LoggingFilter(this.name, this.log, {super.order});

  @override
  FutureOr<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    log.add(name);
    return await chain.doFilter(request);
  }
}

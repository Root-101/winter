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
}

class StoppingFilter extends Filter {
  final String name;
  final List<String> log;

  StoppingFilter(this.name, this.log, {int order = 0}) : super(order: order);

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

  LoggingFilter(this.name, this.log, {int order = 0}) : super(order: order);

  @override
  FutureOr<ResponseEntity> doFilter(
    RequestEntity request,
    FilterChain chain,
  ) async {
    log.add(name);
    return await chain.doFilter(request);
  }
}

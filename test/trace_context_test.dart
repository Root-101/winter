import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// W3C Trace Context: `traceparent` and `tracestate` (DECISIONS.md §7)
void main() {
  const String traceId = '4bf92f3577b34da6a3ce929d0e0e4736';
  const String parentId = '00f067aa0ba902b7';
  const String traceparent = '00-$traceId-$parentId-01';
  final RegExp span = RegExp(r'^[0-9a-f]{16}$');

  group('TraceContext.parse', () {
    test('continues the trace of the caller with a new span', () {
      final trace = TraceContext.parse(traceparent, traceState: 'congo=t61');

      expect(trace!.traceId, traceId);
      expect(trace.parentId, parentId);
      expect(trace.spanId, matches(span));
      expect(trace.spanId, isNot(parentId));
      expect(trace.sampled, isTrue);
      expect(trace.traceState, 'congo=t61');
      expect(TraceContext.parse('00-$traceId-$parentId-00')!.sampled, isFalse);
    });

    test('a later version may add parts; ff and an invalid one are null', () {
      expect(
        TraceContext.parse('01-$traceId-$parentId-01-more')?.traceId,
        traceId,
      );
      for (final invalid in [
        'ff-$traceId-$parentId-01',
        '00-$traceId-$parentId-01-more',
        '00-${traceId.toUpperCase()}-$parentId-01',
        '00-${'0' * 32}-$parentId-01',
        '00-$traceId-${'0' * 16}-01',
        '00-${traceId.substring(1)}-$parentId-01',
        '00-$traceId-$parentId',
        'not a trace',
        '',
      ]) {
        expect(TraceContext.parse(invalid), isNull, reason: invalid);
      }
      expect(TraceContext.parse(null), isNull);
    });

    test('a tracestate too long or not printable ASCII is dropped', () {
      for (final state in ['a=${'x' * 511}', 'a=ñ', 'a=\u0001', '  ']) {
        expect(
          TraceContext.parse(traceparent, traceState: state)!.traceState,
          isNull,
          reason: state,
        );
      }
    });

    test(
      'several traceparent headers are invalid, tracestate lines are joined',
      () {
        RequestEntity request(Map<String, Object> headers) => RequestEntity(
          'GET',
          Uri.parse('http://localhost/'),
          headers: headers,
        );

        expect(
          TraceContext.fromRequest(
            request({
              'traceparent': [traceparent, traceparent],
            }),
          ),
          isNull,
        );
        expect(
          TraceContext.fromRequest(
            request({
              'traceparent': traceparent,
              'tracestate': ['a=1', 'b=2'],
            }),
          )!.traceState,
          'a=1,b=2',
        );
      },
    );
  });

  test('the headers continue the trace with the span of this request', () {
    final trace = TraceContext.parse(traceparent, traceState: 'a=1')!;
    final root = TraceContext.root();

    expect(trace.headers, {
      'traceparent': '00-$traceId-${trace.spanId}-01',
      'tracestate': 'a=1',
    });
    expect(root.headers.keys, ['traceparent']);
    expect(
      root.traceparent,
      matches(RegExp(r'^00-[0-9a-f]{32}-[0-9a-f]{16}-00$')),
    );
    expect(root.parentId, isNull);
    expect(root.traceId, isNot(TraceContext.root().traceId));
  });

  group('In a request', () {
    TraceContext? seen;
    final client = WinterTestClient.build(
      router: WinterRouter(
        routes: [
          Route.get(
            path: '/',
            handler: (request) {
              seen = requestTrace;
              return ResponseEntity.ok();
            },
          ),
        ],
      ),
    );

    setUp(() => seen = null);

    test('the trace of the caller, and its id as the request id', () async {
      final response = await client.get(
        '/',
        headers: {'traceparent': traceparent},
      );

      expect(seen!.traceId, traceId);
      expect(seen!.parentId, parentId);
      expect(response.headers['x-request-id'], traceId);
      expect(response.headers, isNot(contains('traceparent')));
    });

    test('a valid X-Request-Id still wins', () async {
      final response = await client.get(
        '/',
        headers: {'traceparent': traceparent, 'X-Request-Id': 'gw-1'},
      );

      expect(seen!.traceId, traceId);
      expect(response.headers['x-request-id'], 'gw-1');
    });

    test('without a valid traceparent, a trace of its own', () async {
      await client.get('/', headers: {'traceparent': 'nonsense'});

      expect(seen!.parentId, isNull);
      expect(seen!.traceId, isNot(traceId));
      expect(requestTrace, isNull);
    });
  });
}

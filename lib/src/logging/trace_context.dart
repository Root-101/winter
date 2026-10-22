import 'package:winter/src/request_scope.dart' show hexBytes, secureRandomBytes;
import 'package:winter/winter.dart';

/// The distributed trace a request belongs to, as the W3C *Trace Context* recommendation defines
/// it: the `traceparent` and `tracestate` headers that OpenTelemetry, Datadog, Jaeger or a
/// gateway send.
///
/// The server reads it from every request ([parse]) and keeps it in the scope ([requestTrace]):
/// a request without a valid `traceparent` starts a trace of its own. Its [spanId] is the span
/// of this request, so a call to another service continues the trace with [headers]:
///
/// ```dart
/// await http.get(Uri.parse('http://stock/items/7'), headers: requestTrace!.headers);
/// ```
///
/// `JsonLogger` writes [traceId] and [spanId] in every log of the request.
///
/// {@category Logging}
final class TraceContext {
  /// The id of the whole trace: 32 lowercase hex digits, never all zeros
  final String traceId;

  /// The span of this request: 16 lowercase hex digits, new for every request
  final String spanId;

  /// The span of the caller (the `parent-id` of its `traceparent`), or null when this request
  /// started the trace
  final String? parentId;

  /// Whether the caller may have recorded the trace (the `sampled` flag). False when this request
  /// started it: Winter records no spans.
  final bool sampled;

  /// The `tracestate` of the caller (the data of each vendor), forwarded as it came, or null
  final String? traceState;

  /// A trace with all its parts
  const TraceContext({
    required this.traceId,
    required this.spanId,
    this.parentId,
    this.sampled = false,
    this.traceState,
  });

  /// A new trace, started by this request
  TraceContext.root() : this(traceId: _randomHex(16), spanId: _randomHex(8));

  static final RegExp _traceparent = RegExp(
    r'^([0-9a-f]{2})-([0-9a-f]{32})-([0-9a-f]{16})-([0-9a-f]{2})(-.*)?$',
  );
  static final RegExp _zeros = RegExp(r'^0+$');
  static final RegExp _printableAscii = RegExp(r'^[\x20-\x7E]*$');

  /// The trace of a request that sent [traceparent] (and [traceState]), continued with a new span;
  /// null when [traceparent] is missing or invalid (the request then starts a trace of its own):
  ///
  /// - Version `00` is exactly `00-<trace-id>-<parent-id>-<flags>`; a later version may add more
  ///   after another `-`; `ff` is invalid.
  /// - Lowercase hex only, and neither id all zeros.
  /// - A [traceState] longer than 512 characters, or with a character that isn't printable
  ///   ASCII, is dropped, as the recommendation asks.
  static TraceContext? parse(String? traceparent, {String? traceState}) {
    if (traceparent == null) return null;
    final RegExpMatch? match = _traceparent.firstMatch(traceparent.trim());
    if (match == null) return null;
    final String version = match[1]!;
    final String traceId = match[2]!;
    final String parentId = match[3]!;
    if (version == 'ff' || (version == '00' && match[5] != null)) return null;
    if (_zeros.hasMatch(traceId) || _zeros.hasMatch(parentId)) return null;
    final String? state = traceState?.trim();
    return TraceContext(
      traceId: traceId,
      spanId: _randomHex(8),
      parentId: parentId,
      sampled: int.parse(match[4]!, radix: 16) & 1 == 1,
      traceState:
          state == null ||
              state.isEmpty ||
              state.length > 512 ||
              !_printableAscii.hasMatch(state)
          ? null
          : state,
    );
  }

  /// The trace of [request]: its `traceparent` and `tracestate` ([parse]). Several
  /// `traceparent` headers are invalid; several `tracestate` lines are joined.
  static TraceContext? fromRequest(RequestEntity request) {
    final List<String>? parents = request.headersAll[HttpHeader.traceparent];
    if (parents == null || parents.length != 1) return null;
    return parse(
      parents.single,
      traceState: request.headersAll[HttpHeader.tracestate]?.join(','),
    );
  }

  /// The `traceparent` for a call made by this request: this trace, with [spanId] as the parent
  String get traceparent => '00-$traceId-$spanId-${sampled ? '01' : '00'}';

  /// The headers that continue this trace in a call to another service
  Map<String, String> get headers => {
    HttpHeader.traceparent: traceparent,
    HttpHeader.tracestate: ?traceState,
  };

  static String _randomHex(int bytes) {
    final StringBuffer hex = StringBuffer();
    var zeros = true;
    for (final int byte in secureRandomBytes(bytes)) {
      if (byte != 0) zeros = false;
      hex.write(hexBytes[byte]);
    }
    // An id of only zeros is invalid; one in 2^64 at worst, so just try again
    return zeros ? _randomHex(bytes) : hex.toString();
  }

  @override
  String toString() => 'TraceContext($traceparent)';
}

/// The trace of the request in progress (see [TraceContext]), or null outside a request.
///
/// {@category Logging}
TraceContext? get requestTrace => RequestScope.current?.trace;

import 'dart:async';
import 'dart:convert';

import 'package:winter/winter.dart';

/// One event of a Server-Sent Events stream (`text/event-stream`), sent with
/// `ResponseEntity.sse`:
///
/// ```dart
/// ServerSentEvent(data: 'Hello')                                 // data: Hello
/// ServerSentEvent(event: 'order', id: '42', data: 'line 1\nline 2')
/// ServerSentEvent.json(order, event: 'order', id: '${order.id}') // the data as JSON
/// ServerSentEvent.comment('still here')                          // ignored by the browser
/// ```
///
/// In a browser, `new EventSource(url)` receives them: `onmessage` the events without `event`, and
/// `addEventListener('order', ...)` the ones of that name. It reconnects by itself, sending the
/// last `id` it got in the `Last-Event-ID` header, and waits [retry] before.
///
/// {@category Requests and responses}
final class ServerSentEvent {
  /// The text of the event; a line break makes several `data:` lines, joined again by the client
  final String? data;

  /// The name of the event (`addEventListener(name)` in a browser); without it, a `message`
  final String? event;

  /// The id of the event, sent back by the client in `Last-Event-ID` when it reconnects
  final String? id;

  /// How long the client waits before reconnecting
  final Duration? retry;

  /// A comment (`: text`): the client ignores it, but it keeps the connection alive
  final String? comment;

  /// An event. [event] and [id] can't have a line break (it would start another event): an
  /// [ArgumentError]; neither can [id] have a NUL.
  ServerSentEvent({this.data, this.event, this.id, this.retry})
    : comment = null {
    _checkLine(event, 'event');
    _checkLine(id, 'id');
    if (id?.contains('\x00') ?? false) {
      throw ArgumentError.value(id, 'id', 'An id can\'t have a NUL');
    }
  }

  /// An event whose data is [value] as JSON, in one line, written by [objectMapper] (default: the
  /// global `om`): anything a response body can be
  factory ServerSentEvent.json(
    Object? value, {
    String? event,
    String? id,
    Duration? retry,
    ObjectMapper? objectMapper,
  }) => ServerSentEvent(
    data: jsonEncode(
      (objectMapper ?? Winter.context.objectMapper).serialize(value),
    ),
    event: event,
    id: id,
    retry: retry,
  );

  /// A comment: the client ignores it (a keep-alive, a note for whoever reads the stream)
  ServerSentEvent.comment(String this.comment)
    : data = null,
      event = null,
      id = null,
      retry = null;

  static void _checkLine(String? value, String name) {
    if (value != null && (value.contains('\n') || value.contains('\r'))) {
      throw ArgumentError.value(value, name, 'It can\'t have a line break');
    }
  }

  static final RegExp _lineBreak = RegExp(r'\r\n|\r|\n');

  /// The text of the event in the stream, ending with its blank line
  String encode() {
    final StringBuffer text = StringBuffer();
    final String? comment = this.comment;
    if (comment != null) {
      for (final String line in comment.split(_lineBreak)) {
        text.write(': $line\n');
      }
      return (text..write('\n')).toString();
    }
    if (event != null) text.write('event: $event\n');
    if (id != null) text.write('id: $id\n');
    if (retry != null) text.write('retry: ${retry!.inMilliseconds}\n');
    final String? data = this.data;
    if (data != null) {
      for (final String line in data.split(_lineBreak)) {
        text.write('data: $line\n');
      }
    }
    return (text..write('\n')).toString();
  }

  @override
  String toString() => encode();
}

/// The body of `ResponseEntity.sse`: a comment first (so the headers leave at once), [events]
/// as they come, a comment every [keepAlive] without events, and the end when [events] ends, when
/// [closing] completes (the server shuts down) or when the client leaves (its subscription to
/// [events] is cancelled). Internal.
Stream<List<int>> serverSentEventsBody(
  Stream<ServerSentEvent> events, {
  required Duration? keepAlive,
  required Future<void> closing,
}) {
  late final StreamController<List<int>> output;
  StreamSubscription<ServerSentEvent>? subscription;
  Timer? timer;

  List<int> bytes(ServerSentEvent event) => utf8.encode(event.encode());

  void restartKeepAlive() {
    timer?.cancel();
    final Duration? interval = keepAlive;
    if (interval == null) return;
    timer = Timer.periodic(interval, (_) {
      if (!output.isClosed) output.add(utf8.encode(':\n\n'));
    });
  }

  Future<void> finish() async {
    timer?.cancel();
    await subscription?.cancel();
    if (!output.isClosed) await output.close();
  }

  output = StreamController<List<int>>(
    onListen: () {
      output.add(utf8.encode(':\n\n'));
      restartKeepAlive();
      subscription = events.listen(
        (event) {
          output.add(bytes(event));
          restartKeepAlive();
        },
        onError: (Object error, StackTrace stackTrace) {
          logger.error(
            'The stream of Server-Sent Events failed',
            error: error,
            stackTrace: stackTrace,
          );
          unawaited(finish());
        },
        onDone: () => unawaited(finish()),
      );
      unawaited(closing.then((_) => finish()));
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    // The client left (or the response could not be written)
    onCancel: () {
      timer?.cancel();
      return subscription?.cancel();
    },
  );
  return output.stream;
}

/// Server-Sent Events: a stream of events over a normal response. A countdown with an id per
/// event, which a client that reconnects sends back in `Last-Event-ID` to resume.
///
/// Run: `dart run lib/server_sent_events.dart`, then `curl -N localhost:8080/countdown?from=5`
library;

import 'package:winter/winter.dart';

WinterRouter router({Duration interval = const Duration(seconds: 1)}) =>
    WinterRouter(
      routes: [
        Route.get(
          path: '/countdown',
          handler: (request) {
            final int from = request.queryParam<int>('from') ?? 10;
            // A client that reconnects goes on after the last event it got
            final int? lastId = int.tryParse(
              request.headers[HttpHeader.lastEventId] ?? '',
            );
            final int start = lastId == null ? from : lastId - 1;
            return ResponseEntity.sse(
              Stream<int>.periodic(interval, (i) => start - i)
                  .take(start + 1)
                  .map(
                    (n) => n == 0
                        ? ServerSentEvent.json(
                            {'done': true},
                            event: 'end',
                            id: '0',
                          )
                        : ServerSentEvent(data: '$n', id: '$n'),
                  ),
            );
          },
        ),
      ],
    );

Future<void> main() async => Winter.start(router: router());

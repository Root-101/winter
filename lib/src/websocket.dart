import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;

import 'package:winter/winter.dart';

/// The code of a WebSocket route ([Route.websocket]): it gets the socket once the connection is
/// upgraded, with the [RequestEntity] of the handshake (its path params, its principal...).
///
/// The socket is a `WebSocket` of `dart:io`: a stream of the messages of the client (a `String` or
/// `List<int>` each), `add` to send one, `close` to end it. It stays open when the handler
/// returns, until either side closes it: a handler can keep it in a list to send to it later.
///
/// {@category Routing}
typedef WebSocketHandler = FutureOr<void> Function(
  WebSocket socket,
  RequestEntity request,
);

/// What a WebSocket route answers when its request can be upgraded: the server upgrades the
/// connection instead of writing this response. Internal.
final class WebSocketUpgrade {
  /// The code that gets the socket
  final WebSocketHandler handler;

  /// The request that reached the route (after the filters)
  final RequestEntity request;

  /// The subprotocols the route speaks, in order of preference
  final List<String> protocols;

  /// How often a ping goes to the client, or null for none
  final Duration? pingInterval;

  /// An upgrade to [handler]
  const WebSocketUpgrade({
    required this.handler,
    required this.request,
    required this.protocols,
    required this.pingInterval,
  });

  /// The subprotocol to answer among the ones the client asked for: the first of [protocols]
  /// that the client accepts. A [StateError] when there is none (the upgrade fails).
  String selectProtocol(List<String> requested) => protocols.firstWhere(
    requested.contains,
    orElse: () => throw StateError(
      'The client asked for ${requested.join(', ')}; the route speaks ${protocols.join(', ')}',
    ),
  );
}

/// Where a WebSocket route leaves its [WebSocketUpgrade] in the response. Internal.
final ContextKey<WebSocketUpgrade> webSocketUpgradeKey =
    ContextKey<WebSocketUpgrade>('winter.websocket');

/// The handler of [Route.websocket]: a 426 for a request that isn't a WebSocket handshake, a 403
/// for an [allowedOrigins] that doesn't have its `Origin`, and otherwise a 101 that carries the
/// [WebSocketUpgrade] for the server. Internal.
RequestHandler webSocketRouteHandler({
  required WebSocketHandler handler,
  required List<String> protocols,
  required Duration? pingInterval,
  required List<String>? allowedOrigins,
}) => (request) {
  if (!_isHandshake(request)) {
    throw const ApiException(
      StatusCode.upgradeRequired,
      detail: 'This path only accepts WebSocket connections',
      headers: {
        HttpHeader.upgrade: 'websocket',
        HttpHeader.connection: 'Upgrade',
      },
    );
  }
  final String? origin = request.headers[HttpHeader.origin];
  if (allowedOrigins != null &&
      origin != null &&
      !allowedOrigins.contains('*') &&
      !allowedOrigins.contains(origin)) {
    throw const ForbiddenException(detail: 'The origin is not allowed');
  }
  final ResponseEntity<void> response = ResponseEntity<void>(
    StatusCode.switchingProtocols.value,
  );
  response.context.set(
    webSocketUpgradeKey,
    WebSocketUpgrade(
      handler: handler,
      request: request,
      protocols: protocols,
      pingInterval: pingInterval,
    ),
  );
  return response;
};

/// A `GET` with `Upgrade: websocket` and `Connection: upgrade` (the version and the key are
/// checked by `dart:io` when it upgrades)
bool _isHandshake(RequestEntity request) =>
    request.method.toUpperCase() == 'GET' &&
    request.headers[HttpHeader.upgrade]?.toLowerCase() == 'websocket' &&
    (request.headers[HttpHeader.connection]
            ?.toLowerCase()
            .split(',')
            .any((value) => value.trim() == 'upgrade') ??
        false);

/// JSON messages on a WebSocket, with the object mapper
///
/// {@category Routing}
extension WebSocketJson on WebSocket {
  /// Sends [value] as a JSON text message, written by [objectMapper] (default: the global `om`):
  /// anything a response body can be
  void sendJson(Object? value, {ObjectMapper? objectMapper}) => add(
    jsonEncode((objectMapper ?? Winter.context.objectMapper).serialize(value)),
  );
}

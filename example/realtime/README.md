# Real-time examples

Pushing to the client: Server-Sent Events (one way, over a normal response) and WebSockets (both
ways). Each file is a server of its own: `dart run lib/<case>.dart` (port 8080); `dart test` runs
the tests (the WebSocket one starts a real server on port 9301).

| Case | File | What it shows |
|------|------|---------------|
| Server-Sent Events | [`server_sent_events.dart`](lib/server_sent_events.dart) | `ResponseEntity.sse` with `ServerSentEvent` (data, `id`, `event`, `.json`), resuming from `Last-Event-ID` |
| WebSocket chat | [`websocket_chat.dart`](lib/websocket_chat.dart) | `Route.websocket` with a path param, rooms and a broadcast with `sendJson`, `allowedOrigins`, 426 for a plain GET, a client in the terminal |

```bash
curl -N localhost:8080/countdown?from=5          # server_sent_events.dart
dart run lib/websocket_chat.dart --client lobby Ann   # with websocket_chat.dart running
```

Guides: [Server-Sent Events](../../doc/requests-and-responses.md#server-sent-events),
[WebSockets](../../doc/routing.md#websockets). A whole app that uses both:
[`../apps/files_gallery`](../apps/files_gallery).

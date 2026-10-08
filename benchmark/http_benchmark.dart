// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:winter/winter.dart';

/// Requests per second of an empty endpoint, with the server in its own isolate and a client with
/// [_connections] concurrent connections, for [_duration]:
///
/// - `dart:io`: a raw `HttpServer`, the ceiling.
/// - `winter`: `Winter.start` with a `WinterRouter` (the whole pipeline).
///
/// Before phase 3.1, Winter ran on shelf. On the same machine (Windows, AOT, 64 connections):
/// `dart:io` 6363 req/s, shelf alone 5561 (-13 %), Winter on shelf 3984 (-37 %).
///
/// Compile it to measure: `dart compile exe benchmark/http_benchmark.dart -o build/http_bench.exe`
/// and run the executable (`dart run` is JIT, slower and noisier).
Future<void> main(List<String> args) async {
  final List<String> servers = args.isEmpty ? ['dart:io', 'winter'] : args;
  for (final (index, server) in servers.indexed) {
    ///A port per server: killing an isolate doesn't close its server socket
    final int port = _port + index;
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(_serve, [server, port, ready.sendPort]);
    await ready.first;

    await _load(port, const Duration(seconds: 2)); // warm up
    final int requests = await _load(port, _duration);
    print(
      '${server.padRight(8)} ${(requests / _duration.inSeconds).round()} req/s',
    );

    isolate.kill(priority: Isolate.immediate);
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

const int _port = 9097;
const int _connections = 64;
const Duration _duration = Duration(seconds: 10);

Future<void> _serve(List<Object> args) async {
  final server = args[0] as String;
  final port = args[1] as int;
  final ready = args[2] as SendPort;
  switch (server) {
    case 'dart:io':
      final httpServer = await HttpServer.bind('localhost', port);
      httpServer.listen((request) {
        request.response
          ..headers.contentType = ContentType.text
          ..write('pong')
          ..close();
      });
    case 'winter':
      Winter.context.setUp(
        logger: const ConsoleLogger(minLevel: LogLevel.warning),
      );
      await Winter.start(
        config: ServerConfig(
          host: 'localhost',
          port: port,
          handleSignals: false,
        ),
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/ping',
              handler: (request) => ResponseEntity.ok(body: 'pong'),
            ),
          ],
        ),
      );
    default:
      throw ArgumentError.value(server, 'server');
  }
  ready.send(null);
}

/// The requests answered in [duration]
Future<int> _load(int port, Duration duration) async {
  final client = HttpClient()..maxConnectionsPerHost = _connections;
  final uri = Uri.parse('http://localhost:$port/ping');
  final end = DateTime.now().add(duration);
  var count = 0;

  Future<void> worker() async {
    while (DateTime.now().isBefore(end)) {
      final request = await client.getUrl(uri);
      final response = await request.close();
      await response.drain<void>();
      count++;
    }
  }

  await Future.wait([for (var i = 0; i < _connections; i++) worker()]);
  client.close(force: true);
  return count;
}

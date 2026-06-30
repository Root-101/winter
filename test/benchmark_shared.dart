import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:winter/winter.dart';

void main() async {
  final numIsolates = Platform.numberOfProcessors;
  const iterations = 50000;
  const concurrency = 100;
  const port = 9045;

  print('--- Benchmarking Winter Framework (Multi-Isolate Shared) ---');
  print('Processors/Isolates: $numIsolates');
  print('Total iterations: $iterations');
  print('Client concurrency: $concurrency');
  print('Port: $port');

  // Start servers in multiple isolates
  final receivePort = ReceivePort();
  final stopPorts = <SendPort>[];

  for (var i = 0; i < numIsolates; i++) {
    await Isolate.spawn(_startServerIsolate, {
      'replyPort': receivePort.sendPort,
      'port': port,
      'id': i,
    });
  }

  // Wait for all servers to be ready
  int readyCount = 0;
  await for (var message in receivePort) {
    if (message is SendPort) {
      stopPorts.add(message);
      readyCount++;
      if (readyCount == numIsolates) break;
    }
  }

  print('\nAll $numIsolates isolates started and listening on port $port');

  await benchmarkMultiIsolateServer(port, iterations, concurrency);

  // Stop servers
  print('\nShutting down isolates...');
  for (final stopPort in stopPorts) {
    stopPort.send('stop');
  }

  // Small delay to allow isolates to exit gracefully
  await Future.delayed(const Duration(seconds: 1));
  receivePort.close();
  print('Benchmark finished.');
}

void _startServerIsolate(Map<String, dynamic> message) async {
  final SendPort replyPort = message['replyPort'];
  final int port = message['port'];
  final int id = message['id'];

  final router = WinterRouter(
    routes: [
      Route.get(
        path: '/ping',
        handler: (request) async => ResponseEntity.ok(body: 'pong'),
      ),
    ],
  );

  try {
    // We use the shared property to allow multiple isolates to bind to the same port
    await Winter.start(
      config: ServerConfig(port: port),
      router: router,
      shared: true,
    );
    
    final stopPort = ReceivePort();
    replyPort.send(stopPort.sendPort);

    await for (final msg in stopPort) {
      if (msg == 'stop') {
        await Winter.close(force: true);
        break;
      }
    }
  } catch (e) {
    print('Error in isolate $id: $e');
  } finally {
    Isolate.exit();
  }
}

Future<void> benchmarkMultiIsolateServer(
  int port,
  int iterations,
  int concurrency,
) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 5);
  final uri = Uri.parse('http://localhost:$port/ping');

  print('Warming up...');
  // Warm up
  for (var i = 0; i < 1000; i++) {
    final request = await client.getUrl(uri);
    final response = await request.close();
    await response.drain();
  }

  print('Running benchmark...');
  final stopwatch = Stopwatch()..start();

  // Dividimos las iteraciones entre el número de trabajadores concurrentes
  int perWorker = iterations ~/ concurrency;
  List<Future> workers = [];

  for (var i = 0; i < concurrency; i++) {
    workers.add(() async {
      for (var j = 0; j < perWorker; j++) {
        try {
          final request = await client.getUrl(uri);
          final response = await request.close();
          await response.drain();
        } catch (e) {
          // Ignore connection errors during shutdown or extreme load
        }
      }
    }());
  }
  await Future.wait(workers);

  stopwatch.stop();
  _printResults(iterations, stopwatch);

  client.close();
}

void _printResults(int iterations, Stopwatch stopwatch) {
  final ms = stopwatch.elapsedMilliseconds;
  final reqPerSec = (iterations / stopwatch.elapsedMicroseconds * 1000000)
      .toStringAsFixed(2);
  print('Total time: $ms ms');
  print('Requests per second: $reqPerSec');
}

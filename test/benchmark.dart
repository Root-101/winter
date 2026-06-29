import 'dart:async';
import 'dart:io';

import 'package:winter/winter.dart';

void main() async {
  const iterations = 20000;
  const concurrency = 100; // Número de peticiones simultáneas
  final port = 9044;

  final router = WinterRouter(
    routes: [
      Route.get(
        path: '/ping',
        handler: (request) async => ResponseEntity.ok(body: 'pong'),
      ),
    ],
  );

  print('--- Benchmarking Winter Framework (Internal Handler) ---');
  await benchmarkHandler(router, iterations);

  print('\n--- Benchmarking Winter Server (HTTP Sequential) ---');
  await benchmarkServer(router, port, iterations, concurrent: false);

  print(
    '\n--- Benchmarking Winter Server (HTTP Concurrent - $concurrency workers) ---',
  );
  await benchmarkServer(
    router,
    port,
    iterations,
    concurrent: true,
    concurrency: concurrency,
  );
}

Future<void> benchmarkHandler(WinterRouter router, int iterations) async {
  final uri = Uri.parse('http://localhost/ping');

  // Warm up
  for (var i = 0; i < 1000; i++) {
    final request = RequestEntity('GET', uri);
    final response = await router.handler(request);
    await response.readAsString();
  }

  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    final request = RequestEntity('GET', uri);
    final response = await router.handler(request);
    await response.readAsString();
  }
  stopwatch.stop();

  _printResults(iterations, stopwatch);
}

Future<void> benchmarkServer(
  WinterRouter router,
  int port,
  int iterations, {
  required bool concurrent,
  int concurrency = 10,
}) async {
  if (!Winter.isRunning) {
    await Winter.start(
      config: ServerConfig(port: port),
      router: router,
    );
  }

  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 5);
  final uri = Uri.parse('http://localhost:$port/ping');

  // Warm up
  for (var i = 0; i < 1000; i++) {
    final request = await client.getUrl(uri);
    final response = await request.close();
    await response.drain();
  }

  final stopwatch = Stopwatch()..start();

  if (concurrent) {
    // Dividimos las iteraciones entre el número de trabajadores concurrentes
    int perWorker = iterations ~/ concurrency;
    List<Future> workers = [];

    for (var i = 0; i < concurrency; i++) {
      workers.add(() async {
        for (var j = 0; j < perWorker; j++) {
          final request = await client.getUrl(uri);
          final response = await request.close();
          await response.drain();
        }
      }());
    }
    await Future.wait(workers);
  } else {
    for (var i = 0; i < iterations; i++) {
      final request = await client.getUrl(uri);
      final response = await request.close();
      await response.drain();
    }
  }

  stopwatch.stop();
  _printResults(iterations, stopwatch);

  client.close();
  await Winter.close(force: true);
}

void _printResults(int iterations, Stopwatch stopwatch) {
  final ms = stopwatch.elapsedMilliseconds;
  final reqPerSec = (iterations / stopwatch.elapsedMicroseconds * 1000000)
      .toStringAsFixed(2);
  print('Total time: $ms ms');
  print('Requests per second: $reqPerSec');
}

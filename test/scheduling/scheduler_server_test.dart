@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// Ports of their own: the server is started and closed in each test
const int port = 9311;
const int busyPort = 9312;

void main() {
  const ServerConfig config = ServerConfig(port: port, handleSignals: false);

  tearDown(() => Winter.close(force: true, onNotRunning: () {}));

  test('it starts with the server, and stops when it closes', () async {
    final Scheduler scheduler = Scheduler()
      ..every(const Duration(hours: 1), name: 'hourly', task: () {});

    final Winter server = await Winter.start(
      config: config,
      scheduler: scheduler,
    );

    expect(scheduler.isStarted, isTrue);
    expect(server.scheduler, same(scheduler));
    expect(di.find<Scheduler>(), same(scheduler));
    expect(scheduler['hourly']!.nextRun, isNotNull);

    await Winter.close();

    expect(scheduler.isStarted, isFalse);
    expect(scheduler['hourly']!.nextRun, isNull);
    expect(di.isRegistered<Scheduler>(), isFalse, reason: 'restored on close');
  });

  test('the one registered in di', () async {
    final Scheduler scheduler = Scheduler();
    di.put(scheduler);
    addTearDown(() => di.delete<Scheduler>());

    final Winter server = await Winter.start(config: config);

    expect(server.scheduler, same(scheduler));
    expect(scheduler.isStarted, isTrue);
    await Winter.close();
    expect(
      di.find<Scheduler>(),
      same(scheduler),
      reason: 'the previous registration is kept',
    );
  });

  test('without a scheduler there is none', () async {
    final Winter server = await Winter.start(config: config);

    expect(server.scheduler, isNull);
    expect(di.isRegistered<Scheduler>(), isFalse);
  });

  test(
    'a graceful close waits for the tasks in progress; a forced one does not',
    () async {
      final Completer<void> slow = Completer<void>();
      final Scheduler scheduler = Scheduler();
      final ScheduledTask task = scheduler.every(
        const Duration(hours: 1),
        name: 'slow',
        task: () => slow.future,
      );
      await Winter.start(config: config, scheduler: scheduler);
      unawaited(task.run());

      bool closed = false;
      final Future<void> closing = Winter.close().then((_) => closed = true);
      // Let the close go as far as it can, without the real clock
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(closed, isFalse, reason: 'the task is running');

      slow.complete();
      await closing;
      expect(closed, isTrue);

      final Completer<void> stuck = Completer<void>();
      final ScheduledTask other = scheduler.every(
        const Duration(hours: 1),
        name: 'stuck',
        task: () => stuck.future,
      );
      await Winter.start(config: config, scheduler: scheduler);
      unawaited(other.run());
      await Winter.close(force: true);
      expect(other.isRunning, isTrue);
      stuck.complete();
    },
  );

  test('a server that fails to start never starts the scheduler', () async {
    final ServerSocket busy = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      busyPort,
    );
    addTearDown(busy.close);
    final Scheduler scheduler = Scheduler();

    await expectLater(
      Winter.start(
        config: const ServerConfig(
          host: '127.0.0.1',
          port: busyPort,
          handleSignals: false,
        ),
        scheduler: scheduler,
      ),
      throwsA(isA<SocketException>()),
    );

    expect(scheduler.isStarted, isFalse);
    expect(di.isRegistered<Scheduler>(), isFalse);
  });
}

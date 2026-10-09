import 'dart:async';

/// A clock and the timers of the code run by [run], moved by hand: [advance] fires every timer
/// due on the way, in order, without waiting on the real clock. A timer of zero goes to the real
/// event loop (so `await Future<void>.delayed(Duration.zero)` still flushes).
class FakeTime {
  DateTime now;
  final List<_FakeTimer> _timers = [];

  FakeTime(this.now);

  DateTime clock() => now;

  /// The timers waiting now
  int get pendingTimers => _timers.where((timer) => timer.isActive).length;

  /// Runs [body] with its timers faked
  Future<T> run<T>(Future<T> Function() body) => runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        if (duration <= Duration.zero) {
          return parent.createTimer(zone, duration, callback);
        }
        final _FakeTimer timer = _FakeTimer(now.add(duration), callback);
        _timers.add(timer);
        return timer;
      },
    ),
  );

  /// Moves the clock [duration] forward, firing every timer due on the way
  Future<void> advance(Duration duration) async {
    final DateTime target = now.add(duration);
    while (true) {
      await flush();
      _timers.removeWhere((timer) => !timer.isActive);
      final List<_FakeTimer> due =
          _timers.where((timer) => !timer.due.isAfter(target)).toList()
            ..sort((a, b) => a.due.compareTo(b.due));
      if (due.isEmpty) break;
      final _FakeTimer next = due.first;
      if (next.due.isAfter(now)) now = next.due;
      next.fire();
    }
    now = target;
    await flush();
  }

  /// Moves the clock without firing anything: a suspended machine that wakes up
  void jump(Duration duration) => now = now.add(duration);

  /// Lets the microtasks and the zero timers run
  static Future<void> flush() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

class _FakeTimer implements Timer {
  final DateTime due;
  final void Function() _callback;
  bool _active = true;

  _FakeTimer(this.due, this._callback);

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}

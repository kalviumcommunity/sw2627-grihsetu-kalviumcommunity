/// Injectable clock abstraction to avoid hardcoded DateTime.now() calls.
abstract class AppClock {
  const AppClock();

  /// Returns the current date and time.
  DateTime now();

  /// The active global application clock.
  static AppClock current = const SystemClock();

  /// Convenience getter for current time from the active clock.
  static DateTime get nowDateTime => current.now();

  /// Resets back to the default [SystemClock].
  static void reset() {
    current = const SystemClock();
  }
}

/// Standard system clock returning [DateTime.now()].
class SystemClock extends AppClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Deterministic clock returning a fixed [DateTime].
class FixedClock extends AppClock {
  const FixedClock(this.fixedTime);

  final DateTime fixedTime;

  @override
  DateTime now() => fixedTime;
}

/// Monotonically advancing clock for simulating chronological events.
class SteppingClock extends AppClock {
  SteppingClock(this._current, {this.step = const Duration(minutes: 5)});

  DateTime _current;
  final Duration step;

  @override
  DateTime now() {
    final val = _current;
    _current = _current.add(step);
    return val;
  }
}

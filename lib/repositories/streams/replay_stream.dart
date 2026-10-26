import 'dart:async';

/// A broadcast stream controller wrapper that retains and replays its latest
/// event to late subscribers upon subscription.
///
/// Designed for reactive stores and Firestore snapshots replay where late
/// listeners (e.g. newly mounted widgets or controllers) need immediate access
/// to the current state without waiting for the next upstream event.
class ReplayStream<T> {
  ReplayStream({
    T? initialValue,
    void Function()? onListen,
    void Function()? onCancel,
  }) {
    if (initialValue != null) {
      _latest = initialValue;
      _hasLatest = true;
    }
    _controller = StreamController<T>.broadcast(
      onListen: onListen,
      onCancel: onCancel,
      sync: true,
    );
  }

  late final StreamController<T> _controller;
  T? _latest;
  bool _hasLatest = false;
  bool _isClosed = false;

  /// The latest emitted event, or null if no event has been emitted yet.
  T? get latest => _hasLatest ? _latest : null;

  /// Whether at least one event has been emitted.
  bool get hasLatest => _hasLatest;

  /// Whether this replay stream is closed.
  bool get isClosed => _isClosed;

  /// Emits [event] to all active subscribers and caches it for future subscribers.
  void add(T event) {
    if (_isClosed) return;
    _latest = event;
    _hasLatest = true;
    _controller.add(event);
  }

  /// Forwards [error] to all active subscribers.
  void addError(Object error, [StackTrace? stackTrace]) {
    if (_isClosed) return;
    _controller.addError(error, stackTrace);
  }

  /// Returns a [Stream] that replays the latest event immediately upon
  /// subscription, then continues receiving live broadcast events.
  Stream<T> get stream {
    late StreamController<T> subscriberController;
    StreamSubscription<T>? liveSubscription;

    subscriberController = StreamController<T>(
      sync: true,
      onListen: () {
        if (_hasLatest && !_isClosed) {
          subscriberController.add(_latest as T);
        }
        if (!_isClosed) {
          liveSubscription = _controller.stream.listen(
            (event) {
              if (!subscriberController.isClosed) {
                subscriberController.add(event);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!subscriberController.isClosed) {
                subscriberController.addError(error, stackTrace);
              }
            },
            onDone: () {
              if (!subscriberController.isClosed) {
                subscriberController.close();
              }
            },
          );
        } else if (!subscriberController.isClosed) {
          subscriberController.close();
        }
      },
      onCancel: () async {
        await liveSubscription?.cancel();
        liveSubscription = null;
      },
    );

    return subscriberController.stream.asBroadcastStream();
  }

  /// Closes the controller and stops accepting new events.
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _controller.close();
  }
}

import 'dart:async';

import 'app_failure.dart';
import 'firebase_error_mapper.dart';

/// Executes an asynchronous [op] guarded against failures.
///
/// If [op] throws, it is mapped to an [AppFailure] via [FirebaseErrorMapper].
/// If the failure is [AppFailure.retryable] and attempts remain, [runGuarded]
/// retries with exponential backoff (e.g. 400 ms, 1200 ms).
/// Non-retryable failures are thrown immediately without retrying.
Future<T> runGuarded<T>(
  Future<T> Function() op, {
  int retries = 2,
  Duration initialDelay = const Duration(milliseconds: 400),
  double backoffMultiplier = 3.0,
  Future<void> Function(Duration delay)? delayFn,
}) async {
  final sleep = delayFn ?? Future.delayed;
  int attempt = 0;

  while (true) {
    try {
      return await op();
    } catch (error, stackTrace) {
      final failure = FirebaseErrorMapper.map(error, stackTrace);

      if (!failure.retryable || attempt >= retries) {
        throw failure;
      }

      final delayMillis =
          (initialDelay.inMilliseconds * (attempt == 0 ? 1 : backoffMultiplier))
              .round();
      final delay = Duration(milliseconds: delayMillis);

      attempt++;
      await sleep(delay);
    }
  }
}

/// Represents an asynchronous state: [loading], [data], or [error].
sealed class Loadable<T> {
  const Loadable();

  const factory Loadable.loading() = Loading<T>;
  const factory Loadable.data(T data) = Data<T>;
  const factory Loadable.error(AppFailure failure) = Error<T>;

  bool get isLoading => this is Loading<T>;
  bool get hasData => this is Data<T>;
  bool get hasError => this is Error<T>;

  T? get dataOrNull => switch (this) {
    Data<T>(data: final d) => d,
    _ => null,
  };

  AppFailure? get failureOrNull => switch (this) {
    Error<T>(failure: final f) => f,
    _ => null,
  };

  R when<R>({
    required R Function() loading,
    required R Function(T data) data,
    required R Function(AppFailure failure) error,
  }) {
    return switch (this) {
      Loading<T>() => loading(),
      Data<T>(data: final d) => data(d),
      Error<T>(failure: final f) => error(f),
    };
  }

  R maybeWhen<R>({
    R Function()? loading,
    R Function(T data)? data,
    R Function(AppFailure failure)? error,
    required R Function() orElse,
  }) {
    return switch (this) {
      Loading<T>() => loading != null ? loading() : orElse(),
      Data<T>(data: final d) => data != null ? data(d) : orElse(),
      Error<T>(failure: final f) => error != null ? error(f) : orElse(),
    };
  }
}

final class Loading<T> extends Loadable<T> {
  const Loading();

  @override
  String toString() => 'Loadable<$T>.loading()';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Loading<T>;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class Data<T> extends Loadable<T> {
  const Data(this.data);

  final T data;

  @override
  String toString() => 'Loadable<$T>.data($data)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Data<T> && other.data == data;

  @override
  int get hashCode => Object.hash(runtimeType, data);
}

final class Error<T> extends Loadable<T> {
  const Error(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'Loadable<$T>.error($failure)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Error<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(runtimeType, failure);
}

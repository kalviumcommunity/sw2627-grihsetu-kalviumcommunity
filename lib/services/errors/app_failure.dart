import 'package:flutter/foundation.dart';

/// Sealed hierarchy of user-safe application failures.
///
/// Every failure exposes a friendly [userMessage] without technical codes or raw
/// exception strings, a stable machine-readable [code], a [retryable] flag,
/// and the [original] underlying cause if available.
@immutable
sealed class AppFailure implements Exception {
  const AppFailure({
    required this.userMessage,
    required this.code,
    required this.retryable,
    this.original,
  });

  final String userMessage;
  final String code;
  final bool retryable;
  final Object? original;

  @override
  String toString() => 'AppFailure($code: $userMessage, retryable: $retryable)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppFailure &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          userMessage == other.userMessage &&
          retryable == other.retryable;

  @override
  int get hashCode => Object.hash(runtimeType, code, userMessage, retryable);
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.userMessage = 'Unable to connect to the network. Please check your internet connection.',
    super.code = 'network',
    super.retryable = true,
    super.original,
  });
}

final class UnauthenticatedFailure extends AppFailure {
  const UnauthenticatedFailure({
    super.userMessage = 'You need to sign in to continue.',
    super.code = 'unauthenticated',
    super.retryable = false,
    super.original,
  });
}

final class InvalidCredentialsFailure extends AppFailure {
  const InvalidCredentialsFailure({
    super.userMessage = 'Invalid email or password. Please verify your credentials and try again.',
    super.code = 'invalid_credentials',
    super.retryable = false,
    super.original,
  });
}

final class EmailInUseFailure extends AppFailure {
  const EmailInUseFailure({
    super.userMessage = 'An account already exists with this email address.',
    super.code = 'email_already_in_use',
    super.retryable = false,
    super.original,
  });
}

final class WeakPasswordFailure extends AppFailure {
  const WeakPasswordFailure({
    super.userMessage = 'Password is too weak. Please choose a stronger password with at least 6 characters.',
    super.code = 'weak_password',
    super.retryable = false,
    super.original,
  });
}

final class PermissionDeniedFailure extends AppFailure {
  const PermissionDeniedFailure({
    super.userMessage = 'You do not have permission to perform this action.',
    super.code = 'permission_denied',
    super.retryable = false,
    super.original,
  });
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    super.userMessage = 'The requested item could not be found.',
    super.code = 'not_found',
    super.retryable = false,
    super.original,
  });
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure({
    super.userMessage =
        'This record was modified by another user or already exists.',
    super.code = 'conflict',
    super.retryable = true,
    super.original,
  });
}

final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({
    super.userMessage =
        'Too many requests. Please wait a moment and try again.',
    super.code = 'rate_limited',
    super.retryable = true,
    super.original,
  });
}

final class UnavailableFailure extends AppFailure {
  const UnavailableFailure({
    super.userMessage =
        'The service is temporarily unavailable. Please try again shortly.',
    super.code = 'unavailable',
    super.retryable = true,
    super.original,
  });
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({
    super.userMessage = 'The request timed out. Please try again.',
    super.code = 'timeout',
    super.retryable = true,
    super.original,
  });
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    super.userMessage =
        'Please check the entered information and correct any errors.',
    super.code = 'validation_error',
    super.retryable = false,
    super.original,
  });
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({
    super.userMessage = 'An unexpected error occurred. Please try again.',
    super.code = 'unknown',
    super.retryable = true,
    super.original,
  });
}

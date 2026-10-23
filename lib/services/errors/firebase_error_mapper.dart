import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../auth_failure.dart';
import 'app_failure.dart';

/// Centralized mapper that transforms Firebase, network, and system exceptions
/// into user-safe [AppFailure] instances without leaking technical details.
abstract final class FirebaseErrorMapper {
  /// Maps any caught error into a strongly-typed, user-friendly [AppFailure].
  static AppFailure map(Object error, [StackTrace? stackTrace]) {
    debugPrint(
      'FirebaseErrorMapper: mapping error: $error${stackTrace != null ? '\n$stackTrace' : ''}',
    );

    if (error is AppFailure) {
      return error;
    }

    if (error is AuthFailure) {
      return switch (error.code) {
        AuthFailureCode.invalidCredentials ||
        AuthFailureCode.userDisabled => InvalidCredentialsFailure(
          userMessage: error.message,
          code: error.code.name,
          original: error,
        ),
        AuthFailureCode.weakPassword => WeakPasswordFailure(
          userMessage: error.message,
          code: error.code.name,
          original: error,
        ),
        AuthFailureCode.emailAlreadyInUse => EmailInUseFailure(
          userMessage: error.message,
          code: error.code.name,
          original: error,
        ),
        AuthFailureCode.tooManyRequests => RateLimitedFailure(
          userMessage: error.message,
          code: error.code.name,
          original: error,
        ),
        AuthFailureCode.networkError => NetworkFailure(
          userMessage: error.message,
          code: error.code.name,
          original: error,
        ),
        AuthFailureCode.unauthenticated => UnauthenticatedFailure(
          userMessage: error.message,
          code: error.code.name,
          original: error,
        ),
        AuthFailureCode.permissionDenied => PermissionDeniedFailure(
          userMessage: error.message,
          code: error.code.name,
          original: error,
        ),
        AuthFailureCode.serviceUnavailable => UnavailableFailure(
          userMessage: error.message,
          code: error.code.name,
          original: error,
        ),
        AuthFailureCode.invalidInput ||
        AuthFailureCode.invalidEmail => ValidationFailure(
          userMessage: error.message,
          code: error.code.name,
          original: error,
        ),
        AuthFailureCode.profileNotFound => NotFoundFailure(
          userMessage: error.message,
          code: error.code.name,
          original: error,
        ),
        _ => UnknownFailure(
          userMessage: error.message,
          code: error.code.name,
          original: error,
        ),
      };
    }

    if (error is SocketException) {
      return NetworkFailure(
        userMessage: 'Unable to connect to the network. Please check your internet connection.',
        original: error,
      );
    }

    if (error is TimeoutException) {
      return TimeoutFailure(
        userMessage: 'The operation timed out. Please try again.',
        original: error,
      );
    }

    if (error is FormatException || error is ArgumentError) {
      return ValidationFailure(
        userMessage: 'The provided data is invalid. Please check your inputs.',
        original: error,
      );
    }

    try {
      final dynamic e = error;
      if (e.code is Enum &&
          e.code.toString().contains('ComplaintFailureCode')) {
        final codeName = (e.code as Enum).name;
        final message =
            (e.message as String?) ?? 'A complaint operation error occurred.';
        return switch (codeName) {
          'validation' => ValidationFailure(
            userMessage: message,
            original: error,
          ),
          'unauthenticated' => UnauthenticatedFailure(
            userMessage: message,
            original: error,
          ),
          'permissionDenied' => PermissionDeniedFailure(
            userMessage: message,
            original: error,
          ),
          'notFound' => NotFoundFailure(userMessage: message, original: error),
          'network' => NetworkFailure(userMessage: message, original: error),
          'conflict' => ConflictFailure(userMessage: message, original: error),
          _ => UnknownFailure(userMessage: message, original: error),
        };
      }
    } catch (_) {}

    if (error is FirebaseException) {
      return _mapFirebaseException(error);
    }

    return UnknownFailure(
      userMessage: 'An unexpected error occurred. Please try again.',
      original: error,
    );
  }

  static AppFailure _mapFirebaseException(FirebaseException exception) {
    final code = exception.code.trim().toLowerCase();
    final plugin = exception.plugin.trim().toLowerCase();

    // 1. Auth plugin errors & known auth codes
    if (plugin == 'firebase_auth' || _isAuthCode(code)) {
      switch (code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          return InvalidCredentialsFailure(
            userMessage: 'Invalid email or password. Please verify your credentials and try again.',
            code: code,
            original: exception,
          );
        case 'email-already-in-use':
          return EmailInUseFailure(
            userMessage: 'An account already exists with this email address.',
            code: code,
            original: exception,
          );
        case 'weak-password':
          return WeakPasswordFailure(
            userMessage: 'Password is too weak. Please choose a stronger password with at least 6 characters.',
            code: code,
            original: exception,
          );
        case 'too-many-requests':
          return RateLimitedFailure(
            userMessage:
                'Too many attempts. Please wait a moment before trying again.',
            code: code,
            original: exception,
          );
        case 'network-request-failed':
          return NetworkFailure(
            userMessage: 'Network connection failed. Please check your internet connection.',
            code: code,
            original: exception,
          );
        case 'user-disabled':
          return InvalidCredentialsFailure(
            userMessage:
                'This account has been disabled. Please contact support.',
            code: code,
            original: exception,
          );
        case 'requires-recent-login':
          return UnauthenticatedFailure(
            userMessage: 'Please sign in again to verify your identity before continuing.',
            code: code,
            original: exception,
          );
      }
    }

    // 2. Firestore plugin errors & known firestore codes
    if (plugin == 'cloud_firestore' || _isFirestoreCode(code)) {
      switch (code) {
        case 'permission-denied':
          return PermissionDeniedFailure(
            userMessage: 'You do not have permission to perform this action.',
            code: code,
            original: exception,
          );
        case 'unavailable':
          return UnavailableFailure(
            userMessage: 'The service is temporarily unavailable. Please try again shortly.',
            code: code,
            original: exception,
          );
        case 'not-found':
          return NotFoundFailure(
            userMessage: 'The requested record could not be found.',
            code: code,
            original: exception,
          );
        case 'already-exists':
          return ConflictFailure(
            userMessage: 'A record with this identifier already exists.',
            code: code,
            original: exception,
          );
        case 'deadline-exceeded':
          return TimeoutFailure(
            userMessage: 'The request took too long to complete. Please retry.',
            code: code,
            original: exception,
          );
        case 'aborted':
          return ConflictFailure(
            userMessage:
                'The operation was aborted due to a conflict. Please retry.',
            code: code,
            original: exception,
          );
        case 'resource-exhausted':
          return RateLimitedFailure(
            userMessage:
                'Resource quota exceeded. Please wait a moment and retry.',
            code: code,
            original: exception,
          );
        case 'failed-precondition':
          return ValidationFailure(
            userMessage: 'The operation could not be completed because the current state does not permit it.',
            code: code,
            original: exception,
          );
        case 'unauthenticated':
          return UnauthenticatedFailure(
            userMessage: 'You must be signed in to perform this operation.',
            code: code,
            original: exception,
          );
      }
    }

    // 3. Storage plugin errors & known storage codes
    if (plugin == 'firebase_storage' || _isStorageCode(code)) {
      switch (code) {
        case 'object-not-found':
          return NotFoundFailure(
            userMessage: 'The requested file could not be found.',
            code: code,
            original: exception,
          );
        case 'unauthorized':
          return PermissionDeniedFailure(
            userMessage:
                'You do not have permission to access or upload this file.',
            code: code,
            original: exception,
          );
        case 'canceled':
          return UnknownFailure(
            userMessage: 'The file transfer was canceled.',
            code: code,
            retryable: true,
            original: exception,
          );
        case 'quota-exceeded':
          return RateLimitedFailure(
            userMessage:
                'Storage space limit exceeded. Please contact support.',
            code: code,
            original: exception,
          );
        case 'retry-limit-exceeded':
          return UnavailableFailure(
            userMessage: 'The transfer timed out after several retries. Please check your connection and try again.',
            code: code,
            original: exception,
          );
      }
    }

    return UnknownFailure(
      userMessage: 'An error occurred while communicating with the service.',
      code: code.isEmpty ? 'unknown' : code,
      original: exception,
    );
  }

  static bool _isAuthCode(String code) => const {
    'invalid-credential',
    'user-not-found',
    'wrong-password',
    'email-already-in-use',
    'weak-password',
    'too-many-requests',
    'network-request-failed',
    'user-disabled',
    'requires-recent-login',
  }.contains(code);

  static bool _isFirestoreCode(String code) => const {
    'permission-denied',
    'unavailable',
    'not-found',
    'already-exists',
    'deadline-exceeded',
    'aborted',
    'resource-exhausted',
    'failed-precondition',
    'unauthenticated',
  }.contains(code);

  static bool _isStorageCode(String code) => const {
    'object-not-found',
    'unauthorized',
    'canceled',
    'quota-exceeded',
    'retry-limit-exceeded',
  }.contains(code);
}

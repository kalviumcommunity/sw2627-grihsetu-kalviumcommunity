import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/services/errors/app_failure.dart';
import 'package:grihsetu/services/errors/firebase_error_mapper.dart';
import 'package:grihsetu/services/errors/run_guarded.dart';

void main() {
  group('FirebaseErrorMapper Table Test', () {
    final authCases = <String, Type>{
      'invalid-credential': InvalidCredentialsFailure,
      'user-not-found': InvalidCredentialsFailure,
      'wrong-password': InvalidCredentialsFailure,
      'email-already-in-use': EmailInUseFailure,
      'weak-password': WeakPasswordFailure,
      'too-many-requests': RateLimitedFailure,
      'network-request-failed': NetworkFailure,
      'user-disabled': InvalidCredentialsFailure,
      'requires-recent-login': UnauthenticatedFailure,
    };

    for (final entry in authCases.entries) {
      test('maps auth code: ${entry.key}', () {
        final ex = FirebaseException(plugin: 'firebase_auth', code: entry.key);
        final failure = FirebaseErrorMapper.map(ex);
        expect(failure.runtimeType, equals(entry.value));
        expect(failure.userMessage.isNotEmpty, isTrue);
      });
    }

    final firestoreCases = <String, Type>{
      'permission-denied': PermissionDeniedFailure,
      'unavailable': UnavailableFailure,
      'not-found': NotFoundFailure,
      'already-exists': ConflictFailure,
      'deadline-exceeded': TimeoutFailure,
      'aborted': ConflictFailure,
      'resource-exhausted': RateLimitedFailure,
      'failed-precondition': ValidationFailure,
      'unauthenticated': UnauthenticatedFailure,
    };

    for (final entry in firestoreCases.entries) {
      test('maps firestore code: ${entry.key}', () {
        final ex = FirebaseException(
          plugin: 'cloud_firestore',
          code: entry.key,
        );
        final failure = FirebaseErrorMapper.map(ex);
        expect(failure.runtimeType, equals(entry.value));
      });
    }

    final storageCases = <String, Type>{
      'object-not-found': NotFoundFailure,
      'unauthorized': PermissionDeniedFailure,
      'canceled': UnknownFailure,
      'quota-exceeded': RateLimitedFailure,
      'retry-limit-exceeded': UnavailableFailure,
    };

    for (final entry in storageCases.entries) {
      test('maps storage code: ${entry.key}', () {
        final ex = FirebaseException(
          plugin: 'firebase_storage',
          code: entry.key,
        );
        final failure = FirebaseErrorMapper.map(ex);
        expect(failure.runtimeType, equals(entry.value));
      });
    }

    test('maps TimeoutException to TimeoutFailure', () {
      final failure = FirebaseErrorMapper.map(TimeoutException('Time expired'));
      expect(failure, isA<TimeoutFailure>());
      expect(failure.retryable, isTrue);
    });

    test('maps SocketException to NetworkFailure', () {
      final failure = FirebaseErrorMapper.map(
        const SocketException('Failed host lookup'),
      );
      expect(failure, isA<NetworkFailure>());
      expect(failure.retryable, isTrue);
    });

    test('maps unknown exception to UnknownFailure', () {
      final failure = FirebaseErrorMapper.map(Exception('Something strange'));
      expect(failure, isA<UnknownFailure>());
    });

    test('preserves existing AppFailure directly', () {
      const original = NetworkFailure();
      final mapped = FirebaseErrorMapper.map(original);
      expect(identical(mapped, original), isTrue);
    });
  });

  group('runGuarded Tests', () {
    test('succeeds without retry on first try', () async {
      int attempts = 0;
      final result = await runGuarded(() async {
        attempts++;
        return 'success';
      });
      expect(result, equals('success'));
      expect(attempts, equals(1));
    });

    test('does not retry non-retryable failure', () async {
      int attempts = 0;
      expect(
        () => runGuarded(() async {
          attempts++;
          throw const InvalidCredentialsFailure();
        }),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
      expect(attempts, equals(1));
    });

    test('retries retryable failure up to max retries then throws AppFailure with exponential backoff', () async {
      int attempts = 0;
      Object? capturedError;
      final recordedDelays = <Duration>[];

      try {
        await runGuarded<void>(
          () async {
            attempts++;
            throw const NetworkFailure();
          },
          retries: 2,
          delayFn: (delay) async {
            recordedDelays.add(delay);
          },
        );
      } catch (e) {
        capturedError = e;
      }

      expect(attempts, equals(3));
      expect(
        recordedDelays,
        equals([
          const Duration(milliseconds: 400),
          const Duration(milliseconds: 1200),
        ]),
      );
      expect(capturedError, isA<NetworkFailure>());
    });

    test(
      'retries retryable failure and succeeds before exhausting retries',
      () async {
        int attempts = 0;
        final recordedDelays = <Duration>[];

        final result = await runGuarded<String>(
          () async {
            attempts++;
            if (attempts == 1) {
              throw const NetworkFailure();
            }
            return 'recovered';
          },
          retries: 2,
          delayFn: (delay) async {
            recordedDelays.add(delay);
          },
        );

        expect(attempts, equals(2));
        expect(recordedDelays, equals([const Duration(milliseconds: 400)]));
        expect(result, equals('recovered'));
      },
    );
  });
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/core/enums/user_role.dart';
import 'package:grihsetu/core/models/user.dart';
import 'package:grihsetu/services/auth_failure.dart';

void main() {
  group('AppUser profile mapping', () {
    test('maps a valid Firestore role explicitly', () {
      final profile = AppUser.fromMap({
        'uid': 'uid-1',
        'displayName': 'Aman Verma',
        'email': 'aman@example.com',
        'role': 'technician',
      });

      expect(profile.uid, 'uid-1');
      expect(profile.role, UserRole.technician);
      expect(profile.isAuthorized, isTrue);
    });

    test('does not silently assign a role when role is missing', () {
      final profile = AppUser.fromMap({
        'uid': 'uid-2',
        'email': 'pending@example.com',
      });

      expect(profile.role, isNull);
      expect(profile.isAuthorized, isFalse);
      expect(profile.toMap(), isNot(contains('role')));
    });

    test('treats unsupported role values as unauthorized', () {
      final profile = AppUser.fromMap({
        'uid': 'uid-3',
        'email': 'unknown@example.com',
        'role': 'super_admin',
      });

      expect(profile.role, isNull);
      expect(profile.isAuthorized, isFalse);
    });
  });

  group('AuthFailure mapping', () {
    test('maps common auth codes without exposing Firebase messages', () {
      final failure = AuthFailure.fromAuthException(
        FirebaseAuthException(
          code: 'invalid-credential',
          message: 'internal credential detail',
        ),
      );

      expect(failure.code, AuthFailureCode.invalidCredentials);
      expect(failure.message, contains('email or password'));
      expect(failure.message, isNot(contains('internal credential detail')));
    });

    test('maps unknown auth codes to a safe fallback', () {
      final failure = AuthFailure.fromAuthException(
        FirebaseAuthException(code: 'new-firebase-code'),
      );

      expect(failure.code, AuthFailureCode.unknown);
      expect(failure.message, 'Something went wrong. Please try again.');
    });
  });
}

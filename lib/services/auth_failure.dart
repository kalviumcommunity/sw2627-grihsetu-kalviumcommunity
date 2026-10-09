import 'package:firebase_auth/firebase_auth.dart';

enum AuthFailureCode {
  invalidInput,
  invalidEmail,
  weakPassword,
  emailAlreadyInUse,
  userDisabled,
  invalidCredentials,
  tooManyRequests,
  operationNotAllowed,
  networkError,
  profileNotFound,
  roleNotAssigned,
  invalidRole,
  invalidProfile,
  permissionDenied,
  serviceUnavailable,
  profileBootstrapFailed,
  unauthenticated,
  unknown,
}

/// Stable application error returned by authentication/profile operations.
///
/// Firebase exception messages and credential details are intentionally not
/// exposed to presentation code.
class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final AuthFailureCode code;

  String get message => switch (code) {
    AuthFailureCode.invalidInput => 'Please check the required fields.',
    AuthFailureCode.invalidEmail => 'Enter a valid email address.',
    AuthFailureCode.weakPassword => 'Choose a stronger password.',
    AuthFailureCode.emailAlreadyInUse =>
      'An account already exists for this email.',
    AuthFailureCode.userDisabled => 'This account has been disabled.',
    AuthFailureCode.invalidCredentials => 'The email or password is incorrect.',
    AuthFailureCode.tooManyRequests =>
      'Too many attempts. Please wait and try again.',
    AuthFailureCode.operationNotAllowed =>
      'Email and password sign-in is not enabled.',
    AuthFailureCode.networkError =>
      'A network error occurred. Check your connection and try again.',
    AuthFailureCode.profileNotFound =>
      'Your account profile could not be found.',
    AuthFailureCode.roleNotAssigned =>
      'Your account is awaiting role assignment.',
    AuthFailureCode.invalidRole =>
      'Your account has an invalid or unsupported role.',
    AuthFailureCode.invalidProfile => 'Your account profile is invalid.',
    AuthFailureCode.permissionDenied =>
      'You do not have permission to access your profile.',
    AuthFailureCode.serviceUnavailable =>
      'The service is temporarily unavailable. Try again later.',
    AuthFailureCode.profileBootstrapFailed =>
      'Your account was created, but its profile could not be initialized.',
    AuthFailureCode.unauthenticated => 'Please sign in to continue.',
    AuthFailureCode.unknown => 'Something went wrong. Please try again.',
  };

  static AuthFailure fromAuthException(FirebaseAuthException exception) {
    return AuthFailure(_authCode(exception.code));
  }

  static AuthFailure fromFirestoreException(FirebaseException exception) {
    return AuthFailure(_firestoreCode(exception.code));
  }

  static AuthFailure fromUnknown(Object error) {
    if (error is FirebaseAuthException) {
      return fromAuthException(error);
    }
    if (error is FirebaseException) {
      return fromFirestoreException(error);
    }
    return const AuthFailure(AuthFailureCode.unknown);
  }

  @override
  String toString() => 'AuthFailure(${code.name})';
}

AuthFailureCode _authCode(String code) => switch (code) {
  'invalid-email' => AuthFailureCode.invalidEmail,
  'weak-password' => AuthFailureCode.weakPassword,
  'email-already-in-use' => AuthFailureCode.emailAlreadyInUse,
  'user-disabled' => AuthFailureCode.userDisabled,
  'wrong-password' ||
  'user-not-found' ||
  'invalid-credential' => AuthFailureCode.invalidCredentials,
  'too-many-requests' => AuthFailureCode.tooManyRequests,
  'operation-not-allowed' => AuthFailureCode.operationNotAllowed,
  'network-request-failed' => AuthFailureCode.networkError,
  _ => AuthFailureCode.unknown,
};

AuthFailureCode _firestoreCode(String code) => switch (code) {
  'permission-denied' => AuthFailureCode.permissionDenied,
  'unavailable' ||
  'deadline-exceeded' ||
  'aborted' ||
  'resource-exhausted' => AuthFailureCode.serviceUnavailable,
  'not-found' => AuthFailureCode.profileNotFound,
  _ => AuthFailureCode.unknown,
};

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/firestore_collections.dart';
import '../core/enums/user_role.dart';
import '../core/models/user.dart';
import 'auth_failure.dart';

/// Coordinates Firebase Authentication with the application user profile.
///
/// Firebase Auth is the identity source of truth. Firestore `users/{uid}` is
/// the application profile and role source of truth. Callers never provide a
/// role to [signIn] or [signUp].
/// Minimal identity boundary used by workflows that must derive actor IDs
/// from the authenticated Firebase session.
abstract interface class AuthenticatedUserProvider {
  User? get currentUser;
}

class AuthService implements AuthenticatedUserProvider {
  AuthService(this._auth, this._firestore);

  /// Creates a production service using the already initialized Firebase app.
  factory AuthService.firebase() =>
      AuthService(FirebaseAuth.instance, FirebaseFirestore.instance);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  /// Signs in to Firebase Authentication.
  ///
  /// Profile/role resolution is intentionally owned by [AuthGate] through
  /// the auth-state stream. Keeping it out of this method prevents a second
  /// profile read and avoids racing navigation with authorization errors.
  Future<void> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const AuthFailure(AuthFailureCode.invalidInput);
    }

    _log('login submission begins');
    try {
      _log('Firebase sign-in attempt begins');
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null || firebaseUser.uid.isEmpty) {
        _log('Firebase sign-in returned no authenticated user');
        throw const AuthFailure(AuthFailureCode.unknown);
      }
      _log('Firebase sign-in succeeded; uid=${firebaseUser.uid}');
      // AuthGate observes this session change and resolves the trusted
      // users/{uid} profile exactly once for this UID.
      return;
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      _logFirebaseError('Firebase sign-in failed', error);
      throw AuthFailure.fromAuthException(error);
    } on FirebaseException catch (error) {
      _logFirebaseError('Firebase sign-in failed', error);
      throw AuthFailure.fromFirestoreException(error);
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.unknown);
    }
  }

  /// Creates a Firebase account and a UID-keyed, unassigned profile.
  ///
  /// No authoritative role is accepted or written by this method. The
  /// trusted assignment process must add a role later. The returned profile
  /// is therefore not authorized until a subsequent profile load sees a
  /// valid role.
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
    String? phoneNumber,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const AuthFailure(AuthFailureCode.invalidInput);
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null || firebaseUser.uid.isEmpty) {
        throw const AuthFailure(AuthFailureCode.unknown);
      }

      final profileData = <String, dynamic>{
        'uid': firebaseUser.uid,
        'email': normalizedEmail,
        'displayName': _cleanOptional(displayName),
        'phoneNumber': _cleanOptional(phoneNumber),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }..removeWhere((key, value) => value == null);

      try {
        await _firestore
            .collection(FirestoreCollections.users)
            .doc(firebaseUser.uid)
            .set(profileData);
      } on FirebaseException catch (error) {
        await _signOutSafely();
        throw AuthFailure(
          error.code == 'permission-denied'
              ? AuthFailureCode.permissionDenied
              : AuthFailureCode.profileBootstrapFailed,
        );
      } catch (_) {
        await _signOutSafely();
        throw const AuthFailure(AuthFailureCode.profileBootstrapFailed);
      }

      return AppUser.fromMap(profileData, id: firebaseUser.uid);
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure.fromAuthException(error);
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.unknown);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure.fromAuthException(error);
    } on FirebaseException catch (error) {
      throw AuthFailure.fromFirestoreException(error);
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.unknown);
    }
  }

  /// Sends Firebase's password-reset email without revealing whether the
  /// address exists. The UI can therefore show the same confirmation for both
  /// existing and unknown accounts.
  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw const AuthFailure(AuthFailureCode.invalidInput);
    }

    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure.fromAuthException(error);
    } on FirebaseException catch (error) {
      throw AuthFailure.fromFirestoreException(error);
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.unknown);
    }
  }

  /// Loads and validates the profile for a Firebase UID.
  ///
  /// Missing documents, missing roles, unsupported roles, permission errors,
  /// and transient Firestore errors are deliberately distinct failures.
  Future<AppUser> loadProfile(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw const AuthFailure(AuthFailureCode.unauthenticated);
    }

    try {
      _log('Firestore profile fetch begins; uid=$normalizedUid');
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(normalizedUid)
          .get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        _log('Firestore profile fetch failed: profile-not-found');
        throw const AuthFailure(AuthFailureCode.profileNotFound);
      }

      final profileUid = data['uid'];
      if (profileUid is! String || profileUid != normalizedUid) {
        _log('Firestore profile fetch failed: invalid-profile-uid');
        throw const AuthFailure(AuthFailureCode.invalidProfile);
      }

      final rawRole = data['role'];
      if (rawRole == null || (rawRole is String && rawRole.trim().isEmpty)) {
        _log('Role resolution failed: role-not-assigned');
        throw const AuthFailure(AuthFailureCode.roleNotAssigned);
      }
      if (rawRole is! String || UserRole.tryFromValue(rawRole) == null) {
        _log('Role resolution failed: invalid-role');
        throw const AuthFailure(AuthFailureCode.invalidRole);
      }

      final profile = AppUser.fromMap(data, id: normalizedUid);
      if (!profile.isAuthorized) {
        _log('Role resolution failed: inactive-or-invalid-profile');
        throw const AuthFailure(AuthFailureCode.invalidProfile);
      }
      _log('Firestore profile fetch and role resolution succeeded');
      return profile;
    } on AuthFailure {
      rethrow;
    } on FirebaseException catch (error) {
      _logFirebaseError('Firestore profile fetch failed', error);
      throw AuthFailure.fromFirestoreException(error);
    } catch (_) {
      throw const AuthFailure(AuthFailureCode.unknown);
    }
  }

  Future<void> _signOutSafely() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Preserve the original authentication/profile failure.
    }
  }

  static String? _cleanOptional(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[Auth] $message');
  }

  static void _logFirebaseError(String stage, FirebaseException error) {
    if (!kDebugMode) return;
    debugPrint(
      '[Auth] $stage: code=${error.code}, message=${error.message ?? 'none'}',
    );
  }
}

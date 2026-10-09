import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const AuthFailure(AuthFailureCode.invalidInput);
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null || firebaseUser.uid.isEmpty) {
        throw const AuthFailure(AuthFailureCode.unknown);
      }

      try {
        return await loadProfile(firebaseUser.uid);
      } on AuthFailure {
        // Authentication succeeded, but authorization did not. Do not leave
        // an unusable authenticated session active in the client.
        await _signOutSafely();
        rethrow;
      }
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure.fromAuthException(error);
    } on FirebaseException catch (error) {
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
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(normalizedUid)
          .get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const AuthFailure(AuthFailureCode.profileNotFound);
      }

      final profileUid = data['uid'];
      if (profileUid is! String || profileUid != normalizedUid) {
        throw const AuthFailure(AuthFailureCode.invalidProfile);
      }

      final rawRole = data['role'];
      if (rawRole == null || (rawRole is String && rawRole.trim().isEmpty)) {
        throw const AuthFailure(AuthFailureCode.roleNotAssigned);
      }
      if (rawRole is! String || UserRole.tryFromValue(rawRole) == null) {
        throw const AuthFailure(AuthFailureCode.invalidRole);
      }

      final profile = AppUser.fromMap(data, id: normalizedUid);
      if (!profile.isAuthorized) {
        throw const AuthFailure(AuthFailureCode.invalidProfile);
      }
      return profile;
    } on AuthFailure {
      rethrow;
    } on FirebaseException catch (error) {
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
}
